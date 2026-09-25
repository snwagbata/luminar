import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/network.dart';
import 'package:luminar/data/repositories/home_repository.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/data/services/mesh_proxy_service.dart';
import 'package:luminar/data/services/timings.dart';
import 'package:luminar/domain/models/connection.dart';

/// How [ConnectionRepository.connect] ended.
sealed class ConnectResult {
  const ConnectResult();
}

final class Connected extends ConnectResult {
  const Connected();
}

/// There are no lights to connect to yet.
final class NoLights extends ConnectResult {
  const NoLights();
}

/// No mesh proxies are in range.
final class NoneFound extends ConnectResult {
  const NoneFound();
}

/// Only bulbs on another network (or their old setup) answered.
final class OldSetup extends ConnectResult {
  const OldSetup();
}

/// Bulbs were found but none accepted a connection.
final class ConnectFailed extends ConnectResult {
  final String? detail;
  const ConnectFailed([this.detail]);
}

/// No proxy of ours is in range, and some of our lights were seen
/// advertising as new bulbs: they were reset outside the app.
final class LightsWereReset extends ConnectResult {
  final List<String> names;
  const LightsWereReset(this.names);
}

final class BluetoothOff extends ConnectResult {
  final String message;
  const BluetoothOff(this.message);
}

/// The proxy connection into the mesh.
class ConnectionRepository extends ChangeNotifier {
  ConnectionRepository({
    required this._ble,
    required this._proxy,
    required this._home,
    required this._log,
    this.timings = const Timings(),
  }) {
    _lostSub = _proxy.lost.listen((_) {
      _set(Connection.off);
      _dropped.add(null);
    });
  }

  final BleService _ble;
  final MeshProxyService _proxy;
  final HomeRepository _home;
  final ActivityLog _log;
  final Timings timings;
  late final StreamSubscription<void> _lostSub;
  final _dropped = StreamController<void>.broadcast();

  Connection _state = Connection.off;
  Connection get state => _state;
  bool get isConnected => _proxy.isOpen && _state == Connection.on;

  /// The bulb the phone is connected through.
  String? get deviceId => _proxy.deviceId;

  /// Emits when the connection drops without [disconnect].
  Stream<void> get dropped => _dropped.stream;

  void _set(Connection s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  /// Finds a nearby bulb on our network and connects through it.
  Future<ConnectResult> connect() async {
    if (isConnected) return const Connected();
    if (_home.home.lights.isEmpty) return const NoLights();
    _set(Connection.connecting);
    try {
      await _ble.ensureReady();
      final candidates = await _findOurProxies();
      if (candidates.isEmpty) {
        final reset = [
          for (final l in _home.home.lights)
            if (l.wasReset) l.name,
        ];
        return reset.isEmpty ? const NoneFound() : LightsWereReset(reset);
      }
      var foreign = 0;
      for (final b in candidates.take(4)) {
        try {
          await _proxy.open(b.id);
          return const Connected();
        } on ForeignNetwork {
          foreign++;
          _log.add('${b.name} belongs to another network');
        } catch (e) {
          _log.add('Could not connect to ${b.name}: $e');
        }
      }
      return foreign > 0 ? const OldSetup() : const ConnectFailed();
    } on BluetoothUnavailable catch (e) {
      return BluetoothOff(e.message);
    } catch (e) {
      return ConnectFailed('$e');
    } finally {
      _set(_proxy.isOpen ? Connection.on : Connection.off);
    }
  }

  /// Connects through the bulb [id]. [fresh] drops the platform's cached
  /// GATT table first (needed right after provisioning).
  /// Throws [ForeignNetwork] or a Bluetooth error.
  Future<void> connectTo(String id, {bool fresh = false}) async {
    _set(Connection.connecting);
    try {
      await _proxy.open(id, fresh: fresh);
    } finally {
      _set(_proxy.isOpen ? Connection.on : Connection.off);
    }
  }

  Future<void> disconnect() async {
    await _proxy.close();
    _set(Connection.off);
  }

  /// Scans for proxies and sorts them: bulbs we know are ours first (by the
  /// Bluetooth address recorded when they were added, or an advertisement
  /// that proves it), then bulbs that did not say, strongest first. Stops as
  /// soon as one of ours is seen.
  ///
  /// Also notices lights that were reset outside the app: their Bluetooth
  /// address shows up advertising as a new, unprovisioned bulb.
  Future<List<FoundBulb>> _findOurProxies() async {
    final addrs = [for (final l in _home.home.lights) l.addr];
    final known = {for (final l in _home.home.lights) ?l.bleId: l};
    final seen = <String, FoundBulb>{};
    final ours = <String, int>{};
    final foreign = <String>{};
    final reset = <String>{};
    try {
      await for (final list in _ble.scan(const {
        MeshService.proxy,
        MeshService.provisioning,
      }, timeout: timings.scan)) {
        for (final b in list) {
          if (b.service == MeshService.provisioning) {
            final l = known[b.id];
            if (l != null && reset.add(b.id)) await _markReset(l.addr, b.name);
            continue;
          }
          final isNew =
              !seen.containsKey(b.id) || (seen[b.id]!.proxyData == null && b.proxyData != null);
          seen[b.id] = b;
          if (known[b.id] case final l? when !ours.containsKey(b.id)) {
            ours[b.id] = l.addr;
            _log.add('${b.name} is one of our lights (${l.name}, ${hex16(l.addr)})');
            continue;
          }
          final data = b.proxyData;
          if (!isNew || data == null) continue;
          final addr = matchProxyAdvert(_home.netKeys, data, addrs);
          if (addr == null) {
            foreign.add(b.id);
            _log.add('${b.name} does not identify as one of our lights');
          } else {
            ours[b.id] = addr;
            final l = addr == anyNodeOfOurNetwork ? null : _home.home.lightAt(addr);
            _log.add(
              '${b.name} is on our network'
              '${l == null ? '' : ' (${l.name}, ${hex16(addr)})'}',
            );
            if (l != null && l.bleId != b.id) {
              unawaited(_home.updateLight(addr, (l) => l.copyWith(bleId: b.id)));
            }
          }
        }
        if (ours.isNotEmpty) break;
        // Every light we can recognise was reset: nothing left to find.
        if (known.isNotEmpty && known.keys.every(reset.contains)) break;
      }
    } finally {
      await _ble.stopScan();
    }
    // Ours first, then bulbs that did not identify themselves, then bulbs
    // whose identity did not match (tried last; the proxy's replies decide).
    int rank(FoundBulb b) => ours.containsKey(b.id) ? 0 : (foreign.contains(b.id) ? 2 : 1);
    return seen.values.toList()
      ..sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : b.rssi - a.rssi);
  }

  Future<void> _markReset(int addr, String bulbName) async {
    final l = _home.home.lightAt(addr);
    if (l == null || l.wasReset) return;
    _log.add('$bulbName (${l.name}, ${hex16(addr)}) was reset: it advertises as a new bulb');
    await _home.updateLight(addr, (l) => l.copyWith(wasReset: true));
  }

  @override
  void dispose() {
    _lostSub.cancel();
    _dropped.close();
    super.dispose();
  }
}
