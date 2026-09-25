import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/repositories/connection_repository.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/domain/models/light.dart';

import '../../support/harness.dart';
import '../../support/mock_bulb.dart';

void main() {
  test('reports bulbs that belong to another network', () async {
    final h = await Harness.start(FakeBle([MockBulb.foreign('FF:01', 'BLE Bulb_ACF1')]));
    // Pretend we already have a light so connect() scans.
    await h.home.addLight(
      const Light(addr: 0x10, name: 'x', devKey: '00000000000000000000000000000000'),
    );
    expect(await h.connection.connect(), isA<OldSetup>());
    expect(h.connection.isConnected, isFalse);
  });

  group('lights reset outside the app', () {
    test('notices every light was reset and says so', () async {
      final a = MockBulb('AA:01', 'BLE Bulb_A9CB'), b = MockBulb('AA:02', 'BLE Bulb_A9CC');
      final h = await Harness.start(FakeBle([a, b]));
      await h.add(a);
      await h.add(b);
      await h.connection.disconnect();
      a.factoryReset();
      b.factoryReset();

      final r = await h.connection.connect();
      expect(r, isA<LightsWereReset>());
      expect((r as LightsWereReset).names, ['BLE Bulb_A9CB', 'BLE Bulb_A9CC']);
      expect(h.all.every((l) => l.wasReset), isTrue);
      expect(h.home.home.ready, isEmpty, reason: 'reset lights take no commands');
    });

    test('connects through a bulb that was not reset and marks the other', () async {
      final a = MockBulb('AA:01', 'BLE Bulb_A9CB'), b = MockBulb('AA:02', 'BLE Bulb_A9CC');
      final ble = FakeBle([a, b]);
      final store = MemoryHomeStore();
      final h = await Harness.start(ble, store);
      await h.add(a);
      await h.add(b);
      await h.connection.disconnect();
      b.factoryReset();

      expect(await h.connection.connect(), isA<Connected>());
      expect(h.home.home.lightAt(0x11)!.wasReset, isTrue);
      expect(h.home.home.lightAt(0x10)!.wasReset, isFalse);
      final h2 = await Harness.start(ble, store);
      expect(h2.home.home.lightAt(0x11)!.wasReset, isTrue, reason: 'saved');
    });
  });

  test('has nothing to connect to without lights', () async {
    final h = await Harness.start(FakeBle([]));
    expect(await h.connection.connect(), isA<NoLights>());
  });

  test('connects straight to our bulb, skipping a stronger foreign one', () async {
    final ours = MockBulb('AA:01', 'BLE Bulb_7B2E', rssi: -80);
    final ble = FakeBle([ours]);
    final store = MemoryHomeStore();
    final h = await Harness.start(ble, store);
    await h.add(ours);
    await h.connection.disconnect();

    // Recognised by its identity advertisement, not a recorded address.
    await h.home.updateLight(0x10, (l) => l.copyWith(bleId: null));
    final foreign = MockBulb.foreign('FF:01', 'BLE Bulb_A9CC')..rssi = -40;
    ble.bulbs.add(foreign);
    ble.connects.clear();
    final h2 = await Harness.start(ble, store);
    expect(await h2.connection.connect(), isA<Connected>());
    expect(ble.connects, ['AA:01 proxy']);
    expect(h2.log.text, contains('BLE Bulb_A9CC does not identify as one of our lights'));
    expect(h2.log.text, contains('BLE Bulb_7B2E is on our network'));
  });

  test('goes straight to a bulb it added, by Bluetooth address', () async {
    // Like the real bulbs: no beacons, identity adverts that never match,
    // and a stronger bulb from another network nearby.
    final ours = MockBulb('AA:01', 'BLE Bulb_A9CB', rssi: -80)
      ..sendsBeacon = false
      ..advertiseIdentity = false;
    final ble = FakeBle([ours]);
    final store = MemoryHomeStore();
    final h = await Harness.start(ble, store);
    await h.add(ours);
    await h.connection.disconnect();

    ble.bulbs.add(
      MockBulb.foreign('FF:01', 'BLE Bulb_7B2E')
        ..rssi = -40
        ..sendsBeacon = false
        ..advertiseIdentity = false,
    );
    ble.connects.clear();
    final h2 = await Harness.start(ble, store);
    expect(await h2.connection.connect(), isA<Connected>());
    expect(ble.connects, ['AA:01 proxy']);
    expect(h2.log.text, contains('BLE Bulb_A9CB is one of our lights'));
  });

  test('does not wait for a beacon the bulbs never send', () async {
    const slowBeacon = Duration(seconds: 2);
    final ours = MockBulb('AA:01', 'BLE Bulb_A9CB')..sendsBeacon = false;
    final ble = FakeBle([ours]);
    final store = MemoryHomeStore();
    final h = await Harness.start(ble, store);
    await h.add(ours);
    await h.connection.disconnect();

    final h2 = Harness(ble, store, fast.copyWith(beacon: slowBeacon));
    await h2.home.load();
    final watch = Stopwatch()..start();
    expect(await h2.connection.connect(), isA<Connected>());
    expect(watch.elapsed, lessThan(slowBeacon ~/ 2));
  });

  test('skips a foreign proxy that sends no beacon (like the real bulbs)', () async {
    final ours = MockBulb('AA:01', 'BLE Bulb_A9CB', rssi: -80)..sendsBeacon = false;
    final ble = FakeBle([ours]);
    final store = MemoryHomeStore();
    final h = await Harness.start(ble, store);
    await h.add(ours);
    expect(h.single.configured, isTrue, reason: h.vm.status);
    await h.connection.disconnect();

    final foreign = MockBulb.foreign('FF:01', 'BLE Bulb_7B2E')
      ..rssi = -40
      ..sendsBeacon = false
      ..advertiseIdentity = false;
    ours.advertiseIdentity = false; // identity adverts do not match on real bulbs
    // A home restored from a web app backup has no Bluetooth addresses.
    await h.home.updateLight(0x10, (l) => l.copyWith(bleId: null));
    ble.bulbs.add(foreign);
    ble.connects.clear();
    final h2 = await Harness.start(ble, store);
    expect(await h2.connection.connect(), isA<Connected>());
    expect(ble.connects, ['FF:01 proxy', 'AA:01 proxy']);
    expect(h2.connection.deviceId, 'AA:01');
  });

  test('emits dropped when the link goes away, not on disconnect', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    await h.add(bulb);
    var drops = 0;
    h.connection.dropped.listen((_) => drops++);
    bulb.dropConnection();
    await settle();
    expect(drops, 1);
    expect(h.connection.isConnected, isFalse);

    await h.connection.connect();
    await h.connection.disconnect();
    await settle();
    expect(drops, 1);
  });
}
