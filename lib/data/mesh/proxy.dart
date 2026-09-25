import 'dart:typed_data';

import 'package:luminar/data/mesh/bytes.dart';

/// Proxy PDU message types.
abstract final class ProxyType {
  static const network = 0;
  static const beacon = 1;
  static const config = 2;
  static const provisioning = 3;
}

/// Splits a proxy PDU into GATT writes of at most [maxChunk] bytes,
/// including the SAR/type header byte.
List<Uint8List> proxyChunks(int type, List<int> pdu, {int maxChunk = 20}) {
  if (pdu.length + 1 <= maxChunk) {
    return [
      cat([
        [type],
        pdu,
      ]),
    ];
  }
  final out = <Uint8List>[];
  final size = maxChunk - 1;
  for (var i = 0; i < pdu.length; i += size) {
    final sar = i == 0 ? 1 : (i + size >= pdu.length ? 3 : 2);
    final end = i + size > pdu.length ? pdu.length : i + size;
    out.add(
      cat([
        [(sar << 6) | type],
        pdu.sublist(i, end),
      ]),
    );
  }
  return out;
}

/// Joins incoming SAR chunks back into complete proxy PDUs.
class ProxyReassembler {
  final void Function(int type, Uint8List pdu) onPdu;
  int? _type;
  List<int>? _buf;

  ProxyReassembler(this.onPdu);

  void add(List<int> chunk) {
    if (chunk.isEmpty) return;
    final sar = chunk[0] >> 6, type = chunk[0] & 0x3f;
    final body = chunk.sublist(1);
    switch (sar) {
      case 0:
        _buf = null;
        onPdu(type, Uint8List.fromList(body));
      case 1:
        _type = type;
        _buf = [...body];
      default:
        final buf = _buf;
        if (buf == null || type != _type) return;
        buf.addAll(body);
        if (sar == 3) {
          _buf = null;
          onPdu(type, Uint8List.fromList(buf));
        }
    }
  }
}
