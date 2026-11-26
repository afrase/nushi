import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:nushi/editor_ink.dart';
import 'package:nushi/editor_sight.dart';
import 'package:nushi/line_search.dart' show LazyKeys;
import 'package:nushi/transcript_find.dart';
import 'package:nushi/whitespace_marks.dart' show EditorLines;
import 'package:re_editor/re_editor.dart';

/// ⌘F in the preview's editor (ADR 0096), in the [FindBar] the transcript
/// has: re_editor's own find matches (case aside, off the UI thread) and
/// tints every match; this tells the bar its count and steps through them.
/// The current match is the editor's selection, starting from the caret,
/// so it stays selected when the bar closes and the editor takes the focus
/// back. Only the bar's field takes the keys while it's open: nothing typed
/// there reaches the file. Of the matches, the editor paints only those in
/// sight ([sight]), however many there are.
class EditorFind extends Find {
  new(
    this.editor,
    this.editorFocus, {
    required EditorLines lines,
    required EditorScroll scroll,
  }) : sight = EditorSight(
         lines: lines,
         down: scroll.verticalScroller,
         editor: editor,
       ),
       _scroll = scroll {
    _code
      ..addListener(_found)
      ..addListener(_inked);
  }

  /// What of the text is in sight: the editor is built again as it
  /// leaves the matches painted.
  final EditorSight sight;

  /// The editor's text.
  final CodeLineEditingController editor;

  /// The editor's focus, which re_editor asks for as its find closes.
  final FocusNode editorFocus;

  late final CodeFindController _code = CodeFindController(editor);

  /// What the editor is given as its find: re_editor's, less the tint on
  /// the match that's selected.
  late final CodeFindController marking = _Marking(_code, ink);

  /// How the editor's code is drawn on what it paints under it: given its
  /// spans by `FileEdit`, told here of the matches.
  late final EditorInk ink = EditorInk(editor, sight, _scroll.relayout);
  final EditorScroll _scroll;

  /// The matches the editor was last given to paint.
  @visibleForTesting
  List<CodeLineSelection> get painted =>
      (marking as _Marking)._given ?? const [];

  /// Whether re_editor's last answer is for the text as it is now: an
  /// edit leaves the earlier one, which it still paints, until the next.
  @visibleForTesting
  bool get answered =>
      _code.value?.result?.codeLines.equals(editor.codeLines) ?? false;

  /// Whether the text starts below the bar, for a match at the very top
  /// that no scroll takes out from under it; until the bar closes.
  final ValueNotifier<bool> roomAbove = ValueNotifier(false);

  /// The current match, as the editor's lines have it.
  CodeLineSelection? get match => _code.currentMatchSelection;

  /// What re_editor is to look for: the bar's text, which it's given only
  /// once it has answered the last (see [query]).
  String _wanted = '';

  /// Whether re_editor is still looking, or has yet to be given the latest
  /// text: the hits are an earlier query's.
  bool get looking => switch (_code.value) {
    null => false,
    final v => v.searching || v.option.pattern != _wanted,
  };

  /// The last query's count while it looks, nothing before the first: never
  /// "None" for a query not looked for yet.
  @override
  String get count => looking && hits.isEmpty ? '' : super.count;

  @override
  void open() {
    _code.value ??= const CodeFindValue.empty();
    super.open();
  }

  /// One search at a time: re_editor answers each in its isolate, in turn,
  /// and one overtaken by a later text comes back as no matches (0.10.0's
  /// `_updateResult`), so typed fast a file would read "None" until the
  /// last. The text typed meanwhile waits for the answer and goes in its
  /// place, the hits kept till then.
  @override
  set query(String? q) {
    _wanted = q ?? '';
    // re_editor first: by the time the bar hears, it's looking.
    if (_code.value case final v? when !v.searching) _ask();
    super.query = q;
  }

  void _ask() => _code.findInputController.text = _wanted;

