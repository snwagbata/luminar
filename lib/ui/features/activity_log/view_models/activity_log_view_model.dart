import 'package:flutter/foundation.dart';

import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/domain/models/log_entry.dart';

/// The activity log, newest first.
class ActivityLogViewModel extends ChangeNotifier {
  ActivityLogViewModel({required this._log}) {
    _log.addListener(notifyListeners);
  }

  final ActivityLog _log;

  List<LogEntry> get entries => _log.entries.reversed.toList();

  /// The whole log as text, oldest first, for copying and sharing.
  String get text => _log.text;

  @override
  void dispose() {
    _log.removeListener(notifyListeners);
    super.dispose();
  }
}
