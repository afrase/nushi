import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:nushi/motion.dart';

/// Nushi's mark, the still lake: broken rings in [color], agents riding them,
/// and the light at the centre. The same drawing as the app icon
/// (tools/icongen). [turning], its rings go round, each the other way
/// with its agents on it, on [pulseClock] (the jump chip while the agent
/// works, #51), once every [outerTurn] and [innerTurn]; with Reduce Motion
/// or at rest ([loopMoving]) it stands still as the icon.
class Logo extends StatelessWidget {
  const new({
    required this.color,
    this.size = 72,
    this.turning = false,
    this.outerTurn = LogoPainter.driftOuter,
    this.innerTurn = LogoPainter.driftInner,
    super.key,
  });

  final Color color;
  final double size;
  final bool turning;

  /// How long the outer ring takes to go round once, turning.
  final Duration outerTurn;

  /// How long the inner ring takes to go round once, the other way.
  final Duration innerTurn;

  @override
  Widget build(BuildContext context) {
    final turns = turning && !reduceMotion(context);
    return CustomPaint(
      size: Size.square(size),
      painter: LogoPainter(
        color,
        turning: turns,
        outerTurn: outerTurn,
        innerTurn: innerTurn,
        repaint: turns ? loopRepaintOf(context) : null,
      ),
    );
  }
}

// design: the logo's own orange, whatever the theme.
const _light = Color(0xFFF5A524);

// On a 100-unit grid: radius, stroke, segments, drawn share, rotation.
const List<(double, double, int, double, double)> _rings = [
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

/// [Logo]'s drawing. Turning, the outer ring goes round clockwise once
/// every [outerTurn] and the inner one the other way every [innerTurn],
/// read from [loopPhase] as it paints; still, as the icon. A ring's
/// stroke is never thinner than [leastStroke], so a small mark doesn't
/// fade to hairlines; from about 40 across it's drawn to scale.
class LogoPainter extends CustomPainter {
  new(
    this.color, {
    required this.turning,
    this.outerTurn = driftOuter,
    this.innerTurn = driftInner,
    super.repaint,
  });

  final Color color;
  final bool turning;

  /// How long the outer ring takes to go round once.
  final Duration outerTurn;

  /// How long the inner ring takes to go round once, the other way.
  final Duration innerTurn;

  // design: a slow drift, a loop's beat on pulseClock (well under a
  // pixel a tick at the chip's size)
  static const driftOuter = Duration(seconds: 6);
  // design: a loop's beat on pulseClock, quicker than the outer ring's,
  // so the two never line up for long
  static const driftInner = Duration(seconds: 4);

  /// The thinnest a ring is drawn, in logical points.
  static const leastStroke = 1.5;

  /// How far each ring has turned now, in radians: the outer clockwise,
  /// the inner the other way; both 0 when still.
  (double, double) get turned => turning && loopMoving
      ? (2 * pi * loopPhase(outerTurn), -2 * pi * loopPhase(innerTurn))
      : (0.0, 0.0);

  @override
  void paint(Canvas canvas, Size size) {
    // The rings span 12–88 of the grid.
    final u = size.shortestSide / 76;
    final c = size.center(Offset.zero);
    final (outer, inner) = turned;
    double spin(double r) => r == _rings.first.$1 ? outer : inner;
    for (final (r, stroke, n, share, rot) in _rings) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(stroke * u, leastStroke)
        ..strokeCap = StrokeCap.round;
      final period = 2 * pi / n;
      // Less the round caps' reach, so the gaps stay as wide.
      final sweep = period * share - paint.strokeWidth / (r * u);
      for (var k = 0; k < n; k++) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * u),
          rot * pi / 180 + k * period + spin(r),
          sweep,
          false,
          paint,
        );
      }
    }
    final bead = Paint()..color = color;
    for (final (r, deg, s) in _beads) {
      final a = deg * pi / 180 + spin(r);
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r * u, s * u, bead);
    }
    canvas.drawCircle(c, 5.6 * u, Paint()..color = _light);
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.color != color ||
      old.turning != turning ||
      old.outerTurn != outerTurn ||
      old.innerTurn != innerTurn;
}
