import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:nushi/theme/theme.dart';

/// Whether nothing should move: macOS's Reduce Motion, or the browser's
/// reduced-motion setting on the phone, as Flutter reports them.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

/// Nushi's motion: a few durations and curves, so things that move alike
/// move the same (the fluidity review, 2026-11). The rules:
/// - input never waits: the state changes at once and motion is only
///   drawn; what's coming is live from its first frame, what's leaving
///   takes no pointer or focus, and a second press reverses from wherever
///   the motion is;
/// - exits are faster than entries, and nothing comes in for longer than
///   [Motion.enter];
/// - the transcript's width never eases (it lays out every entry): beside
///   the chat, lay out once at the final width and glide by a transform;
/// - under [reduceMotion], sizes and places jump; feedback such as a press
///   tint stays;
/// - nothing runs at rest: a one-shot run ends, loops are on [pulseClock].
abstract final class Motion {
  /// Text and color crossfades, a button swapping: barely seen.
  static const quick = Duration(milliseconds: 120);

  /// Size: opening, folding, bars sliding, rows sliding apart.
  static const standard = Duration(milliseconds: 200);

  /// Coming in: panes, the toast.
  static const enter = Duration(milliseconds: 240);

  /// Going: two-thirds of coming in, so what leaves is out of the way.
  static const exit = Duration(milliseconds: 160);

  /// Entering and moving: quick off the mark, a long settle.
  static const Cubic settle = Cubic(0.2, 0.8, 0.2, 1);

  /// Heights and widths.
  static const Curve size = Curves.ease;

  /// Leaving: gathers speed as it goes.
  static const Cubic leave = Cubic(0.4, 0, 1, 1);
}

/// One clock for the motions that run once ([ClockRun]) and the reply's
/// pacing, every frame: it ticks only while something listens, so they
/// move in step and stop together, and what listens repaints from it
/// without its own controller. What loops for as long as a state lasts is
/// on [pulseClock].
class _Clock extends ChangeNotifier {
  Ticker? _ticker;
  Duration now = Duration.zero;

  /// Where in a loop of [period] the clock is, from 0 to 1.
  double phase(Duration period) =>
      now.inMicroseconds % period.inMicroseconds / period.inMicroseconds;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _ticker ??= Ticker((t) {
      now = t;
      notifyListeners();
      // One that ended as it ticked (a run of [ClockRun]) is gone only
      // now: a notifier keeps who leaves while it notifies until then.
      _stopUnheard();
    })..start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _stopUnheard();
  }

  void _stopUnheard() {
    if (hasListeners) return;
    _ticker?.dispose();
    _ticker = null;
  }
}

/// The one clock of what runs once (see [_Clock]).
final frameClock = _Clock();

/// How many times a second [pulseClock] ticks while Nushi is in front:
/// about the fewest at which a shine still sweeps rather than steps across
/// a title (its band moves two text widths in two seconds), and plenty for
/// the rest (a ring grows under a pixel a tick, a breath or a caret fades).
const pulseRate = 20;

/// The clock everything that loops for as long as a state lasts repaints
/// from (a shine, a working chat's ring, work in the background, a pull
/// request's running checks, a streaming reply's caret, a spinner):
/// [pulseRate] times a second while Nushi is in front (the window focused,
/// the phone's page in front; unknown counts as in front), still otherwise,
/// where a loop's state shows by its color and shape alone, as under
/// Reduce Motion. A loop can last hours (a command in the background), and
/// each tick draws the whole window again: at the display's rate, one chat
/// working in the background kept an idle Nushi at half a core and the
/// window server at more.
class _Pulse extends ChangeNotifier {
  static const _every = Duration(
    microseconds: Duration.microsecondsPerSecond ~/ pulseRate,
  );

