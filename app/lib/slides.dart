import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/disclosure.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

// What comes and goes around a view (the fluidity review's ideas 7, 10 and
// 11): bars and the terminal sliding open, panes and the sidebar sliding
// in from their edge, and the chat's text gliding to where a pane leaves
// it. Each follows motion.dart's rules: nothing waits on it, what goes
// takes no pointer or focus, a second toggle reverses it from where it is,
// and under Reduce Motion it all happens at once.

/// [child] coming as it's given and going as it's taken away (null): its
/// run goes from 0 to 1 over [enter] through [curve] as it comes, and back
/// over [Motion.exit] through [Motion.leave] as it goes, [builder] drawing
/// the child at its run. While it goes it shows the last child it was
/// given (the same widget, so what it read stays) and takes no pointer or
/// focus; once gone it's nothing. What it's given at its first build is
/// there at once unless it [arrives] (a pane opened beside a view that was
/// there), and under Reduce Motion everything is.
///
/// Not [shown], a child goes as one taken away does, but stays: once gone
/// it's kept, laid out but not drawn, taking no pointer or focus, its
/// tickers stopped, and it comes back as the same widget when shown again
/// (the details rail, tucked away while the panes need its room, ADR 0123).
/// Taken away while tucked, it's gone at once.
class Presence extends StatefulWidget {
  const new({
    required this.child,
    required this.builder,
    super.key,
    this.enter = Motion.enter,
    this.curve = Motion.settle,
    this.arrives = false,
    this.shown = true,
  });

  final Widget? child;
  final bool arrives;
  final bool shown;
  final Widget Function(
    BuildContext context,
    Animation<double> run,
    Widget child,
  )
  builder;
  final Duration enter;
  final Curve curve;

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
      reverseDuration: Motion.exit,
      value: _last == null || widget.arrives || !widget.shown ? 0 : 1,
    )..addStatusListener(_ran);
    // Going, the run goes back through [Presence.leave]: it gathers speed.
    _curved = CurvedAnimation(
      parent: _run,
      curve: widget.curve,
      reverseCurve: Motion.leave.flipped,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_last == null || !widget.shown || _run.value > 0 || _run.isAnimating) {
      return;
    }
    if (reduceMotion(context)) {
      _run.value = 1;
    } else {
      _run.forward().ignore();
    }
  }

  void _ran(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _last == null) return;
    if (widget.child == null) {
      setState(() => _last = null);
    } else if (!widget.shown) {
      setState(() {}); // tucked: kept, not drawn
    }
  }

  @override
  void didUpdateWidget(Presence old) {
    super.didUpdateWidget(old);
    final still = reduceMotion(context);
    if (widget.child case final child? when !widget.shown) {
      _last = child;
      if (still) {
        _run.value = 0;
      } else if (_run.isForwardOrCompleted) {
        _run.reverse().ignore();
      }
    } else if (widget.child case final child?) {
      _last = child;
      if (still) {
        _run.value = 1;
      } else if (!_run.isForwardOrCompleted) {
        _run.forward().ignore();
      }
    } else if (still || _run.isDismissed) {
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
    final going = widget.child == null || !widget.shown;
    final tucked = going && _run.isDismissed;
    return IgnorePointer(
      ignoring: going,
      child: ExcludeFocus(
        excluding: going,
        child: Offstage(
          offstage: tucked,
          child: TickerMode(
            enabled: !tucked,
            child: widget.builder(context, _curved, child),
          ),
        ),
      ),
    );
  }
}

/// One of the bars (ADR 0128, amended 2026-11-17): a notice that stays
/// until it's done with (the daemon's lost or back, its update waiting for
/// idle chats, removed chats, a start walked away from), in a row of its
/// own under the header, which pushes what's under it down rather than
/// lying over it. A card on the pane (`raised`, corners `control`, no
/// shadow: it doesn't float), [tint] over its fill for one that says a
/// state, as wide as its row, its text at the header's gutter.
class TopBar extends StatelessWidget {
  const new({required this.child, super.key, this.tint});

  final Widget child;
  final Color? tint;

  /// The room around each: in from the row's sides, and over it (the
  /// header's hairline or the bar before).
  static const side = 12.0;
  static const gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final radius = BorderRadius.circular(NushiTheme.control);
    return Padding(
      padding: const EdgeInsets.fromLTRB(side, gap, side, 0),
      child: DecoratedBox(
        decoration: cardBox(t, radius: NushiTheme.control),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: radius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A bar over (or under) a view that opens as it comes and closes as it
/// goes: its height eases through [curve] and, with [fade], its opacity
/// with it. [down], it slides down from its top edge (a bar under the
/// header, the pinned plan's steps over its line); otherwise its top edge
/// rises (the terminal, under the chat; a line over the composer). What's
/// inside is laid out at its own height throughout, so it's sized once (a
/// terminal's PTY too), and clipped ([Fold]).
class BarSlide extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.down = true,
    this.fade = true,
    this.enter = Motion.standard,
    this.curve = Motion.settle,
  });

  final Widget? child;
  final bool down;
  final bool fade;
  final Duration enter;
  final Curve curve;

  @override
  Widget build(BuildContext context) => Presence(
    enter: enter,
    curve: curve,
    child: child,
    builder: (context, run, child) => AnimatedBuilder(
      animation: run,
      builder: (context, child) => Fold(
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
/// With [clip], what's drawn left of its box while it glides is cut at its
/// left edge: the chat's transcript, whose foot (the composer's backdrop)
/// is its full width and would otherwise lie over the sidebar, drawn under
/// it, as it glides. Drawn right of its box it isn't cut: it slides under
/// the panes, drawn over it, as they slide in, and a cut there would chop
/// what's still in view. At rest nothing is clipped, and nothing is a
/// layer more.
class Glide extends StatefulWidget {
  const new({
    required this.token,
    required this.child,
    super.key,
    this.sides,
    this.clip = false,
    this.scene,
  });

  final Object? token;

  /// A change of it, with [token]'s, is a new scene (another of a chat's
  /// tabs): it's drawn where it is at once.
  final Object? scene;
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
    if (widget.token == old.token ||
        widget.scene != old.scene ||
        reduceMotion(context)) {
      return;
    }
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

  /// Whether it's drawn left of its box, and cut there. Drawn that way,
  /// its right edge is inside its box, so the box is the cut.
  bool get _clipped => clip && _drawn < 0;

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
