import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/repositories/widget_repository.dart';
import 'package:luminar/data/services/home_widget_service.dart';
import 'package:luminar/domain/models/widget_action.dart';

void main() {
  test('redraws the widgets only when the status changes', () async {
    final service = MemoryHomeWidgetService();
    final r = WidgetRepository(service: service, portName: 'luminar.test.redraw');
    expect(await r.lastStatus(), isNull);
    await r.show(WidgetStatus.on);
    await r.show(WidgetStatus.on);
    await r.show(WidgetStatus.off);
    expect(service.shown, [WidgetStatus.on, WidgetStatus.off]);
    expect(await r.lastStatus(), WidgetStatus.off);
  });

  test('hands a tap to the running app and returns its answer', () async {
    final app = WidgetRepository(service: MemoryHomeWidgetService(), portName: 'luminar.test.app');
    final widget = WidgetRepository(
      service: MemoryHomeWidgetService(),
      portName: 'luminar.test.app',
    );
    expect(await widget.askApp(const ToggleAllAction()), isNull, reason: 'app not running');

    final seen = <WidgetAction>[];
    app.listen().listen((r) {
      seen.add(r.action);
      r.reply(WidgetStatus.off);
    });
    expect(await widget.askApp(const ToggleAllAction()), WidgetStatus.off);
    expect(seen.single, isA<ToggleAllAction>());

    app.close();
    expect(await widget.askApp(const ToggleAllAction()), isNull, reason: 'app closed');
  });

  test('gives up on an app that does not answer', () async {
    final app = WidgetRepository(service: MemoryHomeWidgetService(), portName: 'luminar.test.mute');
    app.listen().listen((_) {});
    final widget = WidgetRepository(
      service: MemoryHomeWidgetService(),
      portName: 'luminar.test.mute',
    );
    expect(
      await widget.askApp(const ToggleAllAction(), timeout: const Duration(milliseconds: 50)),
      WidgetStatus.unavailable,
    );
    app.close();
  });
}
