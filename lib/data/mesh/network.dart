import 'dart:typed_data';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/crypto.dart';

/// Keys derived from the network's NetKey and AppKey.
class NetKeys {
  final Uint8List netKey;
  final int nid;
  final Uint8List encKey;
  final Uint8List privKey;
  final Uint8List networkId;
  final Uint8List appKey;
  final int aid;

  NetKeys._(
    this.netKey,
    this.nid,
    this.encKey,
    this.privKey,
    this.networkId,
    this.appKey,
    this.aid,
  );

  factory NetKeys.derive(Uint8List netKey, Uint8List appKey) {
    final d = k2(netKey, [0]);
    return NetKeys._(netKey, d.nid, d.encKey, d.privKey, k3(netKey), appKey, k4(appKey));
  }
}

/// A decrypted network PDU.
class NetworkMessage {
  final bool ctl;
  final int ttl, seq, src, dst, iv;
  final Uint8List transport;
  NetworkMessage(this.ctl, this.ttl, this.seq, this.src, this.dst, this.iv, this.transport);
}

Uint8List _pecb(NetKeys net, int iv, List<int> enc) => aes(
  net.privKey,
  cat([
    [0, 0, 0, 0, 0],
    be(iv, 4),
    enc.sublist(0, 7),
  ]),
);

/// Builds an obfuscated, encrypted network PDU.
/// Use [ctl] for control and proxy configuration messages, and [proxy] for
/// proxy configuration (proxy nonce, TTL 0, DST 0).
Uint8List buildNetworkPdu(
  NetKeys net, {
  required bool ctl,
  required int ttl,
  required int seq,
  required int src,
  required int dst,
  required List<int> transport,
  required int iv,
  bool proxy = false,
}) {
  final micLen = ctl ? 8 : 4;
  final ctlTtl = ((ctl ? 1 : 0) << 7) | (ttl & 0x7f);
  final nonce = proxy
      ? cat([
          [3, 0],
          be(seq, 3),
          be(src, 2),
          [0, 0],
          be(iv, 4),
        ])
      : cat([
          [0, ctlTtl],
          be(seq, 3),
          be(src, 2),
          [0, 0],
          be(iv, 4),
        ]);
  final enc = ccmEncrypt(net.encKey, nonce, cat([be(dst, 2), transport]), micLen);
  final obf = xor(
    cat([
      [ctlTtl],
      be(seq, 3),
      be(src, 2),
    ]),
    _pecb(net, iv, enc).sublist(0, 6),
  );
  return cat([
    [((iv & 1) << 7) | net.nid],
    obf,
    enc,
  ]);
}

/// Decrypts a network PDU sent on our network, or returns null.
/// Pass [proxy] for proxy configuration messages, which use the proxy nonce.
NetworkMessage? decodeNetworkPdu(NetKeys net, List<int> pdu, int ivCurrent, {bool proxy = false}) {
  if (pdu.length < 14 || (pdu[0] & 0x7f) != net.nid) return null;
  final iv = (pdu[0] >> 7) == (ivCurrent & 1) ? ivCurrent : ivCurrent - 1;
  if (iv < 0) return null;
  final enc = pdu.sublist(7);
  final hdr = xor(pdu.sublist(1, 7), _pecb(net, iv, enc).sublist(0, 6));
  final ctl = hdr[0] >> 7 == 1;
  final nonce = cat([
    proxy ? [3, 0] : [0, hdr[0]],
    hdr.sublist(1, 6),
    [0, 0],
    be(iv, 4),
  ]);
  final pt = ccmDecrypt(net.encKey, nonce, enc, ctl ? 8 : 4);
  if (pt == null || pt.length < 3) return null;
  return NetworkMessage(
    ctl,
    hdr[0] & 0x7f,
    rd(hdr, 1, 3),
    rd(hdr, 4, 2),
    rd(pt, 0, 2),
    iv,
    pt.sublist(2),
  );
}

/// The key used for an access message: the network's AppKey, or a node's
/// DeviceKey for configuration messages.
class AccessKey {
  final Uint8List key;
  final bool isDevice;
  final int aid;
  AccessKey.app(NetKeys net) : key = net.appKey, isDevice = false, aid = net.aid;
  AccessKey.device(this.key) : isDevice = true, aid = 0;
}

