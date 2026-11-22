import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/conventions.dart' show CommandKey;
import 'package:nushi/key_choice.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// Settings › Keyboard shortcuts' search (ADR 0146): its field, and what a
// row's words and keys match.

/// The words a person types for a modifier or a key, each to the one the
/// match compares: ⌘, command and cmd alike.
const _same = {
  '⌘': 'cmd',
  'command': 'cmd',
  '⌃': 'ctrl',
  'control': 'ctrl',
  '⌥': 'alt',
  'opt': 'alt',
  'option': 'alt',
  '⇧': 'shift',
  'escape': 'esc',
  'return': 'enter',
  '⏎': 'enter',
  '⇥': 'tab',
  '↑': 'up',
  '↓': 'down',
  '←': 'left',
  '→': 'right',
  '⌫': 'backspace',
  '⌦': 'delete',
  '⇞': 'pageup',
  '⇟': 'pagedown',
  '↖': 'home',
  '↘': 'end',
  'del': 'delete',
  'pgup': 'pageup',
  'pgdn': 'pagedown',
};

String _word(String w) => _same[w] ?? w;

/// The Mac's key glyphs, each a word of its own however it's typed
/// ("⇧⌘P" is shift, cmd and p).
final _glyph = RegExp('[⌘⌃⌥⇧⏎⇥↑↓←→⌫⌦⇞⇟↖↘]');

/// [query]'s words, case aside, a space and `+` alike.
List<String> _words(String query) => query
    .toLowerCase()
    .replaceAll('+', ' ')
    .replaceAllMapped(_glyph, (m) => ' ${m[0]} ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// The words [k] is known by: its modifiers' and its key's, as the page
/// shows it (`keyLabel`) and in the text form (`shortcutText`).
Set<String> _keyWords(SingleActivator k) => {
  if (k.control) 'ctrl',
  if (k.alt) 'alt',
  if (k.shift) 'shift',
  if (k.meta && commandKey == CommandKey.meta) 'cmd',
  if (k.meta && commandKey != CommandKey.meta) 'super',
  for (final text in [?shortcutText(k), keyLabel(k)])
    for (final w in _words(text)) _word(w),
  for (final w in _words(keyName(k.trigger))) _word(w),
  // A key of two words as one ("pageup").
  _word(keyName(k.trigger).toLowerCase().replaceAll(' ', '')),
};

/// Whether a row named [name] in [group], its keys [keys], shows for
/// [query]: every word typed in its name or its group's ("tab", "view"),
/// or every word one of its keys' as shown or in words ("⌘K", "⌃⇥",
/// "cmd k", "ctrl tab", "esc"; a word of two letters or more may be a key
/// word's start, a single letter is the key itself). A key's words are
/// whole: "ctrl s" doesn't find Ctrl+Shift+P.
bool shortcutMatches(
  String query, {
  required String name,
  required String group,
  required Iterable<SingleActivator> keys,
}) {
  final words = _words(query);
  if (words.isEmpty) return true;
  final names = '$group $name'.toLowerCase();
  if (words.every(names.contains)) return true;
  for (final k in keys) {
    final known = _keyWords(k);
    bool has(String w) =>
        known.contains(w) ||
        (w.length > 1 && known.any((k) => k.startsWith(w)));
    if (words.map(_word).every(has)) return true;
  }
  return false;
}

/// The page's search field, its whole column wide: a search icon, its
/// hint, and × to empty it once it holds text. Esc empties it too, and
/// only in an empty field goes on to Settings (which closes).
class ShortcutSearchField extends StatelessWidget {
  const new({required this.controller, super.key, this.focusNode});

  final TextEditingController controller;

  /// Its focus, for the page to move the keyboard to it.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    // Its height and icons grow with the text, as its hint does.
    final scale = MediaQuery.textScalerOf(context);
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => CallbackShortcuts(
        bindings: {
          if (value.text.isNotEmpty)
            const SingleActivator(LogicalKeyboardKey.escape): controller.clear,
        },
        child: SizedBox(
          height: max(26, (scale.scale(12) + 14).roundToDouble()),
          child: TextField(
            key: const ValueKey('shortcuts-search'),
            controller: controller,
            focusNode: focusNode,
            style: theme.ui(t.text, size: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search actions and keys',
              prefixIcon: Icon(
                Icons.search,
                size: scale.scale(14),
                color: t.textMuted,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 26),
              suffixIcon: value.text.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: IconTap(
                        Icons.close,
                        key: const ValueKey('shortcuts-search-clear'),
                        tooltip: 'Clear search',
                        size: scale.scale(14),
                        padding: 4,
                        onTap: controller.clear,
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }
}
