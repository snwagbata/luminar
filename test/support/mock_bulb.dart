import 'dart:async';
import 'dart:typed_data';

import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/crypto.dart';
import 'package:luminar/data/mesh/messages.dart';
import 'package:luminar/data/mesh/network.dart';
import 'package:luminar/data/mesh/provisioning.dart';
import 'package:luminar/data/mesh/proxy.dart';

/// A simulated Sengled bulb: the device side of PB-GATT and the mesh proxy.
/// Ported from reference/mock-bulb.js.
class MockBulb {
  final String id;
  final String name;
  int rssi;

  bool provisioned = false;
  Uint8List? netKey, devKey, appKey;
  int addr = 0;
  int iv = 0;
  int seq = 1;
  final bound = <int>{};

  /// Group addresses each model is subscribed to (model id -> groups).
  final subscriptions = <int, Set<int>>{};

  /// The other bulbs in radio range, which hear what this one relays.
  List<MockBulb> meshPeers = const [];

  /// Network PDUs the phone wrote to this bulb's proxy link.
  int fromPhone = 0;
  bool on = false;
  int lightness = 30000, kelvin = 3000;

  /// Test knobs.
  bool dropFirstSegmented = false;

  /// SeqZeros of our segmented replies the app acknowledged.
  final acked = <int>[];
  bool _dropped = false;

  /// Fail the first proxy connection after provisioning, like Android's
  /// stale GATT cache, unless the caller asks for a fresh service table.
  bool staleGattCacheAfterProvisioning = false;
  bool _justProvisioned = false;

  final received = <String>[];

  // Scenes, CTL setup, scheduler.
  final scenes = <int, (int, int)>{}; // scene -> (lightness, kelvin)
  int currentScene = 0;
  int rangeMin = 2700, rangeMax = 6500;
  int defaultLightness = 65535, defaultKelvin = 3000;
  final schedule = <int, List<int>>{}; // index -> 10 bytes

  /// Models reported in Composition Data (element 0), as seen on BLE Bulb_ACF1.
  List<int> sigModels = [0x0000, 0x1000, 0x1300, 0x1303, 0x1304, 0x1203, 0x1204, 0x1206, 0x1207];
  bool answersComposition = true;
  bool answersAppKeyAdd = true;

  /// The Sengled bulbs never send Secure Network Beacons over the proxy.
  bool sendsBeacon = true;

  MockBulb(this.id, this.name, {this.rssi = -60});

  /// A bulb already provisioned into someone else's network.
  factory MockBulb.foreign(String id, String name) {
    final b = MockBulb(id, name)
      ..provisioned = true
      ..netKey = randomBytes(16)
      ..devKey = randomBytes(16)
      ..addr = 3;
    return b;
  }

  /// Node Identity service data while provisioned, like the real bulbs.
  Uint8List? proxyAdvert() =>
      provisioned && advertiseIdentity ? nodeIdentityAdvert(_net, randomBytes(8), addr) : null;
  bool advertiseIdentity = true;

  MeshService get advertises => provisioned ? MeshService.proxy : MeshService.provisioning;

  NetKeys get _net => NetKeys.derive(netKey!, appKey ?? Uint8List(16));

  // ---------- link ----------
  _MockLink? _link;

  MeshLink open(MeshService svc, {required bool fresh}) {
    if (svc == MeshService.provisioning && provisioned) throw ServiceNotFound();
    if (svc == MeshService.proxy && !provisioned) throw ServiceNotFound();
    if (svc == MeshService.proxy && _justProvisioned) {
      _justProvisioned = false;
      if (staleGattCacheAfterProvisioning && !fresh) throw ServiceNotFound();
    }
    // Secure Network Beacon when notifications start.
    final link = _link = _MockLink(
      id,
      this,
      onListen: svc == MeshService.proxy && sendsBeacon
          ? () => scheduleMicrotask(
              () => _notify(
                ProxyType.beacon,
                cat([
                  [1, 0],
                  _net.networkId,
                  be(iv, 4),
                  Uint8List(8),
                ]),
              ),
            )
          : null,
    );
    _rx = ProxyReassembler(_onChunk);
    _acceptList = true;
    _filter.clear();
    _prov = _ProvState();
    return link;
  }

  // Proxy output filter. Per the spec a new connection starts with an empty
  // accept list, so nothing is forwarded until the client configures it.
  bool _acceptList = true;
  final _filter = <int>{};

  /// false models the Sengled bulbs: a reject list forwards nothing.
  bool honorsRejectList = true;

  bool _forwards(int dst) =>
      _acceptList ? _filter.contains(dst) : (honorsRejectList && !_filter.contains(dst));

