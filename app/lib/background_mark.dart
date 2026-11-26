import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/field_outline.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/run_state.dart';

part 'background_droplets.dart';
part 'background_trace.dart';

/// The mark of a chat whose turn ended while its background tasks run
/// (#113), "rest and play": two drops of [color] side by side, still for
/// two seconds; then for 1.9 seconds they spin clockwise twice round,
/// slowly and then faster, squashed and stretched by their way, each a
/// teardrop as it gathers speed, its tail trailing along the way it came;
/// spiral in and merge into one drop, which lands wide and springs long;
/// and spiral out of it as two again, a neck between them thinning and
/// parting, slow, and wobble into their places like jelly, round only
/// once they're still.
///
/// The two are drops of liquid: each a round head and a tapering tail
/// run into it with a fillet, the two joined by a neck where they near (a
/// smooth union of their fields, traced as one path, its area kept).
/// Tracing is costly, so each of the loop's outlines is traced once per
/// size and kept ([backgroundMarkPath]): every mark draws the same kept
/// path, and a frame of the play draws one small path.
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

  /// The loop's ticks of [pulseClock], at rest and at play: 38 to play,
  /// so the two join over three ticks and their neck thins over four
  /// before it parts, each tick a little change from the one before, and
  /// the last eight are theirs to wobble in.
  static const restTicks = 40;
  static const playTicks = 38;
  static const int ticks = restTicks + playTicks;

  /// The loop's length: 3.9 s.
  // design: a loop's beat, on pulseClock: 78 ticks, 40 at rest, 38 at play
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
  return _trace(_Frame.at(t), size);
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
