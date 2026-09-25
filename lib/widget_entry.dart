import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:luminar/config/dependencies.dart';
import 'package:luminar/data/services/ble/reactive_ble_service.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/domain/models/widget_action.dart';

/// Runs in a background isolate when a home-screen widget is tapped.
///
/// If the app is running, it has the proxy connection, so the tap is handed
/// to it. Otherwise this isolate connects, sends one command and
/// disconnects.
@pragma('vm:entry-point')
Future<void> widgetTapped(Uri? uri) async {
  final action = WidgetAction.fromUri(uri);
  if (action == null) return;
  final deps = Dependencies(ble: ReactiveBleService(interactive: false), store: SecureHomeStore());
  final widgets = deps.widgets;
  final wasOn = await widgets.lastStatus() == WidgetStatus.on;
  await widgets.show(WidgetStatus.busy);

  final viaApp = await widgets.askApp(action);
  if (viaApp != null) {
    await widgets.show(viaApp);
    return;
  }

  var status = WidgetStatus.unavailable;
  try {
    await deps.home.load();
    status = await deps.widgetAction(action, wasOn: wasOn);
    // Writes are queued in the platform; let the last one go out before
    // the link closes.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  } catch (e) {
    debugPrint('[luminar] Widget action failed: $e');
  } finally {
    await deps.connection.disconnect();
    await widgets.show(status);
    deps.dispose();
  }
}
