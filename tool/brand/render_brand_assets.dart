// Renders Luminar's icon and splash images into assets/brand/.
//
//   flutter test tool/brand/render_brand_assets.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// The bulb is Material Icons' "lightbulb" (Apache License 2.0). Its path
// spans x 5–19 and y 2–22 of a 24-unit box, so (12, 12) is its centre; that
// point is placed exactly at the centre of every image.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_parsing/path_parsing.dart';

const navy = Color(0xFF182033);
const amber = Color(0xFFFFD6AA);
const white = Color(0xFFFFFFFF);

const bulbPath =
    'M9,21c0,0.55 0.45,1 1,1h4c0.55,0 1,-0.45 1,-1v-1L9,20v1zM12,2C8.14,2 5,5.14 5,9c0,2.38 '
    '1.19,4.47 3,5.74L8,17c0,0.55 0.45,1 1,1h6c0.55,0 1,-0.45 1,-1v-2.26c1.81,-1.27 3,-3.36 '
    '3,-5.74 0,-3.86 -3.14,-7 -7,-7z';

class _PathProxy extends PathProxy {
  final path = Path();
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

/// The bulb, [height] pixels tall, centred on [centre].
Path bulb(Offset centre, double height) {
  final p = _PathProxy();
  writeSvgPathDataToPath(bulbPath, p);
  final k = height / 20; // the glyph is 20 units tall
  // Scale by k about the glyph's centre (12, 12), then move it to [centre].
  return p.path.transform(
    Float64List.fromList([
      k,
      0,
      0,
      0,
      0,
      k,
      0,
      0,
      0,
      0,
      1,
      0,
      centre.dx - 12 * k,
      centre.dy - 12 * k,
      0,
      1,
    ]),
  );
}

/// Draws one image. [size] is the canvas edge in pixels; [bulbHeight] and
/// [glowRadius] are fractions of it.
Future<void> render(
  String file, {
  required int size,
  Color? background,
  Color bulbColor = amber,
  double bulbHeight = 0.42,
  double glowRadius = 0.40,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  final centre = Offset(s / 2, s / 2);
  if (background != null) canvas.drawRect(Offset.zero & Size(s, s), Paint()..color = background);
  if (glowRadius > 0) {
    canvas.drawCircle(
      centre,
      s * glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE3C2).withValues(alpha: 0.55),
            const Color(0xFFFFB46B).withValues(alpha: 0.22),
            const Color(0xFFFFB46B).withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: s * glowRadius)),
    );
  }
  canvas.drawPath(bulb(centre, s * bulbHeight), Paint()..color = bulbColor);
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File('assets/brand/$file')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render brand assets', () async {
    // Full icon: iOS and pre-Oreo Android (no transparency allowed on iOS).
    await render('icon.png', size: 1024, background: navy);
    // Adaptive icon foreground: the launcher shows the middle 72 of 108 units
    // (67 %) and masks it to a shape, so keep the bulb well inside that.
    await render('icon_foreground.png', size: 1024, bulbHeight: 0.36, glowRadius: 0.36);
    // Android 13 themed icon: a flat silhouette the system tints.
    await render(
      'icon_monochrome.png',
      size: 1024,
      bulbColor: white,
      bulbHeight: 0.36,
      glowRadius: 0,
    );
    // Splash before Android 12 and on iOS: shown at 1/4 of its pixel size
    // (xxxhdpi), so 192 dp.
    await render('splash.png', size: 768, bulbHeight: 0.42, glowRadius: 0.45);
    // Android 12+ splash icon: 288 dp canvas, masked to a 192 dp circle.
    await render('splash_android12.png', size: 1152, bulbHeight: 0.28, glowRadius: 0.30);
  });
}
