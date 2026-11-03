import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/disclosure.dart';
import 'package:nushi/motion.dart';

// Rows that arrive, leave and move (the fluidity review's idea 9): a new
// row grows to its height and rises in; one that goes fades and folds; one
// that moves from one list to another of the same scroll (a chat pinned,
// or moved to another project) glides from where it was drawn to its new
// place, measured by key (FLIP), while the place it left closes and the
// one it takes opens. Only when a list changes, never on a row's status;
// with Reduce Motion rows come and go at once. [SlideList] does the
// lists' part; [ListMotion] knows the rows of all the lists in a scroll.

/// The rows of the lists in one scroll (the sidebar's), so that one a
/// list loses and another gains in the same build is seen to move.
class ListMotion {
  /// The scroll's content, which rows are measured in.
  final GlobalKey space = GlobalKey();

  /// What the lists show as of this build (rows and groups, by key): one
  /// a list loses that's in here went to another list.
  Set<Key> shown = const {};

  /// What the scroll's rows are drawn on: a row gliding past others
  /// covers them with it.
  Color? ground;

  final _seen = <Key, double>{}; // where each row was drawn, at [snapshot]
  /// The rows gliding, as last drawn, and how far each was from its place.
  final _gliding = <RenderObject, double>{};
  final _rows = <Key, PresenceState>{}; // the rows shown, live

  /// Notes where each row is drawn, before a build changes the lists:
  /// called as the lists are built again, while the last frame's layout
  /// still stands.
  void snapshot() {
    _seen.clear();
    final space = this.space.currentContext?.findRenderObject();
    if (space is! RenderBox || !space.attached) return;
    for (final MapEntry(:key, value: row) in _rows.entries) {
      if (row._drawnTop(space) case final y?) _seen[key] = y;
    }
  }

  /// Where the row [key] was drawn, at the last [snapshot], if it showed.
  double? seenAt(Key key) => _seen[key];

  void _add(Key key, PresenceState row) {
    // The row it was, left behind in a list going away, hides: this one
    // takes its place.
    if (_rows[key] case final old? when old != row) old._hide();
    _rows[key] = row;
  }

  void _drop(Key key, PresenceState row) {
    if (_rows[key] == row) _rows.remove(key);
  }

  /// The [ListMotion] its lists share, if any.
  static ListMotion? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListMotionScope>()?.motion;
}

/// Gives the lists under it one [ListMotion]; [child] holds the scroll's
/// content, keyed with [ListMotion.space].
class ListMotionScope extends InheritedWidget {
  const new({required this.motion, required super.child, super.key});

  final ListMotion motion;

  @override
  bool updateShouldNotify(ListMotionScope old) => old.motion != motion;
}

/// How a row comes into a list: there at once (as the list was first
/// built, or with Reduce Motion), new (it grows and rises in), or moved
/// from another list (its place opens as it glides there).
enum Arrival { still, grow, glide }

/// How a row leaves a list: it went (fades and folds), or it moved to
/// another list (its place closes, empty, as it glides away).
enum Leaving { fade, vacate }

/// A list's row, by [id], as it arrives ([arrival], read once, as it's
/// first built), stays, and leaves ([leaving]; then [onGone] once it's
/// gone; null again, it comes back from where it is). Leaving, it takes no
/// pointer or focus. [moves] counts the times its list put it elsewhere
/// among the others (not by a drag): each time, it glides there from
/// where it was drawn.
class Presence extends StatefulWidget {
  const new({
    required this.id,
    required this.arrival,
    required this.leaving,
    required this.onGone,
    required this.child,
    super.key,
    this.moves = 0,
  });

  final Key id;
  final Arrival arrival;
  final Leaving? leaving;
  final VoidCallback onGone;
  final int moves;
  final Widget child;

  @override
  State<Presence> createState() => PresenceState();
}

