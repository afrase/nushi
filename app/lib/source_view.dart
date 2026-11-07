import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/preview_text.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';

/// A line shows this many characters at most (a minified file's one line).
const _maxLine = 5000;

/// An empty line's text: a zero-width space, left out of what's copied.
const _blank = '\u200B';

/// A file's text, highlighted for its language (by [path]'s name, as diffs
/// are, or a script's `#!` line: [sourceLanguage]; off the UI thread, plain
/// until then and past 200,000 characters), its lines numbered and built as
/// they scroll into view. JSON is pretty-printed. With [wrap] off a long
/// line runs on and the view scrolls sideways, the line numbers staying
/// put; a switch keeps the top line.
class SourceView extends StatefulWidget {
  const new(
    this.text, {
    required this.path,
    super.key,
    this.padding,
    this.wrap = true,
  });

  final String text;
  final String path;
  final EdgeInsets? padding;
  final bool wrap;

  @override
  State<SourceView> createState() => _SourceViewState();
}

class _SourceViewState extends State<SourceView> {
  String _text = '';
  List<String> _lines = const [];
  List<Uint32List?>? _spans;
  int _reads = 0; // a highlight lands only for the latest read
  int? _columns; // the widest line's, worked out when first unwrapped

  /// Each wrapping's list, to find the line at its top (a key of their
  /// own: one shared would carry the scroll offset across); and its
  /// scrolling, made again with each switch (one list's at a time).
  final GlobalKey _wrapped = GlobalKey();
  final GlobalKey _runOn = GlobalKey();
  ScrollController _down = ScrollController();
  final _across = ScrollController();

  /// Each list's selection, which copies the whole text after Select All.
  late final _wholeWrapped = _Whole(() => _text);
  late final _wholeRunOn = _Whole(() => _text);

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(SourceView old) {
    super.didUpdateWidget(old);
    // The file changed: read again where it scrolled to.
    if (old.text != widget.text || old.path != widget.path) _read();
    if (old.wrap != widget.wrap) _keepTopLine();
  }

  @override
  void dispose() {
    _down.dispose();
    _across.dispose();
    _wholeWrapped.dispose();
    _wholeRunOn.dispose();
    super.dispose();
  }

  void _read() {
    final text = widget.text;
    final read = ++_reads;
    _text = widget.path.toLowerCase().endsWith('.json')
        ? prettyJson(text)
        : text;
    _lines = _text.split('\n');
    if (_lines.length > 1 && _lines.last.isEmpty) _lines.removeLast();
    _spans = null;
    _columns = null;
    if (sourceLanguage(widget.path, _text) case final language?) {
      highlightSides(language, '', _text).then((s) {
        if (mounted && read == _reads && s[1] != null) {
          setState(() => _spans = s[1]);
        }
      }).ignore();
    }
  }

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

  double get _top => widget.padding?.top ?? 0;
  double _lineHeight = 0;

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
    final most = line.contains('\t') ? tabSize : 2;
    if (most * n + note <= widest) return widest;
    var w = 0;
    for (var i = 0; i < n; i++) {
      final c = line.codeUnitAt(i);
      w += c == 0x09
          ? tabColumns(w)
          : c >= 0x1100 && (c < 0xD800 || c > 0xDFFF)
          ? 2
          : 1;
    }
    return max(widest, w + note);
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = theme.code(t.text, size: 12);
    final gutter = theme.code(t.textMuted, size: 12);
    final digits = '${_lines.length}'.length;
    // Measured as a Text draws it, over the DefaultTextStyle: its letter
    // spacing widens each character, and the run-on width must hold them.
    final zero = TextPainter(
      text: TextSpan(
        text: '0',
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final char = zero.width;
    _lineHeight = zero.height;
    zero.dispose();
    // The letter spacing every character has, a tab's too; and the
    // strut that holds a line's height when a tab's font is larger.
    final drawn = DefaultTextStyle.of(context).style.merge(style);
    final spacing = drawn.letterSpacing ?? 0;
    final strut = StrutStyle.fromTextStyle(drawn, forceStrutHeight: true);
    TextSpan text(int i) {
      final whole = _lines[i];
      final cut = whole.length > _maxLine;
      final line = cut ? whole.substring(0, _maxLine) : whole;
      return TextSpan(
        style: style,
        children: [
          // An empty text can't be selected, so its break wouldn't copy.
          if (line.isEmpty) const TextSpan(text: _blank),
          ...tabStops(
            spansOf(t, line, _spans?.elementAtOrNull(i)),
            fontSize: style.fontSize!,
            column: char,
            spacing: spacing,
          ),
          if (cut)
            TextSpan(
              text: ' … (${whole.length - _maxLine} more)',
              style: gutter,
            ),
        ],
      );
    }

    String number(int i) => '${i + 1}'.padLeft(digits);
    if (widget.wrap) {
      return SelectionArea(
        child: SelectionContainer(
          delegate: _wholeWrapped,
          child: ListView.builder(
            key: _wrapped,
            controller: _down,
            padding: widget.padding,
            itemCount: _lines.length,
            itemBuilder: (context, i) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectionContainer.disabled(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(number(i), style: gutter),
                  ),
                ),
                Expanded(
                  child: _Line(
                    Text.rich(text(i), strutStyle: strut),
                    whole: _lines[i],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final pad = widget.padding ?? EdgeInsets.zero;
    // The numbers' column, the view's inset with them: it stays as the
    // lines scroll under it, over them in the view's color.
    final numbers = pad.left + digits * char + 14 + 1;
    final width = numbers + _widest * char + pad.right;
    return LayoutBuilder(
      builder: (context, box) => MacScrollbar(
        controller: _down,
        notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
        child: MacScrollbar(
          controller: _across,
          notificationPredicate: (n) =>
              n.depth == 0 && n.metrics.axis == Axis.horizontal,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: SelectionArea(
              child: SelectionContainer(
                delegate: _wholeRunOn,
                child: SingleChildScrollView(
                  controller: _across,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: max(box.maxWidth, width),
                    child: ListView.builder(
                      key: _runOn,
                      controller: _down,
                      padding: EdgeInsets.only(
                        top: pad.top,
                        bottom: pad.bottom,
                      ),
                      itemExtent: _lineHeight,
                      itemCount: _lines.length,
                      itemBuilder: (context, i) => Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: numbers),
                            child: _Line(
                              Text.rich(
                                text(i),
                                softWrap: false,
                                strutStyle: strut,
                              ),
                              whole: _lines[i],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: numbers,
                            child: SelectionContainer.disabled(
                              child: ListenableBuilder(
                                listenable: _across,
                                builder: (context, child) =>
                                    Transform.translate(
                                      offset: Offset(
                                        _across.hasClients ? _across.offset : 0,
                                        0,
                                      ),
                                      child: child,
                                    ),
                                child: ColoredBox(
                                  color: t.base,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: pad.left),
                                    child: Text(
                                      number(i),
                                      style: gutter,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  const new(this.text, {required this.whole});

  final Widget text;

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
    return SelectionContainer(delegate: _delegate, child: widget.text);
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
