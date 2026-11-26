import 'package:flutter/rendering.dart';

import 'package:nushi/top_notices.dart';

/// A box drawn and hit [shift] from where it's laid out, the shift read
/// as it paints from where the bars and panes of its [floor] are, after
/// their layout: never a frame behind them, and nothing laid out again.
/// The update card's lift (`CardLift`) and Jump to latest kept clear of
/// the side panes (`ClearOfPanes`) each say only their own [shift].
abstract class PaintShift extends RenderProxyBox {
  new(CardFloor? floor) : _floor = floor;

  CardFloor? _floor;

  /// What it follows: as it changes, it's drawn again.
  CardFloor? get floor => _floor;
  set floor(CardFloor? floor) {
    if (floor == _floor) return;
    if (attached) _floor?.removeListener(moved);
    _floor = floor;
    if (attached) _floor?.addListener(moved);
    moved();
  }

  /// How far from where it's laid out it's drawn and hit, now.
  Offset get shift;

  /// Its shift may have changed: drawn again, and its place told to a
  /// screen reader.
  void moved() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _floor?.addListener(moved);
  }

  @override
  void detach() {
    _floor?.removeListener(moved);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      super.paint(context, offset + shift);

  // No check of its own box: shifted, its child is out of it (and a
  // lifted card's box is out of its parent's, one in another).
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final inner = child;
    if (inner == null) return false;
    final hit = result.addWithPaintOffset(
      offset: shift,
      position: position,
      hitTest: (result, p) => inner.hitTest(result, position: p),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final at = shift;
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }
}
