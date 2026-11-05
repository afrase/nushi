import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/motion.dart';

// What comes and goes around a view (the fluidity review's ideas 7, 10 and
// 11): bars and the terminal sliding open, panes and the sidebar sliding
// in from their edge, and the chat's text gliding to where a pane leaves
// it. Each follows motion.dart's rules: nothing waits on it, what goes
// takes no pointer or focus, a second toggle reverses it from where it is,
// and under Reduce Motion it all happens at once.

/// [child] coming as it's given and going as it's taken away (null): its
/// run goes from 0 to 1 over [enter] through [curve] as it comes, and back
/// over [exit] through [leave] as it goes, [builder] drawing the child at
/// its run. While it goes it shows the last child it was given (the same
/// widget, so what it read stays) and takes no pointer or focus; once gone
/// it's nothing. What it's given at its first build is there at once
/// unless it [arrives] (a pane opened beside a view that was there), and
/// under Reduce Motion everything is.
class Presence extends StatefulWidget {
  const new({
    required this.child,
    required this.builder,
    super.key,
    this.enter = Motion.enter,
    this.exit = Motion.exit,
    this.curve = Motion.settle,
    this.leave = Motion.leave,
    this.arrives = false,
  });

  final Widget? child;
  final bool arrives;
  final Widget Function(
    BuildContext context,
    Animation<double> run,
    Widget child,
  )
  builder;
  final Duration enter;
  final Duration exit;
  final Curve curve;
  final Curve leave;

  @override
  State<Presence> createState() => _PresenceState();
}

class _PresenceState extends State<Presence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run;
  late final CurvedAnimation _curved;
  Widget? _last; // what it shows, or showed before it began to go

  @override
  void initState() {
    super.initState();
    _last = widget.child;
    _run = AnimationController(
      vsync: this,
      duration: widget.enter,
      reverseDuration: widget.exit,
      value: _last == null || widget.arrives ? 0 : 1,
    )..addStatusListener(_ran);
    // Going, the run goes back through [Presence.leave]: it gathers speed.
    _curved = CurvedAnimation(
      parent: _run,
      curve: widget.curve,
      reverseCurve: widget.leave.flipped,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_last == null || _run.value > 0 || _run.isAnimating) return;
    if (reduceMotion(context)) {
      _run.value = 1;
    } else {
      _run.forward().ignore();
    }
  }

  void _ran(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        widget.child == null &&
        _last != null) {
      setState(() => _last = null);
    }
  }

  @override
  void didUpdateWidget(Presence old) {
    super.didUpdateWidget(old);
    final still = reduceMotion(context);
    if (widget.child case final child?) {
      _last = child;
      if (still) {
        _run.value = 1;
      } else if (!_run.isForwardOrCompleted) {
        _run.forward().ignore();
      }
    } else if (still) {
      _last = null;
      _run.value = 0;
    } else if (_run.isForwardOrCompleted && _last != null) {
      _run.reverse().ignore();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _last;
    if (child == null) return const SizedBox.shrink();
    final going = widget.child == null;
    return IgnorePointer(
      ignoring: going,
      child: ExcludeFocus(
        excluding: going,
        child: widget.builder(context, _curved, child),
      ),
    );
  }
}

/// A bar over (or under) a view that opens as it comes and closes as it
/// goes: its height eases and, with [fade], its opacity too. [down], it
/// slides down from its top edge (a bar under the header); otherwise its
/// top edge rises (the terminal, under the chat). What's inside is laid out
/// at its own height throughout, so it's sized once (a terminal's PTY
/// too), and clipped.
class BarSlide extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.down = true,
    this.fade = true,
    this.enter = Motion.standard,
  });

  final Widget? child;
  final bool down;
  final bool fade;
  final Duration enter;

  @override
  Widget build(BuildContext context) => Presence(
    enter: enter,
    child: child,
    builder: (context, run, child) => AnimatedBuilder(
      animation: run,
      builder: (context, child) => _Reveal(
        factor: run.value,
        bottom: down,
        child: fade ? Faded(opacity: run.value, child: child) : child,
      ),
      child: child,
    ),
  );
}

