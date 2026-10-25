import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/mesh/messages.dart';
import 'package:luminar/data/repositories/light_repository.dart';
import 'package:luminar/domain/models/light.dart';
import 'package:luminar/domain/models/preset.dart';

import '../../support/harness.dart';
import '../../support/mock_bulb.dart';

Preset preset(String name) => presets.firstWhere((p) => p.name == name);

void main() {
  group('setup', () {
    test('binds every model reported in composition data', () async {
      final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
      final h = await Harness.start(FakeBle([bulb]));
      await h.add(bulb);
      expect(bulb.bound, {0x1000, 0x1300, 0x1303, 0x1304, 0x1203, 0x1204, 0x1206, 0x1207});
      expect(h.single.models.values.every((v) => v), isTrue);
      expect(h.single.models.keys.toSet(), Models.bindable.keys.toSet());
      expect(h.log.text, contains('0x05040000'));
    });

    test('falls back to the light models without composition data', () async {
      final bulb = MockBulb('AA:02', 'BLE Bulb_A9CB')..answersComposition = false;
      final h = await Harness.start(FakeBle([bulb]));
      await h.add(bulb);
      expect(bulb.bound, {0x1000, 0x1300, 0x1303});
      expect(h.single.configured, isTrue);
    });

    test('retries a dropped segmented AppKey Add', () async {
      final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E')..dropFirstSegmented = true;
      final h = await Harness.start(FakeBle([bulb]));
      await h.add(bulb);
      expect(bulb.received, contains('dropped segmented'));
      expect(h.single.configured, isTrue, reason: h.vm.status);
    });

    test('clears a stale GATT cache when reconnecting after provisioning', () async {
      final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E')..staleGattCacheAfterProvisioning = true;
      final ble = FakeBle([bulb]);
      final h = await Harness.start(ble);
      await h.add(bulb);
      expect(ble.connects, ['AA:01 provisioning', 'AA:01 proxy fresh']);
      expect(h.single.configured, isTrue);
    });

    test('never opens a second connection to a bulb it is connected to', () async {
      final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E')..answersAppKeyAdd = false;
      final ble = FakeBle([bulb]);
      final h = await Harness.start(ble);
      expect(await h.add(bulb), isTrue);
      expect(h.single.configured, isFalse);
      expect(ble.connects, ['AA:01 provisioning', 'AA:01 proxy fresh']);
      expect(h.connection.isConnected, isTrue);
    });

    test('configures a new bulb through an existing proxy connection', () async {
      final a = MockBulb('AA:01', 'BLE Bulb_7B2E', rssi: -50);
      final b = MockBulb('AA:02', 'BLE Bulb_A9CB', rssi: -70);
      final h = await Harness.start(FakeBle([a, b]));
      await h.add(a);
      await h.add(b);
      expect(h.all.map((l) => l.addr), [0x10, 0x11]);
      expect(h.all.every((l) => l.configured), isTrue);
    });

    test('acknowledges segmented replies so the bulb stops resending them', () async {
      // Real bulbs resent Composition Status after every later message.
      final bulb = MockBulb('AA:01', 'BLE Bulb_A9CB');
      final h = await Harness.start(FakeBle([bulb]));
      expect(await h.add(bulb), isTrue);
      expect(bulb.acked, hasLength(1));
    });

    test('hears replies from a proxy that only forwards via an accept list', () async {
      // Like the Sengled bulbs: a reject-list filter forwards nothing.
      final bulb = MockBulb('AA:01', 'BLE Bulb_A9CB')
        ..honorsRejectList = false
        ..sendsBeacon = false;
      final h = await Harness.start(FakeBle([bulb]));
      expect(await h.add(bulb), isTrue);
      expect(h.single.configured, isTrue, reason: h.vm.status);
      expect(bulb.bound, containsAll([0x1000, 0x1300, 0x1303]));
    });
  });

  group('control', () {
    late MockBulb bulb;
    late Harness h;
    setUp(() async {
      bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
      h = await Harness.start(FakeBle([bulb]));
      await h.add(bulb);
      await settle();
    });

    test('reads the state back after setup', () {
      expect(h.lights.stateOf(0x10).known, isTrue);
      expect(h.single.kelvin, 3000);
    });

    test('an off bulb that still reports its lightness stays off', () async {
      // Sengled bulbs answer OnOff Status "off", then a CTL Status with the
      // lightness they will return to, not 0.
      bulb
        ..on = false
        ..lightness = 65535;
      await h.lights.queryState(0x10);
      await settle();
      expect(h.lights.stateOf(0x10).on, isFalse);
      expect(h.single.level, 100, reason: 'the lightness still sets the level');

      bulb.on = true;
      await h.lights.queryState(0x10);
      await settle();
      expect(h.lights.stateOf(0x10).on, isTrue);
    });

    test('power, presets, sliders and toggle all', () async {
      await h.lights.setPower(0x10, true);
      await settle();
      expect(bulb.on, isTrue);

      await h.lights.applyPreset(preset('Daylight'));
      await settle();
      expect([bulb.kelvin, bulb.lightness], [6500, 65535]);

      h.lights.setLevel(0x10, level: 50, kelvin: 2700);
      await settle();
      expect([bulb.kelvin, bulb.lightness], [2700, LightRepository.toLightness(50)]);
      expect([h.single.level, h.single.kelvin], [50, 2700]);

      await h.lights.toggleAll();
      await settle();
      expect(bulb.on, isFalse);
      expect(h.lights.stateOf(0x10).on, isFalse);
    });

    test('a light that stops answering is not responding', () async {
      final other = MockBulb('AA:02', 'BLE Bulb_A9CC');
      h.ble.bulbs.add(other);
      await h.add(other); // configured through the first bulb's proxy
      expect(h.connection.deviceId, 'AA:01');
      await h.lights.queryState(0x11);
      await settle(400);
      expect(h.lights.stateOf(0x11).responding, isTrue);

      other.factoryReset();
      await h.lights.queryState(0x11);
      await settle(400);
      expect(h.lights.stateOf(0x11).responding, isFalse);
      expect(h.lights.stateOf(0x10).responding, isTrue);
    });

    test('rename and remove (Node Reset)', () async {
      await h.lights.rename(0x10, '  Desk  ');
      expect(h.single.name, 'Desk');
      await h.lights.rename(0x10, ' ');
      expect(h.single.name, 'Desk');
      await h.lights.remove(0x10);
      expect(bulb.provisioned, isFalse);
      expect(h.all, isEmpty);
    });

    test('CTL setup: temperature range and default', () async {
      expect((await h.lights.temperatureRange(0x10))!.max, 6500);
      final r = await h.lights.setTemperatureRange(0x10, 3000, 5000);
      expect(r!.ok, isTrue);
      expect([bulb.rangeMin, bulb.rangeMax], [3000, 5000]);

      final d = await h.lights.setCtlDefault(0x10, 50, 4000);
      expect(d!.kelvin, 4000);
      expect(bulb.defaultLightness, LightRepository.toLightness(50));
      expect((await h.lights.ctlDefault(0x10))!.kelvin, 4000);
    });

    test('scheduler: set, list and read back an action', () async {
      const e = ScheduleEntry(
        index: 3,
        hour: 7,
        minute: 30,
        weekdays: 0x1f,
        action: ScheduleAction.on,
      );
      final set = await h.lights.setScheduleAction(0x10, e);
      expect(set!.index, 3);
      expect(await h.lights.schedules(0x10), [3]);
      final back = (await h.lights.scheduleAction(0x10, 3))!;
      expect(
        [back.hour, back.minute, back.weekdays, back.action],
        [7, 30, 0x1f, ScheduleAction.on],
      );
      expect(back.year, ScheduleEntry.anyYear);
    });
  });

  group('All lights group', () {
    Future<(Harness, List<MockBulb>)> threeBulbs() async {
      final bulbs = [
        MockBulb('AA:01', 'BLE Bulb_A9CB'),
        MockBulb('AA:02', 'BLE Bulb_A9CC'),
        MockBulb('AA:03', 'BLE Bulb_ACF1'),
      ];
      final h = await Harness.start(FakeBle(bulbs));
      for (final b in bulbs) {
        expect(await h.add(b), isTrue, reason: h.vm.status);
      }
      await settle();
      return (h, bulbs);
    }

    int phoneWrites(List<MockBulb> bulbs) => bulbs.fold(0, (n, b) => n + b.fromPhone);

    test('setup subscribes the light and scene models to the group', () async {
      final (h, bulbs) = await threeBulbs();
      for (final b in bulbs) {
        for (final m in [Models.onOff, Models.lightness, Models.ctl, Models.scene]) {
          expect(b.subscriptions[m], contains(allLightsGroup), reason: '${b.name} model $m');
        }
      }
      expect(h.all.every((l) => l.grouped), isTrue);
    });

    test('all-lights commands go out as one group message', () async {
      final (h, bulbs) = await threeBulbs();
      final before = phoneWrites(bulbs);
      await h.lights.toggleAll();
      await settle();
      expect(phoneWrites(bulbs) - before, 1);
      final on = bulbs.first.on;
      expect(bulbs.map((b) => b.on), everyElement(on));

      final mid = phoneWrites(bulbs);
      await h.lights.applyPreset(preset('Daylight'));
      await settle();
      expect(phoneWrites(bulbs) - mid, 1);
      expect(bulbs.map((b) => b.kelvin), everyElement(6500));
      expect(bulbs.map((b) => b.on), everyElement(isTrue));
    });

    test('lights added before groups join the group on the next connect', () async {
      final (h, bulbs) = await threeBulbs();
      await h.home.updateLight(0x11, (l) => l.copyWith(groupModels: {}));
      bulbs[1].subscriptions.clear();
      await h.connection.disconnect();
      await h.vm.connect();
      await settle(300);
      expect(h.home.home.lightAt(0x11)!.grouped, isTrue);
      expect(bulbs[1].subscriptions[Models.ctl], contains(allLightsGroup));

      await h.lights.applyPreset(preset('Night'));
      await settle();
      final kelvin = bulbs.first.kelvin;
      expect(bulbs.map((b) => b.kelvin), everyElement(kelvin));
    });

    test('a light that is not in the group still gets its own message', () async {
      final (h, bulbs) = await threeBulbs();
      await h.home.updateLight(0x12, (l) => l.copyWith(groupModels: {}));
      bulbs[2].subscriptions.clear();
      final before = phoneWrites(bulbs);
      await h.lights.applyPreset(preset('Daylight'));
      await settle();
      expect(phoneWrites(bulbs) - before, 2);
      expect(bulbs.map((b) => b.kelvin), everyElement(6500));
    });

    test('scene recall goes out as one group message', () async {
      final (h, bulbs) = await threeBulbs();
      await h.lights.applyPreset(preset('Relax'));
      await settle();
      await h.vm.saveScene('Evening');
      final scene = h.scenes.names.keys.single;
      await h.lights.applyPreset(preset('Daylight'));
      await settle();
      expect(bulbs.map((b) => b.kelvin), everyElement(6500));

      final before = phoneWrites(bulbs);
      await h.vm.recallScene(scene);
      await settle();
      expect(bulbs.map((b) => b.kelvin), everyElement(preset('Relax').kelvin));
      // One recall, then a state query (2 messages) per light.
      expect(phoneWrites(bulbs) - before, 1 + 2 * bulbs.length);
    });
  });
}
