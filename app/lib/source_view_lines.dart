part of 'source_view.dart';

// What a source view's lines copy: the whole file after Select All, and
// each line with its line break; and each line's whitespace marks.

/// A list's selection that copies the whole text after Select All: the
/// list builds only the lines in sight, and only those would copy.
class _Whole extends StaticSelectionContainerDelegate {
  new(this.text);

  final String Function() text;

  /// Whether the last selection was Select All, not since changed.
  bool _all = false;

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    _all = event.type == SelectionEventType.selectAll;
    return super.dispatchSelectionEvent(event);
  }

  @override
  SelectedContent? getSelectedContent() =>
      _all ? SelectedContent(plainText: text()) : super.getSelectedContent();
}

/// A line's text, copied with its line break when it's selected to its
/// end: each line is a text of its own, and a selection across them
/// otherwise runs them together.
class _Line extends StatefulWidget {
  const new(this.text, {required this.whole, required this.column});

  final Widget text;

  /// A column's width, for its whitespace's marks (Show whitespace).
  final double column;

  /// The line as the file has it: a line cut at [_maxLine] copies its
  /// own text to its end, not the note that stands for the rest.
  final String whole;

  @override
  State<_Line> createState() => _LineState();
}

class _LineState extends State<_Line> {
  final _delegate = _LineEnd();

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _delegate.whole = widget.whole;
    final whole = widget.whole;
    final t = NushiTheme.of(context).t;
    return SelectionContainer(
      delegate: _delegate,
      child: ValueListenableBuilder(
        valueListenable: showWhitespace,
        builder: (context, show, text) => WhitespaceMarks(
          line: whole.length > _maxLine ? whole.substring(0, _maxLine) : whole,
          show: show,
          color: whitespaceColor(t),
          column: widget.column,
          child: text,
        ),
        child: widget.text,
      ),
    );
  }
}

class _LineEnd extends StaticSelectionContainerDelegate {
  String whole = '';

  @override
  SelectedContent? getSelectedContent() {
    final content = super.getSelectedContent();
    final range = getSelection();
    if (range == null) return content;
    final start = min(range.startOffset, range.endOffset);
    final end = max(range.startOffset, range.endOffset);
    // Into a cut line's note: the line's own text from the start on.
    final note = whole.length > _maxLine && end > _maxLine;
    if (end < contentLength && !note) return content;
    final text = note
        ? whole.substring(min(start, _maxLine))
        : content?.plainText.replaceAll(_blank, '') ?? '';
    return SelectedContent(plainText: end < contentLength ? text : '$text\n');
  }
}
