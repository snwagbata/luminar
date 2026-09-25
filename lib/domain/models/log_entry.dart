/// One line of the activity log.
class LogEntry {
  final DateTime at;
  final String text;
  LogEntry(this.text, {DateTime? at}) : at = at ?? DateTime.now();

  bool get isError => text.startsWith('ERROR');

  @override
  String toString() => '${at.toIso8601String().substring(11, 23)}  $text';
}