class TransportPdu {
  final int seq;
  final Uint8List transport;
  TransportPdu(this.seq, this.transport);
}

class AccessSegments {
  final int seq0;
  final List<TransportPdu> pdus;

  /// For segmented messages: the same segments with fresh sequence numbers
  /// and the same SeqZero, for retransmission.
  final List<TransportPdu> Function()? resend;
  AccessSegments(this.seq0, this.pdus, this.resend);
}

Uint8List _accessNonce(bool dev, int seq, int src, int dst, int iv) => cat([
  [dev ? 2 : 1, 0],
  be(seq, 3),
  be(src, 2),
  be(dst, 2),
  be(iv, 4),
]);

/// Upper and lower transport for an access message, segmented when needed.
/// [seqs] hands out a fresh sequence number on each call.
AccessSegments buildAccessSegments(
  AccessKey key, {
  required int Function() seqs,
  required int src,
  required int dst,
  required int iv,
  required List<int> access,
}) {
  final seq0 = seqs();
  final upper = ccmEncrypt(key.key, _accessNonce(key.isDevice, seq0, src, dst, iv), access, 4);
  final hdr = key.isDevice ? 0x00 : (0x40 | key.aid);
  if (upper.length <= 15) {
    return AccessSegments(seq0, [
      TransportPdu(
        seq0,
        cat([
          [hdr],
          upper,
        ]),
      ),
    ], null);
  }
  final segN = (upper.length + 11) ~/ 12 - 1;
  final seqZero = seq0 & 0x1fff;
  List<TransportPdu> segmentsFor(int? first) => [
    for (var o = 0; o <= segN; o++)
      TransportPdu(
        o == 0 && first != null ? first : seqs(),
        cat([
          [
            0x80 | hdr,
            (seqZero >> 6) & 0x7f,
            ((seqZero & 0x3f) << 2) | (o >> 3),
            ((o & 7) << 5) | segN,
          ],
          upper.sublist(o * 12, (o * 12 + 12).clamp(0, upper.length)),
        ]),
      ),
  ];
  return AccessSegments(seq0, segmentsFor(seq0), () => segmentsFor(null));
}

/// Decrypts an unsegmented access message.
/// [devKeyFor] returns the DeviceKey of a node address, if known.
Uint8List? openAccess(NetworkMessage msg, NetKeys? app, Uint8List? Function(int src) devKeyFor) {
  final t = msg.transport;
  if (msg.ctl || t.isEmpty || t[0] & 0x80 != 0) return null;
  return _openUpper(t[0], msg.seq, msg, t.sublist(1), app, devKeyFor);
}

Uint8List? _openUpper(
  int hdr,
  int seqAuth,
  NetworkMessage msg,
  List<int> upper,
  NetKeys? app,
  Uint8List? Function(int src) devKeyFor,
) {
  if (hdr & 0x40 != 0) {
    if (app == null || (hdr & 0x3f) != app.aid) return null;
    return ccmDecrypt(app.appKey, _accessNonce(false, seqAuth, msg.src, msg.dst, msg.iv), upper, 4);
  }
  final dk = devKeyFor(msg.src);
  if (dk == null) return null;
  return ccmDecrypt(dk, _accessNonce(true, seqAuth, msg.src, msg.dst, msg.iv), upper, 4);
}

/// Transport PDU of a Segment Acknowledgment (control opcode 0) confirming
/// every segment of the complete segmented message in [segment], one of its
/// lower transport PDUs.
Uint8List segmentAckFor(List<int> segment) {
  final seqZero = ((segment[1] & 0x7f) << 6) | (segment[2] >> 2);
  final segN = segment[3] & 0x1f;
  return cat([
    [0x00, (seqZero >> 6) & 0x7f, (seqZero & 0x3f) << 2],
    be((1 << (segN + 1)) - 1, 4),
  ]);
}

/// Reassembles incoming segmented access messages.
class SegmentAssembler {
  final _pending = <String, _Partial>{};

