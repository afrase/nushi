part of 'sidebar_button.dart';

// What leads a header past the lights while the sidebar is hidden moves
// with the sidebar's edge as it slides, rather than jump.

/// The sidebar's slide, for what follows its edge ([SidebarFollow]).
/// `SidebarBeside` makes one and shares it below it ([scope]); the
/// sidebar's slide gives it its run ([origin]). Under Reduce Motion the
/// slide doesn't run, and nothing moves.
class SidebarGlide {
  /// The sidebar's run: 0 gone, 1 shown.
  final run = ProxyAnimation(kAlwaysCompleteAnimation);

  /// [child], the sidebar inside its slide, whose [run] this follows.
  Widget origin(Animation<double> run, Widget child) {
    this.run.parent = run;
    return child;
  }

  /// [child] with this shared below it.
  Widget scope(Widget child) => _GlideScope(glide: this, child: child);
}

class _GlideScope extends InheritedWidget {
  const new({required this.glide, required super.child});

  final SidebarGlide glide;

  @override
  bool updateShouldNotify(_GlideScope old) => glide != old.glide;
}

/// [child], what leads a header past the lights while the sidebar is
/// hidden, moving with the sidebar's edge as it slides: it's laid out at
/// once where it goes, and drawn as far from where it lies with the sidebar
/// hidden toward where it lay with it shown as the sidebar is shown (each
/// as it was last drawn). Its pointer goes where it's drawn. [clip],
/// nothing of it is drawn past its right edge, so what's right of it stays
/// clear.
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
