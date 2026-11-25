import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/field_outline.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/run_state.dart';

/// The mark of a chat whose turn ended while its background tasks run
/// (#113), "rest and play": two drops of [color] side by side, still for
/// two seconds; then for a second and a half they lean apart, pull
/// together and merge into one drop that spins a turn, stretched by its
/// spin, and fling themselves apart into the two again, which wobble and
/// settle.
///
/// Each drop is squashed and stretched with its area kept, and a neck of
/// liquid joins the two where they near (a smooth union of their fields,
/// traced as one path). Tracing is costly, so each of the loop's outlines
/// is traced once per size and kept ([backgroundMarkPath]): every mark
/// draws the same kept path, and a frame of the play draws one small path.
///
/// It moves with the repaint [BackgroundMark.repaintOf] gives: the play's
/// ticks of [pulseClock], and between plays one timer for the next, so at
/// rest nothing repaints or ticks for it. Without one (Reduce
/// Motion, a hidden pane, a still frame) it draws [t], or its rest.
class BackgroundMark extends CustomPainter {
  new(this.color, {this.t, super.repaint}) : _moves = repaint != null;

  final Color color;

  /// The phase it's drawn at, from 0 to 1, when given.
  final double? t;

  final bool _moves;

  /// The loop's ticks of [pulseClock], at rest and at play.
  static const restTicks = 40;
  static const playTicks = 30;
  static const int ticks = restTicks + playTicks;

  /// The loop's length: 3.5 s.
  // design: a loop's beat, on pulseClock: 70 ticks, 40 at rest, 30 at play
  static const period = Duration(milliseconds: ticks * 1000 ~/ pulseRate);

  /// What a mark under [context] repaints with: the play's ticks; null
  /// where loops don't move ([loopRepaintOf]: a still frame, tickers off).
  static Listenable? repaintOf(BuildContext context) =>
      loopRepaintOf(context) == null ? null : _gate;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    backgroundMarkPath(
      size,
      t ?? (_moves && pulseClock.running ? _gate.phase : 0),
    ),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(BackgroundMark old) =>
      old.color != color || old.t != t || old._moves != _moves;
}

/// Whether the background marks play now (not at rest).
@visibleForTesting
bool get backgroundMarkPlays => _gate.playing;

/// How many outlines have been traced, kept or not: a test's count.
@visibleForTesting
int backgroundMarkTraces = 0;

/// The mark's outline in a room of [size] at the tick of its loop nearest
/// phase [t]: one path, traced once and kept, one for the whole rest and
/// one for each of the play's other ticks, shared by every mark of that
/// size.
Path backgroundMarkPath(Size size, double t) {
  const n = BackgroundMark.ticks;
  final tick = (t % 1 * n).round() % n;
  // 0: the rest, which the play's first tick is too (it starts from it).
  final i = max(tick - BackgroundMark.restTicks, 0);
  // A few sizes at most (the dot's room, a test's enlargement).
  if (_kept.length > 8 && !_kept.containsKey(size)) _kept.clear();
  final kept = _kept[size] ??= List.filled(BackgroundMark.playTicks, null);
  return kept[i] ??= _traceAt(size, i == 0 ? 0 : tick / n);
}

final Map<Size, List<Path?>> _kept = runMap();

/// Every kept outline let go: a test that counts the tracing.
@visibleForTesting
void forgetBackgroundMarks() => _kept.clear();

/// The mark's outline in a room of [size] at phase [t], traced anew (what
/// [backgroundMarkPath] keeps).
Path _traceAt(Size size, double t) {
  backgroundMarkTraces++;
  return _trace(_Frame.at(t, size.shortestSide / _room), size);
}

/// The room the amounts below are in: `ChatDot`'s (its size times 1.6).
const double _room = 11.2;

/// A drop's radius at rest, and half the distance between the two.
const _r0 = 2.0;
const double _apart = 2.68;

/// The neck's reach at rest: too short to join the two.
const _kRest = 0.4;

/// The play's length and the loop's, in milliseconds.
const double _play = BackgroundMark.playTicks * 1000.0 / pulseRate;
const double _loop = BackgroundMark.ticks * 1000.0 / pulseRate;

/// The mark at one moment: where the drops are, how they're bent, how far
/// the liquid between them reaches.
class _Frame {
  new({
    required this.h,
    required this.angle,
    required this.m,
    required this.k,
    required this.scale,
  });

