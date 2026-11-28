part of 'source_view.dart';

// A source view's selection areas and its right-click menu: which line
// a press is on, and what the selection holds there.

extension on _SourceViewState {
  /// The line (from 0) at [at] on the screen, of those laid out: the one
  /// across it, else the nearest.
  int _lineAt(Offset at) {
    final s = _sliver(wrapped: widget.wrap);
    if (s == null) return 0;
    var last = 0;
    for (var c = s.firstChild; c != null; c = s.childAfter(c)) {
      last = s.indexOf(c);
      if (at.dy < c.localToGlobal(Offset.zero).dy + c.size.height) break;
    }
    return last;
  }

  /// The right-click menu's rows, for a press at [at].
  List<MenuEntry> _menuAt(Offset at, SourceActions menu) {
    final whole = widget.wrap ? _wholeWrapped : _wholeRunOn;
    // As copying it gives it.
    final selected = whole.getSelectedContent()?.plainText ?? '';
    final box = _content.currentContext?.findRenderObject() as RenderBox?;
    final local = whole.firstAt(_lineHeight);
    final top = local == null || box == null ? null : box.localToGlobal(local);
    final first = selected.isEmpty
        ? null
        : whole.all
        ? 1
        : top == null
        ? null
        : _lineAt(top) + 1;
    return menu.entries(
      context,
      selected: selected,
      first: first,
      clicked: _lineAt(at) + 1,
      onFind: find?.open,
    );
  }

  /// A list's selection area, its menu inside it when it has one, so its
  /// right-click is the menu's.
  Widget _selectable(_Whole whole, Widget child) => SelectionArea(
    key: identical(whole, _wholeWrapped) ? _areaWrapped : _areaRunOn,
    child: SelectionContainer(
      delegate: whole,
      child: switch (widget.menu) {
        // The selection's points are in its place, which [_content]'s is.
        final menu? => KeyedSubtree(
          key: _content,
          child: SourceMenu(entries: (at) => _menuAt(at, menu), child: child),
        ),
        null => child,
      },
    ),
  );
}
