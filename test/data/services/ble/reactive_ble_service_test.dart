import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/data/services/ble/reactive_ble_service.dart';

/// Stands in for the platform plugin: scanForDevices emits whatever the test
/// pushes into [adverts].
class _FakeReactiveBle implements FlutterReactiveBle {
  // ignore: close_sinks
  final adverts = StreamController<DiscoveredDevice>.broadcast();
  int scansStarted = 0, scansCancelled = 0;

  @override
  Stream<DiscoveredDevice> scanForDevices({
    required List<Uuid> withServices,
    ScanMode scanMode = ScanMode.balanced,
    bool requireLocationServicesEnabled = true,
  }) {
    scansStarted++;
    late StreamController<DiscoveredDevice> c; // ignore: close_sinks
    StreamSubscription<DiscoveredDevice>? sub;
    c = StreamController<DiscoveredDevice>(
      onListen: () => sub = adverts.stream.listen(c.add),
      onCancel: () {
        scansCancelled++;
        return sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiscoveredDevice bulb(String id, String name, int rssi, {String service = '1827'}) =>
    DiscoveredDevice(
      id: id,
      name: name,
      serviceData: const {},
      // Android reports 128-bit UUIDs.
      serviceUuids: [Uuid.parse('0000$service-0000-1000-8000-00805f9b34fb')],
      manufacturerData: Uint8List(0),
      rssi: rssi,
    );

void main() {
  uuidTests();
  test('scans for several services and says which one each bulb offers', () async {
    final fake = _FakeReactiveBle();
    final adapter = ReactiveBleService(ble: fake);
    final lists = <List<FoundBulb>>[];
    adapter
        .scan({MeshService.provisioning, MeshService.proxy}, timeout: const Duration(seconds: 5))
        .listen(lists.add);
    await Future<void>.delayed(Duration.zero);
    fake.adverts
      ..add(bulb('AA:01', 'new', -50))
      ..add(bulb('AA:02', 'ours', -60, service: '1828'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      {for (final b in lists.last) b.id: b.service},
      {'AA:01': MeshService.provisioning, 'AA:02': MeshService.proxy},
    );
    await adapter.stopScan();
  });

  test('first scan stays open and reports bulbs', () async {
    final fake = _FakeReactiveBle();
    final adapter = ReactiveBleService(ble: fake);
    final lists = <List<FoundBulb>>[];
    var done = false;
    adapter
        .scan({MeshService.provisioning}, timeout: const Duration(seconds: 5))
        .listen(lists.add, onDone: () => done = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isFalse, reason: 'scan must not end before its timeout');

    fake.adverts.add(bulb('00:11:22:33:44:01', 'BLE Bulb_7B2E', -60));
    fake.adverts.add(bulb('00:11:22:33:44:02', 'BLE Bulb_A9CB', -50));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(lists.last.map((b) => b.name), ['BLE Bulb_A9CB', 'BLE Bulb_7B2E']);

    await adapter.stopScan();
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
    expect(fake.scansCancelled, 1);
  });

  test('a second scan replaces the first and stays open', () async {
    final fake = _FakeReactiveBle();
    final adapter = ReactiveBleService(ble: fake);
    var firstDone = false, secondDone = false;
    final second = <List<FoundBulb>>[];
    adapter
        .scan({MeshService.provisioning}, timeout: const Duration(seconds: 5))
        .listen((_) {}, onDone: () => firstDone = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    adapter
        .scan({MeshService.provisioning}, timeout: const Duration(seconds: 5))
        .listen(second.add, onDone: () => secondDone = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(firstDone, isTrue);
    expect(secondDone, isFalse);
    expect(fake.scansCancelled, 1);

    fake.adverts.add(bulb('00:11:22:33:44:03', 'BLE Bulb_ACF1', -65));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(second.last.single.name, 'BLE Bulb_ACF1');
    await adapter.stopScan();
  });

  test('scan ends by itself at the timeout', () async {
    final fake = _FakeReactiveBle();
    final adapter = ReactiveBleService(ble: fake);
    final ended = Completer<void>();
    adapter
        .scan({MeshService.proxy}, timeout: const Duration(milliseconds: 50))
        .listen((_) {}, onDone: ended.complete);
    await ended.future.timeout(const Duration(seconds: 1));
    expect(fake.scansCancelled, 1);
  });
}

void uuidTests() {
  test('matches short and 128-bit forms of the same UUID', () {
    // Android reports discovered services in the 128-bit form.
    final discovered = Uuid.parse('00001827-0000-1000-8000-00805f9b34fb');
    expect(sameUuid(discovered, Uuid.parse('1827')), isTrue);
    expect(
      sameUuid(Uuid.parse('2adb'), Uuid.parse('00002ADB-0000-1000-8000-00805F9B34FB')),
      isTrue,
    );
    expect(sameUuid(discovered, Uuid.parse('1828')), isFalse);
  });
}