  void _notify(int type, List<int> pdu, {int? dst}) {
    final l = _link;
    if (l == null || l.closed) {
      // Not the phone's proxy: reach it over the mesh.
      if (type != ProxyType.network) return;
      for (final p in meshPeers) {
        final pl = p._link;
        if (p != this && pl != null && !pl.closed) p._notify(type, pdu, dst: dst);
      }
      return;
    }
    if (type == ProxyType.network && dst != null && !_forwards(dst)) return;
    for (final c in proxyChunks(type, pdu, maxChunk: 20)) {
      l.notes.add(c);
    }
  }

  late ProxyReassembler _rx;
  late _ProvState _prov;

  void _onChunk(int type, Uint8List d) {
    if (type == ProxyType.provisioning) {
      _onProv(d);
    } else if (type == ProxyType.network) {
      _onNetwork(d);
    } else if (type == ProxyType.config) {
      received.add('proxy config');
      // Real proxies answer Set Filter Type with Filter Status, but only
      // when the message decrypts with their NetKey.
      final msg = decodeNetworkPdu(_net, d, iv, proxy: true);
      if (msg == null || msg.transport.isEmpty) return;
      final t = msg.transport;
      switch (t[0]) {
        case 0x00: // Set Filter Type
          _acceptList = t[1] == 0x00;
          _filter.clear();
        case 0x01: // Add Addresses
          for (var i = 1; i + 1 < t.length; i += 2) {
            _filter.add(rd(t, i, 2));
          }
        case 0x02: // Remove Addresses
          for (var i = 1; i + 1 < t.length; i += 2) {
            _filter.remove(rd(t, i, 2));
          }
        default:
          return;
      }
      _notify(
        ProxyType.config,
        buildNetworkPdu(
          _net,
          ctl: true,
          ttl: 0,
          seq: seq++,
          src: addr,
          dst: 0,
          transport: [0x03, _acceptList ? 0 : 1, ...be(_filter.length, 2)],
          iv: iv,
          proxy: true,
        ),
      );
    }
  }

  // ---------- provisioning ----------
  void _sendProv(List<int> b) => _notify(ProxyType.provisioning, b);

  void _onProv(Uint8List d) {
    final type = d[0], p = d.sublist(1);
    final s = _prov;
    switch (type) {
      case ProvPdu.invite:
        s.invite = p;
        s.caps = Uint8List.fromList([1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]);
        _sendProv([ProvPdu.capabilities, ...s.caps!]);
      case ProvPdu.start:
        s.start = p;
      case ProvPdu.publicKey:
        s.pubP = p;
        final kp = EcdhKeyPair.generate();
        s.pubD = kp.publicKey;
        s.secret = kp.sharedSecret(p);
        _sendProv([ProvPdu.publicKey, ...s.pubD!]);
      case ProvPdu.confirmation:
        s.confP = p;
        s.ck = Prov.confirmationKey(
          s.secret!,
          cat([s.invite!, s.caps!, s.start!, s.pubP!, s.pubD!]),
        );
        s.randD = randomBytes(16);
        _sendProv([ProvPdu.confirmation, ...Prov.confirmation(s.ck!.key, s.randD!, Uint8List(16))]);
      case ProvPdu.random:
        if (!bytesEqual(Prov.confirmation(s.ck!.key, p, Uint8List(16)), s.confP!)) {
          _sendProv([ProvPdu.failed, 4]);
          return;
        }
        s.randP = p;
        _sendProv([ProvPdu.random, ...s.randD!]);
      case ProvPdu.data:
        final ses = Prov.session(s.secret!, s.ck!.salt, s.randP!, s.randD!);
        final data = ccmDecrypt(ses.key, ses.nonce, p, 8);
        if (data == null) {
          _sendProv([ProvPdu.failed, 6]);
          return;
        }
        netKey = data.sublist(0, 16);
        iv = rd(data, 19, 4);
        addr = rd(data, 23, 2);
        devKey = ses.devKey;
        provisioned = true;
        _justProvisioned = true;
        _sendProv([ProvPdu.complete]);
    }
  }

  // ---------- network ----------
  final _asm = SegmentAssembler();

  void _onNetwork(Uint8List pdu, {bool fromProxy = true}) {
    final msg = decodeNetworkPdu(_net, pdu, iv);
    if (msg == null) return;
    if (fromProxy) {
      fromPhone++;
      // Relay to the rest of the mesh (the ADV bearer).
      if (msg.dst != addr) {
        for (final p in meshPeers) {
          if (p != this && p.provisioned) p._onNetwork(pdu, fromProxy: false);
        }
      }
    }
    final forUs = msg.dst == addr || subscriptions.values.any((g) => g.contains(msg.dst));
    if (!forUs) return;
    if (msg.ctl) {
      final t = msg.transport;
      if (t[0] & 0x7f == 0 && t.length == 7) {
        acked.add(((t[1] & 0x7f) << 6) | (t[2] >> 2)); // Segment Acknowledgment
      }
      return;
    }
    final seg = msg.transport[0] & 0x80 != 0;
    final a = seg
        ? _asm.add(msg, appKey == null ? null : _net, (_) => devKey)
        : openAccess(msg, appKey == null ? null : _net, (_) => devKey);
    if (a == null) return;
    if (seg && dropFirstSegmented && !_dropped) {
      _dropped = true;
      received.add('dropped segmented');
      return;
    }
    _onAccess(msg.src, a, isDev: msg.transport[0] & 0x40 == 0, dst: msg.dst);
  }

