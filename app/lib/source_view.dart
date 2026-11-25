import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/blame.dart';
import 'package:nushi/blame_gutter.dart';
import 'package:nushi/change_marks.dart';
import 'package:nushi/indent_guides.dart';
import 'package:nushi/line_changes.dart';
import 'package:nushi/menu.dart' show MenuEntry;
import 'package:nushi/preview_find.dart';
import 'package:nushi/preview_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_menu.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/whitespace_marks.dart';

part 'source_view_find.dart';
part 'source_view_lines.dart';

/// A line shows this many characters at most (a minified file's one line).
const _maxLine = 5000;

/// An empty line's text: a zero-width space, left out of what's copied.
const _blank = '\u200B';

/// A file's text, highlighted for its language (by [path]'s name, as diffs
/// are, or a script's `#!` line: [sourceLanguage]; off the UI thread, plain
/// until then and past 200,000 characters), its lines numbered and built as
/// they scroll into view. JSON is pretty-printed. With [wrap] off a long
/// line runs on and the view scrolls sideways, the line numbers staying
/// put; a switch keeps the top line. With a [base], the last commit's
/// text, the lines that differ from it have change marks in the gutter
/// (ADR 0131); pretty-printed JSON's lines aren't the file's, so it has
/// none. With [menu] (the Files pane's) a right-click opens its menu
/// ([SourceMenu]). Under a [FindSlot] (the Files pane's) ⌘F finds in its
/// lines, all of them, not only those laid out. With [blame] (its Blame
/// on, issue #78) a gutter left of the numbers says who last changed each
/// run of lines and when.
class SourceView extends StatefulWidget {
  const new(
    this.text, {
    required this.path,
    super.key,
    this.padding,
    this.wrap = true,
    this.tabSize = defaultTabSize,
    this.guides = false,
    this.pastEnd = false,
    this.base,
    this.menu,
    this.blame,
  });

  final String text;
  final String path;
  final EdgeInsets? padding;
  final bool wrap;

  /// The columns between tab stops.
  final int tabSize;

  /// Whether its indent guides are drawn (the Mac's Files pane's Indent
  /// guides).
  final bool guides;

  /// Whether it scrolls on past its last line, to the top (the Mac's Files
  /// pane's Scroll past end).
  final bool pastEnd;

  /// The last commit's text, its lines marked against; null marks none.
  final String? base;

  /// What its right-click menu does; null: it has none.
  final SourceActions? menu;

  /// Its Blame, while on; null: no gutter.
  final BlameShown? blame;

  @override
  State<SourceView> createState() => _SourceViewState();
}

class _SourceViewState extends State<SourceView> with FindInSlot<SourceView> {
  String _text = '';

  /// The find's matches in the lines (`source_view_find.dart`), for the
  /// lowered query [_looked]; each line's, by its index; the last ask for
  /// the current one that was brought into view; whether the text starts
  /// below the bar, for a match at its very top; the line numbers' width
  /// when unwrapped, which stays over the lines.
  List<_Hit> _hits = const [];
  Map<int, List<int>> _hitsByLine = const {};
  String _looked = '';
  int _shownAsk = -1;
  bool _roomAbove = false;
  double _numbers = 0;

  @override
  void findChanged() {
    final f = find!;
    final q = (f.query ?? '').toLowerCase();
    if (f.query == null) _roomAbove = false;
    if (q != _looked) _look(q);
    setState(() {}); // the lines' marks
    _showCurrent();
  }

  void _setRoomAbove() => setState(() => _roomAbove = true);
  List<String> _lines = const [];
  List<Uint32List?>? _spans;
  int _reads = 0; // a highlight lands only for the latest read
  int? _columns; // the widest line's, worked out when first unwrapped
  Indents? _indents; // each line's indent, worked out when guides show
  List<MarkCell?> _cells = const []; // each line's change mark
  int _markings = 0; // marks land only for the latest base and text
  List<BlameCell> _blamed = const []; // each line's blame
  int _blamings = 0; // blame lands only for the latest answer and text

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

  /// What a list's selection holds, a right-click menu's place.
  final GlobalKey _content = GlobalKey();

