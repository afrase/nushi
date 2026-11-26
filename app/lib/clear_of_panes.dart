import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/top_notices.dart';

/// [child], a band across a chat's column with something centred in it
/// (Jump to latest), drawn and hit in the middle of what the side panes
/// leave of the band while they lie over the view (a narrow window, ADR
/// 0123), and where it's laid out otherwise. It reads where the panes
/// start as it paints, after their layout ([CardFloor.cut]), so it's never
/// a frame behind them and nothing is laid out again; a side pane's own
/// view, never under another pane, stays as it's laid out.
class ClearOfPanes extends SingleChildRenderObjectWidget {
  const new({super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _Clear(_view(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _Clear).follow(_view(context));

  /// The chat area's view it's in, if it's in one: its floor, and its box.
  static InheritedElement? _view(BuildContext context) {
    final at = context.getElementForInheritedWidgetOfExactType<CardFloors>();
    if (at == null) return null;
    context.dependOnInheritedElement(at);
    return (at.widget as CardFloors).pane ? null : at;
  }
}

class _Clear extends RenderProxyBox {
  new(this._at);

  InheritedElement? _at;

  CardFloor? get _floor => (_at?.widget as CardFloors?)?.floor;

  void follow(InheritedElement? at) {
    if (at == _at) return;
    if (attached) _floor?.removeListener(markNeedsPaint);
    _at = at;
    if (attached) _floor?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _floor?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _floor?.removeListener(markNeedsPaint);
    super.detach();
  }

  /// How far left it's drawn: half of what of its band lies under the
  /// panes, so its middle is the middle of what's left, but never past
  /// its band's left edge with what's centred in it.
  double get _shift {
    final cut = _floor?.cut;
    final view = _at?.findRenderObject();
    final inner = child;
    if (cut == null || view is! RenderBox || !hasSize || inner == null) {
      return 0;
    }
    final band = restingRect(this);
    final viewAt = restingRect(view);
    if (band == null || viewAt == null) return 0;
    final hidden = band.right - (viewAt.left + cut);
    if (hidden <= 0) return 0;
    // What's centred in the band: the widest of its children's boxes.
    var wide = 0.0;
    inner.visitChildren((c) {
      if (c is RenderBox && c.hasSize) wide = max(wide, c.size.width);
    });
    return min(hidden / 2, max(0, (size.width - wide) / 2));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      super.paint(context, offset.translate(-_shift, 0));

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final inner = child;
    if (inner == null) return false;
    final hit = result.addWithPaintOffset(
      offset: Offset(-_shift, 0),
      position: position,
      hitTest: (result, p) => inner.hitTest(result, position: p),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) =>
      transform.translateByDouble(-_shift, 0, 0, 1);
}
