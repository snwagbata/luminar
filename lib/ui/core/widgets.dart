import 'package:flutter/material.dart';

import 'package:luminar/domain/models/light.dart';
import 'package:luminar/domain/models/preset.dart';
import 'package:luminar/ui/core/theme.dart';

/// The big round button that toggles every light and glows in their color.
class LampButton extends StatelessWidget {
  final int onCount, total;
  final Color glow;
  final double level; // 0–1
  final VoidCallback onTap;
  const LampButton({
    super.key,
    required this.onCount,
    required this.total,
    required this.glow,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = onCount > 0 ? 0.25 + level * 0.75 : 0.0;
    final size = (MediaQuery.sizeOf(context).width * 0.62).clamp(160.0, 240.0);
    final word = onCount == 0
        ? 'Off'
        : onCount == total
        ? 'On'
        : '$onCount of $total on';
    return Column(
      children: [
        Semantics(
          button: true,
          toggled: onCount > 0,
          label: 'All lights',
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glow.withValues(alpha: 0.2 + a * 0.8),
                    glow.withValues(alpha: a * 0.7),
                    p.off,
                  ],
                  stops: const [0, 0.5, 0.74],
                ),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: a * 0.55),
                    blurRadius: a * 96,
                    spreadRadius: a * 24,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                word,
                style: display(
                  22,
                  color: onCount > 0 ? const Color(0xFF1C2436) : p.text.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          onCount > 0 ? 'Tap to turn every light off' : 'Tap to turn every light on',
          style: TextStyle(color: p.muted, fontSize: 15),
        ),
      ],
    );
  }
}

/// A labeled slider with a gradient track.
class GradientSlider extends StatelessWidget {
  final String label;
  final String valueText;
  final double value, min, max;
  final int? divisions;
  final Gradient gradient;
  final ValueChanged<double> onChanged;
  const GradientSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.gradient,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                valueText,
                style: TextStyle(
                  color: p.muted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 14,
            trackShape: _GradientTrack(gradient, p.line),
            thumbColor: p.surface,
            thumbShape: _Thumb(p.text),
            overlayColor: p.text.withValues(alpha: 0.08),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
            semanticFormatterCallback: (_) => valueText,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _GradientTrack extends SliderTrackShape with BaseSliderTrackShape {
  final Gradient gradient;
  final Color border;
  const _GradientTrack(this.gradient, this.border);

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    context.canvas
      ..drawRRect(r, Paint()..shader = gradient.createShader(rect))
      ..drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = border,
      );
  }
}

class _Thumb extends SliderComponentShape {
  final Color ring;
  const _Thumb(this.ring);
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(30, 30);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    c.drawCircle(
      center + const Offset(0, 1),
      15,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    c.drawCircle(center, 15, Paint()..color = sliderTheme.thumbColor!);
    c.drawCircle(
      center,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
  }
}

const warmGradient = LinearGradient(
  colors: [Color(0xFFFFB46B), Color(0xFFFFE4CE), Color(0xFFF3F2FF)],
);

LinearGradient brightGradient(BuildContext context, Color glow) =>
    LinearGradient(colors: [Palette.of(context).off, glow]);

String kelvinLabel(int k) => '$k K';

/// Brightness and warmth sliders.
class LightSliders extends StatelessWidget {
  final int level, kelvin;
  final bool showWarmth;
  final ValueChanged<int> onLevel;
  final ValueChanged<int>? onKelvin;
  const LightSliders({
    super.key,
    required this.level,
    required this.kelvin,
    required this.onLevel,
    this.onKelvin,
    this.showWarmth = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GradientSlider(
          label: 'Brightness',
          valueText: '$level%',
          value: level.toDouble(),
          min: 1,
          max: 100,
          gradient: brightGradient(context, kelvinColor(kelvin)),
          onChanged: (v) => onLevel(v.round()),
        ),
        if (showWarmth && onKelvin != null)
          GradientSlider(
            label: 'Warm to cool',
            valueText: kelvinLabel(kelvin),
            value: kelvin.toDouble(),
            min: minKelvin.toDouble(),
            max: maxKelvin.toDouble(),
            divisions: (maxKelvin - minKelvin) ~/ 100,
            gradient: warmGradient,
            onChanged: (v) => onKelvin!((v / 100).round() * 100),
          ),
      ],
    );
  }
}

class PresetChips extends StatelessWidget {
  final ValueChanged<Preset> onTap;
  const PresetChips({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in presets)
          ActionChip(
            onPressed: () => onTap(preset),
            backgroundColor: p.surface,
            side: BorderSide(color: p.line),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            avatar: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kelvinColor(preset.kelvin)
                    .withValues(alpha: 0.35 + preset.level / 100 * 0.65),
                border: Border.all(color: p.line),
              ),
            ),
            label: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}

/// The small glowing dot at the start of a light's row.
class Orb extends StatelessWidget {
  final bool lit;
  final Color color;
  final double level;
  const Orb({super.key, required this.lit, required this.color, required this.level});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? color : Palette.of(context).off,
        boxShadow: lit
            ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 5 + level * 16)]
            : null,
      ),
    );
  }
}

/// A bordered panel.
class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