  /// re_editor's matches, once it has them for the bar's text.
  void _found() {
    final v = _code.value;
    if (v == null || v.searching) return;
    if (v.option.pattern != _wanted) {
      _ask(); // an earlier text's answer: the latest's turn
      return;
    }
    final r = v.result;
    final matches = r == null || r.dirty
        ? const <CodeLineSelection>[]
        : r.matches;
    // Each key made only when read: there can be tens of thousands.
    foundAt(
      LazyKeys(matches.length, (i) {
        final m = matches[i];
        return '${m.startIndex}:${m.startOffset}';
      }),
      r?.index ?? 0,
    );
  }

  /// The matches as re_editor paints them, for [ink]: none while the
  /// text has changed since they were found, or with the find closed.
  void _inked() {
    final r = _code.value?.result;
    ink.found(
      r == null || r.dirty ? const [] : r.matches,
      _code.convertMatchToSelection,
    );
  }

  @override
  void step(int by) {
    if (!canStep || looking) return; // re_editor has no matches to step
    super.step(by);
    by > 0 ? _code.nextMatch() : _code.previousMatch();
    // re_editor selects it only while the editor hasn't the focus.
    if (match case final m?) {
      editor
        ..selection = m
        ..makePositionCenterIfInvisible(m.start);
    }
  }

  /// The editor takes the focus back from the bar's field (re_editor gives
  /// it the focus as its find closes). × closes it with the focus anywhere,
  /// or nowhere (a click outside a text field unfocuses it): it stays as it
  /// was, so what's typed next doesn't edit the file.
  @override
  void close() {
    final from = FocusManager.instance.primaryFocus;
    _wanted = '';
    _code
      ..close()
      ..findInputController.clear();
    if (from != null && from != focus) {
      // Taken back from the editor first, for a scope's focus (nothing's)
      // that would otherwise go to the editor it last had.
      editorFocus.unfocus();
      from.requestFocus();
    }
    roomAbove.value = false;
    super.close();
  }

  @override
  void dispose() {
    _code
      ..removeListener(_found)
      ..removeListener(_inked)
      ..dispose();
    ink.dispose();
    roomAbove.dispose();
    sight.dispose();
    super.dispose();
  }
}

/// re_editor's find as the editor draws it, but for the match the
/// selection is on: that one shows as the selection (the current match, in
/// the transcript's colors), not under the others' tint; and only the
/// matches in [EditorInk.sight]'s window, as [_ink] has them for its code.
class _Marking implements CodeFindController {
  new(this._find, this._ink);

  final CodeFindController _find;
  final EditorInk _ink;
  List<CodeLineSelection>? _given;

  @override
  List<CodeLineSelection>? get allMatchSelections => _given = _inSight();

  List<CodeLineSelection>? _inSight() {
    final r = _find.value?.result;
    if (r == null || r.dirty || r.matches.isEmpty) return null;
    final matches = r.matches;
    final window = _ink.sight.take();
    final shown = <CodeLineSelection>[];
    // In order down the text: each line with matches from the window's
    // first, its painted ones.
    var i = firstFrom(matches, window.first, 0);
    while (i < matches.length) {
      final line = matches[i].startIndex;
      if (line > window.last) break;
      shown.addAll(_ink.paintedOn(line));
      i = firstFrom(matches, line + 1, 0);
    }
    return shown;
  }

