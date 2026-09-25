import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Luminar's palette: evening blue in dark mode, cool grey in light mode.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color bg, surface, text, muted, line, off, danger, on;
  const Palette({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.line,
    required this.off,
    required this.danger,
    this.on = const Color(0xFF3BB273),
  });

  static const dark = Palette(
    bg: Color(0xFF182033),
    surface: Color(0xFF212B42),
    text: Color(0xFFEDE8DF),
    muted: Color(0xFF9AA3B5),
    line: Color(0xFF2E3A55),
    off: Color(0xFF34405C),
    danger: Color(0xFFF2B8B5),
  );

  static const light = Palette(
    bg: Color(0xFFE9ECF2),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1C2436),
    muted: Color(0xFF5B6478),
    line: Color(0xFFD3D8E2),
    off: Color(0xFFC9CFDA),
    danger: Color(0xFFB3261E),
  );

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      off: l(off, other.off),
      danger: l(danger, other.danger),
      on: l(on, other.on),
    );
  }
}

TextStyle display(double size, {Color? color}) => GoogleFonts.bricolageGrotesque(
  fontSize: size,
  fontWeight: FontWeight.w700,
  height: 1.15,
  color: color,
);

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFD6AA), brightness: b).copyWith(
      surface: p.surface,
      onSurface: p.text,
      primary: p.text,
      onPrimary: p.bg,
      error: p.danger,
      outline: p.line,
    ),
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );
  final text = GoogleFonts.figtreeTextTheme(base.textTheme)
      .apply(bodyColor: p.text, displayColor: p.text);
  return base.copyWith(
    textTheme: text,
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.bg),
    dividerColor: p.line,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.text,
        foregroundColor: p.bg,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.line),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.text,
        textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.on : p.off,
      ),
      thumbColor: WidgetStateProperty.all(p.surface),
      trackOutlineColor: WidgetStateProperty.all(p.line),
    ),
  );
}

/// Approximate RGB of a black-body color temperature (Tanner Helland).
Color kelvinColor(int k) {
  final t = k / 100;
  double r, g, b;
  r = t <= 66 ? 255 : 329.698727446 * math.pow(t - 60, -0.1332047592);
  g = t <= 66
      ? 99.4708025861 * math.log(t) - 161.1195681661
      : 288.1221695283 * math.pow(t - 60, -0.0755148492);
  b = t >= 66
      ? 255
      : t <= 19
      ? 0
      : 138.5177312231 * math.log(t - 10) - 305.0447927307;
  int c(double v) => v.round().clamp(0, 255);
  return Color.fromARGB(255, c(r), c(g), c(b));
}
