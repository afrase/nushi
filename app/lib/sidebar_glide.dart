part of 'sidebar_button.dart';

// The sidebar's button while the sidebar slides, and what leads a header
// past the lights: both move with the sidebar's edge rather than jump.

/// The sidebar's slide as its button follows it. `SidebarBeside` makes one
/// and shares it below it ([scope]); the sidebar's own top left inside its
/// slide ([origin]) gives it the slide's run, and the button's two places
/// say where they are. While the slide runs, the button is drawn at the
/// place as far from the header's toward the sidebar's as the sidebar is
/// shown, so it leaves with the slide's curve and turns back with it; under
/// Reduce Motion the slide doesn't run, and nothing moves.
class SidebarGlide {
  /// The sidebar's run: 0 gone, 1 shown.
  final run = ProxyAnimation(kAlwaysCompleteAnimation);

  _RenderSpot? _inSidebar;
  _RenderSpot? _inHeader;
  _RenderOrigin? _origin;
  _RenderMover? _mover;

  /// Where the header's place was last drawn, in the window: with the
  /// sidebar shown no header has one, but it's where the button goes.
  Offset? _header;

  /// [child], the sidebar inside its slide, marked as its top left; it
  /// lies at the top left of `SidebarBeside` when the sidebar is shown.
  Widget origin(Animation<double> run, Widget child) =>
      _Origin(glide: this, run: run, child: child);

  /// [child] with this shared below it.
  Widget scope(Widget child) => _GlideScope(glide: this, child: child);

  /// Where the moving button is drawn, from where it's laid out (the top
  /// left of `SidebarBeside`), while the slide runs and both places are
  /// known.
  Offset? _at() {
    final mover = _mover;
    final spot = _inSidebar;
    final origin = _origin;
    if (!run.isAnimating || mover == null || spot == null || origin == null) {
      return null;
    }
    final header = _inHeader;
    final home = header != null && header.hasSize
        ? header.localToGlobal(Offset.zero)
        : _header;
    if (home == null || !spot.hasSize) return null;
    // The sidebar's place as if it were at rest: inside its slide.
    final own = spot.localToGlobal(Offset.zero, ancestor: origin);
    return Offset.lerp(home - mover.localToGlobal(Offset.zero), own, run.value);
  }

  /// Whether the moving button is drawn, so neither place draws its own.
  bool get _moving => _at() != null;
}

class _GlideScope extends InheritedWidget {
  const new({required this.glide, required super.child});

  final SidebarGlide glide;

  @override
  bool updateShouldNotify(_GlideScope old) => glide != old.glide;
}

class _Origin extends SingleChildRenderObjectWidget {
  const new({required this.glide, required this.run, super.child});

  final SidebarGlide glide;
  final Animation<double> run;

  @override
  RenderObject createRenderObject(BuildContext context) {
    glide.run.parent = run;
    return _RenderOrigin(glide);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      glide.run.parent = run;
}

class _RenderOrigin extends RenderProxyBox {
  new(this.glide);

  final SidebarGlide glide;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    glide._origin = this;
  }

  @override
  void detach() {
    if (glide._origin == this) glide._origin = null;
    super.detach();
  }
}

/// A place the button rests: it draws it, and takes its clicks, unless
/// the moving one is drawn.
class _Spot extends SingleChildRenderObjectWidget {
  const new({required this.glide, required this.header, super.child});

  final SidebarGlide glide;
  final bool header;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSpot(glide, header: header);
}

class _RenderSpot extends RenderProxyBox {
  new(this.glide, {required this.header});

  final SidebarGlide glide;
  final bool header;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (header) {
      glide._inHeader = this;
    } else {
      glide._inSidebar = this;
    }
    glide.run.addStatusListener(_ran);
  }

  @override
  void detach() {
    glide.run.removeStatusListener(_ran);
    if (glide._inHeader == this) glide._inHeader = null;
    if (glide._inSidebar == this) glide._inSidebar = null;
    super.detach();
  }

  void _ran(AnimationStatus _) => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (header) glide._header = localToGlobal(Offset.zero);
    if (!glide._moving) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !glide._moving && super.hitTest(result, position: position);
}

/// The button while the sidebar slides, drawn over both, laid out at
/// `SidebarBeside`'s top left and drawn where [SidebarGlide] says; its
/// clicks land where it's drawn.
class _Mover extends SingleChildRenderObjectWidget {
  const new({required this.glide, super.child});

