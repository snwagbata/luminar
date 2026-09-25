import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/crypto.dart';

// Provisioning session math (Mesh Profile 5.4.2) and P-256 ECDH.

class ConfirmationKey {
  final Uint8List salt, key;
  ConfirmationKey(this.salt, this.key);
}

class ProvSession {
  final Uint8List key, nonce, devKey;
  ProvSession(this.key, this.nonce, this.devKey);
}

abstract final class Prov {
  static ConfirmationKey confirmationKey(Uint8List secret, List<int> inputs) {
    final salt = s1(inputs);
    return ConfirmationKey(salt, k1(secret, salt, 'prck'));
  }

  static Uint8List confirmation(Uint8List key, List<int> random, List<int> auth) =>
      cmac(key, cat([random, auth]));

  static ProvSession session(
    Uint8List secret,
    Uint8List confSalt,
    List<int> randP,
    List<int> randD,
  ) {
    final salt = s1(cat([confSalt, randP, randD]));
    return ProvSession(
      k1(secret, salt, 'prsk'),
      k1(secret, salt, 'prsn').sublist(3),
      k1(secret, salt, 'prdk'),
    );
  }

  /// `NetKey(16) || KeyIndex(2) || Flags(1) || IVIndex(4) || Address(2)`
  static Uint8List data(Uint8List netKey, int keyIndex, int flags, int iv, int addr) => cat([
    netKey,
    be(keyIndex, 2),
    [flags],
    be(iv, 4),
    be(addr, 2),
  ]);
}

final _p256 = ECDomainParameters('secp256r1');

/// An ephemeral P-256 key pair for one provisioning session.
class EcdhKeyPair {
  final ECPrivateKey _priv;

  /// X(32) || Y(32)
  final Uint8List publicKey;

  EcdhKeyPair._(this._priv, this.publicKey);

  factory EcdhKeyPair.generate() {
    final rnd = FortunaRandom()..seed(KeyParameter(randomBytes(32)));
    final gen = ECKeyGenerator()..init(ParametersWithRandom(ECKeyGeneratorParameters(_p256), rnd));
    final pair = gen.generateKeyPair();
    final q = pair.publicKey.Q!;
    return EcdhKeyPair._(pair.privateKey, _encode(q));
  }

  /// A key pair from a known private key. For tests.
  factory EcdhKeyPair.fromPrivate(List<int> d) {
    final priv = ECPrivateKey(BigInt.parse(toHex(d), radix: 16), _p256);
    return EcdhKeyPair._(priv, _encode((_p256.G * priv.d)!));
  }

  static Uint8List _encode(ECPoint q) =>
      cat([_int32(q.x!.toBigInteger()!), _int32(q.y!.toBigInteger()!)]);

  /// Returns the 32-byte x-coordinate of the shared point, or throws if
  /// [peer] (X || Y) is not a valid P-256 point.
  Uint8List sharedSecret(List<int> peer) {
    if (peer.length != 64) throw const FormatException('Bad public key length');
    final point = _p256.curve.decodePoint(
      cat([
        [4],
        peer,
      ]),
    );
    if (point == null || point.isInfinity) {
      throw const FormatException('Invalid public key');
    }
    // decodePoint does not check curve membership; verify y² = x³ + ax + b.
    final x = point.x!, y = point.y!;
    final c = _p256.curve;
    if (y * y != x * x * x + c.a! * x + c.b!) {
      throw const FormatException('Public key is not on the curve');
    }
    final shared = (point * _priv.d)!;
    if (shared.isInfinity) throw const FormatException('Invalid shared secret');
    return _int32(shared.x!.toBigInteger()!);
  }
}

Uint8List _int32(BigInt v) {
  final out = Uint8List(32);
  for (var i = 31; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }
  return out;
}

/// Provisioning PDU types.
abstract final class ProvPdu {
  static const invite = 0x00;
  static const capabilities = 0x01;
  static const start = 0x02;
  static const publicKey = 0x03;
  static const confirmation = 0x05;
  static const random = 0x06;
  static const data = 0x07;
  static const complete = 0x08;
  static const failed = 0x09;
}

/// Parsed Provisioning Capabilities (11 bytes of parameters).
class ProvCapabilities {
  final Uint8List raw;
  ProvCapabilities(this.raw);
  int get elements => raw[0];
  int get algorithms => rd(raw, 1, 2);
  bool get supportsP256 => algorithms & 1 != 0;
}