/// [child] at [opacity], as [Opacity] draws it, but at rest (fully shown)
/// no layer of its own: an [Opacity] is one even then, so a golden of what
/// it holds would be of it alone, and its subtree would paint apart.
class Faded extends SingleChildRenderObjectWidget {
  const new({required this.opacity, super.child, super.key});

  final double opacity;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFaded(opacity);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderFaded).opacity = opacity;
}

class _RenderFaded extends RenderProxyBox {
  new(double opacity) : _alpha = Color.getAlphaFromOpacity(opacity);

  int _alpha;
  double get opacity => _alpha / 255;
  set opacity(double v) {
    final alpha = Color.getAlphaFromOpacity(v);
    if (alpha == _alpha) return;
    final layered = alwaysNeedsCompositing;
    _alpha = alpha;
    if (layered != alwaysNeedsCompositing) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  final _layer = LayerHandle<OpacityLayer>();

  @override
  bool get alwaysNeedsCompositing =>
      child != null && _alpha > 0 && _alpha < 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _alpha == 0) {
      _layer.layer = null;
      return;
    }
    if (_alpha == 255) {
      _layer.layer = null;
      super.paint(context, offset);
      return;
    }
    _layer.layer = context.pushOpacity(
      offset,
      _alpha,
      super.paint,
      oldLayer: _layer.layer,
    );
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

/// [child] at its own height, shown [factor] of it: its bottom part when
/// [bottom], otherwise its top, the rest clipped.
class _Reveal extends SingleChildRenderObjectWidget {
  const new({required this.factor, required this.bottom, super.child});

  final double factor;
  final bool bottom;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReveal(factor: factor, bottom: bottom);

  @override
  void updateRenderObject(BuildContext context, _RenderReveal render) => render
    ..factor = factor
    ..bottom = bottom;
}

class _RenderReveal extends RenderShiftedBox {
  new({required this._factor, required this._bottom}) : super(null);

  double _factor;
  double get factor => _factor;
  set factor(double v) {
    if (v == _factor) return;
    _factor = v;
    markNeedsLayout();
  }

  bool _bottom;
  bool get bottom => _bottom;
  set bottom(bool v) {
    if (v == _bottom) return;
    _bottom = v;
    markNeedsLayout();
  }

  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    // The width as given; the height its own, whatever is shown of it.
    child.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      ),
      parentUsesSize: true,
    );
    final full = child.size;
    size = constraints.constrain(
      Size(full.width, full.height * _factor.clamp(0.0, 1.0)),
    );
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      _bottom ? size.height - full.height : 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || size.height <= 0) {
      _clip.layer = null;
      return;
    }
    if (size.height >= child.size.height) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// A pane that slides its full width in from its edge (the left for the
/// sidebar, otherwise the right) as [run] goes from 0 to 1, clipped to its
/// own slot: one beside others seems to come out from under them.
Widget paneSlide(Animation<double> run, Widget child, {bool left = false}) =>
    AnimatedBuilder(
      animation: run,
      builder: (context, child) => ClipRect(
        clipBehavior: run.value < 1 ? Clip.hardEdge : Clip.none,
        child: FractionalTranslation(
          translation: Offset((left ? -1 : 1) * (1 - run.value), 0),
          child: child,
        ),
      ),
      child: child,
    );

/// [child] laid out where it is, but drawn from where it was: when [token]
/// changes (a pane opened or closed beside it, the sidebar came or went),
/// it's drawn from where it showed until then and glides to where it is
/// now over [Motion.enter] through [Motion.settle]. Only its drawing moves:
/// it's laid out once, at its new width, so a transcript that lays out
/// every entry does so once. With [sides] (its text's column's insets at a
/// width: the chat's), that column is what's followed, and only while it
/// keeps its width: a column that re-wraps (a narrow window) just shows
/// where it is. Its pointer goes where it's drawn. A change mid-glide
/// glides from where it is; under Reduce Motion it doesn't glide.
///
/// With [clip], what's drawn off its box while it glides is cut there:
/// the chat's transcript, whose foot (the composer's backdrop) is its full
/// width and would otherwise lie over the sidebar left of it as it glides.
/// At rest nothing is clipped, and nothing is a layer more.
class Glide extends StatefulWidget {
  const new({
    required this.token,
    required this.child,
    super.key,
    this.sides,
    this.clip = false,
  });

