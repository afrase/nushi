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
      child: _LineSelection(
        selection: _delegate,
        color:
            DefaultSelectionStyle.of(context).selectionColor ??
            DefaultSelectionStyle.defaultColor,
        child: ValueListenableBuilder(
          valueListenable: showWhitespace,
          builder: (context, show, text) => WhitespaceMarks(
            line: whole.length > _maxLine
                ? whole.substring(0, _maxLine)
                : whole,
            show: show,
            color: whitespaceColor(t),
            column: widget.column,
            child: text,
          ),
          child: widget.text,
        ),
      ),
    );
  }
}

/// A line's selection, painted under its text a line high. Its text draws
/// none of its own (`Text.rich`'s `selectionColor` is clear): a paragraph
/// paints a selection with tight boxes, which take a run's own height, and
/// a tab's run is set larger to reach its stop ([tabStops]), so its box
/// would reach into the lines above and below.
class _LineSelection extends SingleChildRenderObjectWidget {
  const new({required this.selection, required this.color, super.child});

  final _LineEnd selection;
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLineSelection(selection, color);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderLineSelection)
        ..selection = selection
        ..color = color;
}

class _RenderLineSelection extends RenderProxyBox {
  new(this._selection, this._color);

  _LineEnd _selection;
  _LineEnd get selection => _selection;
  set selection(_LineEnd v) {
    if (identical(v, _selection)) return;
    if (attached) _selection.removeListener(markNeedsPaint);
    _selection = v;
    if (attached) _selection.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _color;
  Color get color => _color;
  set color(Color v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _selection.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _selection.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final range = _selection.getSelection();
    final p = paragraphIn(child);
    if (range != null &&
        range.startOffset != range.endOffset &&
        p != null &&
        p.hasSize) {
      final at =
          offset +
          MatrixUtils.transformPoint(p.getTransformTo(this), Offset.zero);
      final paint = Paint()..color = _color;
      for (final box in p.getBoxesForSelection(
        TextSelection(
          baseOffset: min(range.startOffset, range.endOffset),
          extentOffset: max(range.startOffset, range.endOffset),
        ),
        boxHeightStyle: BoxHeightStyle.max,
      )) {
        context.canvas.drawRect(box.toRect().shift(at), paint);
      }
    }
    super.paint(context, offset);
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