/// [Presence]'s state, which [ListMotion] measures.
class PresenceState extends State<Presence> with TickerProviderStateMixin {
  // How far in it is (its height, and its look as it grows in or fades
  // out), and how far along a glide.
  late final AnimationController _c = AnimationController(vsync: this);
  late final AnimationController _g = AnimationController(
    vsync: this,
    duration: Motion.standard,
    value: 1,
  );
  late Arrival _arrival = widget.arrival;
  double? _from; // where it was drawn, gliding from there
  final GlobalKey _glide = GlobalKey();
  ListMotion? _motion;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.dismissed && widget.leaving != null) {
        widget.onGone();
      }
      if (!s.isAnimating) setState(() {});
    });
    switch (_arrival) {
      case Arrival.still:
        _c.value = 1;
      case Arrival.grow || Arrival.glide:
        _c.duration = Motion.standard;
        _c.forward().ignore();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = ListMotion.of(context);
    if (motion == _motion) return;
    _motion?._drop(widget.id, this);
    _motion = motion;
    if (_arrival == Arrival.glide) _glideFrom(motion?.seenAt(widget.id));
    if (widget.leaving == null) motion?._add(widget.id, this);
  }

  void _glideFrom(double? y) {
    _from = y;
    if (y == null) return;
    _g
      ..value = 0
      ..forward().ignore();
  }

  @override
  void didUpdateWidget(Presence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moves != widget.moves) {
      _glideFrom(_motion?.seenAt(widget.id));
    }
    if (oldWidget.leaving == widget.leaving) return;
    if (widget.leaving case final leaving?) {
      _motion?._drop(widget.id, this);
      _c.duration = leaving == Leaving.fade ? Motion.exit : Motion.standard;
      _c.reverse().ignore();
    } else {
      // Back before it was gone: it comes back from where it is (shown
      // again, if a copy elsewhere had taken its place).
      _glideBox?.hidden = false;
      _motion?._add(widget.id, this);
      _arrival = Arrival.grow;
      _c.duration = Motion.standard;
      _c.forward().ignore();
    }
  }

  @override
  void dispose() {
    _motion?._drop(widget.id, this);
    _c.dispose();
    _g.dispose();
    super.dispose();
  }

  void _hide() => _glideBox?.hidden = true;

  _RenderGlide? get _glideBox =>
      _glide.currentContext?.findRenderObject() as _RenderGlide?;

  /// Where its row is drawn in [space], if it shows (not folded away).
  double? _drawnTop(RenderBox space) {
    final box = _glideBox;
    final row = box?.child;
    if (box == null || row == null || !row.hasSize || row.size.isEmpty) {
      return null;
    }
    if (box.hidden || widget.leaving != null) return null;
    return row.localToGlobal(Offset.zero, ancestor: space).dy;
  }

  @override
  Widget build(BuildContext context) {
    final leaving = widget.leaving;
    return IgnorePointer(
      ignoring: leaving != null,
      child: ExcludeFocus(
        excluding: leaving != null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_c, _g]),
          builder: (context, child) {
            final v = _c.value;
            final double height;
            final double opacity;
            var rise = 0.0;
            if (leaving != null) {
              // Gone by the time it's out of the way: faster as it goes.
              final k = Motion.leave.transform(1 - v);
              height = leaving == Leaving.fade ? 1 - k : v;
              opacity = leaving == Leaving.fade ? 1 - k : 0;
            } else if (_arrival == Arrival.grow) {
              final settled = Motion.settle.transform(v);
              height = Motion.size.transform(v);
              opacity = settled;
              rise = 4 * (1 - settled);
            } else {
              height = Motion.size.transform(v);
              opacity = 1;
            }
            return Fold(
              factor: height,
              // A row gliding in draws where it was, outside its place.
              clip: _arrival != Arrival.glide,
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, rise),
                  child: _Glide(
                    key: _glide,
                    from: _from,
                    motion: _motion,
                    t: Motion.size.transform(_g.value),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// [child] drawn [from] where it was in [motion]'s space (its top
/// there), easing to its own place as [t] goes from 0 to 1.
class _Glide extends SingleChildRenderObjectWidget {
  const new({
    required this.from,
    required this.motion,
    required this.t,
    super.child,
    super.key,
  });

  final double? from;
  final ListMotion? motion;
  final double t;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlide(from, motion, t);

  @override
  void updateRenderObject(BuildContext context, _RenderGlide renderObject) =>
      renderObject
        ..from = from
        ..motion = motion
        ..t = t;
}

class _RenderGlide extends RenderProxyBox {
  new(this._from, this.motion, this._t);

  double? _from;
  double? get from => _from;
  set from(double? v) {
    if (v == _from) return;
    _from = v;
    markNeedsPaint();
  }

  ListMotion? motion;

  double _t;
  double get t => _t;
  set t(double v) {
    if (v == _t) return;
    _t = v;
    markNeedsPaint();
  }

  /// Drawn as nothing: the row moved to another list, and this is what
  /// was left of it in a list going away.
  bool _hidden = false;
  bool get hidden => _hidden;
  set hidden(bool v) {
    if (v == _hidden) return;
    _hidden = v;
    markNeedsPaint();
  }

  /// How far from its place it's drawn now: from where it was toward its
  /// place as it is this frame (which may still be moving, a slot above
  /// it opening), so it never passes it.
  double get _shift {
    final from = _from;
    if (_t >= 1 || from == null || !attached) return 0;
    final space = motion?.space.currentContext?.findRenderObject();
    if (space is! RenderBox) return 0;
    final at = localToGlobal(Offset.zero, ancestor: space).dy;
    return (from - at) * (1 - _t);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shift = _shift;
    final gliding = motion?._gliding;
    if (shift.abs() >= 0.5) {
      gliding?[this] = shift.abs();
    } else {
      gliding?.remove(this);
    }
    if (_hidden) return;
    final c = child;
    if (c == null) return;
    final at = offset + Offset(0, shift);
    // Gliding, it passes over the rows in its way, on the list's own
    // ground ([GlideColumn] draws it last).
    final ground = motion?.ground;
    if (shift.abs() >= 0.5 && ground != null) {
      context.canvas.drawRect(at & size, Paint()..color = ground);
    }
    context.paintChild(c, at);
  }

  @override
  void detach() {
    motion?._gliding.remove(this);
    super.detach();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(0, _shift, 0, 1);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null || _hidden) return false;
    return result.addWithPaintOffset(
      offset: Offset(0, _shift),
      position: position,
      hitTest: (result, position) => c.hitTest(result, position: position),
    );
  }
}

/// A [Column] of a list's items that draws those gliding ([Presence])
/// last, so one moving past the others passes over them.
class GlideColumn extends Column {
  const new({required this.motion, super.key, super.children})
    : super(crossAxisAlignment: CrossAxisAlignment.stretch);

  final ListMotion? motion;

  @override
  RenderFlex createRenderObject(BuildContext context) => _RenderGlideColumn(
    motion,
    direction: direction,
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    crossAxisAlignment: crossAxisAlignment,
    textDirection: getEffectiveTextDirection(context),
    verticalDirection: verticalDirection,
    textBaseline: textBaseline,
    clipBehavior: clipBehavior,
    spacing: spacing,
  );

  @override
  void updateRenderObject(BuildContext context, RenderFlex renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderGlideColumn).motion = motion;
  }
}

class _RenderGlideColumn extends RenderFlex {
  new(
    this.motion, {
    super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    super.spacing,
  });

  ListMotion? motion;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Its children that hold a row gliding, as of the last frame, and
    // the farthest each glides: the farther, the later it's drawn, so
    // what passes over the most is on top.
    final far = <RenderBox, double>{};
    for (final MapEntry(key: g, value: d) in (motion?._gliding ?? {}).entries) {
      RenderObject? o = g;
      while (o != null && o.parent != this) {
        o = o.parent;
      }
      if (o is RenderBox && d > (far[o] ?? 0)) far[o] = d;
    }
    if (far.isEmpty) return super.paint(context, offset);
    void draw(RenderBox c) => context.paintChild(
      c,
      (c.parentData! as FlexParentData).offset + offset,
    );
    for (var c = firstChild; c != null; c = childAfter(c)) {
      if (!far.containsKey(c)) draw(c);
    }
    (far.keys.toList()..sort((a, b) => far[a]!.compareTo(far[b]!))).forEach(
      draw,
    );
  }
}
