// Network PDUs for access messages, cross-checked against Silvair's
// bluetooth-mesh Python library (0.9.3). Vectors: test/support/silvair_vectors.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/messages.dart';
import 'package:luminar/data/mesh/network.dart';

void main() {
  final v = jsonDecode(
    File('test/support/silvair_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final net = NetKeys.derive(
    hex('00112233445566778899aabbccddeeff'),
    hex('0f1e2d3c4b5a69788796a5b4c3d2e1f0'),
  );
  final devKey = AccessKey.device(hex('a1a2a3a4a5a6a7a8a9aaabacadaeafb0'));

  List<List<Object>> ours(AccessKey key, List<int> access, int iv) {
    var s = 5000;
    final r = buildAccessSegments(
      key,
      seqs: () => s++,
      src: 0x0001,
      dst: 0x0010,
      iv: iv,
      access: access,
    );
    return [
      for (final p in r.pdus)
        [
          p.seq,
          toHex(
            buildNetworkPdu(
              net,
              ctl: false,
              ttl: 7,
              seq: p.seq,
              src: 0x0001,
              dst: 0x0010,
              transport: p.transport,
              iv: iv,
            ),
          ),
        ],
    ];
  }

  List<List<Object>> expected(String name) => [
    for (final e in v[name] as List) [(e as List)[0] as int, e[1] as String],
  ];

  group('matches Silvair bluetooth-mesh', () {
    test('Composition Data Get, device key, unsegmented', () {
      expect(ours(devKey, Msg.compositionGet(), 0), expected('compGet'));
    });
    test('Composition Data Get at a non-zero IV index', () {
      expect(ours(devKey, Msg.compositionGet(), 0x12345678), expected('compGetIv'));
    });
    test('AppKey Add, device key, segmented', () {
      expect(
        ours(devKey, Msg.appKeyAdd(hex('0f1e2d3c4b5a69788796a5b4c3d2e1f0')), 0),
        expected('appKeyAdd'),
      );
    });
    test('Generic OnOff Get, app key', () {
      expect(ours(AccessKey.app(net), Msg.onOffGet(), 0), expected('onOffGet'));
    });
  });
}
