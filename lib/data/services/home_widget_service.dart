import 'package:home_widget/home_widget.dart';

import 'package:luminar/domain/models/widget_action.dart';

/// Draws Luminar's home-screen widgets.
abstract interface class HomeWidgetService {
  Future<WidgetStatus?> lastStatus();
  Future<void> show(WidgetStatus status);
}

/// [HomeWidgetService] backed by the home_widget plugin. The Android
/// providers read `status` from the plugin's shared preferences.
class PluginHomeWidgetService implements HomeWidgetService {
  static const _key = 'status';
  static const _providers = [
    'app.luminar.luminar.LightsToggleWidget',
    'app.luminar.luminar.LightsPresetsWidget',
  ];

  @override
  Future<WidgetStatus?> lastStatus() async {
    final name = await HomeWidget.getWidgetData<String>(_key);
    return WidgetStatus.values.where((s) => s.name == name).firstOrNull;
  }

  @override
  Future<void> show(WidgetStatus status) async {
    await HomeWidget.saveWidgetData<String>(_key, status.name);
    for (final p in _providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: p);
    }
  }
}

/// Keeps the status in memory, for tests.
class MemoryHomeWidgetService implements HomeWidgetService {
  final shown = <WidgetStatus>[];

  @override
  Future<WidgetStatus?> lastStatus() async => shown.lastOrNull;

  @override
  Future<void> show(WidgetStatus status) async => shown.add(status);
}
