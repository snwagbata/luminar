import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:luminar/data/services/ble/ble_service.dart';

/// Android reports discovered UUIDs in 128-bit form; compare expanded forms,
/// as flutter_reactive_ble does internally.
bool sameUuid(Uuid a, Uuid b) => a.expanded == b.expanded;

/// Build with `--dart-define=LUMINAR_SCAN_DIAG=true` to scan without a
/// service filter and print every advertisement (for debugging bulbs).
const _scanDiag = bool.fromEnvironment('LUMINAR_SCAN_DIAG');

final _provService = Uuid.parse('1827');
final _proxyService = Uuid.parse('1828');
final _provIn = Uuid.parse('2adb'), _provOut = Uuid.parse('2adc');
final _proxyIn = Uuid.parse('2add'), _proxyOut = Uuid.parse('2ade');

/// [BleService] backed by flutter_reactive_ble.
class ReactiveBleService implements BleService {
  final FlutterReactiveBle _ble;

  /// [interactive] is false in a background isolate (a home-screen widget
  /// tap): permissions are checked there, never requested.
  ReactiveBleService({FlutterReactiveBle? ble, this.interactive = true})
    : _ble = ble ?? FlutterReactiveBle();

  final bool interactive;

  // Both are released in _endScan().
  StreamSubscription<DiscoveredDevice>? _scan; // ignore: cancel_subscriptions
  StreamController<List<FoundBulb>>? _scanOut; // ignore: close_sinks
  Timer? _scanTimer;

  @override
  Future<void> ensureReady() async {
    if (Platform.isAndroid) {
      // Android 12+: nearby devices. Older versions report these as granted.
      final wanted = [Permission.bluetoothScan, Permission.bluetoothConnect];
      final r = interactive ? await wanted.request() : {for (final p in wanted) p: await p.status};
      if (r.values.any((s) => s.isPermanentlyDenied)) {
        throw BluetoothUnavailable(
          'Luminar needs the Nearby devices permission. Allow it in Settings > Apps > Luminar > Permissions.',
        );
      }
      if (r.values.any((s) => !s.isGranted)) {
        throw BluetoothUnavailable(
          'Luminar needs the Nearby devices permission to find your lights.',
        );
      }
    }
    var status = await _status();
    if (status == BleStatus.unauthorized && Platform.isAndroid) {
      // Android 11 and lower need location permission to scan.
      await Permission.locationWhenInUse.request();
      status = await _status();
    }
    switch (status) {
      case BleStatus.ready:
        return;
      case BleStatus.poweredOff:
        throw BluetoothUnavailable('Bluetooth is off. Turn it on and try again.');
      case BleStatus.locationServicesDisabled:
        throw BluetoothUnavailable(
          'Turn on Location so Luminar can scan for lights (Android 11 and lower).',
        );
      case BleStatus.unauthorized:
        throw BluetoothUnavailable(
          'Luminar is not allowed to use Bluetooth. Allow it in Settings.',
        );
      case BleStatus.unsupported:
        throw BluetoothUnavailable('This phone does not support Bluetooth Low Energy.');
      case BleStatus.unknown:
        throw BluetoothUnavailable('Bluetooth is not ready yet. Try again.');
    }
  }

  Future<BleStatus> _status() => _ble.statusStream
      .firstWhere((s) => s != BleStatus.unknown)
      .timeout(const Duration(seconds: 3), onTimeout: () => _ble.status);

  @override
  Stream<List<FoundBulb>> scan(
    Set<MeshService> services, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    Uuid uuid(MeshService s) => s == MeshService.provisioning ? _provService : _proxyService;
    final wanted = [for (final s in services) uuid(s)];
    _endScan(); // detaches the previous scan before returning
    final seen = <String, FoundBulb>{};
    final out = _scanOut = StreamController<List<FoundBulb>>();
    List<FoundBulb> sorted() => seen.values.toList()..sort((a, b) => b.rssi - a.rssi);
    _scan = _ble
        .scanForDevices(
          withServices: _scanDiag ? const [] : wanted,
          scanMode: ScanMode.lowLatency,
          requireLocationServicesEnabled: false,
        )
        .listen(
          (d) {
            if (_scanDiag) {
              debugPrint(
                'SCANDIAG ${d.id} "${d.name}" rssi=${d.rssi} ${d.connectable} '
                'uuids=${d.serviceUuids} data=${d.serviceData.map((k, v) => MapEntry('$k', _hex(v)))} '
                'mfr=${_hex(d.manufacturerData)}',
              );
            }
            // A bulb offers one service at a time: provisioning until it
            // joins a network, then proxy.
            var offered = services.where((s) => d.serviceUuids.any((u) => sameUuid(u, uuid(s))));
            // The platform filter matched but listed no UUIDs: trust it.
            if (offered.isEmpty && !_scanDiag && services.length == 1) offered = services;
            if (offered.isEmpty) return;
            final prev = seen[d.id];
            final name = d.name.isNotEmpty ? d.name : (prev?.name ?? 'Bulb ${_short(d.id)}');
            Uint8List? proxyData;
            for (final e in d.serviceData.entries) {
              if (sameUuid(e.key, _proxyService)) proxyData = e.value;
            }
            seen[d.id] = FoundBulb(
              d.id,
              name,
              d.rssi,
              offered.first,
              proxyData: proxyData ?? prev?.proxyData,
            );
            if (!out.isClosed) out.add(sorted());
          },
          onError: (Object e) {
            if (!out.isClosed) {
              out.addError(BluetoothUnavailable('Scanning failed: $e'));
              out.close();
            }
          },
        );
    _scanTimer = Timer(timeout, _endScan);
    return out.stream;
  }