  factory at(double t, double scale) {
    final u = (t % 1) * _loop - (_loop - _play);
    if (u < 0) {
      return _Frame(
        h: _apart,
        angle: 0,
        m: _Bend.identity,
        k: _kRest,
        scale: scale,
      );
    }
    final h = _h(u);
    final a = _angle(u);
    // Each drop stretches along its travel as it goes fast, from its speed
    // (a millisecond either side).
    Offset at(double u) => Offset.fromDirection(_angle(u), _h(u));
    final v = (at(u + 1) - at(u - 1)) / 2; // px a ms
    final speed = v.distance;
    final m = speed < 1e-6
        ? _Bend.identity
        : _Bend.stretch(v.direction, 1 + min(speed * 22, 0.3));
    return _Frame(
      h: h,
      angle: a,
      m: m * _Bend.stretch(a, _q(u)),
      k: _k(u),
      scale: scale,
    );
  }

  /// Half the distance between the drops' centres, along [angle].
  final double h;
  final double angle;

  /// Each drop's squash and stretch: a unit circle's map (area kept).
  final _Bend m;

  /// How far the neck reaches (a smooth union's width).
  final double k;

  /// Room size over [_room].
  final double scale;
}

double _seg(double u, double a, double b, [Curve c = Curves.easeInOut]) =>
    c.transform(((u - a) / (b - a)).clamp(0.0, 1.0));

double _lerp(double a, double b, double v) => a + (b - a) * v;

// The play, in milliseconds from its start:
//    0 to  180  anticipation: the two lean apart and gather (squashed);
//  180 to  530  they pull together, faster and faster, starting to turn,
//               a neck reaching out between them;
//  530 to  660  impact: one drop, squashed flat along its travel;
//  660 to 1060  it springs long and spins, a peanut stretched by its turn;
// 1060 to 1230  a beat, then it flings itself apart past where they rest;
//               the neck thins and snaps;
// 1230 to 1500  the two wobble back and settle.
// The pull-in and the impact have the 100 ms the owner asked for (#113,
// "maybe like 100ms slower"): at 1400 they read as a pop.

const _pullIn = Cubic(0.55, 0, 0.9, 0.45); // slow to go, fast at the end

double _h(double u) {
  if (u < 180) return _lerp(_apart, 3, _seg(u, 0, 180));
  if (u < 530) return _lerp(3, 0.37, _seg(u, 180, 530, _pullIn));
  if (u < 660) return 0.37;
  if (u < 920) return _lerp(0.37, 1.84, _seg(u, 660, 920));
  if (u < 1060) return _lerp(1.84, 1.63, _seg(u, 920, 1060));
  if (u < 1230) {
    return _lerp(1.63, 3.1, _seg(u, 1060, 1230, const Cubic(0.5, 0, 0.2, 1)));
  }
  final s = (u - 1230) / (_play - 1230);
  // A damped wobble that is nothing at its end (cos 2.5 pi is 0).
  return _apart + (3.1 - _apart) * exp(-3 * s) * cos(2.5 * pi * s);
}

double _angle(double u) => 2 * pi * _seg(u, 180, 1280, Curves.easeInOutCubic);

/// The squash along the line through the two (under 1: squashed along it).
double _q(double u) {
  if (u < 180) return _lerp(1, 0.8, _seg(u, 0, 180));
  if (u < 370) return _lerp(0.8, 1, _seg(u, 180, 370, Curves.easeOut));
  if (u < 530) return 1;
  if (u < 610) return _lerp(1, 0.6, _seg(u, 530, 610, Curves.easeOut));
  if (u < 740) return _lerp(0.6, 1.2, _seg(u, 610, 740));
  if (u < 1060) return _lerp(1.2, 1.1, _seg(u, 740, 1060));
  if (u < 1230) return _lerp(1.1, 1, _seg(u, 1060, 1230));
  final s = (u - 1230) / (_play - 1230);
  // Recoil as the neck snaps: squashed, then long, then still (sin 3 pi
  // is 0).
  return 1 - 0.22 * exp(-2.5 * s) * sin(3 * pi * s);
}

// The neck reaches out early, so two ticks before the drops are one show
// them joined by a thin bridge (as the split's last joined tick does).
double _k(double u) {
  if (u < 205) return _kRest;
  if (u < 480) {
    return _lerp(_kRest, 3.2, _seg(u, 205, 480, Curves.easeOutCubic));
  }
  if (u < 1070) return 3.2;
  return _lerp(3.2, _kRest, _seg(u, 1070, 1230, Curves.easeIn));
}

/// A 2 by 2 matrix, row by row.
class _Bend {
  const new(this.a, this.b, this.c, this.d);

  /// Stretched by [s] along [angle] and squeezed by 1/[s] across it.
  factory stretch(double angle, double s) {
    final co = cos(angle);
    final si = sin(angle);
    final w = s - 1 / s;
    return _Bend(
      s * co * co + si * si / s,
      w * co * si,
      w * co * si,
      s * si * si + co * co / s,
    );
  }

