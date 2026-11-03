import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/spell_check.dart';
import 'package:nushi/spell_scan.dart';
import 'package:nushi/speller.dart';

/// How many suggestions a flagged word's menu offers.
const _mostFixes = 4;

/// The keys that take a suggestion, in order.
const List<LogicalKeyboardKey> _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];

/// The keys that do nothing alone, each by its one name for left and right.
final Set<LogicalKeyboardKey> _modifiers = {
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.control,
};

/// What a flagged word's menu does: it opens above the word, on a click, or
/// on ⌘;, which goes to the next flagged word, and the focus stays in the box
/// the whole time, so typing simply goes on. The box's right-click offers the
/// same on a flagged word, beside Cut, Copy and Paste.
class SpellMenu extends ChangeNotifier {
  new(this.spell);

  final SpellCheck spell;
  final MenuController controller = MenuController();

  /// The word the menu is for, and where it is in the [SpellArea].
  SpellWord? word;
  Rect anchor = Rect.zero;
  List<String> fixes = const [];

  final GlobalKey _area = GlobalKey();
  final _guessed = <String, List<String>>{};
  Offset? _pressedAt;
  bool _disposed = false;

  ComposerText get _text => spell.text;

  /// The field: its focus node is attached under it.
  EditableTextState? get _field =>
      spell.focus.context?.findAncestorStateOfType<EditableTextState>();

  /// [word]'s better spellings, in its shape, at most [_mostFixes]. None if
  /// the checker can't say.
  Future<List<String>> _fixesOf(String word) async {
    if (_guessed[word] case final known?) return known;
    try {
      final guesses = await speller!.guesses(word);
      return _guessed[word] = {for (final g in guesses) inShapeOf(word, g)}
          .take(_mostFixes)
          .toList();
    } on Object {
      return const [];
    }
  }

  /// The menu's rows.
  List<MenuEntry> get entries {
    final w = word;
    if (w == null) return const [];
    return [
      for (final (i, fix) in fixes.indexed)
        MenuEntry(
          fix,
          shortcut: i == 0 ? '⏎' : '${i + 1}',
          lit: i == 0,
          onPick: () => take(w, fix),
        ),
      if (fixes.isEmpty) const MenuEntry('No suggestions'),
      MenuEntry.divider,
      MenuEntry('Ignore', onPick: () => allow(w, add: false)),
      MenuEntry('Add to dictionary', onPick: () => allow(w, add: true)),
    ];
  }

