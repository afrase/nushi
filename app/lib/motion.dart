import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:nushi/theme/theme.dart';

/// Whether nothing should move: macOS's Reduce Motion, or the browser's
/// reduced-motion setting on the phone, as Flutter reports them.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

/// One clock for everything that loops (a shine, a working chat's ring):
/// it ticks only while something listens, so they move in step and stop
/// together, and what listens repaints from it without its own controller.
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
    })..start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _ticker?.dispose();
      _ticker = null;
    }
  }
}

final loopClock = _Clock();

/// Text that is still going (a running call's title, "Thinking…"): a light
/// band sweeps across it, left to right, every two seconds, in the
/// theme's shine colors. Not [on], or with Reduce Motion, it's [child] as
/// it is.
class Shine extends StatelessWidget {
  const new({required this.child, super.key, this.on = true});

  final Widget child;
  final bool on;

  /// Where every shine stops, from 0 to 1, for a still frame (a golden).
  @visibleForTesting
  static double? stopAt;

  static const period = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    if (!on || reduceMotion(context)) return child;
    final t = NushiTheme.of(context).t;
    Widget mask(double v, Widget child) => ShaderMask(
      blendMode: BlendMode.srcIn,
      // A band 0.72 of the text wide, its middle running from half a width
      // before the text to half a width after it.
      shaderCallback: (b) =>
          LinearGradient(colors: [t.shine, t.shineBand, t.shine]).createShader(
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
      listenable: loopClock,
      builder: (context, child) => mask(loopClock.phase(period), child!),
      child: child,
    );
  }
}

/// [child] coming in once, as it's first built: it fades in from [from]
/// away. Not [play], or with Reduce Motion, it's there at once.
class Enter extends StatefulWidget {
  const new({
    required this.child,
    required this.from,
    required this.duration,
    required this.curve,
    super.key,
    this.play = true,
  });

  /// A new transcript item: it rises 8 px.
  const new rise({required Widget child, Key? key, bool play = true})
    : this(
        key: key,
        play: play,
        from: const Offset(0, 8),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: child,
      );

  /// A side pane: it slides 24 px in from the right.
  const new slide({required Widget child, Key? key})
    : this(
        key: key,
        from: const Offset(24, 0),
        duration: const Duration(milliseconds: 240),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        child: child,
      );

  final Widget child;
  final Offset from;
  final Duration duration;
  final Curve curve;
  final bool play;

  @override
  State<Enter> createState() => _EnterState();
}

class _EnterState extends State<Enter> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  CurvedAnimation? _curved;
  Animation<double>? _a;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.play || reduceMotion(context)) return;
    final c = _c = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _a = null);
      });
    _a = _curved = CurvedAnimation(parent: c, curve: widget.curve);
    c.forward().ignore();
  }

  @override
  void dispose() {
    _curved?.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The same widgets throughout, so the child keeps its state; at rest
    // they cost nothing (an opacity of 1 and no offset paint straight).
    final a = _a ?? kAlwaysCompleteAnimation;
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: widget.from * (1 - a.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
