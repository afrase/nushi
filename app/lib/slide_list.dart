import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/list_motion.dart';
import 'package:nushi/motion.dart';

// Lists whose items move by dragging, the others sliding apart to open
// the gap where the dragged one would land and settling on the drop, as
// the details panel's widgets do. The sidebar's lists sit in
// one scroll, a project's chats inside the projects' list, which nested
// ReorderableListViews can't be: these are Columns that slide their items
// by a transform, and work out where a drop lands from the items' places
// as laid out, which the slide doesn't change (so the gap opening under
// the pointer doesn't move the place it points at). Items also come and
// go with motion (`list_motion.dart`).

/// How long the others take to slide apart, or back.
const _slideFor = Duration(milliseconds: 200);

/// Items ([count] of them, [item] building each, keyed) that move by
/// dragging within this list: a drag whose data it [accepts] opens a gap
/// where the dragged item would land, the dragged one shown faded there,
/// and dropped there [onMove] says it moved from one place to another (its
/// place once it's out). Dragged elsewhere, or onto a list that refuses
/// it, everything slides back. Reduce Motion: the gap opens at once.
///
/// An item that comes grows in, one that goes fades and folds, and one
/// that moved here from another list of the same [ListMotion] glides from
/// where it was ([Presence]); none of it as the list is first built.
/// [standIn], while given (keyed), shows at the top for an item on its
/// way, and the first new item to come takes its place, with no jump;
/// nothing drags meanwhile.
class SlideList<T extends Object> extends StatefulWidget {
  const new({
    required this.count,
    required this.item,
    required this.accepts,
    required this.onMove,
    super.key,
    this.standIn,
  });

  final int count;
  final Widget? standIn;

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
    maxSimultaneousDrags: enabled && !_list._standing ? null : 0,
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

  bool _built = false;
  var _last = <Key, Widget>{}; // the items as last built, by key
  var _order = <Key>[]; // the column's, as last built: items, stand-in, gone
  final _gone = <Key, (Widget, Leaving)>{}; // items still leaving
  Widget? _shownStandIn; // the stand-in, as last built, while it showed
  bool _taken = false; // an item came in the stand-in's place
  bool _justDropped = false; // the next order is a drop's: it settles
  final _moves = <Key, int>{}; // how often each was put elsewhere

  /// Counts a move for each item [live] puts elsewhere among those it
  /// had before (not by a drop): each glides there ([Presence.moves]).
  void _reordered(Map<Key, Widget> live, {required bool calm}) {
    final dropped = _justDropped;
    _justDropped = false;
    if (dropped || calm) return;
    final before = [
      for (final k in _last.keys)
        if (live.containsKey(k)) k,
    ];
    final now = [
      for (final k in live.keys)
        if (_last.containsKey(k)) k,
    ];
    for (final (i, k) in now.indexed) {
      if (before[i] != k) _moves[k] = (_moves[k] ?? 0) + 1;
    }
    _moves.removeWhere((k, _) => !live.containsKey(k));
  }

  /// Whether the stand-in shows.
  bool get _standing => _shownStandIn != null;

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
      _gone.clear(); // the column is its items again, as it's measured
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
      _justDropped = true;
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

  /// The column's keys, with how each new item arrives in [arrivals]: the
  /// items, the stand-in on top, and those still leaving where they were.
  List<Key> _arrange(
    Map<Key, Widget> live,
    Map<Key, Arrival> arrivals, {
    required bool still,
  }) {
    final motion = ListMotion.of(context);
    // With Reduce Motion, while dragging, and as first built, nothing grows
    // in or leaves slowly; one moved from another list still glides.
    final calm = still || !_built || _moving != null;
    for (final k in live.keys) {
      if (_last.containsKey(k) || _gone.remove(k) != null) continue;
      arrivals[k] = still
          ? Arrival.still
          : motion?.seenAt(k) != null
          ? Arrival.glide
          : calm
          ? Arrival.still
          : Arrival.grow;
    }
    final standIn = widget.standIn;
    final before = _shownStandIn;
    // The first new item takes the stand-in's place, if it showed (going
    // now or not: the start may end in the build its item comes in).
    var took = false;
    if (before != null && !_taken) {
      final k = arrivals.entries
          .where((e) => e.value == Arrival.grow)
          .firstOrNull
          ?.key;
      if (k != null) {
        arrivals[k] = Arrival.still;
        took = true;
      }
    }
    _taken = standIn != null && (_taken || took);
    final standing = standIn != null && !_taken;
    _shownStandIn = standing ? standIn : null;
    if (standing && before == null) {
      arrivals[standIn.key!] = calm ? Arrival.still : Arrival.grow;
    }
    if (!calm) {
      for (final MapEntry(key: k, value: w) in _last.entries) {
        if (live.containsKey(k)) continue;
        final elsewhere = motion?.shown.contains(k) ?? false;
        _gone[k] = (w, elsewhere ? Leaving.vacate : Leaving.fade);
      }
      if (before != null && !standing && !took && !_taken) {
        _gone[before.key!] = (before, Leaving.fade);
      }
    } else {
      _gone.clear();
    }
    final order = [if (standing) standIn.key!, ...live.keys];
    // Each leaving item stays after what was above it.
    for (final (i, k) in _order.indexed) {
      if (!_gone.containsKey(k) || order.contains(k)) continue;
      final above = _order.sublist(0, i).reversed.where(order.contains);
      order.insert(above.isEmpty ? 0 : order.indexOf(above.first) + 1, k);
    }
    return order;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < widget.count; i++)
        widget.item(i, ItemDrag._(this, i)),
    ];
    _keys = [for (final w in items) w.key!];
    final still = reduceMotion(context);
    final live = {for (final w in items) w.key!: w};
    final arrivals = <Key, Arrival>{};
    final order = _arrange(live, arrivals, still: still);
    _reordered(live, calm: still || _moving != null);
    _last = live;
    _order = order;
    _built = true;
    Widget slot(Key k, int i) {
      if (live[k] case final item?) {
        return _Slide(
          key: k,
          dy: _shift(i),
          faded: k == _moving,
          slideFor: still || _dropped ? Duration.zero : _slideFor,
          fadeFor: still ? Duration.zero : _slideFor,
          child: Presence(
            id: k,
            arrival: arrivals[k] ?? Arrival.still,
            leaving: null,
            moves: _moves[k] ?? 0,
            onGone: () {},
            child: item,
          ),
        );
      }
      final (child, leaving) = switch (_gone[k]) {
        final gone? => (gone.$1, gone.$2 as Leaving?),
        null => (_shownStandIn!, null),
      };
      return _Slide(
        key: k,
        dy: 0,
        faded: false,
        slideFor: Duration.zero,
        fadeFor: Duration.zero,
        child: Presence(
          id: k,
          arrival: arrivals[k] ?? Arrival.still,
          leaving: leaving,
          onGone: () {
            if (mounted) setState(() => _gone.remove(k));
          },
          child: child,
        ),
      );
    }

    return DragTarget<T>(
      onWillAcceptWithDetails: (d) => widget.accepts(d.data),
      onMove: (d) {
        if (widget.accepts(d.data)) _over(d.offset); // refused: no gap
      },
      onLeave: (d) {
        if (d != null && widget.accepts(d)) setState(() => _dropAt = null);
      },
      onAcceptWithDetails: (_) => _drop(),
      builder: (context, _, _) => GlideColumn(
        key: _column,
        motion: ListMotion.of(context),
        children: [for (final k in order) slot(k, _keys.indexOf(k))],
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