  static String _hex(List<int> b) => b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  static String _short(String id) =>
      id.replaceAll(':', '').substring((id.replaceAll(':', '').length - 4).clamp(0, 99));

  @override
  Future<void> stopScan() => _endScan();

  /// Detaches the current scan synchronously, so a scan started right after
  /// this call is never torn down by it, then waits for the platform.
  Future<void> _endScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    final s = _scan, out = _scanOut;
    _scan = null;
    _scanOut = null;
    await s?.cancel();
    if (out != null && !out.isClosed) await out.close();
  }

  @override
  Future<MeshLink> connect(String id, MeshService service, {bool fresh = false}) async {
    final serviceId = service == MeshService.provisioning ? _provService : _proxyService;
    final inId = service == MeshService.provisioning ? _provIn : _proxyIn;
    final outId = service == MeshService.provisioning ? _provOut : _proxyOut;

    final connected = Completer<void>();
    final done = Completer<void>();
    late final StreamSubscription<ConnectionStateUpdate> conn;
    conn = _ble
        .connectToDevice(id: id, connectionTimeout: const Duration(seconds: 12))
        .listen(
          (u) {
            if (u.connectionState == DeviceConnectionState.connected && !connected.isCompleted) {
              connected.complete();
            } else if (u.connectionState == DeviceConnectionState.disconnected) {
              final err = u.failure;
              if (!connected.isCompleted) {
                connected.completeError(
                  Exception('Could not connect${err != null ? ': ${err.message}' : ''}'),
                );
              }
              if (!done.isCompleted) done.complete();
            }
          },
          onError: (Object e) {
            if (!connected.isCompleted) connected.completeError(e);
            if (!done.isCompleted) done.complete();
          },
        );

    Future<void> close() async {
      await conn.cancel();
      if (!done.isCompleted) done.complete();
    }

    try {
      // The plugin's own timeout does not fire in every state; never wait
      // forever for a connection.
      await connected.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );
      Future<Service?> find() async {
        await _ble.discoverAllServices(id);
        final services = await _ble.getDiscoveredServices(id);
        for (final s in services) {
          if (sameUuid(s.id, serviceId)) return s;
        }
        return null;
      }

      if (fresh && Platform.isAndroid) {
        await _ble.clearGattCache(id).catchError((_) {});
      }
      var svc = await find();
      if (svc == null && Platform.isAndroid && !fresh) {
        await _ble.clearGattCache(id).catchError((_) {});
        svc = await find();
      }
      if (svc == null) throw ServiceNotFound();
      if (!svc.characteristics.any((c) => sameUuid(c.id, inId)) ||
          !svc.characteristics.any((c) => sameUuid(c.id, outId))) {
        throw ServiceNotFound();
      }

      var mtu = 23;
      try {
        mtu = await _ble.requestMtu(deviceId: id, mtu: 247);
      } catch (_) {}
      // No connection priority request: Android has no callback for it, so
      // the plugin holds its operation queue for 2 s, and the bulbs already
      // use a 15 ms connection interval.

      final qIn = QualifiedCharacteristic(
        serviceId: serviceId,
        characteristicId: inId,
        deviceId: id,
      );
      final qOut = QualifiedCharacteristic(
        serviceId: serviceId,
        characteristicId: outId,
        deviceId: id,
      );
      // Single-subscription so notifications that arrive before the caller
      // listens (like the proxy's first beacon) are buffered, not dropped.
      final notes = StreamController<Uint8List>();
      final sub = _ble
          .subscribeToCharacteristic(qOut)
          .listen(
            (v) => notes.add(Uint8List.fromList(v)),
            onError: (Object e) => notes.addError(e),
          );
      // The subscription enables notifications asynchronously; give the
      // CCCD write time to land before the first request goes out.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      return _ReactiveLink(
        id: id,
        maxChunk: (mtu - 3).clamp(20, 244),
        notifications: notes.stream,
        done: done.future,
        writeFn: (chunk) => _ble.writeCharacteristicWithoutResponse(qIn, value: chunk),
        closeFn: () async {
          await sub.cancel();
          await notes.close();
          await close();
        },
      );
    } catch (e) {
      await close();
      rethrow;
    }
  }
}

class _ReactiveLink implements MeshLink {
  @override
  final String id;
  @override
  final int maxChunk;
  @override
  final Stream<Uint8List> notifications;
  @override
  final Future<void> done;
  final Future<void> Function(Uint8List) writeFn;
  final Future<void> Function() closeFn;
  bool _closed = false;

  _ReactiveLink({
    required this.id,
    required this.maxChunk,
    required this.notifications,
    required this.done,
    required this.writeFn,
    required this.closeFn,
  });

  @override
  Future<void> write(Uint8List chunk) => writeFn(chunk);

  @override
  Future<void> disconnect() async {
    if (_closed) return;
    _closed = true;
    await closeFn();
  }
}
