import 'package:luminar/data/repositories/connection_repository.dart';
import 'package:luminar/data/repositories/light_repository.dart';
import 'package:luminar/data/repositories/provisioning_repository.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/timings.dart';
import 'package:luminar/domain/models/light.dart';
import 'package:luminar/domain/models/nearby_bulb.dart';

enum AddLightStep {
  /// Provisioning, key exchange (1 of 3).
  exchangingKeys,

  /// Provisioning, confirmation and network key (2 of 3).
  confirming,

  /// Configuring through the proxy (3 of 3).
  configuring,
}

/// How [AddLightUseCase.call] ended.
sealed class AddLightResult {
  const AddLightResult();
}

/// Added and configured.
final class LightAdded extends AddLightResult {
  final Light light;
  const LightAdded(this.light);
}

/// Added to the network, but configuration did not finish.
final class LightNeedsSetup extends AddLightResult {
  final Light light;
  const LightNeedsSetup(this.light);
}

/// Provisions a bulb, connects to it as a proxy (the service it switches to
/// after provisioning) and configures it.
class AddLightUseCase {
  AddLightUseCase({
    required this._provisioning,
    required this._connection,
    required this._lights,
    required this._log,
    this.timings = const Timings(),
  });

  final ProvisioningRepository _provisioning;
  final ConnectionRepository _connection;
  final LightRepository _lights;
  final ActivityLog _log;
  final Timings timings;

  /// Throws ProvisioningException or BluetoothUnavailable if the bulb could
  /// not join the network.
  Future<AddLightResult> call(NearbyBulb bulb, {void Function(AddLightStep step)? onStep}) async {
    final light = await _provisioning.provision(
      bulb,
      onStep: (s) => onStep?.call(s == 1 ? AddLightStep.exchangingKeys : AddLightStep.confirming),
    );
    onStep?.call(AddLightStep.configuring);
    var ok = false;
    if (_connection.isConnected) {
      ok = await _lights.configure(light.addr, tries: 1) == ConfigureResult.ready;
    }
    for (var i = 0; i < 5 && !ok; i++) {
      await Future<void>.delayed(timings.reconnectBase + timings.reconnectStep * i);
      try {
        // After provisioning the bulb swaps to the proxy service; ask the
        // platform to forget the cached provisioning-only GATT table.
        await _connection.connectTo(bulb.id, fresh: true);
        ok = await _lights.configure(light.addr) == ConfigureResult.ready;
      } catch (e) {
        _log.add('Proxy retry ${i + 1}: $e');
      }
    }
    if (!ok) return LightNeedsSetup(light);
    await _lights.queryState(light.addr);
    return LightAdded(light);
  }
}
