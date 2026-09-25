import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/crypto.dart';
import 'package:luminar/data/mesh/messages.dart';
import 'package:luminar/data/mesh/network.dart';
import 'package:luminar/data/mesh/provisioning.dart';
import 'package:luminar/data/mesh/proxy.dart';

void main() {
  group('RFC 4493 AES-CMAC', () {
    final k = hex('2b7e151628aed2a6abf7158809cf4f3c');
    test('empty', () {
      expect(toHex(cmac(k, [])), 'bb1d6929e95937287fa37d129b756746');
    });
    test('16 bytes', () {
      expect(
        toHex(cmac(k, hex('6bc1bee22e409f96e93d7e117393172a'))),
        '070a16b46b4d4144f79bdd9dd04a287c',
      );
    });
    test('40 bytes', () {
      final m = hex(
        '6bc1bee22e409f96e93d7e117393172a'
        'ae2d8a571e03ac9c9eb76fac45af8e51'
        '30c81c46a35ce411',
      );
      expect(toHex(cmac(k, m)), 'dfa66747de9ae63030ca32611497c827');
    });
  });

  group('Mesh Profile sample data', () {
    test('s1', () {
      expect(toHex(s1('test')), 'b73cefbd641ef2ea598c2b6efb62f79c');
    });
    test('k1', () {
      expect(
        toHex(
          k1(
            hex('3216d1509884b533248541792b877f98'),
            hex('2ba14ffa0df84a2831938d57d276cab4'),
            hex('5a09d60797eeb4478aada59db3352a0d'),
          ),
        ),
        'f6ed15a8934afbe7d83e8dcb57fcf5d7',
      );
    });
    test('k2', () {
      final r = k2(hex('f7a2a44f8e8a8029064f173ddc1e2b00'), [0]);
      expect(r.nid, 0x7f);
      expect(toHex(r.encKey), '9f589181a0f50de73c8070c7a6d27f46');
      expect(toHex(r.privKey), '4c715bd4a64b938f99b453351653124f');
    });
    test('k3', () {
      expect(toHex(k3(hex('f7a2a44f8e8a8029064f173ddc1e2b00'))), 'ff046958233db014');
    });
    test('k4', () {
      expect(k4(hex('3216d1509884b533248541792b877f98')), 0x38);
    });
    test('Message #1 network PDU', () {
      final net = NetKeys.derive(hex('7dd7364cd842ad18c17c2b820c84c3d6'), Uint8List(16));
      final pdu = buildNetworkPdu(
        net,
        ctl: true,
        ttl: 0,
        seq: 1,
        src: 0x1201,
        dst: 0xfffd,
        transport: hex('034b50057e400000010000'),
        iv: 0x12345678,
      );
      expect(toHex(pdu), '68eca487516765b5e5bfdacbaf6cb7fb6bff871f035444ce83a670df');
      final back = decodeNetworkPdu(net, pdu, 0x12345678)!;
      expect(back.ctl, isTrue);
      expect(back.seq, 1);
      expect(back.src, 0x1201);
      expect(back.dst, 0xfffd);
      expect(toHex(back.transport), '034b50057e400000010000');
    });
  });

  // Vectors produced by reference/mesh-core.js (test/support/js_vectors.mjs).
  group('matches the verified JS core', () {
    final v =
        jsonDecode(File('test/support/js_vectors.json').readAsStringSync()) as Map<String, dynamic>;
    final netKey = hex('00112233445566778899aabbccddeeff');
    final appKey = hex('0f1e2d3c4b5a69788796a5b4c3d2e1f0');
    final net = NetKeys.derive(netKey, appKey);

    test('key derivation', () {
      final n = v['net'] as Map<String, dynamic>;
      expect(net.nid, n['nid']);
      expect(toHex(net.encKey), n['encKey']);
      expect(toHex(net.privKey), n['privKey']);
      expect(toHex(net.networkId), n['networkId']);
      expect(net.aid, n['aid']);
    });

    test('app-key access message and network PDU', () {
      var s = 1000;
      final r = buildAccessSegments(
        AccessKey.app(net),
        seqs: () => s++,
        src: 1,
        dst: 0x10,
        iv: 0,
        access: Msg.ctlSet(0x1234, 5576, 7),
      );
      expect(Msg.ctlSet(0x1234, 5576, 7), hex('825f3412c815000007'));
      final exp = (v['appAccess'] as List).cast<Map<String, dynamic>>();
      expect(r.pdus.length, exp.length);
      expect(r.pdus[0].seq, exp[0]['seq']);
      expect(toHex(r.pdus[0].transport), exp[0]['transport']);
      expect(r.resend, isNull);
      final pdu = buildNetworkPdu(
        net,
        ctl: false,
        ttl: 7,
        seq: r.pdus[0].seq,
        src: 1,
        dst: 0x10,
        transport: r.pdus[0].transport,
        iv: 0,
      );
      expect(toHex(pdu), v['appNet']);

      final msg = decodeNetworkPdu(net, pdu, 0)!;
      expect(toHex(openAccess(msg, net, (_) => null)!), '825f3412c815000007');
    });

    test('device-key segmented message and resend', () {
      final devKey = hex('a1a2a3a4a5a6a7a8a9aaabacadaeafb0');
      var s = 5000;
      final access = Msg.appKeyAdd(appKey);
      expect(toHex(access.sublist(0, 4)), '00000000');
      final r = buildAccessSegments(
        AccessKey.device(devKey),
        seqs: () => s++,
        src: 1,
        dst: 0x10,
        iv: 0x12345678,
        access: access,
      );
      List<Map<String, dynamic>> list(String k) => (v[k] as List).cast<Map<String, dynamic>>();
      expect([for (final p in r.pdus) p.seq], [for (final e in list('devSeg')) e['seq']]);
      expect(
        [for (final p in r.pdus) toHex(p.transport)],
        [for (final e in list('devSeg')) e['transport']],
      );
      final nets = [
        for (final p in r.pdus)
          toHex(
            buildNetworkPdu(
              net,
              ctl: false,
              ttl: 7,
              seq: p.seq,
              src: 1,
              dst: 0x10,
              transport: p.transport,
              iv: 0x12345678,
            ),
          ),
      ];
      expect(nets, v['devSegNet']);
      final again = r.resend!();
      expect([for (final p in again) p.seq], [for (final e in list('devSegResend')) e['seq']]);
      expect(
        [for (final p in again) toHex(p.transport)],
        [for (final e in list('devSegResend')) e['transport']],
      );

      // Reassemble the retransmission (later SEQ, same SeqZero) and decrypt.
      final asm = SegmentAssembler();
      Uint8List? out;
      for (final p in again) {
        final pdu = buildNetworkPdu(
          net,
          ctl: false,
          ttl: 7,
          seq: p.seq,
          src: 1,
          dst: 0x10,
          transport: p.transport,
          iv: 0x12345678,
        );
        out = asm.add(decodeNetworkPdu(net, pdu, 0x12345678)!, net, (_) => devKey);
      }
      expect(out, access);
    });

    test('decodes a proxy configuration PDU with the proxy nonce', () {
      final msg = decodeNetworkPdu(net, hex(v['proxyCfg'] as String), 0, proxy: true)!;
      expect(msg.ctl, isTrue);
      expect(msg.seq, 42);
      expect(msg.src, 1);
      expect(toHex(msg.transport), '0001');
      expect(decodeNetworkPdu(net, hex(v['proxyCfg'] as String), 0), isNull);
    });

    test('proxy configuration PDU', () {
      final pdu = buildNetworkPdu(
        net,
        ctl: true,
        ttl: 0,
        seq: 42,
        src: 1,
        dst: 0,
        transport: [0, 1],
        iv: 0,
        proxy: true,
      );
      expect(toHex(pdu), v['proxyCfg']);
    });

    test('provisioning session math', () {
      final p = v['prov'] as Map<String, dynamic>;
      final secret = hex('ab' * 32);
      final inputs = hex('05${'01' * 11}${'00' * 5}${'11' * 64}${'22' * 64}');
      final ck = Prov.confirmationKey(secret, inputs);
      expect(toHex(ck.salt), p['salt']);
      expect(toHex(ck.key), p['key']);
      final randP = hex('33' * 16), randD = hex('44' * 16);
      expect(toHex(Prov.confirmation(ck.key, randP, Uint8List(16))), p['conf']);
      final ses = Prov.session(secret, ck.salt, randP, randD);
      expect(toHex(ses.key), p['sessionKey']);
      expect(toHex(ses.nonce), p['nonce']);
      expect(toHex(ses.devKey), p['devKey']);
      final data = Prov.data(netKey, 0, 0, 0, 0x10);
      expect(data.length, 25);
      final enc = ccmEncrypt(ses.key, ses.nonce, data, 8);
      expect(toHex(enc), p['data']);
      expect(ccmDecrypt(ses.key, ses.nonce, enc, 8), data);
      enc[3] ^= 1;
      expect(ccmDecrypt(ses.key, ses.nonce, enc, 8), isNull);
    });

    test('proxy SAR chunks', () {
      final pdu = hex('03${'55' * 64}');
      expect([for (final c in proxyChunks(3, pdu)) toHex(c)], v['chunks']);
      final got = <Uint8List>[];
      final rx = ProxyReassembler((t, d) {
        expect(t, 3);
        got.add(d);
      });
      for (final c in proxyChunks(3, pdu)) {
        rx.add(c);
      }
      expect(got.single, pdu);
      expect(proxyChunks(3, pdu, maxChunk: 100).single.length, 66);
    });
  });

  group('ECDH P-256', () {
    test('both sides derive the same secret', () {
      final a = EcdhKeyPair.generate(), b = EcdhKeyPair.generate();
      expect(a.publicKey.length, 64);
      expect(a.sharedSecret(b.publicKey), b.sharedSecret(a.publicKey));
    });
    test('matches Node crypto (test/support/ecdh_vector.json)', () {
      final v = jsonDecode(
        File('test/support/ecdh_vector.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final a = EcdhKeyPair.fromPrivate(hex(v['privA'] as String));
      expect(toHex(a.publicKey), v['pubA']);
      expect(toHex(a.sharedSecret(hex(v['pubB'] as String))), v['shared']);
    });
    test('rejects a point that is not on the curve', () {
      final a = EcdhKeyPair.generate();
      final bad = Uint8List.fromList(a.publicKey)..[63] ^= 1;
      expect(() => a.sharedSecret(bad), throwsFormatException);
    });
  });

  group('status parsing', () {
    test('CTL status with target', () {
      final s = LightStatus.parse(hex('8260 0000 b80b ffff 6419 05'))!;
      expect(s.lightness, 0xffff);
      expect(s.kelvin, 6500);
    });
    test('OnOff status', () {
      expect(LightStatus.parse(hex('820401'))!.on, isTrue);
      expect(LightStatus.parse(hex('8204010005'))!.on, isFalse);
    });
    test('model app bind packs little-endian', () {
      expect(toHex(Msg.modelAppBind(0x0010, Models.ctl)), '803d100000000313');
    });
  });
}