  final Object? token;
  final EdgeInsets Function(double width)? sides;
  final bool clip;
  final Widget child;

  @override
  State<Glide> createState() => _GlideState();
}

class _GlideState extends State<Glide> with SingleTickerProviderStateMixin {
  late final _run = AnimationController(
    vsync: this,
    duration: Motion.enter,
    value: 1,
  );
  late final _curved = CurvedAnimation(parent: _run, curve: Motion.settle);
  int _armed = 0; // how many times it was told to glide

  @override
  void didUpdateWidget(Glide old) {
    super.didUpdateWidget(old);
    if (widget.token == old.token || reduceMotion(context)) return;
    _armed++;
    _run.forward(from: 0).ignore();
  }

  @override
  void dispose() {
    _curved.dispose();
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Glide(
    run: _curved,
    armed: _armed,
    sides: widget.sides,
    clip: widget.clip,
    child: RepaintBoundary(child: widget.child),
  );
}

class _Glide extends SingleChildRenderObjectWidget {
  const new({
    required this.run,
    required this.armed,
    required this.sides,
    required this.clip,
    super.child,
  });

  final Animation<double> run;
  final int armed;
  final EdgeInsets Function(double width)? sides;
  final bool clip;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlide(run, armed, sides, clip: clip);

  @override
  void updateRenderObject(BuildContext context, _RenderGlide render) => render
    ..sides = sides
    ..clip = clip
    ..armed = armed;
}

class _RenderGlide extends RenderProxyBox {
  new(this._run, this._armed, this.sides, {required this.clip});

  final Animation<double> _run;
  EdgeInsets Function(double width)? sides;
  bool clip;
  final _clip = LayerHandle<ClipRectLayer>();

  int _armed;
  int get armed => _armed;
  (double, double)? _was; // its column as drawn when told to glide
  double _from = 0; // how far off it's drawn as the glide starts
  double _drawn = 0; // how far off it was last drawn

  set armed(int v) {
    if (v == _armed) return;
    _armed = v;
    // Where it shows now: its last layout and its glide's offset. Not yet
    // laid out again, so this is still the old place.
    if (attached && hasSize) {
      final (x, width) = _column();
      _was = (x + _drawn, width);
    }
    markNeedsPaint();
  }

  /// Its column's x in the window, and its width.
  (double, double) _column() {
    final x = localToGlobal(Offset.zero).dx;
    final s = sides?.call(size.width) ?? EdgeInsets.zero;
    return (x + s.left, size.width - s.horizontal);
  }

  double get _dx => _from == 0 ? 0 : _from * (1 - _run.value);

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _run.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _run.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  /// Whether it's drawn off its box, and cut to it.
  bool get _clipped => clip && _drawn != 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_was case (final x, final width)?) {
      _was = null;
      final (now, nowWidth) = _column();
      final by = x - now;
      _from = by.abs() < 0.5 || (width - nowWidth).abs() > 0.5 ? 0 : by;
    }
    if (_run.isCompleted) _from = 0;
    _drawn = _dx;
    final child = this.child;
    if (child == null) return;
    if (!_clipped) {
      _clip.layer = null;
      context.paintChild(child, offset + Offset(_drawn, 0));
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) =>
          context.paintChild(child, offset + Offset(_drawn, 0)),
      oldLayer: _clip.layer,
    );
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _clipped ? Offset.zero & size : null;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: Offset(_drawn, 0),
        position: position,
        hitTest: (result, position) =>
            child?.hitTest(result, position: position) ?? false,
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_drawn, 0, 0, 1);
}
