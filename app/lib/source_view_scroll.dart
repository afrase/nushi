part of 'source_view.dart';

// Where a source view's lists stand: the line at their top, kept when
// the wrapping switches; a line brought into view once laid out; the
// room the lines take run on.

extension on _SourceViewState {
  /// The laid-out lines of the list [wrapped] or not, while it shows.
  RenderSliverMultiBoxAdaptor? _sliver({required bool wrapped}) {
    RenderSliverMultiBoxAdaptor? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderSliverMultiBoxAdaptor) {
        found = o;
      } else {
        o.visitChildren(visit);
      }
    }

    final list = wrapped ? _wrapped : _runOn;
    if (list.currentContext?.findRenderObject() case final root?) {
      visit(root);
    }
    return found;
  }

  /// The line at the top of the list [wrapped] or not: the one across its
  /// top edge, or the next when less than half of it shows.
  int _topLine({required bool wrapped}) {
    final s = _sliver(wrapped: wrapped);
    if (s == null || s.firstChild == null) return 0;
    final top = s.constraints.scrollOffset;
    for (var c = s.firstChild; c != null; c = s.childAfter(c)) {
      final bottom = s.childScrollOffset(c)! + c.size.height;
      if (bottom > top) {
        final next =
            bottom - top < c.size.height / 2 && s.childAfter(c) != null;
        return s.indexOf(c) + (next ? 1 : 0);
      }
    }
    return 0;
  }

  /// A new list for the other wrapping, scrolled to the line on top now:
  /// unwrapped, each line is one high, so it starts there; wrapped, from
  /// there as a guess, then onto the line once it's laid out.
  void _keepTopLine() {
    final line = _topLine(wrapped: !widget.wrap);
    final old = _down;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _down = ScrollController(
      initialScrollOffset: line == 0 ? 0 : _top + line * _lineHeight,
    );
    if (widget.wrap && line > 0) _showLine(line, 30);
  }

  double get _top => _pad.top;

  /// The view's padding, with room above the text for the find bar while
  /// a match at the very top needs it.
  EdgeInsets get _pad {
    final pad = widget.padding ?? EdgeInsets.zero;
    return _roomAbove ? pad.copyWith(top: pad.top + FindBar.height) : pad;
  }

  void _showLine(int line, int tries) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final s = _sliver(wrapped: true);
        if (!mounted || !_down.hasClients || s == null || tries == 0) return;
        final p = _down.position;
        for (var c = s.firstChild; c != null; c = s.childAfter(c)) {
          if (s.indexOf(c) == line) {
            return p.jumpTo(
              min(_top + s.childScrollOffset(c)!, p.maxScrollExtent),
            );
          }
        }
        // Not laid out: the lines above wrap, so it's further on.
        final first = s.firstChild == null ? 0 : s.indexOf(s.firstChild!);
        p.jumpTo(p.pixels + (first > line ? -1 : 1) * p.viewportDimension);
        _showLine(line, tries - 1);
      });

  /// The widest line's room in columns, as near as cheaply known: a wide
  /// character (CJK, an emoji's halves) counts as two, a tab to its stop,
  /// a cut line its note.
  int get _widest => _columns ??= _lines.fold<int>(0, (widest, line) {
    final n = min(line.length, _maxLine);
    final note = line.length > _maxLine ? 24 : 0;
    final most = line.contains('\t') ? widget.tabSize : 2;
    if (most * n + note <= widest) return widest;
    var w = 0;
    for (var i = 0; i < n; i++) {
      final c = line.codeUnitAt(i);
      w += c == 0x09
          ? tabColumns(w, widget.tabSize)
          : c >= 0x1100 && (c < 0xD800 || c > 0xDFFF)
          ? 2
          : 1;
    }
    return max(widest, w + note);
  });
}
