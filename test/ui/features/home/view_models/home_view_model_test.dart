import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/domain/models/connection.dart';
import 'package:luminar/domain/models/light.dart';
import 'package:luminar/data/repositories/widget_repository.dart';
import 'package:luminar/data/services/home_widget_service.dart';
import 'package:luminar/domain/models/preset.dart';
import 'package:luminar/domain/models/widget_action.dart';

import '../../../../support/harness.dart';
import '../../../../support/mock_bulb.dart';

void main() {
  test('adds a bulb, reports progress, and controls it', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    final seen = <String>[];
    h.vm.addListener(() {
      if (seen.lastOrNull != h.vm.status) seen.add(h.vm.status);
    });

    expect(await h.vm.addLight(nearby(bulb)), isTrue);
    expect(seen, [
      'Connecting to BLE Bulb_7B2E…',
      'Setting up BLE Bulb_7B2E (1 of 3)…',
      'Setting up BLE Bulb_7B2E (2 of 3)…',
      'Setting up BLE Bulb_7B2E (3 of 3)…',
      'BLE Bulb_7B2E is ready.',
    ]);
    expect(h.vm.statusIsError, isFalse);
    expect(h.vm.busy, isFalse);
    expect(h.vm.connection, Connection.on);
    await settle();

    final l = h.vm.lights.single;
    // The simulated bulb reports a nonzero lightness, which means on.
    expect(h.vm.statusLine(l), 'On, 46%, 3000 K');
    await h.vm.setPower(l, false);
    expect(h.vm.statusLine(l), 'Off');
    expect(h.vm.onCount, 0);
    await h.vm.setPower(l, true);
    expect(h.vm.onCount, 1);
    await h.vm.applyPreset(presets.firstWhere((p) => p.name == 'Read'));
    expect(h.vm.statusLine(h.vm.lights.single), 'On, 90%, 4000 K');
    expect([h.vm.allLevel, h.vm.allKelvin], [90, 4000]);
    await settle();
    expect(bulb.kelvin, 4000);
  });

  test('asks to connect before controlling', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    await h.vm.addLight(nearby(bulb));
    await h.vm.disconnect();
    await h.vm.toggleAll();
    expect(h.vm.status, 'Tap Connect first.');
    expect(h.vm.statusIsError, isTrue);
    expect(
      h.vm.statusLine(h.vm.lights.single),
      isNot('Not connected'),
      reason: 'the state is known from before',
    );
  });

  test('explains a bulb that is on another network', () async {
    final h = await Harness.start(FakeBle([MockBulb.foreign('FF:01', 'BLE Bulb_ACF1')]));
    await h.home.addLight(
      const Light(addr: 0x10, name: 'x', devKey: '00000000000000000000000000000000'),
    );
    await h.vm.connect();
    expect(h.vm.isConnected, isFalse);
    expect(h.vm.statusIsError, isTrue);
    expect(h.vm.status, contains('old setup'));
    expect(h.vm.connection, Connection.off);
  });

  test('reports an unexpected disconnect', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    await h.vm.addLight(nearby(bulb));
    bulb.dropConnection();
    await settle();
    expect(h.vm.isConnected, isFalse);
    expect(h.vm.connection, Connection.off);
    expect(h.vm.status, startsWith('Disconnected'));
  });

  test('a bulb that will not take the AppKey needs Finish setup', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E')..answersAppKeyAdd = false;
    final h = await Harness.start(FakeBle([bulb]));
    expect(await h.vm.addLight(nearby(bulb)), isTrue);
    expect(h.vm.status, contains('Finish setup'));
    expect(h.vm.statusIsError, isTrue);
    final l = h.vm.lights.single;
    expect(h.vm.statusLine(l), 'Needs one more setup step');

    bulb.answersAppKeyAdd = true;
    await h.vm.finishSetup(l);
    expect(h.vm.status, 'BLE Bulb_7B2E is ready.');
    expect(h.vm.lights.single.configured, isTrue);
  });

  test('explains a provisioning failure', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    bulb.provisioned = true; // no longer offers PB-GATT
    expect(await h.vm.addLight(nearby(bulb)), isFalse);
    expect(h.vm.statusIsError, isTrue);
    expect(h.vm.lights, isEmpty);
    expect(h.vm.busy, isFalse);
  });

  test('remove, scenes, backup and start over say what happened', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    await h.vm.addLight(nearby(bulb));

    await h.vm.saveScene('Evening');
    expect(h.vm.status, 'Saved on 1 light. Tap it to bring it back.');
    expect(h.vm.scenes, {1: 'Evening'});
    expect(h.vm.showScenes, isTrue);

    expect(await h.vm.restore('LAMPLIGHT1:nope'), isFalse);
    expect(h.vm.status, contains('not valid'));
    expect(h.vm.isConnected, isTrue, reason: 'an invalid code changes nothing');

    final code = h.vm.backupCode();
    await h.vm.remove(h.vm.lights.single);
    expect(h.vm.status, 'BLE Bulb_7B2E was removed.');
    expect(h.vm.lights, isEmpty);

    expect(await h.vm.restore(code), isTrue);
    expect(h.vm.status, 'Restored 1 light. Tap Connect.');
    expect(h.vm.lights, hasLength(1));

    await h.vm.startOver();
    expect(h.vm.lights, isEmpty);
    expect(h.vm.scenes, isEmpty);
    expect(h.vm.status, 'Starting fresh. Tap Add a light.');
  });

  group('lights reset outside the app', () {
    test('says so when every light was reset, and sets one up again', () async {
      final bulb = MockBulb('AA:01', 'BLE Bulb_A9CB');
      final h = await Harness.start(FakeBle([bulb]));
      await h.vm.addLight(nearby(bulb));
      await h.vm.disconnect();
      bulb.factoryReset();

      await h.vm.connect();
      expect(h.vm.status, 'BLE Bulb_A9CB was reset. Tap Set up again next to it.');
      expect(h.vm.statusIsError, isTrue);
      final l = h.vm.lights.single;
      expect(h.vm.statusLine(l), 'Was reset');

      await h.vm.setUpAgain(l);
      expect(h.vm.status, 'BLE Bulb_A9CB is ready.');
      expect(h.vm.lights.single.wasReset, isFalse);
      expect(h.vm.lights, hasLength(1));
    });

    test('mentions reset lights after connecting through another', () async {
      final a = MockBulb('AA:01', 'BLE Bulb_A9CB'), b = MockBulb('AA:02', 'BLE Bulb_A9CC');
      final h = await Harness.start(FakeBle([a, b]));
      await h.vm.addLight(nearby(a));
      await h.vm.addLight(nearby(b));
      await h.vm.disconnect();
      b.factoryReset();
      await h.vm.connect();
      expect(h.vm.isConnected, isTrue);
      expect(h.vm.status, 'Connected. BLE Bulb_A9CC was reset. Tap Set up again next to it.');
    });

    test('lists several reset lights by name', () async {
      final bulbs = [
        for (final n in ['A', 'B', 'C']) MockBulb('AA:0$n', 'Bulb $n'),
      ];
      final h = await Harness.start(FakeBle(bulbs));
      for (final b in bulbs) {
        await h.vm.addLight(nearby(b));
      }
      await h.vm.disconnect();
      for (final b in bulbs) {
        b.factoryReset();
      }
      await h.vm.connect();
      expect(h.vm.status, 'Bulb A, Bulb B and Bulb C were reset. Tap Set up again next to each.');
    });
  });

  test('shows Not responding for a light that does not answer', () async {
    final a = MockBulb('AA:01', 'BLE Bulb_A9CB'), b = MockBulb('AA:02', 'BLE Bulb_A9CC');
    final h = await Harness.start(FakeBle([a, b]));
    await h.vm.addLight(nearby(a));
    await h.vm.addLight(nearby(b)); // configured through a's proxy
    b.factoryReset(); // without a scan noticing
    await h.lights.queryAll();
    await settle(400);
    expect(h.vm.statusLine(h.vm.lights.last), 'Not responding');
    expect(h.vm.statusLine(h.vm.lights.first), isNot('Not responding'));
  });

  test('reconnects on return from the background, not on launch', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final ble = FakeBle([bulb]);
    final h = await Harness.start(ble);
    await h.vm.addLight(nearby(bulb));
    await h.vm.disconnect();
    ble.scans = 0;

    // Android reports resumed while the app launches.
    await h.vm.lifecycleChanged(AppLifecycleState.resumed);
    expect(ble.scans, 0);

    await h.vm.lifecycleChanged(AppLifecycleState.inactive);
    await h.vm.lifecycleChanged(AppLifecycleState.hidden);
    await h.vm.lifecycleChanged(AppLifecycleState.paused);
    await h.vm.lifecycleChanged(AppLifecycleState.resumed);
    expect(ble.scans, 1);
    expect(h.vm.isConnected, isTrue);

    // Already connected: returning again does nothing.
    await h.vm.lifecycleChanged(AppLifecycleState.paused);
    await h.vm.lifecycleChanged(AppLifecycleState.resumed);
    expect(ble.scans, 1);
  });

  group('home-screen widgets', () {
    test('show whether any light is on', () async {
      final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
      final h = await Harness.start(FakeBle([bulb]));
      await h.vm.start();
      expect(h.widgetService.shown, isEmpty, reason: 'no lights yet');
      await h.vm.addLight(nearby(bulb));
      await settle();
      await h.vm.setPower(h.vm.lights.single, false);
      await h.vm.setPower(h.vm.lights.single, true);
      expect(h.widgetService.shown.last, WidgetStatus.on);
      await h.vm.toggleAll();
      expect(h.widgetService.shown.last, WidgetStatus.off);
      expect(h.widgetService.shown, isNot(contains(WidgetStatus.busy)));
      h.vm.dispose();
    });

    test('taps go through the running app, which connects if needed', () async {
      final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
      final h = await Harness.start(FakeBle([bulb]));
      await h.vm.start();
      await h.vm.addLight(nearby(bulb));
      await h.vm.disconnect();
      await settle();
      bulb.on = false;

      // The widget's background isolate, asking the app.
      final widget = WidgetRepository(service: MemoryHomeWidgetService(), portName: h.widgetPort);
      expect(await widget.askApp(const ToggleAllAction()), WidgetStatus.on);
      await settle();
      expect(h.vm.isConnected, isTrue);
      expect(bulb.on, isTrue);
      expect(await widget.askApp(const ToggleAllAction()), WidgetStatus.off);
      h.vm.dispose();
    });
  });

  test('start loads and connects when there are lights', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final ble = FakeBle([bulb]);
    final h = await Harness.start(ble);
    await h.vm.addLight(nearby(bulb));
    await h.vm.disconnect();

    final h2 = Harness(ble, h.store);
    expect(h2.vm.loaded, isFalse);
    await h2.vm.start();
    expect(h2.vm.loaded, isTrue);
    expect(h2.vm.isConnected, isTrue, reason: h2.vm.status);
    expect(h2.vm.status, 'Connected.');
  });
}