  /// Whether [model] handles an app-key message sent to [dst].
  bool _accepts(int model, int dst) =>
      bound.contains(model) && (dst == addr || (subscriptions[model]?.contains(dst) ?? false));

  void _reply(int dst, List<int> access, {bool dev = false}) {
    final net = _net;
    final r = buildAccessSegments(
      dev ? AccessKey.device(devKey!) : AccessKey.app(net),
      seqs: () => seq++,
      src: addr,
      dst: dst,
      iv: iv,
      access: access,
    );
    for (final p in r.pdus) {
      _notify(
        ProxyType.network,
        buildNetworkPdu(
          net,
          ctl: false,
          ttl: 7,
          seq: p.seq,
          src: addr,
          dst: dst,
          transport: p.transport,
          iv: iv,
        ),
        dst: dst,
      );
    }
  }

  void _onAccess(int src, Uint8List a, {required bool isDev, required int dst}) {
    final op = opcodeOf(a);
    received.add('${isDev ? 'dev' : 'app'} ${op.toRadixString(16)}');
    if (op == Op.appKeyAdd && isDev) {
      if (!answersAppKeyAdd) return;
      appKey = a.sublist(4, 20);
      _reply(src, [0x80, 0x03, 0, ...a.sublist(1, 4)], dev: true);
    } else if (op == Op.modelAppBind && isDev) {
      bound.add(u16le(a, 6));
      _reply(src, [0x80, 0x3E, 0, ...a.sublist(2, 8)], dev: true);
    } else if (op == Op.modelSubscriptionAdd && isDev) {
      subscriptions.putIfAbsent(u16le(a, 6), () => {}).add(u16le(a, 4));
      _reply(src, [0x80, 0x1F, 0, ...a.sublist(2, 8)], dev: true);
    } else if (op == Op.nodeReset && isDev) {
      _reply(src, [0x80, 0x4A], dev: true);
      provisioned = false;
      appKey = null;
      bound.clear();
      subscriptions.clear();
    } else if (op == Op.compositionGet && isDev) {
      if (!answersComposition) return;
      _reply(src, [
        0x02, 0, // opcode, page
        ...le16(0x0000), ...le16(0x0001), ...le16(0x0001), ...le16(10), ...le16(0x0003),
        ...le16(0), sigModels.length, 1,
        for (final m in sigModels) ...le16(m),
        ...le16(0x0504), ...le16(0x0000),
      ], dev: true);
    } else if (!isDev && op == Op.sceneStore && bound.contains(Models.sceneSetup)) {
      final n = u16le(a, 2);
      scenes[n] = (lightness, kelvin);
      currentScene = n;
      _replySceneRegister(src);
    } else if (!isDev && op == Op.sceneDelete && bound.contains(Models.sceneSetup)) {
      scenes.remove(u16le(a, 2));
      _replySceneRegister(src);
    } else if (!isDev && op == Op.sceneRegisterGet && bound.contains(Models.scene)) {
      _replySceneRegister(src);
    } else if (!isDev &&
        (op == Op.sceneRecallUnack || op == Op.sceneRecall) &&
        _accepts(Models.scene, dst)) {
      final n = u16le(a, 2);
      final st = scenes[n];
      if (st != null) {
        lightness = st.$1;
        kelvin = st.$2;
        on = lightness > 0;
        currentScene = n;
      }
      if (op == Op.sceneRecall) _reply(src, [0x5E, st == null ? 2 : 0, ...le16(currentScene)]);
    } else if (!isDev && op == Op.ctlTempRangeGet && bound.contains(Models.ctl)) {
      _reply(src, [0x82, 0x63, 0, ...le16(rangeMin), ...le16(rangeMax)]);
    } else if (!isDev && op == Op.ctlTempRangeSet && bound.contains(Models.ctlSetup)) {
      rangeMin = u16le(a, 2);
      rangeMax = u16le(a, 4);
      _reply(src, [0x82, 0x63, 0, ...le16(rangeMin), ...le16(rangeMax)]);
    } else if (!isDev && op == Op.ctlDefaultGet && bound.contains(Models.ctl)) {
      _reply(src, [0x82, 0x68, ...le16(defaultLightness), ...le16(defaultKelvin), 0, 0]);
    } else if (!isDev && op == Op.ctlDefaultSet && bound.contains(Models.ctlSetup)) {
      defaultLightness = u16le(a, 2);
      defaultKelvin = u16le(a, 4);
      _reply(src, [0x82, 0x68, ...le16(defaultLightness), ...le16(defaultKelvin), 0, 0]);
    } else if (!isDev && op == Op.schedulerGet && bound.contains(Models.scheduler)) {
      var bits = 0;
      for (final i in schedule.keys) {
        bits |= 1 << i;
      }
      _reply(src, [0x82, 0x4A, ...le16(bits)]);
    } else if (!isDev && op == Op.schedulerActionSet && bound.contains(Models.schedulerSetup)) {
      final p = a.sublist(1, 11);
      schedule[p[0] & 0x0f] = p;
      _reply(src, [0x5F, ...p]);
    } else if (!isDev && op == Op.schedulerActionGet && bound.contains(Models.scheduler)) {
      _reply(src, [
        0x5F,
        ...(schedule[a[2]] ?? [a[2], ...List.filled(9, 0)]),
      ]);
    } else if (!isDev && op == Op.onOffGet && bound.contains(Models.onOff)) {
      _reply(src, [0x82, 0x04, on ? 1 : 0]);
    } else if (!isDev && op == Op.onOffSetUnack && _accepts(Models.onOff, dst)) {
      on = a[2] != 0;
    } else if (!isDev && op == Op.ctlGet && bound.contains(Models.ctl)) {
      _reply(src, [0x82, 0x60, ...le16(lightness), ...le16(kelvin)]);
    } else if (!isDev && op == Op.ctlSetUnack && _accepts(Models.ctl, dst)) {
      lightness = u16le(a, 2);
      kelvin = u16le(a, 4);
      on = lightness > 0;
    }
  }

