import 'dart:async';
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
import 'package:nushi/line_search.dart';
import 'package:nushi/menu.dart' show MenuEntry;
import 'package:nushi/preview_find.dart';
import 'package:nushi/preview_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_menu.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/whitespace_marks.dart';

part 'source_view_find.dart';
part 'source_view_lines.dart';
part 'source_view_marks.dart';
part 'source_view_menu.dart';
part 'source_view_scroll.dart';
part 'source_view_text.dart';
part 'source_view_views.dart';

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
  /// lowered query [_looked], and the search that finds them; the last ask
  /// for the current one that was brought into view; whether the text
  /// starts below the bar, for a match at its very top; the line numbers'
  /// width when unwrapped, which stays over the lines.
  PackedHits _hits = PackedHits();
  final _search = LineSearch();
  String _looked = '';
  int _shownAsk = -1;
  bool _roomAbove = false;
  double _numbers = 0;

  @override
  LaterFind makeFind() => LaterFind()..onBeyond = _beyond;

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
  double _lineHeight = 0; // a line's, as last built
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
    // A search still going would tell the find, disposed below.
    _search.cancel();
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
    // The find looks in the new text once this build is done. A search in
    // the old one needs no cancel: no slice of it can run before the frame
    // ends, and the look then drops it.
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

  @override
  Widget build(BuildContext context) =>
      FindFrame(find: find, child: _view(context));

  Widget _view(BuildContext context) {
    final d = _Drawn(this, context);
    return widget.wrap ? _wrappedView(d) : _runOnView(d);
  }
}