  /// Each list's selection area: a key of their own, as one shared would
  /// move a selection area, its selection and all, into the other list.
  final GlobalKey<SelectionAreaState> _areaWrapped = GlobalKey();
  final GlobalKey<SelectionAreaState> _areaRunOn = GlobalKey();

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(SourceView old) {
    super.didUpdateWidget(old);
    // The file changed: read again where it scrolled to.
    if (old.text != widget.text || old.path != widget.path) {
      _read();
    } else {
      if (old.base != widget.base) _mark();
      if (!identical(old.blame?.blamed, widget.blame?.blamed)) _blame();
    }
    if (old.wrap != widget.wrap) _keepTopLine();
    if (old.tabSize != widget.tabSize) _columns = _indents = null;
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
    _unselect();
    final text = widget.text;
    final read = ++_reads;
    _text = widget.path.toLowerCase().endsWith('.json')
        ? prettyJson(text)
        : text;
    _lines = _text.split('\n');
    if (_lines.length > 1 && _lines.last.isEmpty) _lines.removeLast();
    _spans = null;
    _columns = null;
    _indents = null;
    _mark();
    _blame();
    // The find looks in the new text, once this build is done.
    if (find?.query != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _look(_looked);
      });
    }
    if (sourceLanguage(widget.path, _text) case final language?) {
      highlightSides(language, '', _text).then((s) {
        if (mounted && read == _reads && s[1] != null) {
          _unselect();
          setState(() => _spans = s[1]);
        }
      }).ignore();
    }
  }

  /// Clears the selection before the lines' text changes under it (a new
  /// read, the highlighting landing): a line's text laid out anew drops
  /// its own selection, but the containers above it keep pointing at it,
  /// and asking them for it then throws in Flutter's selection code
  /// (issue 100). It would be gone from sight anyway.
  void _unselect() {
    for (final area in [_areaWrapped, _areaRunOn]) {
      area.currentState?.selectableRegion.clearSelection();
    }
  }

  /// Its lines' change marks against [SourceView.base]: none without one,
  /// or when the lines shown aren't the file's own (JSON pretty-printed;
  /// already formatted, it shows as it is, but for its last line break).
  void _mark() {
    final marked = ++_markings;
    final base = widget.base;
    final own = _text.trimRight() == widget.text.trimRight();
    if (base == null || !own) {
      _cells = const [];
      return;
    }
    List<MarkCell?> cells(List<LineMark> marks) =>
        marks.isEmpty ? const [] : markCells(marks, _lines.length);
    // At once while the view builds anyway; a long file's when it's done,
    // the last ones showing meanwhile.
    switch (lineMarksSoon(base, _text)) {
      case final List<LineMark> marks:
        _cells = cells(marks);
      case final Future<List<LineMark>> later:
        later.then((marks) {
          if (mounted && marked == _markings) {
            setState(() => _cells = cells(marks));
          }
        }).ignore();
    }
  }

  /// Its lines' blame ([SourceView.blame]): none when its lines aren't
  /// the file's own (JSON pretty-printed), as for the marks.
  void _blame() {
    final blamings = ++_blamings;
    final blamed = widget.blame?.blamed;
    if (blamed == null || _text.trimRight() != widget.text.trimRight()) {
      _blamed = const [];
      return;
    }
    switch (blameCells(blamed, _text)) {
      case final List<BlameCell> cells:
        _blamed = cells;
      case final Future<List<BlameCell>> later:
        later.then((cells) {
          if (mounted && blamings == _blamings) {
            setState(() => _blamed = cells);
          }
        }).ignore();
    }
  }

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

  @override
  Widget build(BuildContext context) =>
      FindFrame(find: find, child: _view(context));

  Widget _view(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final colors = findColors(t);
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
            tabSize: widget.tabSize,
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
    // Indent guides, a level's columns apart (the file's own, [indents]).
    final counted = widget.guides
        ? (_indents ??= indents(_lines, widget.tabSize))
        : null;
    final step = (counted?.unit ?? widget.tabSize) * char;
    int level(int i) => counted?.levels[i] ?? 0;
    // Scrolled past the end, the last line can come to the top.
    EdgeInsets padded(double viewport) {
      final pad = _pad;
      if (!widget.pastEnd) return pad;
      return pad.copyWith(
        bottom: pastEndPadding(
          viewport,
          _lineHeight,
          top: pad.top,
          bottom: pad.bottom,
        ),
      );
    }

    // The Blame gutter, left of the numbers, while on; its width set by
    // the pane's.
    final scaler = MediaQuery.textScalerOf(context);
    BlameLook? lookIn(double pane) => widget.blame == null
        ? null
        : BlameLook(context, pane: pane, scaler: scaler);
    if (widget.wrap) {
      Widget blamed(int i, Widget line, {required BlameLook? look}) =>
          look == null
          ? line
          : Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: look.width + blameGap),
                  child: line,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: look.width,
                  child: _blameCell(i, look),
                ),
              ],
            );
      return _selectable(
        _wholeWrapped,
        LayoutBuilder(
          builder: (context, box) {
            final look = lookIn(box.maxWidth);
            return ListView.builder(
              key: _wrapped,
              controller: _down,
              padding: padded(box.maxHeight),
              itemCount: _lines.length,
              itemBuilder: (context, i) => blamed(
                look: look,
                i,
                _marked(
                  i,
                  cell: digits * char + markGap + markBar + markRoom,
                  bar: digits * char + markGap,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectionContainer.disabled(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: markGap + markBar + markRoom,
                          ),
                          child: Text(number(i), style: gutter),
                        ),
                      ),
                      Expanded(
                        child: _Line(
                          LineHits(
                            hits: _lineHits(i),
                            colors: colors,
                            child: Text.rich(
                              text(i),
                              strutStyle: strut,
                              selectionColor: Colors.transparent,
                            ),
                          ),
                          whole: _lines[i],
                          column: char,
                          level: level(i),
                          step: step,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    final pad = _pad;
    return LayoutBuilder(
      builder: (context, box) {
        final look = lookIn(box.maxWidth);
        final blameWidth = look == null ? 0.0 : look.width + blameGap;
        // The numbers' column, the view's inset with them: it stays as
        // the lines scroll under it, over them in the view's color.
        final numbers = _numbers =
            pad.left +
            blameWidth +
            digits * char +
            markGap +
            markBar +
            markRoom +
            1;
        final width = numbers + _widest * char + pad.right;
        return MacScrollbar(
          controller: _down,
          notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
          child: MacScrollbar(
            controller: _across,
            notificationPredicate: (n) =>
                n.depth == 0 && n.metrics.axis == Axis.horizontal,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: _selectable(
                _wholeRunOn,
                SingleChildScrollView(
                  controller: _across,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: max(box.maxWidth, width),
                    child: ListView.builder(
                      key: _runOn,
                      controller: _down,
                      padding: EdgeInsets.only(
                        top: pad.top,
                        bottom: padded(box.maxHeight).bottom,
                      ),
                      itemExtent: _lineHeight,
                      itemCount: _lines.length,
                      itemBuilder: (context, i) => Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: numbers),
                            child: _Line(
                              LineHits(
                                hits: _lineHits(i),
                                colors: colors,
                                child: Text.rich(
                                  text(i),
                                  softWrap: false,
                                  strutStyle: strut,
                                  selectionColor: Colors.transparent,
                                ),
                              ),
                              whole: _lines[i],
                              column: char,
                              level: level(i),
                              step: step,
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
                                  child: look == null
                                      ? _marked(
                                          i,
                                          cell: numbers,
                                          bar:
                                              pad.left +
                                              digits * char +
                                              markGap,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: pad.left,
                                            ),
                                            child: Text(
                                              number(i),
                                              style: gutter,
                                              softWrap: false,
                                            ),
                                          ),
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            SizedBox(width: pad.left),
                                            SizedBox(
                                              width: look.width,
                                              child: _blameCell(i, look),
                                            ),
                                            const SizedBox(width: blameGap),
                                            Expanded(
                                              child: _marked(
                                                i,
                                                cell:
                                                    numbers -
                                                    pad.left -
                                                    blameWidth,
                                                bar: digits * char + markGap,
                                                child: Text(
                                                  number(i),
                                                  style: gutter,
                                                  softWrap: false,
                                                ),
                                              ),
                                            ),
                                          ],
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
        );
      },
    );
  }
}
