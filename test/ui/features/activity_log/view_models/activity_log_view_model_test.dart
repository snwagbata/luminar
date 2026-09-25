import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/ui/features/activity_log/view_models/activity_log_view_model.dart';

void main() {
  test('shows the newest entry first and follows the log', () {
    final log = ActivityLog()..add('first');
    final vm = ActivityLogViewModel(log: log);
    var changes = 0;
    vm.addListener(() => changes++);
    log.add('ERROR second');
    expect(changes, 1);
    expect(vm.entries.map((e) => e.text), ['ERROR second', 'first']);
    expect(vm.entries.first.isError, isTrue);
    expect(vm.text.split('\n').map((l) => l.substring(14)), ['first', 'ERROR second']);
    vm.dispose();
    log.add('third');
    expect(changes, 1, reason: 'stops listening when disposed');
  });
}
