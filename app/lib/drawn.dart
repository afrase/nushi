import 'dart:math';

import 'package:flutter/material.dart';

/// A check drawn [drawn] of the way (0 to 1), at [opacity]: a turn's end,
/// a finished subagent or command. With [sparks], a burst of them leaves
/// it ([Sparks]).
class CheckPainter extends CustomPainter {
  new(this.color, this.drawn, this.opacity, {this.sparks});

  final Color color;
  final double drawn;
  final double opacity;
  final Sparks? sparks;

  /// How long a check takes to draw.
  static const drawFor = Duration(milliseconds: 350);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 10;
    final path = Path()
      ..moveTo(1.5 * s, 5.2 * s)
      ..lineTo(4 * s, 7.5 * s)
      ..lineTo(8.5 * s, 2.5 * s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: opacity);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * drawn), paint);
    }
    sparks?.paint(canvas, size.center(Offset.zero));
  }

  @override
  bool shouldRepaint(CheckPainter old) =>
      old.color != color ||
      old.drawn != drawn ||
      old.opacity != opacity ||
      old.sparks != sparks;
}

/// Six sparks leaving a point [ms] into their burst, and a ring: each a
/// dot of [color] that starts as [band] (the shine's light), flies 9 to
/// 14 px out at evenly spaced angles (about 12° of jitter, from [seed])
/// and falls 2 px, fading and shrinking; the ring grows and fades. A turn
/// that ended while you watched.
@immutable
class Sparks {
  const new(this.ms, {required this.color, required this.band, this.seed = 0});

  final double ms;
  final Color color;
  final Color band;
  final int seed;

  /// The shortest turn whose end sparks: short ones don't need a
  /// celebration.
  static const after = Duration(seconds: 10);

  /// How long the burst lasts.
  static const length = Duration(milliseconds: 520);
  static const _ring = 450.0;
  static const _curve = Cubic(0.2, 0.8, 0.2, 1);

  bool get done => ms >= length.inMilliseconds;

  void paint(Canvas canvas, Offset c) {
    if (done || ms < 0) return;
    final r = Random(seed);
    final base = r.nextDouble() * 2 * pi;
    final e = _curve.transform(ms / length.inMilliseconds);
    final color = Color.lerp(band, this.color, (e / 0.3).clamp(0.0, 1.0))!;
    final alpha = e < 0.3 ? 1.0 : 1 - (e - 0.3) / 0.7;
    final dot = Paint()..color = color.withValues(alpha: alpha);
    for (var i = 0; i < 6; i++) {
      final a = base + i * 2 * pi / 6 + (r.nextDouble() - 0.5) * 0.42;
      final d = 9 + r.nextDouble() * 5;
      final at = c + Offset(cos(a) * d, sin(a) * d + 2) * e;
      canvas.drawCircle(at, 1.2 * (1 - 0.6 * e), dot);
    }
    final v = Curves.easeOut.transform((ms / _ring).clamp(0.0, 1.0));
    if (v < 1) {
      canvas.drawCircle(
        c,
        4 * (1 + 1.4 * v),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = this.color.withValues(alpha: 0.6 * (1 - v)),
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Sparks &&
      other.ms == ms &&
      other.color == color &&
      other.band == band &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(ms, color, band, seed);
}

/// Whether a turn's end gets its sparks: it ran for [turnLasted] of
/// [Sparks.after] or more, and Nushi is in front (the window focused, the
/// phone's page shown), so someone is there to see them; unknown counts
/// as in front.
bool sparksFor(Duration turnLasted) =>
    turnLasted >= Sparks.after &&
    (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