  // Its time: the ticks it ticked, so every loop is in step within a tick
  // and a test's fake time moves it.
  Duration _now = Duration.zero;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  /// Where in a loop of [period] the clock is, from 0 to 1.
  double phase(Duration period) =>
      _now.inMicroseconds % period.inMicroseconds / period.inMicroseconds;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _lifecycle ??= AppLifecycleListener(onStateChange: (_) => _run());
    _run();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    // Stops once the work at hand is done, if no one came back: a painter
    // made anew as its widget rebuilds leaves and its successor comes at
    // once (RenderCustomPaint swaps them), and a spinner rebuilt each
    // frame would otherwise start the timer again every frame and never
    // turn. One that leaves as it ticks is gone only then too: a notifier
    // keeps who leaves while it notifies until it's done.
    if (!hasListeners) scheduleMicrotask(_run);
  }

  /// Ticks while something listens and Nushi is in front; with no one
  /// listening, stops listening to the app's state too.
  void _run() {
    final front =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
    if (hasListeners && front) {
      if (_timer != null) return;
      final from = _now;
      // A late tick counts the ticks it missed (Timer.tick), so a loop
      // keeps its pace when the app is busy.
      _timer = Timer.periodic(_every, (t) {
        _now = from + _every * t.tick;
        notifyListeners();
      });
      return;
    }
    _timer?.cancel();
    _timer = null;
    if (hasListeners) return;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

/// The one clock of what loops (see [_Pulse]).
final pulseClock = _Pulse();

/// A motion that runs once for a while (a call's title typing, a check
/// drawing, sparks) on [frameClock]: the state rebuilds on each tick until
/// it has run [runFor]'s length, so no ticker of its own runs, and
/// nothing at rest.
mixin ClockRun<T extends StatefulWidget> on State<T> {
  Duration? _from; // the clock's time at the run's first tick
  Duration _length = Duration.zero;
  bool _on = false;

  /// How long the run has gone, to its length once it ended; zero until
  /// its first tick.
  Duration get ran => !_on
      ? _length
      : _from == null
      ? Duration.zero
      : frameClock.now - _from!;

  /// [ran] in milliseconds.
  double get ranMs => ran.inMicroseconds / 1000;

  /// Whether it runs.
  bool get running => _on;

  /// Starts (or starts again) a run of [length].
  void runFor(Duration length) {
    _length = length;
    _from = null;
    if (_on) return;
    _on = true;
    frameClock.addListener(_tick);
  }

  /// Ends the run where it is (as if it had run its length).
  void stopRun() {
    if (!_on) return;
    _on = false;
    frameClock.removeListener(_tick);
  }

  /// Called on each tick before the rebuild ([ran] as of this tick; the
  /// run may have just ended), to start another with [runFor].
  @protected
  void ticked() {}

  void _tick() {
    final from = _from ??= frameClock.now;
    if (frameClock.now - from >= _length) stopRun();
    if (!mounted) return;
    ticked();
    setState(() {});
  }

  @override
  void dispose() {
    stopRun();
    super.dispose();
  }
}

/// How long a hop lasts: a dot (or the Jump chip) saying "this needs you".
const hopFor = Duration(milliseconds: 1200);

// The hop: up 3 px, down, up 1.5, down, still.
final Animatable<double> _hop = TweenSequence([
  for (final (from, to, weight) in const [
    (0.0, 3.0, 20.0),
    (3.0, 0.0, 20.0),
    (0.0, 1.5, 15.0),
    (1.5, 0.0, 15.0),
    (0.0, 0.0, 30.0),
  ])
    TweenSequenceItem(
      tween: Tween(
        begin: from,
        end: to,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: weight,
    ),
]);

/// How high a hop is [v] of the way through it (0 to 1), in pixels.
double hopHeight(double v) => _hop.transform(v.clamp(0.0, 1.0));

/// How far [ms] is into a part of a run from [start] lasting [length]
/// (all in milliseconds), from 0 to 1, through [curve].
double part(
  double ms,
  double start,
  double length, [
  Curve curve = Curves.linear,
]) => curve.transform(((ms - start) / length).clamp(0.0, 1.0));

/// Whether what's built under it comes as the user watches: a transcript's
/// entry that rose in, or one built again as the agent works (a call
/// joining a run). Not what a chat opened or loaded with.
class Arriving extends InheritedWidget {
  const new({required this.play, required super.child, super.key});

  final bool play;

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Arriving>()?.play ?? false;

  @override
  bool updateShouldNotify(Arriving old) => false; // read once, as it comes
}

/// Text that is still going (a running call's title, "Thinking…"): a light
/// band sweeps across it, left to right, every two seconds, in the
/// theme's shine colors, or [color] with a light of its own (amber text
/// stays amber). Not [on], or with Reduce Motion, it's [child] as it is.
class Shine extends StatelessWidget {
  const new({required this.child, super.key, this.on = true, this.color});

  final Widget child;
  final bool on;
  final Color? color;

  /// Where every shine stops, from 0 to 1, for a still frame (a golden).
  @visibleForTesting
  static double? stopAt;

  static const period = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    if (!on || reduceMotion(context)) return child;
    final t = NushiTheme.of(context).t;
    final base = color ?? t.shine;
    final band = color == null
        ? t.shineBand
        : Color.lerp(color, t.shineBand, 0.6)!;
    Widget mask(double v, Widget child) => ShaderMask(
      blendMode: BlendMode.srcIn,
      // A band 0.72 of the text wide, its middle running from half a width
      // before the text to half a width after it.
      shaderCallback: (b) => LinearGradient(colors: [base, band, base])
          .createShader(
            Rect.fromLTWH(
              (-0.5 + 2 * v) * b.width - 0.36 * b.width,
              0,
              0.72 * b.width,
              b.height,
            ),
          ),
      child: child,
    );
    if (stopAt case final v?) return mask(v, child);
    return ListenableBuilder(
      listenable: pulseClock,
      builder: (context, child) => mask(pulseClock.phase(period), child!),
      child: child,
    );
  }
}

/// Where in a loop of [period] something that loops on [pulseClock] is: as
/// the clock says, or where [Shine.stopAt] stops every shine, for a still
/// frame.
double loopPhase(Duration period) => Shine.stopAt ?? pulseClock.phase(period);

/// What a looping painter repaints with: [pulseClock], unless stopped for a
/// still frame (see [loopPhase]).
Listenable? get loopRepaint => Shine.stopAt == null ? pulseClock : null;

/// [child] easing to its new size as it changes, over [Motion.standard]
/// from [alignment]; under Reduce Motion at once, with no AnimatedSize (one
/// of no length relays out as it lays out, and never settles).
class EaseSize extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.alignment = AlignmentDirectional.topStart,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => reduceMotion(context)
      ? child
      : AnimatedSize(
          duration: Motion.standard,
          curve: Motion.size,
          alignment: alignment,
          child: child,
        );
}

