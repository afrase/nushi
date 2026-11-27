import 'dart:async';

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart' show findKey;
import 'package:nushi/blame.dart';
import 'package:nushi/blame_gutter.dart';
import 'package:nushi/change_marks.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/indent_guides.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/line_changes.dart';
import 'package:nushi/menu.dart' show Menu, MenuEntry;
import 'package:nushi/motion.dart' show Waits;
import 'package:nushi/settings.dart';
import 'package:nushi/source_menu.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/tab_indent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart' show FindBar, findColors;
import 'package:nushi/whitespace_marks.dart';
import 'package:re_editor/re_editor.dart';

/// A file's text as an editor (ADR 0096), as the preview's source shows
/// it (`SourceView`: the code face, its highlighting, numbered lines
/// wrapped as [wrap] says): a click and typing edit [edit]. It saves when
/// the focus leaves it for somewhere that takes the keys (the prompt box,
/// a terminal, another editor or pane), and when it goes (another tab or
/// chat); not for a menu, the palette, a dialog, find, or a selection in
/// the transcript or a preview, which wait for where the focus goes next.
/// ⌘F with the focus in it finds in the file ([EditorFind]), not the chat.
/// With a [base], the last commit's text, the lines that differ from it
/// have change marks beside their numbers (ADR 0131), unsaved edits too,
/// a pause in typing after each. With [menu] a right-click opens its menu
/// ([SourceMenu]), with Find and, when it can be written, Cut and Paste.
/// With [blame] (its Blame on, issue #78) a gutter left of the numbers
/// says who last changed each run of lines, an unsaved edit's lines not
/// committed, worked out again as typing pauses.
class SourceEditor extends StatefulWidget {
  const new({
    required this.edit,
    required this.wrap,
    super.key,
    this.padding = EdgeInsets.zero,
    this.base,
    this.menu,
    this.blame,
  });

  final FileEdit edit;
  final bool wrap;
  final EdgeInsets padding;

  /// The last commit's text, its lines marked against (null marks none).
  final ValueListenable<String?>? base;

  /// What its right-click menu does; null: it has none.
  final SourceActions? menu;

  /// Its Blame, while on; null: no gutter.
  final BlameShown? blame;

  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<SourceEditor> {
  final _focus = FocusNode(debugLabel: 'editor');

  /// The editor's scrolling, down and (lines unwrapped) across.
  final _down = ScrollController();
  final _across = ScrollController();
  late final _scroll = CodeScrollController(
    verticalScroller: _down,
    horizontalScroller: _across,
  );

  /// The lines as re_editor laid them out, and its line numbers' place:
  /// where Show whitespace marks them.
  late final _lines = EditorLines(_across);
  late final _find = EditorFind(
    widget.edit.controller,
    _focus,
    lines: _lines,
    down: _down,
  );
  final GlobalKey _gutter = GlobalKey();
  ModalRoute<Object?>? _route;
  bool _following = false;

  /// Each line's change mark, against [SourceEditor.base]; the lines they
  /// were worked out for, and the next working out, while typing pauses.
  final _cells = ValueNotifier<List<MarkCell?>>(const []);
  CodeLines? _marked;
  Timer? _typing;
  int _markings = 0;

  /// Each line's blame, against [SourceEditor.blame]'s text.
  final _blamed = ValueNotifier<List<BlameCell>>(const []);

  /// The selection as last drawn: a right-click keeps it, though
  /// re_editor's own press has moved the caret by then.
  late CodeLineSelection _drawn = widget.edit.controller.selection;
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    widget.edit.controller.addListener(_selectionMoved);
    _focus.addListener(_focusChanged);
    tabSize.addListener(_tabSizeChanged);
    widget.base?.addListener(_mark);
    widget.edit.controller.addListener(_edited);
    _mark();
  }

