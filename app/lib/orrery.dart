import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:nushi/logo.dart';
import 'package:nushi/orbits.dart';
import 'package:nushi/theme/theme.dart';

/// Nushi's mark over [label], moving: its agents orbit the light, and the
/// pointer plays with them (drag one and let go to fling it, click to add
/// one, hover to pull them a little). Left alone for half a minute it goes
/// back to the mark. Still under Reduce motion; paused while the app isn't
/// active or something covers it.
class Orrery extends StatefulWidget {
  const new({required this.label, this.orbits, super.key});

  final Widget label;

  /// The system shown; a new one when not given.
  final Orbits? orbits;

  @override
  State<Orrery> createState() => _OrreryState();
}

const _size = 72.0;
final double _u = markUnit(_size);

// A planet takes the pointer within this many points of its edge; a fling
// gives it this share of the pointer's speed (the system is slow: a ring
// goes round in tens of seconds).
const _slop = 6.0;
const _fling = 0.2;

// A frame each: 15 a second at rest (a planet moves under a pixel a frame;
// each frame costs the whole window's, about 0.35% of a core), 60 while
// played with.
const _calm = Duration(microseconds: 66667);
const _busy = Duration(microseconds: 16667);

class _OrreryState extends State<Orrery> with WidgetsBindingObserver {
  late final Orbits _orbits = widget.orbits ?? Orbits();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final GlobalKey _mark = GlobalKey();
  final GlobalKey _label = GlobalKey();
  Timer? _timer;
  Duration _period = _calm;
  int _ticks = 0;
  bool _resumed = true;
  bool _shown = true;
  bool _still = false;
  bool _over = false;
  VelocityTracker? _tracker;
  Offset? _down;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = WidgetsBinding.instance.lifecycleState;
    _resumed = s == null || s == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _still = _reduceMotion();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (!mounted) return;
    setState(() => _still = _reduceMotion());
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _frame.dispose();
    super.dispose();
  }

  bool _reduceMotion() =>
      MediaQuery.disableAnimationsOf(context) ||
      View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

  bool get _hurried =>
      _orbits.held >= 0 || (_orbits.disturbed && _orbits.idle < 5);

  /// Runs the clock while the system shows and may move, faster while
  /// it's played with; else stops it.
  void _sync() {
    if (!_resumed || !_shown || _still) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final period = _hurried ? _busy : _calm;
    if (_timer != null && period == _period) return;
    _timer?.cancel();
    _period = period;
    _ticks = 0;
    _timer = Timer.periodic(period, _tick);
  }

  // Timer.periodic's tick counts the periods gone, ticks it skipped too.
  void _tick(Timer t) {
    final n = t.tick - _ticks;
    _ticks = t.tick;
    _orbits.advance(n * _period.inMicroseconds / 1e6);
    _frame.value++;
    if (_hurried != (_period == _busy)) _sync();
  }

  /// [global] on the system's grid, or null before it's laid out.
  (double, double)? _units(Offset global) {
    final box = _mark.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final p = box.globalToLocal(global) - box.size.center(Offset.zero);
    return (p.dx / _u, p.dy / _u);
  }

  bool _onLabel(Offset global) {
    final box = _label.currentContext?.findRenderObject() as RenderBox?;
    return box != null &&
        box.hasSize &&
        (Offset.zero & box.size).contains(box.globalToLocal(global));
  }

  void _hover(PointerEvent e) {
    final p = _units(e.position);
    if (p == null) return;
    _orbits.point(p.$1, p.$2);
    final over = _orbits.hit(p.$1, p.$2, _slop / _u) >= 0;
    if (over != _over) setState(() => _over = over);
  }

  void _press(PointerDownEvent e) {
    final p = _units(e.position);
    if (p == null || e.buttons & kPrimaryButton == 0) return;
    _orbits.point(p.$1, p.$2);
    final i = _orbits.hit(p.$1, p.$2, _slop / _u);
    if (i < 0) {
      _down = e.position;
      return;
    }
    _orbits.grab(i);
    _tracker = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.position);
    setState(() {});
    _sync();
  }

  void _move(PointerMoveEvent e) {
    final p = _units(e.position);
    if (p == null) return;
    _orbits.point(p.$1, p.$2);
    if (_orbits.held < 0) return;
    _orbits.moveHeld(p.$1, p.$2);
    _tracker?.addPosition(e.timeStamp, e.position);
    _frame.value++;
  }

  void _lift(PointerUpEvent e) {
    final down = _down;
    _down = null;
    if (_orbits.held >= 0) {
      final v = _tracker?.getVelocity().pixelsPerSecond ?? Offset.zero;
      _tracker = null;
      _orbits.release(v.dx / _u * _fling, v.dy / _u * _fling);
      setState(() {});
    } else if (down != null &&
        (e.position - down).distance < 4 &&
        !_onLabel(e.position)) {
      final p = _units(e.position);
      if (p != null && _orbits.add(p.$1, p.$2)) _frame.value++;
    }
    _sync();
  }

  void _cancel(PointerCancelEvent e) {
    _down = null;
    _tracker = null;
    _orbits.release(0, 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final Widget mark;
    if (_still) {
      mark = Logo(color: t.mark, light: t.markLight);
    } else {
      mark = SizedBox.square(
        key: _mark,
        dimension: _size,
        child: CustomPaint(
          painter: _Rings(t.mark),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _Planets(_orbits, t.mark, t.markLight, _frame),
            ),
          ),
        ),
      );
    }
    final column = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(height: 16),
          KeyedSubtree(key: _label, child: widget.label),
        ],
      ),
    );
    if (_still) return column;
    return LayoutBuilder(
      builder: (context, box) {
        _orbits.bound = max(box.maxWidth, box.maxHeight) / 2 / _u;
        return ClipRect(
          child: MouseRegion(
            cursor: _orbits.held >= 0
                ? SystemMouseCursors.grabbing
                : _over
                ? SystemMouseCursors.grab
                : MouseCursor.defer,
            onExit: (_) {
              _orbits.point(null, null);
              if (_over) setState(() => _over = false);
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerHover: _hover,
              onPointerDown: _press,
              onPointerMove: _move,
              onPointerUp: _lift,
              onPointerCancel: _cancel,
              child: column,
            ),
          ),
        );
      },
    );
  }
}

class _Rings extends CustomPainter {
  new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintRings(
    canvas,
    size.center(Offset.zero),
    markUnit(size.shortestSide),
    color,
  );

  @override
  bool shouldRepaint(_Rings old) => old.color != color;
}

/// The planets and the light, drawn where they are each frame (past the
/// mark's box too: the pane clips them).
class _Planets extends CustomPainter {
  new(this.orbits, this.color, this.light, Listenable frame)
    : super(repaint: frame);

  final Orbits orbits;
  final Color color;
  final Color light;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final u = markUnit(size.shortestSide);
    final o = orbits;
    for (var i = 0; i < o.slots; i++) {
      if (o.state[i] == Orbits.free) continue;
      _paint.color = color.withValues(alpha: color.a * o.alpha[i]);
      canvas.drawCircle(
        Offset(c.dx + o.x[i] * u, c.dy + o.y[i] * u),
        o.radius[i] * u,
        _paint,
      );
    }
    _paint.color = light;
    canvas.drawCircle(c, sunRadius * u, _paint);
  }

  @override
  bool shouldRepaint(_Planets old) =>
      old.orbits != orbits || old.color != color || old.light != light;
}