  /// Returns the decrypted access payload when the last missing segment of a
  /// message arrives; otherwise null.
  Uint8List? add(NetworkMessage msg, NetKeys? app, Uint8List? Function(int src) devKeyFor) {
    final t = msg.transport;
    if (msg.ctl || t.length < 5 || t[0] & 0x80 == 0) return null;
    if (t[1] & 0x80 != 0) return null; // SZMIC=1 (64-bit TransMIC) unsupported
    final seqZero = ((t[1] & 0x7f) << 6) | (t[2] >> 2);
    final segO = ((t[2] & 3) << 3) | (t[3] >> 5);
    final segN = t[3] & 0x1f;
    if (segO > segN) return null;
    final id = '${msg.src}:$seqZero';
    final p = _pending.putIfAbsent(id, () => _Partial(segN));
    if (_pending.length > 16) _pending.remove(_pending.keys.first);
    if (p.segN != segN) return null;
    p.parts[segO] = t.sublist(4);
    if (p.parts.any((x) => x == null)) return null;
    _pending.remove(id);
    var seqAuth = (msg.seq & ~0x1fff) | seqZero;
    if (seqAuth > msg.seq) seqAuth -= 0x2000;
    final upper = cat([for (final x in p.parts) x!]);
    return _openUpper(t[0], seqAuth, msg, upper, app, devKeyFor);
  }
}

class _Partial {
  final int segN;
  final List<Uint8List?> parts;
  _Partial(this.segN) : parts = List.filled(segN + 1, null);
}

/// A decoded Secure Network Beacon.
class SecureBeacon {
  final int flags;
  final Uint8List networkId;
  final int ivIndex;
  SecureBeacon(this.flags, this.networkId, this.ivIndex);

  bool get ivUpdateActive => flags & 2 != 0;

  /// The IV index to transmit with.
  int get txIv => ivUpdateActive ? ivIndex - 1 : ivIndex;

  static SecureBeacon? parse(List<int> data) {
    if (data.length < 22 || data[0] != 1) return null;
    return SecureBeacon(data[1], Uint8List.fromList(data.sublist(2, 10)), rd(data, 10, 4));
  }
}

// ---------- proxy advertisements (Mesh Profile 7.2.2.2) ----------

/// IdentityKey = k1(NetKey, s1("nkik"), "id128" || 0x01).
Uint8List identityKey(Uint8List netKey) => k1(
  netKey,
  s1('nkik'),
  cat([
    utf8Bytes('id128'),
    [0x01],
  ]),
);

Uint8List _nodeIdentityHash(Uint8List idKey, List<int> random, int addr) => aes(
  idKey,
  cat([
    [0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
    random,
    be(addr, 2),
  ]),
).sublist(8);

/// Mesh Proxy service data for a Node Identity advertisement:
/// `0x01 || Hash(8) || Random(8)`. Used by tests and simulated bulbs.
Uint8List nodeIdentityAdvert(NetKeys net, List<int> random, int addr) => cat([
  [0x01],
  _nodeIdentityHash(identityKey(net.netKey), random, addr),
  random,
]);

/// Returned by [matchProxyAdvert] for a Network ID advertisement, which names
/// the network but not the node.
const anyNodeOfOurNetwork = -1;

/// Checks Mesh Proxy (0x1828) service data against our network.
/// Returns the matching address from [addrs] for a Node Identity
/// advertisement, [anyNodeOfOurNetwork] for a matching Network ID, or null
/// when the advertiser is not on our network (or the data is malformed).
int? matchProxyAdvert(NetKeys net, Uint8List data, Iterable<int> addrs) {
  if (data.length == 9 && data[0] == 0x00) {
    return bytesEqual(data.sublist(1), net.networkId) ? anyNodeOfOurNetwork : null;
  }
  if (data.length == 17 && data[0] == 0x01) {
    final idKey = identityKey(net.netKey);
    final hash = data.sublist(1, 9), random = data.sublist(9, 17);
    for (final a in addrs) {
      if (bytesEqual(_nodeIdentityHash(idKey, random, a), hash)) return a;
    }
  }
  return null;
}
