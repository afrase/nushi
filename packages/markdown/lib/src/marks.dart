part of 'text_marks.dart';

/// Gives what's under it its [TextMarks].
class TextMarksScope extends InheritedWidget {
  /// [marks] for what's in [child].
  const new({required this.marks, required super.child, super.key});

  /// The find's marks.
  final TextMarks marks;

  /// The marks above [context], if any.
  static TextMarks? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TextMarksScope>()?.marks;

  @override
  bool updateShouldNotify(TextMarksScope old) => marks != old.marks;
}

/// Paints the [TextMarks] of the text under it beneath that text. Goes
/// inside anything opaque around the text, as a code block's fill; without
/// a [TextMarksScope] above it does nothing. Given an [entry], one of the
/// entries a [TextMarks] looks in: put it where a repaint stays small.
class Marks extends SingleChildRenderObjectWidget {
  /// Marks the text in [child].
  const new({
    required Widget super.child,
    super.key,
    this.entry,
    this.background,
  });

  /// The entry's name, unique under its scope.
  final String? entry;

  /// The opaque fill the text is on (a code block's), where its colours
  /// were chosen for: given one, a match's text is drawn in the
  /// [TextMarks.ink] of its colour on the match's fill over it.
  final Color? background;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMarks(TextMarksScope.maybeOf(context), entry, null, null)
        .._background = background
        ..seen = _SeenScope.maybeOf(context);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMarks)
        ..update(TextMarksScope.maybeOf(context), entry, null, null)
        ..background = background
        ..seen = _SeenScope.maybeOf(context);
}

/// Something that folds [text] away (what opening a row shows, what a
/// subagent's row stands for): its matches there are [TextMark]s of this
/// row, which is tinted, and [builder] has how many ([text] empty once it's
/// open, its text then marked where it shows).
class FoldedMarks extends StatefulWidget {
  /// The row [builder] makes, folding away [text].
  const new({required this.text, required this.builder, super.key});

  /// What's folded away.
  final String text;

  /// The row, told how many matches are in what it folds away.
  final Widget Function(BuildContext context, ValueListenable<int> found)
  builder;

  @override
  State<FoldedMarks> createState() => _FoldedMarksState();
}

class _FoldedMarksState extends State<FoldedMarks> {
  final _found = ValueNotifier<int>(0);

  @override
  void dispose() {
    _found.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _Fold(widget.text, _found, child: widget.builder(context, _found));
}

class _Fold extends SingleChildRenderObjectWidget {
  const new(this.text, this.found, {required Widget super.child});

  final String text;
  final ValueNotifier<int> found;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMarks(TextMarksScope.maybeOf(context), null, text, found);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMarks).update(
        TextMarksScope.maybeOf(context),
        null,
        text,
        found,
      );
}

