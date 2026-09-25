import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:luminar/domain/models/log_entry.dart';

/// Every PDU and event, for debugging with real bulbs. Also printed in
/// debug builds.
class ActivityLog extends ChangeNotifier {
  static const _max = 600, _keep = 500;
  final _entries = <LogEntry>[];

  UnmodifiableListView<LogEntry> get entries => UnmodifiableListView(_entries);

  void add(String text) {
    _entries.add(LogEntry(text));
    if (_entries.length > _max) _entries.removeRange(0, _entries.length - _keep);
    if (kDebugMode) debugPrint('[luminar] $text');
    notifyListeners();
  }

  String get text => _entries.join('\n');
}
