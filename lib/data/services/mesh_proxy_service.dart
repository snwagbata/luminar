import 'dart:async';
import 'dart:typed_data';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/messages.dart';
import 'package:luminar/data/mesh/network.dart';
import 'package:luminar/data/mesh/proxy.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/data/services/timings.dart';

/// The network state the proxy link needs: keys, addresses and SEQ.
abstract interface class MeshKeyring {
  NetKeys get netKeys;

  /// Our own unicast address.
  int get src;
  int get iv;

  /// Called when a Secure Network Beacon from our network moves the IV index.
  void updateIv(int iv);
  Uint8List? deviceKey(int addr);

  /// A never-before-used sequence number.
  int nextSeq();
}

/// The proxy belongs to another mesh network.
class ForeignNetwork implements Exception {}

/// A decrypted access message addressed to us.
class AccessMessage {
  final int src;
  final Uint8List payload;
  const AccessMessage(this.src, this.payload);
}

/// One light's message for [MeshProxyService.sendEach].
typedef Target = ({int addr, List<int> access, bool subscribed});

class _Waiter {
  final bool Function(int src, Uint8List a) pred;
  final done = Completer<Uint8List?>();
  _Waiter(this.pred);
}

/// The GATT proxy connection into the mesh: network and transport layers,
/// request/reply matching and segment acknowledgements.
class MeshProxyService {
  MeshProxyService({
    required this._ble,
    required this._keys,
    required this._log,
    this.timings = const Timings(),
  });

  final BleService _ble;
  final MeshKeyring _keys;
  final ActivityLog _log;
  final Timings timings;

  MeshLink? _link;
  LinkWriter? _writer;
  StreamSubscription<Uint8List>? _rxSub;
  bool _ready = false;
  final _waiters = <_Waiter>{};
  final _assembler = SegmentAssembler();
  Completer<void>? _beaconWait;
  Completer<void>? _filterStatus;
  bool _beaconOurs = false, _beaconForeign = false;
  int _tid = DateTime.now().millisecondsSinceEpoch & 0xff;

  final _messages = StreamController<AccessMessage>.broadcast();
  final _lost = StreamController<void>.broadcast();

  /// Access messages from the mesh (statuses included).
  Stream<AccessMessage> get messages => _messages.stream;

  /// Emits when the link drops without [close] being called.
  Stream<void> get lost => _lost.stream;

  bool get isOpen => _link != null && _ready;
  String? get deviceId => _link?.id;

  /// A fresh transaction identifier for state-changing messages.
  int nextTid() => _tid = (_tid + 1) & 0xff;

  // ---------- connection ----------

  /// Opens the proxy service on [id], checks it belongs to our network and
  /// sets the proxy filter so every reply reaches us.
  /// Throws [ForeignNetwork] if the proxy is on another network.
  Future<void> open(String id, {bool fresh = false}) async {
    if (isOpen && _link?.id == id) return; // already connected to it
    // Never open a second connection to a device we still hold a link to.
    if (_link?.id == id) _drop();
    _log.add('Connecting to $id (${MeshService.proxy.name}${fresh ? ', fresh' : ''})');
    final link = await _ble.connect(id, MeshService.proxy, fresh: fresh);
    _log.add('Connected to $id, writes up to ${link.maxChunk} bytes');
    _beaconOurs = false;
    _beaconForeign = false;
    final beacon = _beaconWait = Completer<void>();
    // Kept in _rxSub and cancelled by _drop().
    // ignore: cancel_subscriptions
    final sub = link.notifications.listen(ProxyReassembler(_onProxyPdu).add);
    // Replacing another proxy link: its done-handler ignores stale links.
    if (_link != null && _link != link) _drop();
    _link = link;
    _rxSub = sub;
    _writer = LinkWriter(link);
    unawaited(
      link.done.then((_) {
        if (_link == link) {
          _log.add('Disconnected');
          _drop();
          _lost.add(null);
        }
      }),
    );
    // Accept list with our own address, as nRF Mesh does: the Sengled
    // proxies forward nothing under an (empty) reject list. Only a proxy on
    // our network can decrypt this and answer with Filter Status, so the
    // answer proves the proxy is ours. The Sengled bulbs send no beacons, so
    // do not wait for one; a beacon from another network ends the wait early.
    final status = _filterStatus = Completer<void>();
    await _sendProxyConfig([0x00, 0x00]); // Set Filter Type: accept list
    await _sendProxyConfig([0x01, ...be(_keys.src, 2)]); // Add Addresses
    final answered = await Future.any([
      status.future.then((_) => true),
      beacon.future.then((_) => _beaconOurs),
      Future<bool>.delayed(timings.beacon, () => false),
    ]);
    _filterStatus = null;
    _beaconWait = null;
    if (_beaconForeign && !_beaconOurs) {
      _log.add('$id is on another network');
      _drop();
      throw ForeignNetwork();
    }
    if (!answered && !_beaconOurs) {
      _log.add('$id did not answer with our network key');
      _drop();
      throw ForeignNetwork();
    }
    _ready = true;
    _log.add('Proxy ready via $id');
  }

