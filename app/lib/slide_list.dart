import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/motion.dart';

// Lists whose items move by dragging, the others sliding apart to open
// the gap where the dragged one would land and settling on the drop, as
// the details panel's widgets do. The sidebar's lists sit in
// one scroll, a project's chats inside the projects' list, which nested
// ReorderableListViews can't be: these are Columns that slide their items
// by a transform, and work out where a drop lands from the items' places
// as laid out, which the slide doesn't change (so the gap opening under
// the pointer doesn't move the place it points at).

/// How long the others take to slide apart, or back.
const _slideFor = Duration(milliseconds: 200);

/// Items ([count] of them, [item] building each, keyed) that move by
/// dragging within this list: a drag whose data it [accepts] opens a gap
/// where the dragged item would land, the dragged one shown faded there,
/// and dropped there [onMove] says it moved from one place to another (its
/// place once it's out). Dragged elsewhere, or onto a list that refuses
/// it, everything slides back. Reduce Motion: the gap opens at once.
class SlideList<T extends Object> extends StatefulWidget {
  const new({
    required this.count,
    required this.item,
    required this.accepts,
    required this.onMove,
    super.key,
  });

  final int count;

  /// The item at an index, keyed; its [ItemDrag] makes the part that
  /// drags it.
  final Widget Function(int i, ItemDrag<T> drag) item;
  final bool Function(T data) accepts;
  final void Function(int from, int to) onMove;

  @override
  State<SlideList<T>> createState() => _SlideListState<T>();
}

/// What makes a [SlideList]'s item draggable.
class ItemDrag<T extends Object> {
  const new _(this._list, this._i);

  final _SlideListState<T> _list;
  final int _i;

  /// [child] dragging its item, carrying [data], [feedback] under the
  /// pointer; not while [enabled] is off.
  Widget draggable({
    required T data,
    required Widget feedback,
    required Widget child,
    bool enabled = true,
  }) => Draggable<T>(
    data: data,
    maxSimultaneousDrags: enabled ? null : 0,
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: feedback,
    onDragStarted: () => _list._start(_i),
    onDragUpdate: (d) => _list._scroll.update(_list.context, d),
    onDragEnd: (_) => _list._end(),
    child: child,
  );
}

class _SlideListState<T extends Object> extends State<SlideList<T>> {
  final GlobalKey _column = GlobalKey();
  final _scroll = EdgeScroll();
  Key? _moving; // the dragged item's
  int? _dropAt; // where it would go: before the item at this index
  var _keys = <Key>[]; // the items', as last built

  /// Each item's top and height as laid out, measured as the drag moves.
  var _spans = <(double, double)>[];

  /// Whether the order just changed under a drop: the items are where the
  /// slide put them, so they settle without sliding again.
  bool _dropped = false;

  int get _from => _moving == null ? -1 : _keys.indexOf(_moving!);

  /// Where the dragged item would land (its index once moved), if a drop
  /// would move it, not just put it back.
  int? get _to {
    final at = _dropAt;
    final from = _from;
    if (from < 0 || at == null || at == from || at == from + 1) return null;
    return at > from ? at - 1 : at;
  }

  void _start(int i) {
    _measure();
    setState(() {
      _moving = _keys[i];
      _dropAt = null;
      _dropped = false;
    });
  }

  void _measure() {
    final flex = _column.currentContext?.findRenderObject();
    if (flex is! RenderFlex) return;
    final spans = <(double, double)>[];
    for (var child = flex.firstChild; child != null;) {
      final data = child.parentData! as FlexParentData;
      spans.add((data.offset.dy, child.size.height));
      child = data.nextSibling;
    }
    _spans = spans;
  }

  /// The pointer at [global]: an item's upper half puts the dragged one
  /// before it, its lower half after.
  void _over(Offset global) {
    final box = _column.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    _measure();
    final y = box.globalToLocal(global).dy;
    var at = _spans.length;
    for (final (i, (top, height)) in _spans.indexed) {
      if (y < top + height / 2) {
        at = i;
        break;
      }
    }
    if (at != _dropAt) setState(() => _dropAt = at);
  }

  void _drop() {
    if (_to case final to?) {
      _dropped = true;
      widget.onMove(_from, to);
    }
    _end();
  }

  void _end() {
    _scroll.stop();
    if (mounted) {
      setState(() {
        _moving = null;
        _dropAt = null;
      });
    }
  }

  /// How far the [i]th item slides: the dragged one to where it would
  /// land, those it passes by its height the other way.
  double _shift(int i) {
    final from = _from;
    final to = _to;
    if (to == null || from >= _spans.length || to >= _spans.length) return 0;
    double sum(int a, int b) =>
        _spans.sublist(a, b).fold(0, (s, span) => s + span.$2);
    if (i == from) return to > from ? sum(from + 1, to + 1) : -sum(to, from);
    final height = _spans[from].$2;
    if (from < i && i <= to) return -height;
    if (to <= i && i < from) return height;
    return 0;
  }

  @override
  void dispose() {
    _scroll.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < widget.count; i++)
        widget.item(i, ItemDrag._(this, i)),
    ];
    _keys = [for (final w in items) w.key!];
    final still = reduceMotion(context);
    return DragTarget<T>(
      onWillAcceptWithDetails: (d) => widget.accepts(d.data),
      onMove: (d) {
        if (widget.accepts(d.data)) _over(d.offset); // refused: no gap
      },
      onLeave: (d) {
        if (d != null && widget.accepts(d)) setState(() => _dropAt = null);
      },
      onAcceptWithDetails: (_) => _drop(),
      builder: (context, _, _) => Column(
        key: _column,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed)
            _Slide(
              key: item.key,
              dy: _shift(i),
              faded: item.key == _moving,
              slideFor: still || _dropped ? Duration.zero : _slideFor,
              fadeFor: still ? Duration.zero : _slideFor,
              child: item,
            ),
        ],
      ),
    );
  }
}

/// An item [dy] down from its place (up when negative), getting there
/// over [slideFor]; [faded] while it's the one dragged.
class _Slide extends StatelessWidget {
  const new({
    required this.dy,
    required this.faded,
    required this.slideFor,
    required this.fadeFor,
    required this.child,
    super.key,
  });

  final double dy;
  final bool faded;
  final Duration slideFor;
  final Duration fadeFor;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: dy),
    duration: slideFor,
    curve: Curves.easeOutCubic,
    builder: (context, y, child) =>
        Transform.translate(offset: Offset(0, y), child: child),
    child: AnimatedOpacity(
      opacity: faded ? 0.4 : 1,
      duration: fadeFor,
      child: child,
    ),
  );
}

/// Scrolls the list a drag is in while the pointer is near its top or
/// bottom edge.
class EdgeScroll {
  EdgeDraggingAutoScroller? _scroller;

  void update(BuildContext context, DragUpdateDetails d) {
    if (_scroller == null) {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;
      _scroller = EdgeDraggingAutoScroller(scrollable, velocityScalar: 50);
    }
    _scroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: d.globalPosition, width: 1, height: 40),
    );
  }

  void stop() {
    _scroller?.stopAutoScroll();
    _scroller = null;
  }
}