  void _replySceneRegister(int src) =>
      _reply(src, [0x82, 0x45, 0, ...le16(currentScene), for (final n in scenes.keys) ...le16(n)]);

  void dropConnection() => _link?.close();

  /// Five quick off/on cycles: forgets the network and advertises as a new
  /// bulb again (same Bluetooth address and name).
  void factoryReset() {
    dropConnection();
    provisioned = false;
    netKey = devKey = appKey = null;
    addr = 0;
    seq = 1;
    bound.clear();
    subscriptions.clear();
    scenes.clear();
  }
}

class _ProvState {
  Uint8List? invite, caps, start, pubP, pubD, secret, confP, randD, randP;
  ConfirmationKey? ck;
}

class _MockLink implements MeshLink {
  @override
  final String id;
  final MockBulb bulb;
  final StreamController<Uint8List> notes;
  final _done = Completer<void>();
  bool closed = false;
  _MockLink(this.id, this.bulb, {void Function()? onListen})
    : notes = StreamController<Uint8List>.broadcast(onListen: onListen);

  @override
  int get maxChunk => 20;
  @override
  Stream<Uint8List> get notifications => notes.stream;
  @override
  Future<void> get done => _done.future;

  @override
  Future<void> write(Uint8List chunk) async {
    if (closed) throw StateError('disconnected');
    // Deliver asynchronously, like a radio.
    scheduleMicrotask(() => bulb._rx.add(chunk));
  }

  void close() {
    if (closed) return;
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> disconnect() async => close();
}

class FakeBle implements BleService {
  final List<MockBulb> bulbs;
  final connects = <String>[];
  int scans = 0;

  /// If set, scans emit these lists in turn instead of the bulbs.
  List<List<FoundBulb>>? scanScript;
  FakeBle(this.bulbs) {
    _joinMesh();
  }

  /// Puts every bulb in radio range of the others, including bulbs a test
  /// added after construction.
  void _joinMesh() {
    for (final b in bulbs) {
      b.meshPeers = bulbs;
    }
  }

  @override
  Future<void> ensureReady() async {}

  @override
  Stream<List<FoundBulb>> scan(Set<MeshService> services, {Duration? timeout}) async* {
    scans++;
    _joinMesh();
    if (scanScript case final script?) {
      for (final list in script) {
        yield list;
      }
      return;
    }
    yield [
      for (final b in bulbs)
        if (services.contains(b.advertises))
          FoundBulb(b.id, b.name, b.rssi, b.advertises, proxyData: b.proxyAdvert()),
    ]..sort((a, b) => b.rssi - a.rssi);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<MeshLink> connect(String id, MeshService service, {bool fresh = false}) async {
    connects.add('$id ${service.name}${fresh ? ' fresh' : ''}');
    _joinMesh();
    return bulbs.firstWhere((b) => b.id == id).open(service, fresh: fresh);
  }
}
