part of 'text_marks.dart';

/// Gives the text under it to [registrar]'s selection, as a
/// [SelectionRegistrarScope] does, and lets a [Marks] below that names
/// its background see what of it is selected: that [Marks] draws the
/// selected text again, each run in the [TextMarks.ink] of its colour on
/// the selection's fill, as it does a find's matches (a code block's: a
/// theme's code colours were published for its background, and the
/// selection's tint can all but hide the dimmest). The text joins the
/// selection around it directly, with no container of its own, so
/// selecting across it is as it was.
class InkedSelection extends StatefulWidget {
  /// [child]'s text in [registrar]'s selection.
  const new({required this.registrar, required this.child, super.key});

  /// The selection the text joins.
  final SelectionRegistrar registrar;

  /// What holds the text, a [Marks] around it.
  final Widget child;

  @override
  State<InkedSelection> createState() => _InkedSelectionState();
}

class _InkedSelectionState extends State<InkedSelection> {
  late final _seen = _Seen(widget.registrar);

  @override
  void didUpdateWidget(InkedSelection old) {
    super.didUpdateWidget(old);
    _seen.target = widget.registrar;
  }

  @override
  void dispose() {
    _seen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionRegistrarScope(
    registrar: _seen,
    child: _SeenScope(seen: _seen, child: widget.child),
  );
}

class _SeenScope extends InheritedWidget {
  const new({required this.seen, required super.child});

  final _Seen seen;

  static _Seen? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SeenScope>()?.seen;

  @override
  bool updateShouldNotify(_SeenScope old) => seen != old.seen;
}

/// A selection's registrar, passed through: what's given to it goes to
/// [target], and is kept here to read its selection, told on each change.
final class _Seen extends ChangeNotifier implements SelectionRegistrar {
  new(this._target);

  SelectionRegistrar _target;
  final _selectables = <Selectable>{};
  bool _gone = false;

  /// Where what's given to it goes.
  SelectionRegistrar get target => _target;

  /// What's given to it is given to [t] instead, from now on.
  set target(SelectionRegistrar t) {
    if (identical(t, _target)) return;
    for (final s in _selectables) {
      _target.remove(s);
      t.add(s);
    }
    _target = t;
  }

  void _changed() {
    if (!_gone) notifyListeners();
  }

  @override
  void add(Selectable selectable) {
    if (_selectables.add(selectable)) selectable.addListener(_changed);
    _target.add(selectable);
  }

  @override
  void remove(Selectable selectable) {
    if (_selectables.remove(selectable)) {
      selectable.removeListener(_changed);
    }
    _target.remove(selectable);
  }

  @override
  void dispose() {
    _gone = true;
    for (final s in _selectables) {
      s.removeListener(_changed);
    }
    _selectables.clear();
    super.dispose();
  }
}

extension on _RenderMarks {
  /// The selection's boxes in what's seen, where this paints.
  Path? _selectedPath(Offset offset) {
    final seen = _seen;
    if (seen == null || _background == null || _scope?.ink == null) {
      return null;
    }
    Path? path;
    for (final s in seen._selectables) {
      final v = s.value;
      if (v.status != SelectionStatus.uncollapsed) continue;
      final to = s.getTransformTo(this);
      for (final r in v.selectionRects) {
        (path ??= Path()).addRect(
          MatrixUtils.transformRect(to, r).shift(offset),
        );
      }
    }
    return path;
  }

  /// Draws the text under [selected] again, each run in the ink of its
  /// colour on the fill there: the selection over the background, or over
  /// a match's tint (the paragraph paints its selection over the marks).
  /// Made once for a paragraph's text, matches and fills, so a drag only
  /// clips it anew.
  void _inkSelected(PaintingContext context, Offset offset, Path selected) {
    final scope = _scope!;
    final background = _background!;
    final ink = scope.ink!;
    final matches = _matchesByParagraph();
    final shown = <RenderParagraph>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) {
        shown.add(o);
      } else {
        o.visitChildren(visit);
      }
    }

    visitChildren(visit);
    _selInked.removeWhere((p, i) {
      if (shown.contains(p)) return false;
      i.painter?.dispose();
      return true;
    });
    final bounds = selected.getBounds();
    final canvas = context.canvas;
    for (final p in shown) {
      final tint = p.selectionColor;
      if (!p.hasSize || tint == null || tint.a == 0) continue;
      final at =
          offset +
          MatrixUtils.transformPoint(p.getTransformTo(this), Offset.zero);
      if (!bounds.overlaps(at & p.size)) continue;
      final plain = Color.alphaBlend(tint, background);
      final hit = Color.alphaBlend(
        tint,
        Color.alphaBlend(scope._hit, background),
      );
      final nowFill = Color.alphaBlend(
        tint,
        Color.alphaBlend(scope._now, background),
      );
      final inked = _inkedOf(
        _selInked,
        p,
        matches[p] ?? const [],
        (plain, hit, nowFill),
        (c, {required now}) => ink(c, now ? nowFill : hit, background),
        rest: (c) => ink(c, plain, background),
      );
      if (inked == null) continue;
      canvas
        ..save()
        ..clipPath(selected);
      inked.paint(canvas, at);
      canvas.restore();
    }
  }
}
