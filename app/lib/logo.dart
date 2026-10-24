import 'dart:math';

import 'package:flutter/widgets.dart';

/// Nushi's mark, the still lake: broken rings in [color], agents riding them,
/// and the light at the centre. The same drawing as the app icon
/// (tools/icongen).
class Logo extends StatelessWidget {
  const Logo({required this.color, this.size = 72, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _Lake(color));
}

const _light = Color(0xFFF5A524);

// On a 100-unit grid: radius, stroke, segments, drawn share, rotation.
const _rings = [
  (31.0, 2.8, 4, 40 / 48.7, 0.0),
  (19.0, 2.8, 4, 24 / 29.85, 30.0),
];
// Radius, angle, size.
const _beads = [
  (31.0, 0.0, 3.8),
  (31.0, 135.0, 3.8),
  (19.0, -90.0, 3.2),
  (19.0, 30.0, 3.2),
];

class _Lake extends CustomPainter {
  _Lake(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The rings span 12–88 of the grid.
    final u = size.shortestSide / 76;
    final c = size.center(Offset.zero);
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
    final bead = Paint()..color = color;
    for (final (r, deg, s) in _beads) {
      final a = deg * pi / 180;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r * u, s * u, bead);
    }
    canvas.drawCircle(c, 5.6 * u, Paint()..color = _light);
  }

  @override
  bool shouldRepaint(_Lake old) => old.color != color;
}