  @override
  void didUpdateWidget(SourceEditor old) {
    super.didUpdateWidget(old);
    if (old.base != widget.base) {
      old.base?.removeListener(_mark);
      widget.base?.addListener(_mark);
      _mark();
    } else if (!identical(old.blame?.blamed, widget.blame?.blamed)) {
      _mark();
    }
  }

  /// The text changed (not only the caret): marked again once typing
  /// pauses.
  void _edited() {
    if (identical(widget.edit.controller.codeLines, _marked)) return;
    _typing?.cancel();
    _typing = Timer(Waits.typing, _mark);
  }

  void _mark() {
    _typing?.cancel();
    final marked = ++_markings;
    final lines = widget.edit.controller.codeLines;
    _marked = lines;
    _blame(marked);
    final base = widget.base?.value;
    if (base == null) {
      _cells.value = const [];
      return;
    }
    List<MarkCell?> cells(List<LineMark> marks) =>
        marks.isEmpty ? const [] : markCells(marks, lines.length);
    switch (lineMarksSoon(base, widget.edit.text)) {
      case final List<LineMark> marks:
        _cells.value = cells(marks);
      case final Future<List<LineMark>> later:
        later.then((marks) {
          if (mounted && marked == _markings) _cells.value = cells(marks);
        }).ignore();
    }
  }

  /// The lines' blame, for the marking [marked].
  void _blame(int marked) {
    final blamed = widget.blame?.blamed;
    if (blamed == null) {
      _blamed.value = const [];
      return;
    }
    switch (blameCells(blamed, widget.edit.text)) {
      case final List<BlameCell> cells:
        _blamed.value = cells;
      case final Future<List<BlameCell>> later:
        later.then((cells) {
          if (mounted && marked == _markings) _blamed.value = cells;
        }).ignore();
    }
  }