  @override
  CodeFindValue? get value => _find.value;
  @override
  set value(CodeFindValue? v) => _find.value = v;
  @override
  void addListener(VoidCallback l) => _find.addListener(l);
  @override
  void removeListener(VoidCallback l) => _find.removeListener(l);
  @override
  // The find's owner, EditorFind, disposes it.
  void dispose() {}
  @override
  bool get hasListeners => _find.hasListeners;
  @override
  void notifyListeners() => _find.notifyListeners();
  @override
  TextEditingController get findInputController => _find.findInputController;
  @override
  TextEditingController get replaceInputController =>
      _find.replaceInputController;
  @override
  FocusNode get findInputFocusNode => _find.findInputFocusNode;
  @override
  FocusNode get replaceInputFocusNode => _find.replaceInputFocusNode;
  @override
  CodeLineSelection? get currentMatchSelection => _find.currentMatchSelection;
  @override
  void findMode() => _find.findMode();
  @override
  void replaceMode() => _find.replaceMode();
  @override
  void focusOnFindInput() => _find.focusOnFindInput();
  @override
  void focusOnReplaceInput() => _find.focusOnReplaceInput();
  @override
  void toggleMode() => _find.toggleMode();
  @override
  void close() => _find.close();
  @override
  void toggleRegex() => _find.toggleRegex();
  @override
  void toggleCaseSensitive() => _find.toggleCaseSensitive();
  @override
  void previousMatch() => _find.previousMatch();
  @override
  void nextMatch() => _find.nextMatch();
  @override
  void replaceMatch() => _find.replaceMatch();
  @override
  void replaceAllMatches() => _find.replaceAllMatches();
  @override
  CodeLineSelection? convertMatchToSelection(CodeLineSelection match) =>
      _find.convertMatchToSelection(match);
}

/// The find bar, while it's open, for the editor's top right (where
/// Changes' sits); a match stepped or typed to that it covers goes below
/// it. Laid over the editor,
/// whose lines are [lines], its text area right of [gutter], scrolled by
/// [down].
class EditorFindBar extends StatefulWidget {
  const new({
    required this.find,
    required this.lines,
    required this.gutter,
    required this.down,
    super.key,
  });

  final EditorFind find;
  final EditorLines lines;
  final GlobalKey gutter;
  final ScrollController down;

  @override
  State<EditorFindBar> createState() => _EditorFindBarState();
}

class _EditorFindBarState extends State<EditorFindBar> {
  final GlobalKey _bar = GlobalKey();
  int _shown = -1; // the last ask whose match was looked for under the bar

  @override
  void initState() {
    super.initState();
    widget.find.addListener(_changed);
  }

  @override
  void dispose() {
    widget.find.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final f = widget.find;
    if (f.current == null || f.looking || f.asked == _shown) return;
    _shown = f.asked;
    WidgetsBinding.instance.addPostFrameCallback((_) => _uncover());
  }

  /// Moves the current match out from under the bar, if it's there.
  void _uncover() {
    final m = widget.find.match;
    final bar = _bar.currentContext?.findRenderObject();
    final gutter = widget.gutter.currentContext?.findRenderObject();
    final laidOut = widget.lines.value;
    final down = widget.down;
    if (!mounted || m == null || laidOut == null || !down.hasClients) return;
    if (bar is! RenderBox || gutter is! RenderBox || !gutter.hasSize) return;
    final p = laidOut.paragraphs.where((p) => p.index == m.startIndex);
    if (p.isEmpty) return; // out of sight: re_editor brings it to the middle
    final line = p.first;
    final at =
        gutter.localToGlobal(Offset(gutter.size.width, 0)) +
        line.offset +
        Offset(widget.lines.moved, 0);
    final cover = (bar.localToGlobal(Offset.zero) & bar.size).inflate(4);
    final under = line
        .getRangeRects(
          TextRange(
            start: m.startOffset,
            end: m.isSameLine ? m.endOffset : line.length,
          ),
        )
        .map((r) => r.shift(at))
        .where(cover.overlaps);
    if (under.isEmpty) return;
    final by = cover.bottom - under.map((r) => r.top).reduce(min);
    final to = down.position.pixels - by;
    if (to >= down.position.minScrollExtent) {
      down.jumpTo(to);
    } else {
      widget.find.roomAbove.value = true;
      down.jumpTo(down.position.minScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.find,
    builder: (context, _) => widget.find.query == null
        ? const SizedBox.shrink()
        : FindBar(widget.find, key: _bar, hint: 'Find in the file'),
  );
}
