import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';

/// What's on its way: an arc of [color] (the accent if not given), its
/// line [strokeWidth] wide, chasing round a ring that fills the box it's
/// given (16 square when loose). It turns on [pulseClock], not on a ticker
/// of its own as Material's spinner does: one can show for as long as a
/// command a code block ran (a dev server, for hours), and a ticker draws
/// the whole window every frame. With Reduce Motion, or in a still frame,
/// it's a ring three parts drawn.
class Spinner extends StatelessWidget {
  const new({super.key, this.strokeWidth = 1.5, this.color});

  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(16),
    painter: _Arc(
      color ?? Theme.of(context).colorScheme.primary,
      strokeWidth,
      turning: !reduceMotion(context) && loopRepaint != null,
    ),
  );
}

/// The spinner's arc: it goes round once every [turn] while its length
/// grows and shrinks over [breath], as Material's does.
class _Arc extends CustomPainter {
  new(this.color, this.strokeWidth, {required this.turning})
    : super(repaint: turning ? loopRepaint : null);

  final Color color;
  final double strokeWidth;
  final bool turning;

  static const turn = Duration(milliseconds: 1333);
  static const breath = Duration(milliseconds: 2666);

  @override
  void paint(Canvas canvas, Size size) {
    final (from, length) = turning
        ? (
            2 * pi * loopPhase(turn),
            0.1 + 0.65 * (0.5 - 0.5 * cos(2 * pi * loopPhase(breath))),
          )
        : (0.0, 0.75);
    canvas.drawArc(
      (Offset.zero & size).deflate(strokeWidth / 2),
      -pi / 2 + from,
      2 * pi * length,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Arc old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.turning != turning;
}