  final SidebarGlide glide;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMover(glide);
}

class _RenderMover extends RenderProxyBox {
  new(this.glide);

  final SidebarGlide glide;
  Offset? _drawn; // where it was last drawn

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    glide._mover = this;
    glide.run.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    glide.run.removeListener(markNeedsPaint);
    if (glide._mover == this) glide._mover = null;
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final at = _drawn = glide._at();
    if (at != null) super.paint(context, offset + at);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final at = _drawn;
    if (at == null) return false;
    return result.addWithPaintOffset(
      offset: at,
      position: position,
      hitTest: (result, position) =>
          child?.hitTest(result, position: position) ?? false,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final at = _drawn ?? Offset.zero;
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }
}

/// [SidebarButton] while the sidebar slides, in `SidebarBeside`'s top
/// layer: there from the toggle (so from the slide's first frame) until
/// the slide ends, not at rest or under Reduce Motion.
class MovingSidebarButton extends StatefulWidget {
  const new({required this.glide, super.key});

  final SidebarGlide glide;

  @override
  State<MovingSidebarButton> createState() => _MovingState();
}

class _MovingState extends State<MovingSidebarButton> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    sidebarHidden.addListener(_toggled);
    widget.glide.run.addStatusListener(_ran);
  }

  @override
  void dispose() {
    sidebarHidden.removeListener(_toggled);
    widget.glide.run.removeStatusListener(_ran);
    super.dispose();
  }

  // The toggle comes before the frame that starts the slide (whose start
  // is told while the sidebar builds, too late to build this then).
  void _toggled() {
    if (reduceMotion(context)) return;
    setState(() => _on = true);
    _settle();
  }

  void _ran(AnimationStatus status) {
    if (!status.isAnimating) _settle();
  }

  /// Gone after the frame, unless the slide runs.
  void _settle() => SchedulerBinding.instance.addPostFrameCallback((_) {
    if (mounted && _on && !widget.glide.run.isAnimating) {
      setState(() => _on = false);
    }
  });

  @override
  Widget build(BuildContext context) =>
      _on ? const SidebarButton._moving() : const SizedBox.shrink();
}

/// [child], what leads a header past the lights while the sidebar is
/// hidden, moving with the sidebar's edge as it slides: it's laid out at
/// once where it goes, and drawn as far from where it lies with the sidebar
/// hidden toward where it lay with it shown as the sidebar is shown (each
/// as it was last drawn), so the moving [SidebarButton] never crosses it.
/// Its pointer goes where it's drawn. [clip], nothing of it is drawn past
/// its right edge, so what's right of it stays clear.
class SidebarFollow extends SingleChildRenderObjectWidget {
  const new({required this.shut, super.key, super.child, this.clip = false});

  /// Whether the sidebar is hidden, so where it's laid out is its place
  /// with the sidebar hidden.
  final bool shut;
  final bool clip;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFollow(
    context.getInheritedWidgetOfExactType<_GlideScope>()?.glide,
    shut: shut,
    clip: clip,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderFollow)
        ..shut = shut
        ..clip = clip;
}

class _RenderFollow extends RenderProxyBox {
  new(this.glide, {required this.shut, required this.clip});

  final SidebarGlide? glide;
  bool shut;
  bool clip;
  final _clip = LayerHandle<ClipRectLayer>();
  double? _hidden; // its x in the window with the sidebar hidden
  double? _shown; // and shown
  double _drawn = 0; // how far off it was last drawn

  @override
  bool get isRepaintBoundary => glide != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    glide?.run.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    glide?.run.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _drawn = 0;
    if (glide case final glide?) {
      final x = localToGlobal(Offset.zero).dx;
      if (shut) {
        _hidden = x;
      } else {
        _shown = x;
      }
      if ((_hidden, _shown) case (final hidden?, final shown?)
          when glide.run.isAnimating) {
        _drawn = hidden + (shown - hidden) * glide.run.value - x;
      }
    }
    if (!clip || _drawn <= 0) {
      _clip.layer = null;
      super.paint(context, offset + Offset(_drawn, 0));
      return;
    }
    // Only its right edge: drawn from the left, it's whole.
    const far = 1e5;
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTRB(-far, -far, size.width, size.height + far),
      (context, offset) => super.paint(context, offset + Offset(_drawn, 0)),
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

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
