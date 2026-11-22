import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/app_actions.dart' show paletteKeyToo, quitKey;
import 'package:nushi/chat_keys.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/shortcut_row.dart';

// Settings › Keyboard shortcuts' list (ADR 0146): its groups and rows in
// the page's order, the keys a search finds each by, and the fixed keys'
// rows.

/// A row of the page: a binding's, which can change, or a fixed key's,
/// its keys as the page shows them, and the keys a search matches it by
/// (a binding's own and its second key).
typedef ShortcutEntry = ({
  String label,
  Cmd? binding,
  String keys,
  List<SingleActivator> match,
});

/// A group of the page's rows, as a `SettingsGroup` shows it.
typedef ShortcutGroup = ({
  String title,
  String? about,
  List<ShortcutEntry> rows,
});

/// Every group and its rows, in the page's order: the menus' groups, then
/// the fixed keys.
List<ShortcutGroup> shortcutGroupsShown() => [
  for (final (name, keys) in shortcutGroups)
    (
      title: name,
      about: null,
      rows: [
        for (final k in keys)
          (
            label: bindingName(k),
            binding: k,
            keys: keyLabel(k),
            match: [?k.single, ?secondKeyOf(k)?.single],
          ),
      ],
    ),
  (
    title: 'Fixed',
    about: "These keys can't be changed",
    rows: [
      for (final (label, keys, match) in _fixed())
        (label: label, binding: null, keys: keys, match: match),
    ],
  ),
];

/// The key bound beside [key]'s own (Chrome's tab keys, ⇧⌘P for the
/// palette), shown in its row. It can't be changed: it goes when the
/// action gets a chosen key or another binding takes it (ADR 0146), and
/// then reads '' and isn't shown. ⇧⌘} and ⇧⌘{ are the same keys as a
/// keyboard may report them, so not shown apart.
Cmd? secondKeyOf(Cmd key) => [
  previousTabKeysToo.first,
  nextTabKeysToo.first,
  paletteKeyToo,
].where((a) => a.aliasOf == key.id).firstOrNull;

/// The keys the page shows but doesn't let change: Esc's, the chats' and
/// terminals' numbers, Quit; each as shown and every key it stands for.
List<(String, String, List<SingleActivator>)> _fixed() {
  const esc = SingleActivator(LogicalKeyboardKey.escape);
  final digits = [for (var n = 1; n <= 9; n++) n];
  return [
    ('Stop', 'Esc', [esc]),
    ('Rewind', 'Esc Esc', [esc]),
    (
      'Open chat 1–9',
      '${keyLabel(chatNumberKey(1))}–${keyLabel(chatNumberKey(9))}',
      [for (final n in digits) ?chatNumberKey(n).single],
    ),
    (
      'Terminal 1–9',
      '${keyLabel(altDigitKey(1))}–${keyLabel(altDigitKey(9))}',
      [for (final n in digits) ?altDigitKey(n).single],
    ),
    ('Quit', keyLabel(quitKey), [?quitKey.single]),
  ];
}

/// A key the page lists but doesn't let change: its [label] and [keys]
/// on a quiet cap where a binding's would be, with no hover, hand or
/// focus.
class FixedShortcutRow extends StatelessWidget {
  const new({required this.label, required this.keys, super.key});

  final String label;
  final String keys;

  @override
  Widget build(BuildContext context) => ShortcutRow(
    key: ValueKey('shortcut-fixed-$label'),
    label: label,
    slots: false,
    cap: KeyCapButton(keys),
  );
}
