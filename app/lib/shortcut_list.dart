import 'dart:math' show max;

import 'package:flutter/widgets.dart';

import 'package:nushi/app_actions.dart' show secondKeys;
import 'package:nushi/controls.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/key_rules.dart';
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
      for (final f in fixedKeys())
        (label: f.label, binding: null, keys: f.shown, match: f.keys),
    ],
  ),
];

/// The key bound beside [key]'s own (Chrome's tab keys, ⇧⌘P for the
/// palette), shown in its row. It can't be changed: it goes when the
/// action gets a chosen key or another binding takes it (ADR 0146), and
/// then reads '' and isn't shown. ⇧⌘} and ⇧⌘{ are the same keys as a
/// keyboard may report them, so not shown apart.
Cmd? secondKeyOf(Cmd key) =>
    secondKeys.where((a) => a.aliasOf == key.id).firstOrNull;

/// A key the page lists but doesn't let change: its [label] and [keys]
/// on a quiet cap where a binding's would be, with no hover, hand or
/// focus.
class FixedShortcutRow extends StatelessWidget {
  const new({
    required this.label,
    required this.keys,
    super.key,
    this.lane = 0,
  });

  final String label;
  final String keys;

  /// The group's caps' room ([ShortcutRow.lane]).
  final double lane;

  @override
  Widget build(BuildContext context) => ShortcutRow(
    key: ValueKey('shortcut-fixed-$label'),
    label: label,
    slots: false,
    lane: lane,
    cap: KeyCapButton(keys),
  );
}

/// The room [g]'s caps take, its widest's ([ShortcutRow.lane]), measured
/// in [context], whatever a search shows of it.
double shortcutLane(BuildContext context, ShortcutGroup g) => [
  for (final e in g.rows)
    KeyCapButton.widthOf(context, switch (e.binding) {
      final b? => keyLabel(b),
      null => e.keys,
    }),
].fold(KeyCapButton.minWidth, max);
