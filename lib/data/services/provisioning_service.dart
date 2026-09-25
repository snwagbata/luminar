import 'dart:async';
import 'dart:typed_data';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/crypto.dart';
import 'package:luminar/data/mesh/provisioning.dart';
import 'package:luminar/data/mesh/proxy.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/data/services/timings.dart';

/// A bulb that joined our network.
class ProvisionedNode {
  final Uint8List devKey;
  final int elements;
  const ProvisionedNode(this.devKey, this.elements);
}

enum ProvisioningError {
  /// The bulb dropped the connection.
  disconnected,

  /// The bulb stopped answering.
  noAnswer,

  /// The bulb sent Provisioning Failed ([ProvisioningException.code]).
  failed,

  /// The bulb sent a reply out of order.
  unexpected,

  /// The bulb needs an authentication method Luminar does not support.
  unsupported,

  /// The bulb's confirmation did not match: wrong device or tampering.
  securityCheck,
}

class ProvisioningException implements Exception {
  final ProvisioningError error;

  /// The error code of Provisioning Failed.
  final int? code;
  const ProvisioningException(this.error, [this.code]);

  @override
  String toString() => 'ProvisioningException(${error.name}${code == null ? '' : ', $code'})';
}

/// PB-GATT provisioning with No OOB authentication.
class ProvisioningService {
  ProvisioningService({required this._ble, required this._log, this.timings = const Timings()});

  final BleService _ble;
  final ActivityLog _log;
  final Timings timings;

  /// Provisions the unprovisioned bulb [id] into the network [netKey] at
  /// [addr]. [onStep] reports progress: 1 (key exchange), 2 (confirmation).
  /// Throws [ProvisioningException], or BluetoothUnavailable.
  Future<ProvisionedNode> provision(
    String id, {
    required Uint8List netKey,
    required int iv,
    required int addr,
    void Function(int step)? onStep,
  }) async {
    _log.add('Connecting to $id (${MeshService.provisioning.name})');
    final link = await _ble.connect(id, MeshService.provisioning);
    _log.add('Connected to $id, writes up to ${link.maxChunk} bytes');
    final writer = LinkWriter(link);
    final inbox = <Uint8List>[];
    Completer<Uint8List>? waiter;
    final sub = link.notifications.listen(
      ProxyReassembler((type, d) {
        if (type != ProxyType.provisioning || d.isEmpty) return;
        _log.add('← prov ${toHex(d)}');
        final w = waiter;
        if (w != null) {
          waiter = null;
          w.complete(d);
        } else {
          inbox.add(d);
        }
      }).add,
    );

    Future<Uint8List> recv(int expect) async {
      final Uint8List d;
      if (inbox.isNotEmpty) {
        d = inbox.removeAt(0);
      } else {
        final c = waiter = Completer<Uint8List>();
        d =
            await Future.any([
              c.future,
              link.done.then<Uint8List>(
                (_) => throw const ProvisioningException(ProvisioningError.disconnected),
              ),
            ]).timeout(
              timings.provReply,
              onTimeout: () {
                waiter = null;
                throw const ProvisioningException(ProvisioningError.noAnswer);
              },
            );
      }
      if (d[0] == ProvPdu.failed) {
        throw ProvisioningException(ProvisioningError.failed, d.length > 1 ? d[1] : null);
      }
      if (d[0] != expect) throw const ProvisioningException(ProvisioningError.unexpected);
      return d.sublist(1);
    }

    Future<void> send(List<int> bytes) {
      _log.add('→ prov ${toHex(bytes)}');
      return writer.writeAll(proxyChunks(ProxyType.provisioning, bytes, maxChunk: link.maxChunk));
    }

    try {
      onStep?.call(1);
      const invite = [0x05];
      await send([ProvPdu.invite, ...invite]);
      final caps = ProvCapabilities(await recv(ProvPdu.capabilities));
      if (caps.raw.length < 11 || !caps.supportsP256) {
        throw const ProvisioningException(ProvisioningError.unsupported);
      }
      const start = [0x00, 0x00, 0x00, 0x00, 0x00];
      await send([ProvPdu.start, ...start]);

      final kp = EcdhKeyPair.generate();
      await send([ProvPdu.publicKey, ...kp.publicKey]);
      final pubD = await recv(ProvPdu.publicKey);
      final secret = kp.sharedSecret(pubD);

      onStep?.call(2);
      final inputs = cat([invite, caps.raw, start, kp.publicKey, pubD]);
      final ck = Prov.confirmationKey(secret, inputs);
      final auth = Uint8List(16), randP = randomBytes(16);
      await send([ProvPdu.confirmation, ...Prov.confirmation(ck.key, randP, auth)]);
      final confD = await recv(ProvPdu.confirmation);
      await send([ProvPdu.random, ...randP]);
      final randD = await recv(ProvPdu.random);
      if (!bytesEqual(Prov.confirmation(ck.key, randD, auth), confD)) {
        throw const ProvisioningException(ProvisioningError.securityCheck);
      }
      final ses = Prov.session(secret, ck.salt, randP, randD);
      final data = Prov.data(netKey, 0, 0, iv, addr);
      await send([ProvPdu.data, ...ccmEncrypt(ses.key, ses.nonce, data, 8)]);
      await recv(ProvPdu.complete);
      _log.add('Provisioned $id at ${hex16(addr)}');
      return ProvisionedNode(ses.devKey, caps.elements);
    } finally {
      await sub.cancel();
      await link.disconnect().catchError((_) {});
    }
  }
}
