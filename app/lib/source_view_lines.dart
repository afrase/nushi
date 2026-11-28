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

  /// Whether the whole text is selected (Select All).
  bool get all => _all;

  /// Where the selection starts, in the list's own place: the top of its
  /// edges' lower one's line, which [lineHeight] high; null with nothing
  /// selected.
  Offset? firstAt(double lineHeight) {
    final v = value;
    final a = v.startSelectionPoint?.localPosition;
    final b = v.endSelectionPoint?.localPosition;
    if (!v.hasSelection || a == null || b == null) return null;
    final first = a.dy <= b.dy ? a : b;
    return first.translate(0, -lineHeight / 2);
  }

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
  const new(
    this.text, {
    required this.whole,
    required this.column,
    this.level = 0,
    this.step = 0,
    this.overSelection,
  });

  final Widget text;

  /// The line's text as it's drawn again over its selection, so code keeps
  /// its contrast there (issue 117); null when nothing would change.
  final TextSpan? Function()? overSelection;

  /// A column's width, for its whitespace's marks (Show whitespace).
  final double column;

  /// Its indent guides: how many, [step] apart (Indent guides; none off).
  final int level;
  final double step;

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
        overSelection: widget.overSelection,
        color:
            DefaultSelectionStyle.of(context).selectionColor ??
            DefaultSelectionStyle.defaultColor,
        child: IndentGuides(
          level: widget.level,
          step: widget.step,
          color: whitespaceColor(t),
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
      ),
    );
  }
}

/// A line's selection, painted under its text a line high. Its text draws
/// none of its own (`Text.rich`'s `selectionColor` is clear): a paragraph
/// paints a selection with tight boxes, which take a run's own height, and
/// a tab's run is set larger to reach its stop ([tabStops]), so its box
/// would reach into the lines above and below.
///
/// Its code is drawn again over the selection, clipped to it, from
/// [overSelection]: a dim token keeps its contrast on the selection's fill
/// (issue 117). That text is laid out once for the line as drawn (the
/// same text keeps its paragraph's span) and kept, so a drag only clips
/// it anew.
class _LineSelection extends SingleChildRenderObjectWidget {
  const new({
    required this.selection,
    required this.color,
    this.overSelection,
    super.child,
  });

  final _LineEnd selection;
  final Color color;
  final TextSpan? Function()? overSelection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLineSelection(selection, color)..overSelection = overSelection;

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderLineSelection)
        ..selection = selection
        ..color = color
        ..overSelection = overSelection;
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
    _forget();
    super.detach();
  }

  @override
  void dispose() {
    _forget();
    super.dispose();
  }

  // A build of the line brings a new one (its hits may have changed with
  // its text as drawn the same): what was laid out from the last goes. A
  // drag only repaints, so it keeps it.
  TextSpan? Function()? _overSelection;
  TextSpan? Function()? get overSelection => _overSelection;
  set overSelection(TextSpan? Function()? v) {
    if (identical(v, _overSelection)) return;
    _overSelection = v;
    _forget();
    markNeedsPaint();
  }

  // The line drawn again over its selection, for the paragraph's text and
  // width it was laid out for; null painter: nothing to draw again.
  (InlineSpan, BoxConstraints, TextPainter?)? _over;

  void _forget() {
    _over?.$3?.dispose();
    _over = null;
  }

  TextPainter? _overFor(RenderParagraph p) {
    if (_over case (final text, final c, final painter)
        when identical(text, p.text) && c == p.constraints) {
      return painter;
    }
    _forget();
    final line = overSelection?.call();
    final root = p.text;
    final painter = line == null || root is! TextSpan
        ? null
        : (TextPainter(
            // As Text.rich wraps it: its style over the line's.
            text: TextSpan(style: root.style, children: [line]),
            textAlign: p.textAlign,
            textDirection: p.textDirection,
            textScaler: p.textScaler,
            maxLines: p.maxLines,
            locale: p.locale,
            strutStyle: p.strutStyle,
            textWidthBasis: p.textWidthBasis,
            textHeightBehavior: p.textHeightBehavior,
          )..layout(
            minWidth: p.constraints.minWidth,
            maxWidth: p.softWrap ? p.constraints.maxWidth : double.infinity,
          ));
    _over = (p.text, p.constraints, painter);
    return painter;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final range = _selection.range;
    final p = paragraphIn(child);
    final boxes = <Rect>[];
    var at = offset;
    if (range != null &&
        range.startOffset != range.endOffset &&
        p != null &&
        p.hasSize) {
      at =
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
        final r = box.toRect().shift(at);
        boxes.add(r);
        context.canvas.drawRect(r, paint);
      }
    }
    super.paint(context, offset);
    if (boxes.isEmpty || p == null) return;
    final over = _overFor(p);
    if (over == null) return;
    final clip = Path();
    boxes.forEach(clip.addRect);
    final canvas = context.canvas
      ..save()
      ..clipPath(clip);
    over.paint(canvas, at);
    canvas.restore();
  }
}

class _LineEnd extends StaticSelectionContainerDelegate {
  String whole = '';

  bool _disposed = false;

  /// Whether a moment with no selection was kept from the list.
  bool _held = false;

  // A line whose hits change is split into runs anew (issue 117), so its
  // text's selectable is made again, and its container gives it the
  // selection back by replaying the last edges: the end first, then the
  // start. Between the two the line has no selection, and the list, told
  // so, moves its selection's start past it for good: a shift-click or a
  // shift and an arrow then extends from a later line. While this line
  // still holds its selection (its indices set), that moment isn't told;
  // the next change is, and one left with no selection is told after.
  @override
  void notifyListeners() {
    final passing =
        value.status == SelectionStatus.none &&
        currentSelectionStartIndex >= 0 &&
        currentSelectionEndIndex >= 0;
    if (!passing) {
      _held = false;
      super.notifyListeners();
      return;
    }
    if (_held) return;
    _held = true;
    scheduleMicrotask(() {
      if (_disposed || !_held) return;
      _held = false;
      super.notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The line's selection, or null, for painting it: a line whose spans
  /// were split anew (a find's hits changed) has a new selectable with no
  /// selection while the delegate still points at the old one's edges,
  /// and [getSelection] throws there.
  SelectedContentRange? get range {
    final (a, b) = (currentSelectionStartIndex, currentSelectionEndIndex);
    if (a < 0 || b < 0 || a >= selectables.length || b >= selectables.length) {
      return null;
    }
    if (selectables[a].getSelection() == null) return null;
    return getSelection();
  }

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
