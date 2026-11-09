import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:nushi/transcript_find.dart';
import 'package:nushi/whitespace_marks.dart' show EditorLines;
import 'package:re_editor/re_editor.dart';

/// ⌘F in the preview's editor (ADR 0096), in the [FindBar] the transcript
/// has: re_editor's own find matches (case aside, off the UI thread) and
/// tints every match; this tells the bar its count and steps through them.
/// The current match is the editor's selection, starting from the caret,
/// so it stays selected when the bar closes and the editor takes the focus
/// back. Only the bar's field takes the keys while it's open: nothing typed
/// there reaches the file.
class EditorFind extends TranscriptFind {
  new(this.editor) {
    _code.addListener(_found);
  }

  /// The editor's text.
  final CodeLineEditingController editor;

  late final CodeFindController _code = CodeFindController(editor);

  /// What the editor is given as its find: re_editor's, less the tint on
  /// the match that's selected.
  late final CodeFindController marking = _Marking(_code, editor);

  /// Whether the text starts below the bar, for a match at the very top
  /// that no scroll takes out from under it; until the bar closes.
  final ValueNotifier<bool> roomAbove = ValueNotifier(false);

  /// The current match, as the editor's lines have it.
  CodeLineSelection? get match => _code.currentMatchSelection;

  /// Whether re_editor is still looking: the hits are the last query's.
  bool get looking => _code.value?.searching ?? false;

  @override
  void open() {
    _code.value ??= const CodeFindValue.empty();
    super.open();
  }

  @override
  set query(String? q) {
    // re_editor first: by the time the bar hears, it's looking.
    if (_code.value != null) _code.findInputController.text = q ?? '';
    super.query = q;
  }

  /// re_editor's matches, once it has them: the bar keeps the last count
  /// while it looks.
  void _found() {
    final v = _code.value;
    if (v == null || v.searching) return;
    final r = v.result;
    final matches = r == null || r.dirty
        ? const <CodeLineSelection>[]
        : r.matches;
    foundAt([
      for (final m in matches) '${m.startIndex}:${m.startOffset}',
    ], r?.index ?? 0);
  }

  @override
  void step(int by) {
    if (!canStep) return;
    super.step(by);
    by > 0 ? _code.nextMatch() : _code.previousMatch();
    // re_editor selects it only while the editor hasn't the focus.
    if (match case final m?) {
      editor
        ..selection = m
        ..makePositionCenterIfInvisible(m.start);
    }
  }

  @override
  void close() {
    _code
      ..close()
      ..findInputController.clear();
    roomAbove.value = false;
    super.close();
  }

  @override
  void dispose() {
    _code
      ..removeListener(_found)
      ..dispose();
    roomAbove.dispose();
    super.dispose();
  }
}

/// re_editor's find as the editor draws it, but for the match the
/// selection is on: that one shows as the selection (the current match, in
/// the transcript's colors), not under the others' tint.
class _Marking implements CodeFindController {
  new(this._find, this._editor);

  final CodeFindController _find;
  final CodeLineEditingController _editor;

  @override
  List<CodeLineSelection>? get allMatchSelections {
    final s = _editor.selection;
    return _find.allMatchSelections
        ?.where(
          (m) =>
              m.startIndex != s.startIndex ||
              m.startOffset != s.startOffset ||
              m.endIndex != s.endIndex ||
              m.endOffset != s.endOffset,
        )
        .toList();
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
