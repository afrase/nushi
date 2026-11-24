import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart' show findKey;
import 'package:nushi/conventions.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/preview_path.dart' show copiedPath;
import 'package:nushi/replies.dart';
import 'package:nushi/review.dart' show linesWord, quotedLines;
import 'package:nushi/widgets.dart';

// The right-click menu in a file's source in the Files pane (issue 75), as
// an editor has one: Copy, Copy path with the line, Quote in reply, Find
// where the view has it, and the file shown in the file manager or opened
// in the default text editor.

/// What a file's source in the Files pane offers on its right-click menu,
/// past what its text does itself: the file ([path], as its tab names it,
/// and the chat's [folder], which a copied path is relative to), a quote
/// of its lines as a reply card in the chat's box ([onQuote]), showing it
/// in the file manager ([onReveal]) and opening it in the default text
/// editor ([onOpen]).
class SourceActions {
  const new({
    required this.folder,
    required this.path,
    required this.onQuote,
    required this.onReveal,
    required this.onOpen,
  });

  final String folder;
  final String path;
  final void Function(Reply reply) onQuote;
  final VoidCallback onReveal;
  final VoidCallback onOpen;

  /// The path a Copy path copies for [line] (from 1): the path line's
  /// copy ([copiedPath]) and the line, as `docs/a.md:12`.
  String pathAt(int line) => '${copiedPath(folder, path)}:$line';

  /// [text], the lines from [first] (from 1), as a reply card quotes a
  /// file's lines: the path, the lines, their text in a fence.
  Reply quoteOf(String text, int first) {
    final lines = text.endsWith('\n')
        ? text.substring(0, text.length - 1)
        : text;
    final last = first + '\n'.allMatches(lines).length;
    return (
      quote: quotedLines(
        copiedPath(folder, path),
        linesWord(first, last),
        lines,
      ),
      text: '',
      from: '',
    );
  }

  /// The menu's rows for a right-click on line [clicked] (from 1), with
  /// [selected] the selection's text and [first] its first line (null with
  /// none). Copy and Quote in reply want a selection; Copy path takes its
  /// first line, else the clicked one. [onFind] (the editor's) adds Find;
  /// [onCut] and [onPaste] (an editor that can be written) Cut and Paste.
  List<MenuEntry> entries(
    BuildContext context, {
    required String selected,
    required int? first,
    required int clicked,
    VoidCallback? onFind,
    VoidCallback? onCut,
    VoidCallback? onPaste,
    bool editing = false,
  }) {
    final some = selected.isNotEmpty && first != null;
    return [
      if (editing)
        MenuEntry(
          'Cut',
          shortcut: cmdLabel(LogicalKeyboardKey.keyX),
          onPick: some ? onCut : null,
        ),
      MenuEntry(
        'Copy',
        shortcut: cmdLabel(LogicalKeyboardKey.keyC),
        onPick: some
            ? () => unawaited(Clipboard.setData(ClipboardData(text: selected)))
            : null,
      ),
      if (editing)
        MenuEntry(
          'Paste',
          shortcut: cmdLabel(LogicalKeyboardKey.keyV),
          onPick: onPaste,
        ),
      MenuEntry(
        'Copy path',
        onPick: () => tryOrShow(context, () async {
          await Clipboard.setData(
            ClipboardData(text: pathAt(some ? first : clicked)),
          );
          if (context.mounted) showToast(Toasts.maybeOf(context), 'Copied');
        }),
      ),
      MenuEntry(
        'Quote in reply',
        onPick: some ? () => onQuote(quoteOf(selected, first)) : null,
      ),
      if (onFind != null) ...[
        MenuEntry.divider,
        MenuEntry('Find…', shortcut: keyLabel(findKey), onPick: onFind),
      ],
      MenuEntry.divider,
      MenuEntry(conventions.reveal, onPick: onReveal),
      MenuEntry('Open in your editor', onPick: onOpen),
    ];
  }
}

/// Opens the app's [Menu] where [child] is right-clicked, its rows worked
/// out at the press ([entries], given where it was, on the screen): the
/// press is this menu's alone, so the text under it keeps its selection
/// (a selection area would select the word under it on the Mac) and its
/// focus (the menu's rows don't take it, so the selection shows and ⌘C
/// copies it while it's open; Esc closes it). [onPress] runs at the press
/// and at its release, first, given the place: the editor puts back the
/// selection its own handling of them moved.
class SourceMenu extends StatefulWidget {
  const new({
    required this.entries,
    required this.child,
    super.key,
    this.onPress,
  });

  final List<MenuEntry> Function(Offset at) entries;
  final ValueChanged<Offset>? onPress;
  final Widget child;

  @override
  State<SourceMenu> createState() => _SourceMenuState();
}

class _SourceMenuState extends State<SourceMenu> {
  final _menu = MenuController();
  List<MenuEntry> _entries = const [];
  OpenMenu? _open;

  void _pressed(Offset at) {
    widget.onPress?.call(at);
    setState(() => _entries = widget.entries(at));
  }

  void _released(Offset at) {
    widget.onPress?.call(at);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    _open?.call(box.globalToLocal(at));
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent ||
        e.logicalKey != LogicalKeyboardKey.escape ||
        !_menu.isOpen) {
      return KeyEventResult.ignored;
    }
    _menu.close();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // The text's selection reaches its child, not the menu's rows, which
    // are built under it but are no part of the text.
    final registrar = SelectionContainer.maybeOf(context);
    Widget selectable(Widget child) => registrar == null
        ? child
        : SelectionRegistrarScope(registrar: registrar, child: child);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _key,
      child: SelectionContainer.disabled(
        child: Menu(
          controller: _menu,
          entries: _entries,
          filter: false,
          keepFocus: true,
          builder: (context, open) {
            _open = open;
            return RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: {
                _RightClick: GestureRecognizerFactoryWithHandlers<_RightClick>(
                  () => _RightClick(debugOwner: this),
                  (r) => r
                    ..onDown = _pressed
                    ..onUp = _released,
                ),
              },
              child: selectable(widget.child),
            );
          },
        ),
      ),
    );
  }
}

/// A right-click, taken at once: no other gesture under or around it (a
/// selection area's own right-click) sees it.
class _RightClick extends OneSequenceGestureRecognizer {
  new({super.debugOwner});

  ValueChanged<Offset>? onDown;
  ValueChanged<Offset>? onUp;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.buttons == kSecondaryButton && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
    onDown?.call(event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      onUp?.call(event.position);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'right-click';
}
