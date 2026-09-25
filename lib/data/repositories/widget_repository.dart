import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:luminar/data/services/home_widget_service.dart';
import 'package:luminar/domain/models/widget_action.dart';

/// A widget tap handed to the running app, which answers with the status
/// the widget should show.
class WidgetRequest {
  final WidgetAction action;
  final void Function(WidgetStatus status) reply;
  const WidgetRequest(this.action, this.reply);
}

/// The home-screen widgets: what they show, and taps passed between the
/// widget's background isolate and the running app.
class WidgetRepository {
  WidgetRepository({required this._service, this.portName = defaultPortName});

  final HomeWidgetService _service;

  /// Where the running app listens for widget taps. Tests use their own.
  final String portName;
  static const defaultPortName = 'luminar.widget';

  WidgetStatus? _shown;

  Future<WidgetStatus?> lastStatus() async => _shown ?? await _service.lastStatus();

  /// Updates the widgets, unless they already show [status].
  Future<void> show(WidgetStatus status) async {
    if (status == _shown) return;
    _shown = status;
    await _service.show(status);
  }

  // ---------- the running app ----------

  ReceivePort? _port;

  /// In the running app: widget taps from the background isolate.
  Stream<WidgetRequest> listen() {
    final port = _port = ReceivePort();
    IsolateNameServer.removePortNameMapping(portName);
    IsolateNameServer.registerPortWithName(port.sendPort, portName);
    return port
        .map((msg) {
          if (msg case [final String uri, final SendPort replyTo]) {
            final action = WidgetAction.fromUri(Uri.parse(uri));
            if (action != null) return WidgetRequest(action, (s) => replyTo.send(s.name));
          }
          return null;
        })
        .where((r) => r != null)
        .cast<WidgetRequest>();
  }

  void close() {
    if (_port == null) return;
    IsolateNameServer.removePortNameMapping(portName);
    _port?.close();
    _port = null;
  }

  // ---------- the widget's background isolate ----------

  /// Hands [action] to the running app, if there is one, and returns the
  /// status it answered with. Returns null if the app is not running.
  Future<WidgetStatus?> askApp(
    WidgetAction action, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final app = IsolateNameServer.lookupPortByName(portName);
    if (app == null) return null;
    final answer = ReceivePort();
    try {
      app.send([action.toUri().toString(), answer.sendPort]);
      final name = await answer.first.timeout(timeout);
      return WidgetStatus.values.where((s) => s.name == name).firstOrNull ??
          WidgetStatus.unavailable;
    } on TimeoutException {
      return WidgetStatus.unavailable;
    } finally {
      answer.close();
    }
  }
}