  /// Closes the link. Does not emit [lost].
  Future<void> close() async => _drop();

  void _drop() {
    final link = _link;
    _rxSub?.cancel();
    _rxSub = null;
    _link = null;
    _writer = null;
    _ready = false;
    for (final w in [..._waiters]) {
      w.done.complete(null);
    }
    _waiters.clear();
    if (link != null) link.disconnect().catchError((_) {});
  }

  void dispose() {
    _drop();
    _messages.close();
    _lost.close();
  }

  // ---------- sending ----------

  Future<void> _proxySend(int type, Uint8List pdu) {
    final w = _writer;
    if (w == null) throw StateError('Not connected');
    return w.writeAll(proxyChunks(type, pdu, maxChunk: w.link.maxChunk));
  }

  Future<void> _sendNetwork(List<TransportPdu> pdus, int dst) async {
    for (final p in pdus) {
      final pdu = buildNetworkPdu(
        _keys.netKeys,
        ctl: false,
        ttl: 7,
        seq: p.seq,
        src: _keys.src,
        dst: dst,
        transport: p.transport,
        iv: _keys.iv,
      );
      _log.add('→ net seq=${p.seq} dst=${hex16(dst)} ${toHex(p.transport)}');
      await _proxySend(ProxyType.network, pdu);
    }
  }

  /// Sends an access message, with the AppKey or (for configuration
  /// messages) [dst]'s DeviceKey.
  Future<AccessSegments> send(int dst, List<int> access, {bool device = false}) async {
    if (_link == null) throw StateError('Not connected');
    final AccessKey key;
    if (device) {
      final dk = _keys.deviceKey(dst);
      if (dk == null) throw StateError('No device key for ${hex16(dst)}');
      key = AccessKey.device(dk);
    } else {
      key = AccessKey.app(_keys.netKeys);
    }
    _log.add('→ ${device ? 'dev' : 'app'} ${hex16(dst)} ${toHex(access)}');
    final r = buildAccessSegments(
      key,
      seqs: _keys.nextSeq,
      src: _keys.src,
      dst: dst,
      iv: _keys.iv,
      access: access,
    );
    await _sendNetwork(r.pdus, dst);
    return r;
  }

  /// Sends each target its message: once to [group] for the subscribed
  /// targets that share the first subscribed target's message (every bulb
  /// acts on the same broadcast, together), and directly to the rest.
  Future<void> sendEach(int group, List<Target> targets) async {
    final subscribed = [
      for (final t in targets)
        if (t.subscribed) t,
    ];
    final shared = subscribed.isEmpty ? null : subscribed.first.access;
    final viaGroup = {
      for (final t in subscribed)
        if (bytesEqual(t.access, shared!)) t.addr,
    };
    if (shared != null) await send(group, shared);
    for (final t in targets) {
      if (!viaGroup.contains(t.addr)) await send(t.addr, t.access);
    }
  }

  Future<void> _sendControl(int dst, List<int> transport) async {
    final seq = _keys.nextSeq();
    final pdu = buildNetworkPdu(
      _keys.netKeys,
      ctl: true,
      ttl: 7,
      seq: seq,
      src: _keys.src,
      dst: dst,
      transport: transport,
      iv: _keys.iv,
    );
    _log.add('→ ctl seq=$seq dst=${hex16(dst)} ${toHex(transport)}');
    await _proxySend(ProxyType.network, pdu);
  }

  Future<void> _sendProxyConfig(List<int> payload) async {
    final seq = _keys.nextSeq();
    final pdu = buildNetworkPdu(
      _keys.netKeys,
      ctl: true,
      ttl: 0,
      seq: seq,
      src: _keys.src,
      dst: 0,
      transport: payload,
      iv: _keys.iv,
      proxy: true,
    );
    _log.add('→ proxy config ${toHex(payload)}');
    await _proxySend(ProxyType.config, pdu);
  }

  Future<Uint8List?> _waitFor(bool Function(int src, Uint8List a) pred, Duration timeout) {
    final w = _Waiter(pred);
    _waiters.add(w);
    Timer(timeout, () {
      if (_waiters.remove(w)) w.done.complete(null);
    });
    return w.done.future;
  }

