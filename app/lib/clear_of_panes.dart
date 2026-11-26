import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:nushi/paint_shift.dart';
import 'package:nushi/top_notices.dart';

/// A band across a chat's column with [child] centred in it (Jump to
/// latest), [child] drawn and hit in the middle of what the side panes
/// leave of the band while they lie over the view (a narrow window, ADR
/// 0123), and in the band's middle otherwise. It reads where the panes
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

class _Clear extends PaintShift {
  new(this._at) : super(_floorOf(_at));

  InheritedElement? _at;

  static CardFloor? _floorOf(InheritedElement? at) =>
      (at?.widget as CardFloors?)?.floor;

  void follow(InheritedElement? at) {
    if (at == _at) return;
    _at = at;
    floor = _floorOf(at);
    moved();
  }

  // As wide as its band and as high as what's in it, which takes what
  // width it needs.
  Size _sized(BoxConstraints constraints, Size inner) => constraints.constrain(
    Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : inner.width,
      inner.height,
    ),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final inner = child;
    if (inner == null) return constraints.smallest;
    return _sized(constraints, inner.getDryLayout(constraints.loosen()));
  }

  @override
  void performLayout() {
    final inner = child;
    if (inner == null) {
      size = constraints.smallest;
      return;
    }
    inner.layout(constraints.loosen(), parentUsesSize: true);
    size = _sized(constraints, inner.size);
  }

  /// Where what's in it is drawn: in its band's middle, and left by half
  /// of what of the band lies under the panes, so its middle is the
  /// middle of what's left, but never past the band's left edge.
  @override
  Offset get shift {
    final inner = child;
    if (inner == null || !hasSize || !inner.hasSize) return Offset.zero;
    final free = max(0.0, (size.width - inner.size.width) / 2);
    return Offset(free - min(free, _hidden / 2), 0);
  }

  /// How much of its band lies under the panes lying over the view.
  double get _hidden {
    final cut = floor?.cut;
    final view = _at?.findRenderObject();
    if (cut == null || view is! RenderBox) return 0;
    final band = restingRect(this);
    final viewAt = restingRect(view);
    if (band == null || viewAt == null) return 0;
    return max(0, band.right - (viewAt.left + cut));
  }
}
