import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart' show findKey;
import 'package:nushi/conventions.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart' show Menu;
import 'package:nushi/settings.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/tab_indent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart' show FindBar;
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
class SourceEditor extends StatefulWidget {
  const new({
    required this.edit,
    required this.wrap,
    super.key,
    this.padding = EdgeInsets.zero,
  });

  final FileEdit edit;
  final bool wrap;
  final EdgeInsets padding;

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
  late final _find = EditorFind(widget.edit.controller, _focus);
  final GlobalKey _gutter = GlobalKey();
  ModalRoute<Object?>? _route;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
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
      tabOutdent,
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
    final editor = ListenableBuilder(
      listenable: Listenable.merge([widget.edit, _find.roomAbove]),
      builder: (context, _) => CodeEditor(
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
        padding: EdgeInsets.only(
          left: 14,
          top:
              widget.padding.top + (_find.roomAbove.value ? FindBar.height : 0),
          right: widget.padding.right,
          bottom: widget.padding.bottom,
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
          highlightColor: t.needs.withValues(alpha: 0.3),
        ),
        indicatorBuilder: (context, controller, chunks, notifier) {
          _lines.follow(notifier);
          return Padding(
            key: _gutter,
            padding: EdgeInsets.only(left: widget.padding.left),
            child: DefaultCodeLineNumber(
              controller: controller,
              notifier: notifier,
              minNumberCount: 1,
              textStyle: gutter,
              focusedTextStyle: gutter.copyWith(color: t.textSecondary),
            ),
          );
        },
      ),
    );
    // ⌘F here finds in the file, as a terminal keeps it (`terminalPasses`);
    // elsewhere it's the chat's or Changes'.
    return CallbackShortcuts(
      bindings: {findKey: _find.open},
      child: ValueListenableBuilder(
        valueListenable: showWhitespace,
        builder: (context, show, editor) => Stack(
          fit: StackFit.expand,
          children: [
            editor!,
            if (show)
              WhitespaceOverlay(
                lines: _lines,
                controller: widget.edit.controller,
                gutter: _gutter,
                // re_editor draws with no text scaling.
                column: columnWidth(code, TextScaler.noScaling),
              ),
            Positioned(
              top: 8,
              right: NushiTheme.gutter,
              child: EditorFindBar(
                find: _find,
                lines: _lines,
                gutter: _gutter,
                down: _down,
              ),
            ),
          ],
        ),
        child: editor,
      ),
    );
  }
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
    CodeShortcutType.multiLineComment => null,
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
