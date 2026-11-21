part of 'controls.dart';

/// A widget and, [gap] after it, an extra one, which gives way: it shows
/// only when both fit at their full widths, so a chosen key that's long
/// (a Linux Ctrl+Alt+Shift+Page Up) never pushes out the label beside it
/// (ADR 0146). With [fill] it takes all the width it's given and the
/// extra one stands at its end (the sidebar's New chat); else it's as
/// wide as what it shows. Each is centred in its height.
class GivesWay extends MultiChildRenderObjectWidget {
  new({
    required Widget lead,
    required Widget extra,
    super.key,
    this.gap = 6,
    this.fill = false,
  }) : super(children: [lead, extra]);

  final double gap;
  final bool fill;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGivesWay(gap: gap, fill: fill);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderGivesWay)
        ..gap = gap
        ..fill = fill;
}

class _GivesWayData extends ContainerBoxParentData<RenderBox>;

class _RenderGivesWay extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GivesWayData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GivesWayData> {
  new({required this._gap, required this._fill});

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  bool _fill;
  bool get fill => _fill;
  set fill(bool v) {
    if (v == _fill) return;
    _fill = v;
    markNeedsLayout();
  }

  /// Whether the extra one fit, at the last layout.
  bool _shows = false;

  RenderBox get _lead => firstChild!;
  RenderBox get _extra => childAfter(firstChild!)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GivesWayData) child.parentData = _GivesWayData();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _lead.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _lead.getMaxIntrinsicWidth(height) +
      _gap +
      _extra.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => max(
    _lead.getMinIntrinsicHeight(width),
    _extra.getMinIntrinsicHeight(double.infinity),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => max(
    _lead.getMaxIntrinsicHeight(width),
    _extra.getMaxIntrinsicHeight(double.infinity),
  );

  /// The size, whether the extra one shows, and each one's size.
  (Size, bool, Size, Size) _measure(
    BoxConstraints c,
    Size Function(RenderBox, BoxConstraints) size,
  ) {
    final loose = BoxConstraints(maxHeight: c.maxHeight);
    final extra = size(_extra, loose);
    final wants = _lead.getMaxIntrinsicWidth(c.maxHeight);
    final shows = wants + _gap + extra.width <= c.maxWidth;
    final lead = size(
      _lead,
      loose.copyWith(
        maxWidth: max(0.0, c.maxWidth - (shows ? _gap + extra.width : 0)),
      ),
    );
    final used = lead.width + (shows ? _gap + extra.width : 0);
    final width = _fill && c.hasBoundedWidth ? c.maxWidth : used;
    final height = max(lead.height, shows ? extra.height : 0.0);
    return (c.constrain(Size(width, height)), shows, lead, extra);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _measure(constraints, (r, c) => r.getDryLayout(c)).$1;

  @override
  void performLayout() {
    final (all, shows, lead, extra) = _measure(constraints, (r, c) {
      r.layout(c, parentUsesSize: true);
      return r.size;
    });
    size = all;
    _shows = shows;
    (_lead.parentData! as _GivesWayData).offset = Offset(
      0,
      (all.height - lead.height) / 2,
    );
    (_extra.parentData! as _GivesWayData).offset = Offset(
      _fill ? all.width - extra.width : lead.width + _gap,
      (all.height - extra.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(_lead, offset + _offset(_lead));
    if (_shows) context.paintChild(_extra, offset + _offset(_extra));
  }

  Offset _offset(RenderBox r) => (r.parentData! as _GivesWayData).offset;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final r in [if (_shows) _extra, _lead]) {
      final hit = result.addWithPaintOffset(
        offset: _offset(r),
        position: position,
        hitTest: (result, p) => r.hitTest(result, position: p),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_lead);
    if (_shows) visitor(_extra);
  }
}
