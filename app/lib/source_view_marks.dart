part of 'source_view.dart';

// What a source view draws beside a line's text: its Blame cell and its
// change mark.

extension on _SourceViewState {
  /// Line [i]'s Blame cell, [look]'s width.
  Widget _blameCell(int i, BlameLook look) => SelectionContainer.disabled(
    child: BlameCellView(
      cell: _blamed.elementAtOrNull(i),
      look: look,
      line: _lineHeight,
      divider: i > 0,
      onOpen: widget.blame!.onOpen,
    ),
  );

  /// Line [i]'s [child] with its change mark over its first [cell]
  /// points, its bar [bar] in, when it has one.
  Widget _marked(
    int i, {
    required double cell,
    required double bar,
    required Widget child,
  }) {
    final mark = _cells.elementAtOrNull(i);
    if (mark == null) return child;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: cell,
          child: ChangeMark(cell: mark, barX: bar),
        ),
      ],
    );
  }
}
