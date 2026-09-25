import 'package:luminar/data/repositories/connection_repository.dart';
import 'package:luminar/data/repositories/light_repository.dart';
import 'package:luminar/domain/models/widget_action.dart';

/// Runs a widget tap while the app is not running: connect, send one group
/// command, report what the widget should show.
class WidgetActionUseCase {
  WidgetActionUseCase({required this._connection, required this._lights});

  final ConnectionRepository _connection;
  final LightRepository _lights;

  /// [wasOn] is what the widget showed: the lights' last known state, since
  /// a fresh connection has not heard from them yet.
  Future<WidgetStatus> call(WidgetAction action, {required bool wasOn}) async {
    if (!_connection.isConnected && await _connection.connect() is! Connected) {
      return WidgetStatus.unavailable;
    }
    switch (action) {
      case ToggleAllAction():
        await _lights.setAllPower(!wasOn);
        return wasOn ? WidgetStatus.off : WidgetStatus.on;
      case ApplyPresetAction(:final preset):
        await _lights.applyPreset(preset);
        return WidgetStatus.on;
    }
  }
}