  _Bend operator *(_Bend o) => _Bend(
    a * o.a + b * o.c,
    a * o.b + b * o.d,
    c * o.a + d * o.c,
    c * o.b + d * o.d,
  );

  _Bend get inverse {
    final det = a * d - b * c;
    return _Bend(d / det, -b / det, -c / det, a / det);
  }

  static const identity = _Bend(1, 0, 0, 1);

  final double a;
  final double b;
  final double c;
  final double d;
}

/// The two drops' field in a room of [size]: under 0 inside, about the
/// distance to the edge, traced where it's at a level the level chosen
/// so the shape keeps two drops' area.
Path _trace(_Frame f, Size size) {
  const n = 72; // cells across
  final side = size.shortestSide;
  final cell = side / n;
  final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
  final s = f.scale;
  final inv = f.m.inverse;
  final axis = Offset.fromDirection(f.angle, f.h * s);
  final mid = size.center(Offset.zero);
  final c1 = mid + axis;
  final c2 = mid - axis;
  final r = _r0 * s;
  final k = f.k * s;
  final field = List<double>.filled((n + 1) * (n + 1), 0);
  for (var j = 0; j <= n; j++) {
    for (var i = 0; i <= n; i++) {
      final p = origin + Offset(i * cell, j * cell);
      double lobe(Offset c) {
        final x = p.dx - c.dx;
        final y = p.dy - c.dy;
        final lx = inv.a * x + inv.b * y;
        final ly = inv.c * x + inv.d * y;
        return sqrt(lx * lx + ly * ly) - r;
      }

      final d1 = lobe(c1);
      final d2 = lobe(c2);
      final w = max(k - (d1 - d2).abs(), 0.0) / k;
      // The room's edge is outside, so every outline closes inside it.
      final edge = i == 0 || j == 0 || i == n || j == n;
      field[j * (n + 1) + i] = edge ? cell : min(d1, d2) - w * w * k / 4;
    }
  }
  // At the level that keeps the two drops' area.
  return fieldOutline(field, n, cell, origin, area: 2 * pi * r * r, step: s);
}

/// The marks' beat, one for every mark so all play in step: at rest it
/// waits on one timer for the next play and hears nothing else; at play
/// it hears [pulseClock] and passes on each of its [BackgroundMark.playTicks]
/// ticks, then rests again. Nushi going to the back ends a play (each mark
/// draws its rest); it plays again once in front.
class _Gate extends ChangeNotifier {
  // design: the loop's rest, on the clock's beat
  static const _rest = Duration(
    milliseconds: BackgroundMark.restTicks * 1000 ~/ pulseRate,
  );

  Timer? _timer;
  bool playing = false;
  int _tick = 0; // of the play
  bool _clockRan = false; // as of the clock's last word

  /// Where in the loop the marks are, from 0 to 1.
  double get phase =>
      playing ? (BackgroundMark.restTicks + _tick) / BackgroundMark.ticks : 0;

  @override
  void addListener(VoidCallback listener) {
    final first = !hasListeners;
    super.addListener(listener);
    // A painter's successor finds the rest's timer or the play still on.
    if (first && _timer == null && !playing) _toRest();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    // Stops once the work at hand is done, if no one came back: a painter
    // made anew as its widget rebuilds leaves and its successor comes at
    // once (RenderCustomPaint swaps them), and a mark rebuilt now and then
    // would otherwise start its rest again each time and never play.
    scheduleMicrotask(() {
      if (hasListeners) return;
      _timer?.cancel();
      _timer = null;
      _leaveClock();
    });
  }

  void _toRest() {
    _leaveClock();
    _timer?.cancel();
    _timer = Timer(_rest, _toPlay);
  }

  void _toPlay() {
    _timer = null;
    playing = true;
    _tick = 0; // the play's first frame is the rest's look
    pulseClock.addListener(_heard);
    _clockRan = pulseClock.running;
  }

  void _leaveClock() {
    if (playing) pulseClock.removeListener(_heard);
    playing = false;
    _tick = 0;
  }

  void _heard() {
    final ran = _clockRan;
    _clockRan = pulseClock.running;
    if (!_clockRan) {
      // Nushi went to the back: the rest's look, and rest.
      _toRest();
      notifyListeners();
      return;
    }
    if (!ran) return; // back in front: its next tick plays on
    if (++_tick >= BackgroundMark.playTicks) _toRest();
    notifyListeners();
  }
}

final _gate = _Gate();
