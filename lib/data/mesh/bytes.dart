import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Parses a hex string, ignoring any non-hex characters (spaces, colons).
Uint8List hex(String s) {
  final clean = s.replaceAll(RegExp('[^0-9a-fA-F]'), '');
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String toHex(List<int> b) => b.map((v) => (v & 0xff).toRadixString(16).padLeft(2, '0')).join();

Uint8List cat(List<List<int>> parts) {
  final out = Uint8List(parts.fold(0, (n, p) => n + p.length));
  var o = 0;
  for (final p in parts) {
    out.setAll(o, p);
    o += p.length;
  }
  return out;
}

Uint8List xor(List<int> a, List<int> b) =>
    Uint8List.fromList(List.generate(a.length, (i) => a[i] ^ b[i]));

Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// Big-endian encoding of [v] into [n] bytes.
Uint8List be(int v, int n) {
  final o = Uint8List(n);
  for (var i = n - 1; i >= 0; i--) {
    o[i] = v & 0xff;
    v >>= 8;
  }
  return o;
}

/// Big-endian read of [n] bytes at [o].
int rd(List<int> u, int o, int n) {
  var v = 0;
  for (var i = 0; i < n; i++) {
    v = (v << 8) | u[o + i];
  }
  return v;
}

/// Little-endian 16-bit, as used by access-message parameters.
List<int> le16(int v) => [v & 0xff, (v >> 8) & 0xff];
int u16le(List<int> a, int i) => a[i] | (a[i + 1] << 8);

bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

final _rng = Random.secure();
Uint8List randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

/// A 16-bit mesh address or model id as `0x0010`.
String hex16(int v) => '0x${v.toRadixString(16).padLeft(4, '0')}';