/// [child] coming in once, as it's first built: it fades in as it rises
/// ([Enter.rise]) or grows ([Enter.pop]). Not [play], or with Reduce
/// Motion, it's there at once.
class Enter extends StatefulWidget {
  /// A new transcript item: it rises 8 px as it fades in, both eased out.
  const new rise({required this.child, super.key, this.play = true})
    : _from = const Offset(0, 8),
      _scale = 1,
      _duration = const Duration(milliseconds: 220),
      _curve = Curves.easeOutCubic,
      _pop = false;

  /// A box's button or a queued message's pill: it grows from [from] of
  /// its size over [Motion.quick] as it fades in, its fade not eased.
  const new pop({
    required this.child,
    super.key,
    this.play = true,
    double from = 0.85,
  }) : _from = Offset.zero,
       _scale = from,
       _duration = Motion.quick,
       _curve = Motion.settle,
       _pop = true;

  final Widget child;
  final bool play;
  final Offset _from;
  final double _scale;
  final Duration _duration;
  final Curve _curve;
  final bool _pop;

  @override
  State<Enter> createState() => _EnterState();
}

class _EnterState extends State<Enter> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  bool _playing = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.play || reduceMotion(context)) return;
    _playing = true;
    _c = AnimationController(vsync: this, duration: widget._duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _playing = false);
      })
      ..forward().ignore();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The same widgets throughout, so the child keeps its state; at rest
    // they cost nothing (an opacity of 1 and no transform paint straight).
    final a = _playing ? _c! : kAlwaysCompleteAnimation;
    final w = widget;
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) {
        final v = w._curve.transform(a.value);
        final scale = w._scale + (1 - w._scale) * v;
        final by = w._from * (1 - v);
        return Opacity(
          opacity: w._pop ? a.value : v,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scale, scale, 1)
              ..setTranslationRaw(by.dx, by.dy, 0),
            child: child,
          ),
        );
      },
      child: w.child,
    );
  }
}
