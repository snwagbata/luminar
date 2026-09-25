import 'dart:async';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/repositories/home_repository.dart';
import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/data/services/provisioning_service.dart';
import 'package:luminar/domain/models/light.dart';
import 'package:luminar/domain/models/nearby_bulb.dart';

/// Finds unprovisioned bulbs and brings them into our network.
class ProvisioningRepository {
  ProvisioningRepository({required this._ble, required this._provisioning, required this._home});

  final BleService _ble;
  final ProvisioningService _provisioning;
  final HomeRepository _home;

  /// Emits the growing list of unprovisioned bulbs with their latest
  /// signal readings. A bulb that was one of our lights (it was reset
  /// outside the app) says which, and its light is marked as reset.
  /// Errors with BluetoothUnavailable.
  Stream<List<NearbyBulb>> scan({Duration timeout = const Duration(seconds: 30)}) async* {
    await _ble.ensureReady();
    yield* _ble.scan(const {MeshService.provisioning}, timeout: timeout).map((list) {
      return [
        for (final b in list)
          NearbyBulb(id: b.id, name: b.name, rssi: b.rssi, replaces: _wasOurs(b.id)?.name),
      ];
    });
  }

  Light? _wasOurs(String bleId) {
    final l = _home.home.lightWithBleId(bleId);
    if (l != null && !l.wasReset) {
      unawaited(_home.updateLight(l.addr, (l) => l.copyWith(wasReset: true)));
    }
    return l;
  }

  Future<void> stopScan() => _ble.stopScan();

  /// Provisions [bulb] at the next free address and adds it to the home
  /// (not yet configured). A bulb that was one of our lights takes over that
  /// light's entry and name. Throws [ProvisioningException] or
  /// BluetoothUnavailable.
  Future<Light> provision(NearbyBulb bulb, {void Function(int step)? onStep}) async {
    await _ble.stopScan();
    final h = _home.home;
    final addr = h.nextAddr;
    final node = await _provisioning.provision(
      bulb.id,
      netKey: hex(h.netKey),
      iv: h.iv,
      addr: addr,
      onStep: onStep,
    );
    // Looked up after provisioning: the home may have changed meanwhile.
    final old = _home.home.lightWithBleId(bulb.id);
    final light = Light(
      addr: addr,
      elements: node.elements,
      name: old?.name ?? (bulb.name.isNotEmpty ? bulb.name : 'Light ${h.lights.length + 1}'),
      devKey: toHex(node.devKey),
      bleId: bulb.id,
    );
    if (old != null) {
      await _home.replaceLight(old.addr, light);
    } else {
      await _home.addLight(light);
    }
    return light;
  }
}