  /// Selects [w] and opens its menu over it, once it's laid out with the box
  /// scrolled to it.
  Future<void> open(SpellWord w) async {
    final found = await _fixesOf(w.word);
    if (_disposed || !_text.marks.contains(w)) return;
    spell.focus.requestFocus();
    _text.selection = TextSelection(baseOffset: w.start, extentOffset: w.end);
    word = w;
    fixes = found;
    _field?.bringIntoView(TextPosition(offset: w.end));
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _placeAt(w))
      ..ensureVisualUpdate();
  }

  void _placeAt(SpellWord w) {
    if (_disposed || word != w) return;
    final at = _rectOf(w);
    if (at == null) return;
    anchor = at;
    notifyListeners(); // the menu's anchor moves there in this frame
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!_disposed && word == w) controller.open();
      })
      ..ensureVisualUpdate();
  }

  /// [w]'s first line in the [SpellArea], within the box when the box is
  /// scrolled.
  Rect? _rectOf(SpellWord w) {
    final box = _field?.renderEditable;
    final area = _area.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || area == null) return null;
    final boxes = box.getBoxesForSelection(
      TextSelection(baseOffset: w.start, extentOffset: w.end),
    );
    if (boxes.isEmpty) return null;
    final rect = boxes.first.toRect();
    final at = area.globalToLocal(box.localToGlobal(rect.topLeft));
    return Offset(at.dx, max(0, at.dy)) & rect.size;
  }

  void close() {
    word = null;
    controller.close();
  }

  /// Replaces [w] with [fix], unless the text moved on; ⌘Z undoes it.
  void take(SpellWord w, String fix) {
    close();
    final text = _text.text;
    if (w.end <= text.length && text.substring(w.start, w.end) == w.word) {
      _text.value = TextEditingValue(
        text: text.replaceRange(w.start, w.end, fix),
        selection: TextSelection.collapsed(offset: w.start + fix.length),
      );
      spell.settle();
    }
    spell.focus.requestFocus();
  }

  /// Ignores [w], or with [add] adds it to the dictionary, with the caret
  /// after it.
  void allow(SpellWord w, {required bool add}) {
    close();
    spell.allow(w.word, add: add);
    if (w.end <= _text.text.length) {
      _text.selection = TextSelection.collapsed(offset: w.end);
    }
    spell.focus.requestFocus();
  }

  /// A key in the box while the menu is open: ⏎ takes the first suggestion
  /// and doesn't send, 1 to 4 take that one, Esc closes, and anything else
  /// closes it and goes on to the box. Whether it's used up.
  bool onKey(KeyEvent e) {
    final w = word;
    if (w == null || !controller.isOpen || e is KeyUpEvent) return false;
    final key = LogicalKeyboardKey.collapseSynonyms({e.logicalKey}).first;
    if (_modifiers.contains(key)) return false;
    if (key == LogicalKeyboardKey.escape) {
      close();
      return true;
    }
    if (isSendKey(e)) {
      fixes.isEmpty ? close() : take(w, fixes.first);
      return true;
    }
    final n = _digits.indexOf(key);
    final plain = !HardwareKeyboard.instance.isMetaPressed;
    if (n >= 0 && n < fixes.length && plain) {
      take(w, fixes[n]);
      return true;
    }
    close();
    return false;
  }

  /// ⌘;: the first flagged word after the caret, or the first of all, with
  /// the word being typed judged too.
  Future<void> next() async {
    if (!spell.on) return;
    close();
    await spell.judgeAll();
    final all = _text.marks;
    if (_disposed || all.isEmpty) return;
    final sel = _text.selection;
    final from = sel.isValid ? sel.end : 0;
    await open(all.firstWhere((w) => w.start >= from, orElse: () => all.first));
  }

  /// A press in the box. The suggestions of a right-click are fetched now, so
  /// its menu has them when it shows.
  void pressed(PointerDownEvent e) {
    _pressedAt = e.position;
    if (e.buttons != kSecondaryButton) return;
    if (_flaggedAt(e.position) case final w?) unawaited(_fixesOf(w.word));
  }

  /// A click in the box, after it put the caret there.
  void tapped() {
    final at = _pressedAt;
    if (!spell.on || at == null || !_text.selection.isCollapsed) return;
    if (_flaggedAt(at) case final w?) unawaited(open(w));
  }

  /// The flagged word drawn at [global], not just the nearest place to it as
  /// the caret goes: a click past a line's end isn't on its last word.
  SpellWord? _flaggedAt(Offset global) {
    final box = _field?.renderEditable;
    if (box == null) return null;
    final at = box.globalToLocal(global);
    for (final w in _text.marks) {
      final boxes = box.getBoxesForSelection(
        TextSelection(baseOffset: w.start, extentOffset: w.end),
      );
      if (boxes.any((b) => b.toRect().inflate(2).contains(at))) return w;
    }
    return null;
  }

  /// The box's right-click menu: as ever, but with [EditableTextState]
  /// [field]'s selection on a flagged word (a right-click selects the word
  /// under it), which gets its suggestions on top.
  Widget toolbar(BuildContext context, EditableTextState field) {
    final sel = field.textEditingValue.selection;
    final w = _text.marks
        .where((m) => m.start <= sel.start && sel.end <= m.end)
        .firstOrNull;
    if (w == null || !spell.on) {
      return AdaptiveTextSelectionToolbar.editableText(
        editableTextState: field,
      );
    }
    ContextMenuButtonItem item(String label, VoidCallback run) =>
        ContextMenuButtonItem(
          label: label,
          onPressed: () {
            field.hideToolbar();
            run();
          },
        );
    return FutureBuilder(
      future: _fixesOf(w.word),
      initialData: _guessed[w.word] ?? const <String>[],
      builder: (context, found) => AdaptiveTextSelectionToolbar.buttonItems(
        anchors: field.contextMenuAnchors,
        buttonItems: [
          for (final fix in found.data ?? const <String>[])
            item(fix, () => take(w, fix)),
          item('Ignore', () => allow(w, add: false)),
          item('Add to dictionary', () => allow(w, add: true)),
          ...field.contextMenuButtonItems,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The prompt's field, [child], with what spell check's menu needs around
/// it: the presses it listens for, and the menu over the word. Only where
/// there's a speller: on the phone it's [child] alone.
class SpellArea extends StatelessWidget {
  const new(this.menu, {required this.child, super.key});

  final SpellMenu menu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (speller == null) return child;
    return Stack(
      key: menu._area,
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Listener(onPointerDown: menu.pressed, child: child),
        ListenableBuilder(
          listenable: menu,
          builder: (context, _) => Positioned.fromRect(
            rect: menu.anchor,
            child: Menu(
              controller: menu.controller,
              entries: menu.entries,
              above: true,
              filter: false,
              keepFocus: true,
              builder: (context, _) => const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
