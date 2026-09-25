import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/domain/models/preset.dart';
import 'package:luminar/domain/models/widget_action.dart';

void main() {
  test('actions travel as luminar:// URIs', () {
    for (final a in [const ToggleAllAction(), for (final p in presets) ApplyPresetAction(p)]) {
      final back = WidgetAction.fromUri(a.toUri());
      expect(back.runtimeType, a.runtimeType);
      if (a is ApplyPresetAction) expect((back! as ApplyPresetAction).preset, a.preset);
    }
    expect(const ToggleAllAction().toUri().toString(), 'luminar://toggle');
    expect(ApplyPresetAction(presets[1]).toUri().toString(), 'luminar://preset?name=Read');
  });

  test('ignores URIs it does not know', () {
    for (final u in ['other://toggle', 'luminar://nope', 'luminar://preset?name=Disco', null]) {
      expect(WidgetAction.fromUri(u == null ? null : Uri.parse(u)), isNull, reason: '$u');
    }
  });
}
