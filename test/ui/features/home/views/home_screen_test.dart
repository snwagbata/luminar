import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:luminar/config/dependencies.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/data/services/home_widget_service.dart';
import 'package:luminar/main.dart';
import 'package:luminar/ui/features/home/view_models/home_view_model.dart';
import 'package:provider/provider.dart';

import '../../../../support/harness.dart';
import '../../../../support/mock_bulb.dart';

/// Writes a PNG of the app to build/screens/ when SCREENSHOTS=1.
Future<void> shot(WidgetTester tester, String name) async {
  if (Platform.environment['SCREENSHOTS'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('app')));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/screens/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Pumps the app with the real dependency graph over [ble]. Returns the
/// home screen's view model.
Future<HomeViewModel> pumpApp(WidgetTester tester, FakeBle ble, Brightness b) async {
  tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.platformBrightnessTestValue = b;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  // Build the graph in the real zone, so its stream listeners and saves
  // do not wait on the fake clock.
  final deps = (await tester.runAsync(() async {
    final d = Dependencies(
      ble: ble,
      store: MemoryHomeStore(),
      timings: fast,
      widgetService: MemoryHomeWidgetService(),
      widgetPort: 'luminar.test.screen.${b.name}',
    );
    d.providers; // creates every object
    return d;
  }))!;
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('app'),
      child: MultiProvider(providers: deps.providers, child: const LuminarApp()),
    ),
  );
  // Let the home load in the real zone.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pumpAndSettle();
  return deps.homeViewModel;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  debugPrint = debugPrintSynchronously;

  for (final b in Brightness.values) {
    testWidgets('empty state, add a light, control it (${b.name})', (tester) async {
      final bulbA = MockBulb('AA:01', 'BLE Bulb_7B2E');
      final bulbB = MockBulb('AA:02', 'BLE Bulb_A9CB', rssi: -80);
      final vm = await pumpApp(tester, FakeBle([bulbA, bulbB]), b);

      expect(find.text('Luminar'), findsOneWidget);
      expect(find.textContaining('No lights yet'), findsOneWidget);
      await shot(tester, '1-empty-${b.name}');

      // The add sheet lists both unprovisioned bulbs.
      await tester.tap(find.text('Add a light'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('BLE Bulb_7B2E'), findsOneWidget);
      expect(find.text('BLE Bulb_A9CB'), findsOneWidget);
      await shot(tester, '2-add-${b.name}');
      await tester.tapAt(const Offset(20, 20)); // dismiss the sheet
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        expect(await vm.addLight(nearby(bulbA)), isTrue);
        await vm.setPower(vm.lights.single, true);
        await vm.saveScene('Evening');
      });
      await tester.pumpAndSettle();
      expect(find.text('On'), findsOneWidget); // the lamp
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);

      // Expand the row to show per-light controls.
      await tester.tap(find.text('BLE Bulb_7B2E'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Use as default'), findsOneWidget);
      await shot(tester, '3-controls-${b.name}');

      // The lamp turns everything off.
      await tester.tap(find.text('On'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(bulbA.on, isFalse);
      expect(find.text('Off'), findsWidgets);

      // The activity log opens with its own view model.
      await tester.tap(find.text('Activity log'));
      await tester.pumpAndSettle();
      expect(find.textContaining('BLE Bulb_7B2E is ready.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.runAsync(vm.disconnect);
    }, timeout: const Timeout(Duration(seconds: 40)));
  }
}
