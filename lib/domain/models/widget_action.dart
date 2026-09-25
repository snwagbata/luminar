import 'preset.dart';

/// What a home-screen widget shows.
enum WidgetStatus {
  on,
  off,

  /// Sending a command.
  busy,

  /// The last command failed (no lights in range, Bluetooth off, …).
  unavailable,
}

/// A tap on a home-screen widget, carried as a `luminar://` URI.
sealed class WidgetAction {
  const WidgetAction();

  Uri toUri();

  static WidgetAction? fromUri(Uri? uri) {
    if (uri == null || uri.scheme != 'luminar') return null;
    return switch (uri.host) {
      'toggle' => const ToggleAllAction(),
      'preset' => switch (presets.where((p) => p.name == uri.queryParameters['name'])) {
        final found when found.isNotEmpty => ApplyPresetAction(found.first),
        _ => null,
      },
      _ => null,
    };
  }
}

/// Turns every light off if any is on, otherwise on.
final class ToggleAllAction extends WidgetAction {
  const ToggleAllAction();

  @override
  Uri toUri() => Uri.parse('luminar://toggle');
}

final class ApplyPresetAction extends WidgetAction {
  final Preset preset;
  const ApplyPresetAction(this.preset);

  @override
  Uri toUri() => Uri(scheme: 'luminar', host: 'preset', queryParameters: {'name': preset.name});
}
