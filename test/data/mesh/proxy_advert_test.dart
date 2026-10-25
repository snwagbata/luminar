// Mesh Proxy advertisements (Network ID and Node Identity). The IdentityKey
// is checked against the Bluetooth Mesh Profile sample data, section 8.2.6;
// the rest round-trips adverts built by Luminar itself.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/network.dart';

void main() {
  group('proxy advertisement identification', () {
    test('IdentityKey matches Mesh Profile sample data 8.2.6', () {
      expect(
        toHex(identityKey(hex('7dd7364cd842ad18c17c2b820c84c3d6'))),
        '84396c435ac48560b5965385253e210c',
      );
    });

    final net = NetKeys.derive(hex('00112233445566778899aabbccddeeff'), Uint8List(16));

    test('recognizes a Node Identity advertisement for one of our addresses', () {
      final random = hex('0102030405060708');
      final data = nodeIdentityAdvert(net, random, 0x0010);
      expect(data.length, 17);
      expect(data[0], 0x01);
      expect(matchProxyAdvert(net, data, [0x0010, 0x0011]), 0x0010);
      expect(matchProxyAdvert(net, data, [0x0011]), isNull);
    });

    test('rejects a Node Identity from another network', () {
      final other = NetKeys.derive(hex('ffeeddccbbaa99887766554433221100'), Uint8List(16));
      final data = nodeIdentityAdvert(other, hex('0102030405060708'), 0x0010);
      expect(matchProxyAdvert(net, data, [0x0010]), isNull);
    });

    test('recognizes a Network ID advertisement for our network', () {
      final data = Uint8List.fromList([0x00, ...net.networkId]);
      expect(matchProxyAdvert(net, data, const []), anyNodeOfOurNetwork);
      expect(matchProxyAdvert(net, Uint8List.fromList([0x00, ...Uint8List(8)]), const []), isNull);
    });

    test('ignores malformed service data', () {
      expect(matchProxyAdvert(net, Uint8List(0), [0x10]), isNull);
      expect(matchProxyAdvert(net, Uint8List.fromList([0x01, 1, 2]), [0x10]), isNull);
    });
  });
}