  /// Sends a request and waits for the first reply matching [pred],
  /// retrying. Returns null if none arrives.
  Future<Uint8List?> ask(
    int dst,
    List<int> access,
    bool Function(int src, Uint8List a) pred, {
    bool device = false,
    int tries = 3,
    Duration? timeout,
  }) async {
    final t = timeout ?? timings.configReply;
    for (var i = 0; i < tries && _link != null; i++) {
      final wait = _waitFor(pred, t);
      final r = await send(dst, access, device: device);
      var reply = await wait;
      if (reply != null) return reply;
      final resend = r.resend;
      if (resend != null && _link != null) {
        // Segmented: resend the same segments with fresh sequence numbers.
        _log.add('No reply; resending segments (SeqZero ${r.seq0 & 0x1fff})');
        final wait2 = _waitFor(pred, t);
        await _sendNetwork(resend(), dst);
        reply = await wait2;
        if (reply != null) return reply;
      }
    }
    return null;
  }

  /// Sends an AppKey request to [dst] and waits for a reply with [replyOp].
  Future<Uint8List?> request(int dst, List<int> access, int replyOp, {int tries = 2}) async {
    try {
      return await ask(dst, access, (s, a) => s == dst && opcodeOf(a) == replyOp, tries: tries);
    } catch (e) {
      _log.add('Request failed: $e');
      return null;
    }
  }

  // ---------- receiving ----------

  void _onProxyPdu(int type, Uint8List data) {
    try {
      switch (type) {
        case ProxyType.beacon:
          _onBeacon(data);
        case ProxyType.network:
          _onNetwork(data);
        case ProxyType.config:
          final msg = decodeNetworkPdu(_keys.netKeys, data, _keys.iv, proxy: true);
          final w = _filterStatus;
          if (msg != null && msg.transport.isNotEmpty && msg.transport[0] == 0x03) {
            if (w != null && !w.isCompleted) w.complete();
          }
          _log.add(
            msg == null
                ? '← proxy config NOT decodable with our network key: ${toHex(data)}'
                : '← proxy config from ${hex16(msg.src)} ${toHex(msg.transport)}',
          );
        default:
          _log.add('← proxy type $type ${toHex(data)}');
      }
    } catch (e) {
      _log.add('Bad incoming PDU: $e');
    }
  }

  void _onBeacon(Uint8List data) {
    final b = SecureBeacon.parse(data);
    if (b == null) {
      _log.add('← beacon (not a secure network beacon) ${toHex(data)}');
      return;
    }
    final ours = bytesEqual(b.networkId, _keys.netKeys.networkId);
    _log.add('← beacon ${ours ? 'ours' : 'foreign network'} iv=${b.ivIndex} flags=${b.flags}');
    if (ours) {
      _beaconOurs = true;
      if (b.txIv != _keys.iv && b.txIv >= 0) _keys.updateIv(b.txIv);
    } else {
      _beaconForeign = true;
    }
    final w = _beaconWait;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _onNetwork(Uint8List data) {
    final msg = decodeNetworkPdu(_keys.netKeys, data, _keys.iv);
    if (msg == null) {
      _log.add('← net (not decodable with our keys) ${toHex(data)}');
      return;
    }
    final t = msg.transport;
    if (msg.ctl) {
      // Control messages: segment acknowledgements (opcode 0) and others.
      final op = t[0] & 0x7f;
      if (op == 0 && t.length >= 7) {
        final seqZero = ((t[1] & 0x7f) << 6) | (t[2] >> 2);
        _log.add(
          '← ${hex16(msg.src)} segment ack SeqZero $seqZero '
          'blocks 0x${rd(t, 3, 4).toRadixString(16)}',
        );
      } else {
        _log.add('← ${hex16(msg.src)} control op 0x${op.toRadixString(16)} ${toHex(t)}');
      }
      return;
    }
    final segmented = t[0] & 0x80 != 0;
    final a = segmented
        ? _assembler.add(msg, _keys.netKeys, _keys.deviceKey)
        : openAccess(msg, _keys.netKeys, _keys.deviceKey);
    if (segmented && a != null && msg.dst == _keys.src) {
      // Otherwise the sender keeps retransmitting the whole message.
      unawaited(_sendControl(msg.src, segmentAckFor(t)).catchError((_) {}));
    }
    if (a != null && a.isNotEmpty) {
      _log.add('← ${hex16(msg.src)} ${toHex(a)}');
      _onAccess(msg.src, a);
    } else if (segmented) {
      _log.add('← ${hex16(msg.src)} segment seq=${msg.seq} ${toHex(t)}');
    } else {
      _log.add(
        '← ${hex16(msg.src)} access not decryptable '
        '(${t[0] & 0x40 != 0 ? 'app key aid ${t[0] & 0x3f}' : 'device key'}) seq=${msg.seq}',
      );
    }
  }

  void _onAccess(int src, Uint8List a) {
    for (final w in [..._waiters]) {
      if (w.pred(src, a)) {
        _waiters.remove(w);
        w.done.complete(a);
      }
    }
    _messages.add(AccessMessage(src, a));
  }
}
