// Renders the README screenshots into docs/screenshots/:
//
//   flutter test tool/screenshots/take_screenshots.dart
//
// The app runs with its real object graph over simulated bulbs
// (test/support/mock_bulb.dart), so the screens show real app states.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:luminar/config/dependencies.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/data/services/home_widget_service.dart';
import 'package:luminar/domain/models/preset.dart';
import 'package:luminar/main.dart';
import 'package:provider/provider.dart';

import '../../test/support/harness.dart';
import '../../test/support/mock_bulb.dart';

const _phone = Size(390, 844);
const _pixelRatio = 2.0;

/// Widget tests draw icon fonts as boxes unless the font is loaded.
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final font = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('app')));
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('docs/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _wait(WidgetTester tester, [int ms = 100]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pumpAndSettle();
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  debugPrint = (String? message, {int? wrapWidth}) {};

  setUpAll(_loadMaterialIcons);

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    testWidgets('screenshots ($theme)', (tester) async {
      tester.view.physicalSize = _phone * _pixelRatio;
      tester.view.devicePixelRatio = _pixelRatio;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      // Three lights in the home, and two reset bulbs nearby to add.
      final lights = [
        MockBulb('AA:01', 'BLE Bulb_A9CB'),
        MockBulb('AA:02', 'BLE Bulb_A9CC'),
        MockBulb('AA:03', 'BLE Bulb_ACF1'),
      ];
      final ble = FakeBle([
        ...lights,
        MockBulb('AA:04', 'BLE Bulb_7B2E', rssi: -52),
        MockBulb('AA:05', 'BLE Bulb_5C10', rssi: -71),
      ]);
      final deps = (await tester.runAsync(() async {
        final d = Dependencies(
          ble: ble,
          store: MemoryHomeStore(),
          timings: fast,
          widgetService: MemoryHomeWidgetService(),
          widgetPort: 'luminar.screenshots.$theme',
        );
        d.providers; // creates every object in the real zone
        final vm = d.homeViewModel;
        await d.home.load();
        for (final b in lights) {
          await vm.addLight(nearby(b));
        }
        final names = ['Living room', 'Desk lamp', 'Bedroom'];
        for (var i = 0; i < names.length; i++) {
          await vm.rename(vm.lights[i], names[i]);
        }
        Preset preset(String name) => presets.firstWhere((p) => p.name == name);
        await vm.applyPreset(preset('Read'));
        await vm.saveScene('Movie night');
        await vm.applyPreset(preset('Relax'));
        await vm.saveScene('Evening');
        await vm.setPower(vm.lights[2], false);
        await settle(100);
        // Reconnect for a clean status line.
        await vm.disconnect();
        await vm.connect();
        await settle(200);
        return d;
      }))!;

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('app'),
          child: MultiProvider(providers: deps.providers, child: const LuminarApp()),
        ),
      );
      await _wait(tester);

      await _shot(tester, 'home-$theme');

      // The light list, with one light opened.
      await tester.ensureVisible(find.text('Your lights'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desk lamp'));
      await _shot(tester, 'lights-$theme');

      // The Add a light sheet.
      await tester.tap(find.text('Desk lamp')); // close it again
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add a light'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a light'));
      await _wait(tester);
      await _shot(tester, 'add-light-$theme');

      await tester.tapAt(const Offset(20, 20)); // dismiss
      await _wait(tester);
      await tester.runAsync(deps.homeViewModel.disconnect);
    }, timeout: const Timeout(Duration(minutes: 1)));
  }
}