  /// The selection changed: it's the one drawn once the frame is.
  void _selectionMoved() {
    if (_drawing) return;
    _drawing = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _drawing = false;
        if (mounted) _drawn = widget.edit.controller.selection;
      })
      ..ensureVisualUpdate();
  }

  /// A right-click: the selection stays as it was drawn.
  void _rightPressed(Offset _) {
    final c = widget.edit.controller;
    if (c.selection != _drawn) c.selection = _drawn;
  }

  /// The line (from 0) at [at] on the screen, of those laid out: the one
  /// across it, else the nearest; the caret's without any.
  int _lineAt(Offset at) {
    final box = _gutter.currentContext?.findRenderObject() as RenderBox?;
    final lines = _lines.value?.paragraphs ?? const [];
    if (box == null || lines.isEmpty) {
      return widget.edit.controller.selection.extentIndex;
    }
    final y = box.globalToLocal(at).dy;
    for (final p in lines) {
      if (y < p.top + p.height) return p.index;
    }
    return lines.last.index;
  }

  /// The right-click menu's rows, for a press at [at].
  List<MenuEntry> _menuAt(Offset at, SourceActions menu) {
    final c = widget.edit.controller;
    final s = c.selection;
    final writable = widget.edit.readOnly == null;
    return menu.entries(
      context,
      selected: s.isCollapsed ? '' : c.selectedText,
      first: s.isCollapsed ? null : min(s.baseIndex, s.extentIndex) + 1,
      clicked: _lineAt(at) + 1,
      editing: true,
      onCut: writable ? c.cut : null,
      onPaste: writable ? c.paste : null,
      onFind: _find.open,
    );
  }

  /// Tab size set: the lines' runs are made again, to the new stops
  /// (`FileEdit`'s spans read it), in the same editor and its edits.
  void _tabSizeChanged() => widget.edit.controller.forceRepaint();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _typing?.cancel();
    widget.base?.removeListener(_mark);
    widget.edit.controller
      ..removeListener(_edited)
      ..removeListener(_selectionMoved);
    _cells.dispose();
    _blamed.dispose();
    tabSize.removeListener(_tabSizeChanged);
    _unfollow();
    _find.dispose();
    _focus.dispose();
    _lines.dispose();
    _scroll.dispose();
    _down.dispose();
    _across.dispose();
    // Another tab, the pane closed, another chat: the focus went
    // elsewhere with the view.
    if (widget.edit.canSave) unawaited(widget.edit.save());
    super.dispose();
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _unfollow();
    } else if (widget.edit.canSave && !_following) {
      _following = true;
      FocusManager.instance.addListener(_moved);
      WidgetsBinding.instance.addPostFrameCallback((_) => _moved());
    }
  }

  void _unfollow() {
    if (!_following) return;
    _following = false;
    FocusManager.instance.removeListener(_moved);
  }

  /// Where the focus went since it left: somewhere that takes the keys
  /// saves; somewhere that only passes (a menu, a dialog) waits.
  void _moved() {
    if (!_following || !mounted) return;
    if (_focus.hasFocus) return _unfollow();
    if (passing(FocusManager.instance.primaryFocus, _route)) return;
    _unfollow();
    unawaited(widget.edit.save());
  }

  /// Tab, ⇧Tab and Return in a file that indents with tabs, which
  /// re_editor's own (spaces only) would get wrong.
  late final Map<Type, Action<Intent>> _tabActions = {
    CodeShortcutIndentIntent: _tabAction<CodeShortcutIndentIntent>(tabIndent),
    CodeShortcutOutdentIntent: _tabAction<CodeShortcutOutdentIntent>(
      (v) => tabOutdent(v, size: tabSize.value),
    ),
    CodeShortcutNewLineIntent: _tabAction<CodeShortcutNewLineIntent>(
      tabNewLine,
    ),
  };

  Action<T> _tabAction<T extends Intent>(
    CodeLineEditingValue Function(CodeLineEditingValue) edit,
  ) => CallbackAction<T>(
    onInvoke: (_) {
      final c = widget.edit.controller;
      if (widget.edit.readOnly != null) return null;
      c
        ..runRevocableOp(() => c.value = edit(c.value))
        ..makeCursorVisible();
      return null;
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final code = theme.code(t.text, size: 12);
    final gutter = theme.code(t.textMuted, size: 12);
    // A line as re_editor draws it (no text scaling): Scroll past end's
    // room under the last one.
    final line = (TextPainter(
      text: TextSpan(text: '0', style: code),
      textDirection: TextDirection.ltr,
    )..layout());
    final lineHeight = line.height;
    line.dispose();
    final editor = ListenableBuilder(
      listenable: Listenable.merge([
        widget.edit,
        _find.roomAbove,
        _find.sight,
        scrollPastEnd,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final top =
              widget.padding.top + (_find.roomAbove.value ? FindBar.height : 0);
          return CodeEditor(
            controller: widget.edit.controller,
            findController: _find.marking,
            focusNode: _focus,
            scrollController: _scroll,
            readOnly: widget.edit.readOnly != null,
            wordWrap: widget.wrap,
            autocompleteSymbols: false,
            chunkAnalyzer: const NonCodeChunkAnalyzer(),
            shortcutsActivatorsBuilder: const _EditorKeys(),
            shortcutOverrideActions: widget.edit.tabs ? _tabActions : null,
            // The numbers' own room is the change marks' (markRoom), so
            // the text starts where a read-only source's does.
            padding: EdgeInsets.only(
              left: 14 - markGap - markBar,
              top: top,
              right: widget.padding.right,
              bottom: scrollPastEnd.value
                  ? pastEndPadding(
                      box.maxHeight,
                      lineHeight,
                      top: top,
                      bottom: widget.padding.bottom,
                    )
                  : widget.padding.bottom,
            ),
            style: CodeEditorStyle(
              fontFamily: code.fontFamily,
              fontFamilyFallback: code.fontFamilyFallback,
              fontSize: code.fontSize,
              fontHeight: code.height,
              textColor: t.text,
              backgroundColor: t.base,
              selectionColor: DefaultSelectionStyle.of(context).selectionColor,
              cursorColor: t.text,
              cursorWidth: 1.5,
              cursorLineColor: t.base,
              // A find's matches; the current one is the selection, as the
              // transcript's (TextMarks) are.
              highlightColor: findColors(t).hit,
            ),
            indicatorBuilder: (context, controller, chunks, notifier) {
              _lines.follow(notifier);
              return Padding(
                key: _gutter,
                padding: EdgeInsets.only(left: widget.padding.left),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.blame case final blame?)
                      EditorBlame(
                        lines: notifier,
                        cells: _blamed,
                        line: lineHeight,
                        pane: box.maxWidth,
                        onOpen: blame.onOpen,
                      ),
                    Stack(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DefaultCodeLineNumber(
                              controller: controller,
                              notifier: notifier,
                              minNumberCount: 1,
                              textStyle: gutter,
                              focusedTextStyle: gutter.copyWith(
                                color: t.textSecondary,
                              ),
                            ),
                            const SizedBox(width: markGap + markBar),
                          ],
                        ),
                        Positioned.fill(
                          child: _EditorMarks(lines: notifier, cells: _cells),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    // ⌘F here finds in the file, as a terminal keeps it (`terminalPasses`);
    // elsewhere it's the chat's or Changes'.
    return CallbackShortcuts(
      bindings: {findKey: _find.open},
      child: ListenableBuilder(
        listenable: Listenable.merge([showWhitespace, indentGuides, tabSize]),
        builder: (context, editor) => Stack(
          fit: StackFit.expand,
          children: [
            switch (widget.menu) {
              final menu? => SourceMenu(
                entries: (at) => _menuAt(at, menu),
                onPress: _rightPressed,
                child: editor!,
              ),
              null => editor!,
            },
            // Over its fill, in the indentation, where no text is.
            if (indentGuides.value)
              IndentGuideOverlay(
                lines: _lines,
                controller: widget.edit.controller,
                gutter: _gutter,
                column: columnWidth(code, TextScaler.noScaling),
                size: tabSize.value,
                color: whitespaceColor(NushiTheme.of(context).t),
              ),
            if (showWhitespace.value)
              WhitespaceOverlay(
                lines: _lines,
                controller: widget.edit.controller,
                gutter: _gutter,
                // re_editor draws with no text scaling.
                column: columnWidth(code, TextScaler.noScaling),
              ),
            // At the top right, and no wider than the pane leaves it: a
            // pane at its least is narrower than the bar.
            Positioned(
              top: 8,
              left: NushiTheme.gutter,
              right: NushiTheme.gutter,
              child: Align(
                alignment: Alignment.topRight,
                child: EditorFindBar(
                  find: _find,
                  lines: _lines,
                  gutter: _gutter,
                  down: _down,
                ),
              ),
            ),
          ],
        ),
        child: editor,
      ),
    );
  }
}

/// The editor's change marks over its line numbers' cells, where
/// re_editor laid the lines out ([lines], the numbers' own), each bar at
/// its cell's right edge: painted as the lines are laid out, so they
/// scroll with them; and where the pointer finds them, set a frame later
/// (re_editor tells of its lines while it lays them out, when nothing
/// may build).
class _EditorMarks extends StatefulWidget {
  const new({required this.lines, required this.cells});

  final CodeIndicatorValueNotifier lines;
  final ValueListenable<List<MarkCell?>> cells;

  @override
  State<_EditorMarks> createState() => _EditorMarksState();
}

class _EditorMarksState extends State<_EditorMarks> {
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    widget.lines.addListener(_laidOut);
    widget.cells.addListener(_laidOut);
  }

  @override
  void dispose() {
    widget.lines.removeListener(_laidOut);
    widget.cells.removeListener(_laidOut);
    super.dispose();
  }

  void _laidOut() {
    if (_waiting) return;
    _waiting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waiting = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return LayoutBuilder(
      builder: (context, box) {
        final marks = widget.cells.value;
        final x = box.maxWidth - markBar;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EditorMarkPainter(widget.lines, widget.cells, x, t),
              ),
            ),
            for (final p
                in widget.lines.value?.paragraphs ??
                    const <CodeLineRenderParagraph>[])
              if (marks.elementAtOrNull(p.index) case final cell?)
                Positioned(
                  left: 0,
                  width: box.maxWidth,
                  top: p.top,
                  height: p.height,
                  child: ChangeMark(cell: cell, barX: x, painted: false),
                ),
          ],
        );
      },
    );
  }
}