/// Keeps what's under it out of the [TextMarks]: what isn't the text (a
/// message's actions on hover, a mark's own count).
class Unmarked extends SingleChildRenderObjectWidget {
  /// Leaves [child] out.
  const new({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderUnmarked();
}

class _RenderUnmarked extends RenderProxyBox;

class _RenderMarks extends RenderProxyBox {
  new(this._scope, this._entry, this._fold, this._count);

  TextMarks? _scope;
  String? _entry;
  Color? _background; // a code block's: its matches' text drawn in ink
  final _inked = <RenderParagraph, _Inked>{};

  // Under an [InkedSelection]: its selected text drawn in ink too.
  _Seen? _seen;
  final _selInked = <RenderParagraph, _Inked>{};

  _Seen? get seen => _seen;
  set seen(_Seen? v) {
    if (identical(v, _seen)) return;
    if (attached) _seen?.removeListener(markNeedsPaint);
    _seen = v;
    if (attached) _seen?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color? get background => _background;
  set background(Color? v) {
    if (v == _background) return;
    _background = v;
    _forget();
    markNeedsPaint();
  }

  void _forget() {
    for (final i in [..._inked.values, ..._selInked.values]) {
      i.painter?.dispose();
    }
    _inked.clear();
    _selInked.clear();
  }

  String? _fold; // what's folded away here; null: not a fold
  ValueNotifier<int>? _count;
  (String, String)? _foldLowered;

  bool _stale = true; // a root's matches need finding
  List<TextMark> _all = const []; // a root's matches
  List<TextMark> _painted = const []; // the characters it paints under
  List<TextMark> _folded = const []; // those folded away here
  bool _had = false; // it painted some when a scan began

  (String, String) get _lowered =>
      _foldLowered ??= (_fold!, _fold!.toLowerCase());

  void update(
    TextMarks? scope,
    String? entry,
    String? fold,
    ValueNotifier<int>? count,
  ) {
    if (fold != _fold) {
      _fold = fold;
      _foldLowered = null;
      _touch();
    }
    if (scope != _scope || entry != _entry) {
      _drop();
      _forget(); // another scope may ink otherwise
      _scope = scope;
      _entry = entry;
      _join();
    }
    _count = count;
  }

  /// What's under it changed: the entry it's in is looked at again.
  void _touch() {
    final scope = _scope;
    if (scope == null || scope._query.isEmpty) return;
    if (_entry != null) {
      _stale = true;
      scope._later();
    } else {
      // A fold's text changes with no layout to tell its entry.
      for (var o = parent; o != null; o = o.parent) {
        if (o is _RenderMarks && o._entry != null) {
          o._touch();
          return;
        }
      }
    }
  }

  void _join() {
    final (scope, entry) = (_scope, _entry);
    if (scope == null || entry == null) return;
    _stale = true;
    scope._roots[entry] = this;
    if (scope._query.isNotEmpty) scope._later();
  }

  void _drop() {
    final (scope, entry) = (_scope, _entry);
    if (scope == null || entry == null) return;
    if (identical(scope._roots[entry], this)) scope._roots.remove(entry);
    if (scope._query.isNotEmpty) scope._later();
  }

  // A scan keeps the inked painters: one is made again only when its
  // paragraph's text, constraints, matches or fills change (`_inkedOf`), so
  // a code block stays as laid out while the agent streams after it. Those
  // of a paragraph it no longer paints marks in go at the scan's end.
  void _begin() {
    _had = _painted.isNotEmpty || _folded.isNotEmpty;
    _painted = [];
    _folded = [];
  }

  void _end() {
    if (_inked.isNotEmpty) {
      final still = {
        for (final m in _painted)
          for (final p in m._parts) p.paragraph,
      };
      _inked.removeWhere((p, i) {
        if (still.contains(p)) return false;
        i.painter?.dispose();
        return true;
      });
    }
    _count?.value = _folded.length;
    if (_had || _painted.isNotEmpty || _folded.isNotEmpty) markNeedsPaint();
  }

  void _clear() {
    _forget();
    _painted = const [];
    _folded = const [];
    _count?.value = 0;
    if (attached) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _seen?.addListener(markNeedsPaint);
    _join();
  }

  @override
  void detach() {
    _seen?.removeListener(markNeedsPaint);
    _drop();
    _forget();
    super.detach();
  }

  @override
  void dispose() {
    _forget();
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (_entry != null) _touch();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final scope = _scope;
    if (scope != null && (_painted.isNotEmpty || _folded.isNotEmpty)) {
      final canvas = context.canvas;
      final now = Paint()..color = scope._now;
      final hit = Paint()..color = scope._hit;
      final edge = Paint()
        ..color = scope._edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final current = scope._current;
      if (_folded.isNotEmpty) {
        final row = offset & size;
        final isNow = _folded.any((m) => identical(m, current));
        canvas.drawRect(row, isNow ? now : hit);
        if (isNow) canvas.drawRect(row.deflate(0.5), edge);
      }
      for (final m in _painted) {
        if (!m._here) continue;
        final isNow = identical(m, current);
        for (final box in m._boxes) {
          // A found word's box, a line of text high: its corners stay
          // small whatever the app's (which this package can't see).
          final r = RRect.fromRectAndRadius(
            box.shift(offset).inflate(1),
            const Radius.circular(3),
          );
          canvas.drawRRect(r, isNow ? now : hit);
          if (isNow) canvas.drawRRect(r, edge);
        }
      }
    }
    super.paint(context, offset);
    final selected = _selectedPath(offset);
    _ink(context, offset, selected: selected);
    if (selected != null) _inkSelected(context, offset, selected);
  }
}
