import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:luminar/data/mesh/bytes.dart';

// AES primitives and Mesh key derivation (Mesh Profile 3.8.2).

final _engines = <String, AESEngine>{};

/// Single-block AES-128 encryption.
Uint8List aes(Uint8List key, List<int> block) {
  final engine = _engines.putIfAbsent(toHex(key), () {
    if (_engines.length > 64) _engines.clear();
    return AESEngine()..init(true, KeyParameter(key));
  });
  final out = Uint8List(16);
  engine.processBlock(Uint8List.fromList(block), 0, out, 0);
  return out;
}

/// AES-CMAC (RFC 4493).
Uint8List cmac(Uint8List k, List<int> m) {
  final mac = CMac(AESEngine(), 128)..init(KeyParameter(k));
  return mac.process(Uint8List.fromList(m));
}

/// AES-CCM with a 13-byte nonce (L=2) and no additional data.
/// Returns ciphertext || MIC.
Uint8List ccmEncrypt(Uint8List k, List<int> nonce, List<int> pt, int micLen) =>
    _ccm(true, k, nonce, micLen).process(Uint8List.fromList(pt));

/// Returns the plaintext, or null if the MIC does not match.
Uint8List? ccmDecrypt(Uint8List k, List<int> nonce, List<int> ctmic, int micLen) {
  if (ctmic.length < micLen) return null;
  try {
    return _ccm(false, k, nonce, micLen).process(Uint8List.fromList(ctmic));
  } on InvalidCipherTextException {
    return null;
  } on StateError {
    return null; // pointycastle reports a MIC mismatch this way
  }
}

CCMBlockCipher _ccm(bool encrypt, Uint8List k, List<int> nonce, int micLen) =>
    CCMBlockCipher(AESEngine())..init(
      encrypt,
      AEADParameters(KeyParameter(k), micLen * 8, Uint8List.fromList(nonce), Uint8List(0)),
    );

Uint8List s1(Object m) => cmac(Uint8List(16), m is String ? utf8Bytes(m) : m as List<int>);

Uint8List k1(List<int> n, Uint8List salt, Object p) {
  final t = cmac(salt, n);
  return cmac(t, p is String ? utf8Bytes(p) : p as List<int>);
}

class K2 {
  final int nid;
  final Uint8List encKey;
  final Uint8List privKey;
  K2(this.nid, this.encKey, this.privKey);
}

K2 k2(List<int> n, List<int> p) {
  final t = cmac(s1('smk2'), n);
  final t1 = cmac(
    t,
    cat([
      p,
      [1],
    ]),
  );
  final t2 = cmac(
    t,
    cat([
      t1,
      p,
      [2],
    ]),
  );
  final t3 = cmac(
    t,
    cat([
      t2,
      p,
      [3],
    ]),
  );
  return K2(t1[15] & 0x7f, t2, t3);
}

Uint8List k3(List<int> n) {
  final t = cmac(s1('smk3'), n);
  return cmac(
    t,
    cat([
      utf8Bytes('id64'),
      [1],
    ]),
  ).sublist(8);
}

int k4(List<int> n) {
  final t = cmac(s1('smk4'), n);
  return cmac(
        t,
        cat([
          utf8Bytes('id6'),
          [1],
        ]),
      )[15] &
      0x3f;
}