class _EditorMarkPainter extends CustomPainter {
  new(this.lines, this.cells, this.x, this.t)
    : super(repaint: Listenable.merge([lines, cells]));

  final CodeIndicatorValueNotifier lines;
  final ValueListenable<List<MarkCell?>> cells;
  final double x;
  final Tokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final marks = cells.value;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    for (final p
        in lines.value?.paragraphs ?? const <CodeLineRenderParagraph>[]) {
      if (marks.elementAtOrNull(p.index) case final cell?) {
        final box = Rect.fromLTWH(0, p.top, size.width, p.height);
        paintChangeMark(canvas, box, cell, x, t);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EditorMarkPainter old) =>
      old.x != x ||
      old.t != t ||
      !identical(old.lines, lines) ||
      !identical(old.cells, cells);
}

/// Whether the focus at [focus] only passes on its way somewhere (an
/// editor whose page is [route] waits to see where): nothing, a scope
/// (after a click on what takes no focus), another page (a dialog, the
/// palette), a menu, find, or a selection in a transcript or preview.
bool passing(FocusNode? focus, ModalRoute<Object?>? route) {
  if (focus == null || focus is FocusScopeNode) return true;
  final at = focus.context;
  if (at == null) return true;
  if (ModalRoute.of(at) != route) return true;
  if (at.findAncestorWidgetOfExactType<Menu>() != null ||
      at.findAncestorWidgetOfExactType<MenuAnchor>() != null ||
      at.findAncestorWidgetOfExactType<FindBar>() != null) {
    return true;
  }
  return at.findAncestorStateOfType<EditableTextState>() == null &&
      at.findAncestorStateOfType<SelectableRegionState>() != null;
}

/// re_editor's keys (the Mac's, or Control's on Linux), less those the app
/// keeps (⌘S saves, ⌘D pins the chat, ⌘L is the browser's address), its
/// find's (⌘F opens Nushi's bar, [EditorFind]) or those that aren't the
/// Mac's (⌘L selecting a line, ⌘/ commenting), with Emacs's ⌃A and ⌃E as
/// every Mac text field has them; on Linux Ctrl+A selects all.
class _EditorKeys extends CodeShortcutsActivatorsBuilder {
  const new();

  static const _builtIn = DefaultCodeShortcutsActivatorsBuilder();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) => switch (type) {
    CodeShortcutType.save ||
    CodeShortcutType.find ||
    CodeShortcutType.replace ||
    CodeShortcutType.findToggleMatchCase ||
    CodeShortcutType.findToggleRegex ||
    CodeShortcutType.lineDelete ||
    CodeShortcutType.lineSelect ||
    CodeShortcutType.singleLineComment ||
    CodeShortcutType.multiLineComment ||
    // Esc is the pane's: it collapses an expanded Files pane (ADR 0094);
    // the find bar takes its own.
    CodeShortcutType.esc => null,
    CodeShortcutType.cursorMoveLineStart when commandKey == CommandKey.meta => [
      ...?_builtIn.build(type),
      const SingleActivator(LogicalKeyboardKey.keyA, control: true),
    ],
    CodeShortcutType.cursorMoveLineEnd when commandKey == CommandKey.meta => [
      ...?_builtIn.build(type),
      const SingleActivator(LogicalKeyboardKey.keyE, control: true),
    ],
    _ => _builtIn.build(type),
  };
}
