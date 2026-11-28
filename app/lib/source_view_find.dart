part of 'source_view.dart';

// ⌘F in a read-only source (issue 63): the file's lines are all there,
// though only those in sight are laid out, so matches are found in the
// text and counted whole, off the keystroke ([LineSearch]: a slice at a
// time, at most 10,000 kept, a step past them looking on for the next);
// each line in sight finds and paints its own ([LineHits]), and a step
// jumps near the line until it's laid out, then onto the match.

/// A match: its line (from 0) and its characters there.
typedef _Hit = ({int line, int start, int end});

extension on _SourceViewState {
  /// Looks for the (lowered) query in the lines anew, and tells the bar
  /// once the search ends; the current match stays if it's still one.
  void _look(String query) {
    _looked = query;
    final f = find as LaterFind?;
    if (f == null) return;
    if (query.isEmpty) {
      _search.cancel();
      _hits = PackedHits();
      f.took(const [], 0, more: false);
      return;
    }
    f.look();
    _search.start(
      _lines,
      query,
      cut: _maxLine,
      done: (hits, {required more}) {
        final was = _current();
        _hits = hits;
        final i = was == null ? -1 : hits.indexOf(was.line, was.start);
        f.took(hits.keys, i >= 0 ? i : f.order.start(hits.length), more: more);
      },
    );
  }

  /// Looks on past the matches kept, [way], for a step that went past
  /// them; the find takes what it finds and steps into it.
  void _beyond(Beyond way) {
    final f = find as LaterFind?;
    if (f == null) return;
    final kept = _hits;
    final last = kept.length - 1;
    switch (way) {
      case Beyond.after || Beyond.top:
        _search.start(
          _lines,
          _looked,
          cut: _maxLine,
          after: way == Beyond.after && last >= 0
              ? (line: kept.line(last), start: kept.start(last))
              : null,
          done: (hits, {required more}) {
            _hits = hits;
            final base = way == Beyond.after ? f.base + kept.length : 0;
            f.took(hits.keys, 0, more: more, base: base);
          },
        );
      case Beyond.before || Beyond.end:
        _search.back(
          _lines,
          _looked,
          cut: _maxLine,
          before: way == Beyond.before && last >= 0
              ? (line: kept.line(0), start: kept.start(0))
              : null,
          done: (hits, {required earlier}) {
            _hits = hits;
            f.took(
              hits.keys,
              hits.length - 1,
              more: way == Beyond.before,
              base: earlier,
            );
          },
        );
    }
  }

  /// The current match, if any.
  _Hit? _current() {
    final f = find;
    if (f == null || _hits.isEmpty) return null;
    final i = f.at.clamp(0, _hits.length - 1);
    return (line: _hits.line(i), start: _hits.start(i), end: _hits.end(i));
  }

  /// Line [i]'s matches as its [LineHits] paints them: found in the line
  /// itself, so a line in sight shows all its own, past the 10,000 kept
  /// and before the search ends.
  List<LineHit> _lineHits(int i) {
    final f = find;
    if (f == null || f.query == null || _looked.isEmpty) return const [];
    final whole = _lines[i];
    final line = whole.length > _maxLine ? whole.substring(0, _maxLine) : whole;
    final now = _current();
    return [
      for (final (start, end) in hitsIn(line, _looked))
        (
          start: start,
          end: end,
          now: now != null && now.line == i && now.start == start,
        ),
    ];
  }

  /// Brings the current match into view when it was asked for.
  void _showCurrent() {
    final f = find;
    if (f == null || f.query == null || f.asked == _shownAsk) return;
    // Its matches still coming: once they have.
    if (f is LaterFind && f.looking) return;
    _shownAsk = f.asked;
    if (_current() case final hit?) _revealHit(hit, 30, f.asked);
  }

  /// Takes the list to [hit]: once its line is laid out, onto the match
  /// ([revealFound]); until then, near where the line should be, from the
  /// lines laid out, and again after the frame, [tries] times at most;
  /// dropped once a later ask ([asked]) has its own on the way, so steps
  /// quicker than frames end on the last one's.
  void _revealHit(_Hit hit, int tries, int asked) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // closed meanwhile: its context is gone
        if (asked != _shownAsk) return;
        final s = _sliver(wrapped: widget.wrap);
        final view = context.findRenderObject();
        if (!mounted || !_down.hasClients || tries == 0) return;
        if (s == null || s.firstChild == null || view is! RenderBox) return;
        for (var c = s.firstChild; c != null; c = s.childAfter(c)) {
          if (s.indexOf(c) != hit.line) continue;
          final p = hitParagraphIn(c);
          if (p == null || !p.hasSize) return;
          final boxes = hitBoxes(p, hit.start, hit.end);
          final rect = boxes.isEmpty
              ? Offset.zero & p.size
              : boxes.reduce((a, b) => a.expandToInclude(b));
          // Clear of the line numbers, which stay over a run-on line.
          final r = revealFound(
            scroll: _down,
            box: p,
            rect: widget.wrap
                ? rect
                : Rect.fromLTRB(
                    rect.left - _numbers,
                    rect.top,
                    rect.right,
                    rect.bottom,
                  ),
            view: view,
            roomAbove: _roomAbove,
          );
          if (r == Revealed.needsRoom) {
            _setRoomAbove();
            _revealHit(hit, tries - 1, asked);
          }
          return;
        }
        // Not laid out: near it, by the lines that are.
        final first = s.firstChild!;
        final last = s.lastChild!;
        final from = s.childScrollOffset(first)!;
        final to = s.childScrollOffset(last)! + last.size.height;
        final count = s.indexOf(last) - s.indexOf(first) + 1;
        final each = (to - from) / count;
        final p = _down.position;
        p.jumpTo(
          (_top + hit.line * each - p.viewportDimension * 0.3).clamp(
            p.minScrollExtent,
            p.maxScrollExtent,
          ),
        );
        _revealHit(hit, tries - 1, asked);
      });
}
