import 'dart:math';

import 'package:flutter/widgets.dart';

/// Nushi's mark, the still lake: broken rings in [color], agents riding them,
/// and the [light] at the centre. The same drawing as the app icon
/// (tools/icongen); `orrery.dart` sets it moving.
class Logo extends StatelessWidget {
  const new({
    required this.color,
    required this.light,
    this.size = 72,
    super.key,
  });

  final Color color;
  final Color light;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _Lake(color, light));
}

/// Points to a unit of the mark's 100-unit grid in a mark of [size]: the
/// rings span 12–88 of it.
double markUnit(double size) => size / 76;

/// The light's radius, in units.
const sunRadius = 5.6;

// On a 100-unit grid: radius, stroke, segments, drawn share, rotation.
const List<(double, double, int, double, double)> _rings = [
  (31.0, 2.8, 4, 40 / 48.7, 0.0),
  (19.0, 2.8, 4, 24 / 29.85, 30.0),
];

/// The agents on the rings: ring radius, angle in degrees, radius.
const markBeads = [
  (31.0, 0.0, 3.8),
  (31.0, 135.0, 3.8),
  (19.0, -90.0, 3.2),
  (19.0, 30.0, 3.2),
];

/// Draws the broken rings around [c], [u] points to a unit.
void paintRings(Canvas canvas, Offset c, double u, Color color) {
  for (final (r, stroke, n, share, rot) in _rings) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * u
      ..strokeCap = StrokeCap.round;
    final period = 2 * pi / n;
    final sweep = period * share - stroke / r;
    for (var k = 0; k < n; k++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * u),
        rot * pi / 180 + k * period,
        sweep,
        false,
        paint,
      );
    }
  }
}

class _Lake extends CustomPainter {
  new(this.color, this.light);

  final Color color;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final u = markUnit(size.shortestSide);
    final c = size.center(Offset.zero);
    paintRings(canvas, c, u, color);
    final bead = Paint()..color = color;
    for (final (r, deg, s) in markBeads) {
      final a = deg * pi / 180;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r * u, s * u, bead);
    }
    canvas.drawCircle(c, sunRadius * u, Paint()..color = light);
  }

  @override
  bool shouldRepaint(_Lake old) => old.color != color || old.light != light;
}
