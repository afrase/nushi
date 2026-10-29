import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

/// How far right two fingers pan on the trackpad, in logical pixels, for
/// a swipe to go back: about Safari's, a third of a trackpad's width at
/// an easy pace (macOS's deltas grow with speed, so a quick one needs
/// less of the pad).
const backSwipeAt = 120.0;

/// A flick goes back short of [backSwipeAt]: at least this fast to the
/// right as the fingers lift, and half the way there.
const _flick = 900.0;

/// Pan before the arrow shows: past a [Scrollable]'s slop (18), so one
/// under the fingers that takes the swipe has it before anything shows.
const _quiet = 20.0;

/// Pan before the swipe is side or up and down, and stays so.
const _lockAt = 8.0;

/// What a side scroller that isn't a [Scrollable] (a diff's panes) sends
/// when it moved, so a swipe that scrolled it doesn't go back too.
class SideScrolled extends Notification {
  const new();
}

/// Goes [onBack] on a two-finger swipe right on the trackpad (as Safari
/// and Finder do; macOS sends it as pan/zoom), a three-finger one when
/// macOS's "Swipe between pages" says so (an `NSEvent` swipe, through
/// `nushi/swipe`), and the mouse's back button, over [child]. Not while
/// a side scroller under the fingers moves instead (a diff, a code
/// block, a wide table, scrolled right), nor on a swipe mostly up or
/// down. While swiping, an arrow at the left edge grows and fills as the
/// swipe reaches [backSwipeAt]; let go short of it and it fades. With
/// Reduce Motion there is no arrow, only the going back.
class BackSwipe extends StatefulWidget {
  const new({required this.onBack, required this.child, super.key});

  final VoidCallback onBack;
  final Widget child;

  @override
  State<BackSwipe> createState() => _BackSwipeState();
}

enum _Way { unknown, side, other }

class _BackSwipeState extends State<BackSwipe> {
  /// Those mounted, outermost first, for a three-finger swipe.
  static final _all = <_BackSwipeState>[];

  /// The pointer the innermost one took (the first to see it), so an
  /// outer one leaves it; and the last back button's.
  static int? _taken;
  static int? _pressed;

  static bool _listening = false;

  int? _pointer; // this swipe's, while the fingers are down
  _Way _way = _Way.unknown;
  bool _scrolled = false; // something under it moved instead
  Offset _pan = Offset.zero;
  VelocityTracker? _speed;
  bool _queued = false;

  double _shown = 0; // the arrow's progress, 0 to 1
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    _all.add(this);
    if (!_listening) {
      _listening = true;
      const MethodChannel('nushi/swipe').setMethodCallHandler(_swiped);
    }
  }

  @override
  void dispose() {
    _all.remove(this);
    if (_taken == _pointer) _taken = null;
    super.dispose();
  }

  /// A three-finger swipe right at a point of the window (logical
  /// pixels): the innermost [BackSwipe] there goes back.
  static Future<void> _swiped(MethodCall call) async {
    final at = switch ((call.method, call.arguments)) {
      ('back', [final num x, final num y]) => Offset(
        x.toDouble(),
        y.toDouble(),
      ),
      _ => null,
    };
    if (at == null) return;
    for (final s in _all.reversed) {
      final box = s.context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      if (box.size.contains(box.globalToLocal(at))) {
        s.widget.onBack();
        return;
      }
    }
  }

  void _down(PointerDownEvent e) {
    if ((e.buttons & kBackMouseButton) == 0 || _pressed == e.pointer) return;
    _pressed = e.pointer;
    widget.onBack();
  }

  void _start(PointerPanZoomStartEvent e) {
    if (_taken == e.pointer) return; // an inner one's
    _taken = _pointer = e.pointer;
    _way = _Way.unknown;
    _scrolled = false;
    _pan = Offset.zero;
    _speed = VelocityTracker.withKind(PointerDeviceKind.trackpad);
  }

  void _update(PointerPanZoomUpdateEvent e) {
    if (e.pointer != _pointer) return;
    _pan = e.pan;
    _speed?.addPosition(e.timeStamp, e.pan);
    if (_way == _Way.unknown && _pan.distance >= _lockAt) {
      _way = _pan.dx.abs() > _pan.dy.abs() ? _Way.side : _Way.other;
    }
    // After the event has gone everywhere: a scroller under the fingers
    // takes it after this listener sees it.
    if (!_queued) {
      _queued = true;
      scheduleMicrotask(_show);
    }
  }

  bool get _going => _way == _Way.side && !_scrolled;

  void _show() {
    _queued = false;
    if (!mounted || _pointer == null) return;
    final p = _going
        ? ((_pan.dx - _quiet) / (backSwipeAt - _quiet)).clamp(0.0, 1.0)
        : 0.0;
    if (p != _shown || _fading) {
      setState(() {
        _shown = p;
        _fading = false;
      });
    }
  }

  void _end(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _taken = _pointer = null;
    final speed = _speed?.getVelocity().pixelsPerSecond.dx ?? 0;
    _speed = null;
    final back =
        _going &&
        (_pan.dx >= backSwipeAt ||
            _pan.dx >= backSwipeAt / 2 && speed >= _flick);
    if (back) {
      setState(() => _shown = 0);
      widget.onBack();
    } else if (_shown > 0) {
      setState(() => _fading = true);
    }
  }

  bool _onScroll(Notification n) {
    if (_pointer == null || _scrolled) return false;
    _scrolled = switch (n) {
      SideScrolled() => true,
      ScrollUpdateNotification(:final metrics, :final scrollDelta) =>
        metrics.axis == Axis.horizontal && (scrollDelta ?? 0) != 0,
      _ => false,
    };
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return NotificationListener<Notification>(
      onNotification: _onScroll,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerPanZoomStart: _start,
        onPointerPanZoomUpdate: _update,
        onPointerPanZoomEnd: _end,
        onPointerCancel: _end,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (!still && _shown > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _fading ? 0 : 1,
                      duration: Duration(milliseconds: _fading ? 160 : 0),
                      onEnd: () {
                        if (_fading) {
                          setState(() {
                            _fading = false;
                            _shown = 0;
                          });
                        }
                      },
                      child: BackArrow(_shown),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The arrow a swipe back shows at the left edge, at [progress] (0 to
/// 1): it comes in and grows, its ring fills, and at 1 it is the
/// accent, ready.
class BackArrow extends StatelessWidget {
  const new(this.progress, {super.key});

  final double progress;

  static const size = 40.0;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final p = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final ready = progress >= 1;
    final scale = 0.6 + 0.4 * p;
    return Transform.translate(
      offset: Offset(-size + (size + 12) * p, 0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ready ? t.accent : t.raised,
            border: Border.all(color: ready ? t.accent : t.borderStrong),
            boxShadow: [BoxShadow(color: t.shadow, blurRadius: 8)],
          ),
          child: CustomPaint(
            painter: _Ring(ready ? 0 : progress, t.accent),
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: ready ? t.onAccent : t.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring's part filled so far, from the top, clockwise.
class _Ring extends CustomPainter {
  new(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final r = Offset.zero & size;
    canvas.drawArc(
      r.deflate(2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.progress != progress || old.color != color;
}
