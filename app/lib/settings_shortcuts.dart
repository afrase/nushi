import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart' show paletteKeyToo, quitKey;
import 'package:nushi/chat_keys.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/key_rules.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/shortcut_field.dart';
import 'package:nushi/shortcut_row.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// Settings › Keyboard shortcuts (ADR 0146): every key the user may
// change, by the menus' groups, one line each as desktop apps' keymaps
// are: its name, its key as a cap that records a new one, Reset and No
// key beside it, and an action's second key in its row; a clash offered
// to take, a key the system or a field owns refused with why, on a line
// under the name; and the keys that stay as they are, read-only at the
// end, so the page is a cheat sheet too.

/// A key another binding holds, waiting on Take it or Cancel; alias:
/// it's the holder's second key, which goes once the key's binding has
/// it.
typedef _Pending = ({Cmd key, SingleActivator chosen, Cmd holder, bool alias});

/// A binding's row that refused the key pressed, and why.
typedef _Refused = ({Cmd key, SingleActivator pressed, String reason});

/// Settings › Keyboard shortcuts.
class ShortcutsSection extends StatefulWidget {
  const new({super.key});

  @override
  State<ShortcutsSection> createState() => _ShortcutsSectionState();
}

class _ShortcutsSectionState extends State<ShortcutsSection> {
  _Pending? _pending;
  _Refused? _refused;
  final _fields = <String, FocusNode>{};
  final _caps = <String, GlobalKey<ShortcutFieldState>>{};
  final _cancel = FocusNode(debugLabel: 'shortcut-cancel');

  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    _cancel.dispose();
    super.dispose();
  }

  FocusNode _field(Cmd key) => _fields.putIfAbsent(
    key.id!,
    () => FocusNode(debugLabel: 'shortcut-${key.id}'),
  );

  /// [key]'s cap, so a click on its row makes it listen.
  GlobalKey<ShortcutFieldState> _cap(Cmd key) =>
      _caps.putIfAbsent(key.id!, GlobalKey<ShortcutFieldState>.new);

  /// Drops a clash or a refusal; [key]'s field gets the focus back, so a
  /// keyboard user keeps their row when the button they pressed goes.
  void _done(Cmd key) {
    setState(() {
      _pending = null;
      _refused = null;
    });
    _field(key).requestFocus();
  }

  /// The binding other than [key] whose key is [k] now.
  Cmd? _holder(Cmd key, SingleActivator k) {
    for (final b in rebindable) {
      if (b.id == key.id) continue;
      if (b.single case final a? when sameKey(a, k)) return b;
    }
    return null;
  }

  /// The binding other than [key] whose second key, bound now, is [k].
  Cmd? _aliasHolder(Cmd key, SingleActivator k) {
    for (final a in [...nextTabKeysToo, ...previousTabKeysToo, paletteKeyToo]) {
      if (a.aliasOf == key.id) continue; // its own: no clash
      if (a.single case final s? when oneKey(s, k)) {
        return rebindable.firstWhere((b) => b.id == a.aliasOf);
      }
    }
    return null;
  }

  void _pend(Cmd key, SingleActivator k, Cmd holder, {required bool alias}) {
    setState(
      () => _pending = (key: key, chosen: k, holder: holder, alias: alias),
    );
    // Take it clears another binding: the keyboard lands on Cancel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pending != null) _cancel.requestFocus();
    });
  }

  void _refuse(Cmd key, SingleActivator pressed, String reason) =>
      setState(() => _refused = (key: key, pressed: pressed, reason: reason));

  /// What [k], recorded on [key]'s row (or its default, by Reset), does:
  /// nothing is changed behind the user's back.
  void _propose(Cmd key, SingleActivator k) {
    setState(() {
      _pending = null;
      _refused = null;
    });
    // Its own default: back to it, unless another binding has it now.
    if (sameKey(k, key.standard)) {
      if (_holder(key, k) case final h?) return _pend(key, k, h, alias: false);
      if (_aliasHolder(key, k) case final h?) {
        return _pend(key, k, h, alias: true);
      }
      if (resolved(key.id!).stored != null) resetKey(key);
      return;
    }
    if (refusal(k, own: key) case final why?) return _refuse(key, k, why);
    if (key.single case final now? when sameKey(now, k)) return;
    if (fixedReason(k) case final why?) return _refuse(key, k, why);
    if (_holder(key, k) case final h?) return _pend(key, k, h, alias: false);
    if (_aliasHolder(key, k) case final h?) {
      return _pend(key, k, h, alias: true);
    }
    chooseKey(key, k);
  }

  void _take(_Pending p) {
    if (p.alias) {
      chooseKey(p.key, p.chosen); // the second key goes by itself
    } else {
      takeKey(p.key, p.chosen, p.holder);
    }
    _done(p.key);
  }

  void _clear(Cmd key) {
    chooseKey(key, null);
    _done(key);
  }

  void _reset(Cmd key) {
    _propose(key, key.standard);
    _field(key).requestFocus();
  }

  Future<void> _resetAll() async {
    final yes = await confirm(
      context,
      'Reset all keys?',
      'Every key goes back to its default.',
      'Reset all',
      destructive: true,
    );
    if (!yes || !mounted) return;
    resetAllKeys();
    // The button goes off, which would leave the keyboard nowhere: the
    // first row's field gets it.
    _done(shortcutGroups.first.$2.first);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: shortcutKeys,
    builder: (context, saved, _) => SettingsPage(
      title: 'Keyboard shortcuts',
      actions: [
        // Off rather than gone, so it never moves.
        Button(
          key: const ValueKey('shortcuts-reset-all'),
          label: 'Reset all to defaults',
          onPressed: rebindable.any((b) => saved.containsKey(b.id))
              ? () => unawaited(_resetAll())
              : null,
        ),
      ],
      children: [
        for (final g in _groups())
          if (g.rows.where(_shows).toList() case final rows
              when rows.isNotEmpty)
            SettingsGroup(
              title: g.title,
              about: g.about,
              children: [
                for (final e in rows)
                  if (e.binding case final b?)
                    _row(context, b)
                  else
                    _FixedRow(label: e.label, keys: e.keys),
              ],
            ),
      ],
    ),
  );

  /// Whether [e]'s row shows: the one place that narrows the list (every
  /// row shows, but a group left with none isn't drawn).
  bool _shows(_Entry e) => true;

  Widget _row(BuildContext context, Cmd key) {
    final t = NushiTheme.of(context).t;
    final id = key.id!;
    final r = resolved(id);
    final pending = _pending?.key.id == id ? _pending : null;
    final refused = _refused?.key.id == id ? _refused : null;
    void cancel() => _done(key);
    final (String? line, Color? color) = switch ((pending, refused)) {
      // The cap still shows the row's key: the line names the one pressed.
      (final p?, _) when p.alias => (
        "${keyLabel(p.chosen)} is ${bindingName(p.holder)}'s second key",
        t.needs,
      ),
      (final p?, _) => (
        '${bindingName(p.holder)} has ${keyLabel(p.chosen)}',
        t.needs,
      ),
      (_, final f?) => (_refusedLine(f), t.crashed),
      _ when r.issue != null => (r.issue, t.needs),
      _ => (r.chosen && r.key != null ? note(r.key!) : null, null),
    };
    final second = _secondOf(key);
    final secondKeys = second == null ? '' : keyLabel(second);
    final row = ShortcutRow(
      key: ValueKey('shortcut-row-$id'),
      label: bindingName(key),
      onTap: () => _cap(key).currentState?.listen(),
      // Gone once it stops working: the action has a chosen key, or
      // another holds it.
      second: secondKeys.isEmpty
          ? null
          : tooltip(
              context,
              'Second key: works while ${bindingName(key)} keeps its '
              'default key',
              ShortcutCap(secondKeys, key: ValueKey('shortcut-second-$id')),
            ),
      // Saved, or its default another binding's chosen key holds: Reset
      // offers to take it back.
      reset: r.stored != null || (!r.chosen && r.key == null)
          ? IconTap(
              Icons.restart_alt,
              key: ValueKey('shortcut-reset-$id'),
              tooltip: 'Back to ${keyLabel(key.standard)}',
              onTap: () => _reset(key),
            )
          : null,
      clear: r.key != null
          ? IconTap(
              Icons.close,
              key: ValueKey('shortcut-clear-$id'),
              tooltip: 'No key',
              onTap: () => _clear(key),
            )
          : null,
      line: line,
      lineColor: color,
      lineEnd: [
        if (pending != null) ...[
          Button(
            key: ValueKey('shortcut-take-$id'),
            label: 'Take it',
            kind: ButtonKind.primary,
            onPressed: () => _take(pending),
          ),
          Button(
            key: ValueKey('shortcut-cancel-$id'),
            label: 'Cancel',
            kind: ButtonKind.quiet,
            focusNode: _cancel,
            onPressed: cancel,
          ),
        ],
      ],
      cap: KeyedSubtree(
        key: ValueKey('shortcut-key-$id'),
        child: ShortcutField(
          key: _cap(key),
          label: keyLabel(key),
          chosen: r.chosen,
          focusNode: _field(key),
          onKey: (k) => _propose(key, k),
          onStart: () => setState(() {
            _pending = null;
            _refused = null;
          }),
        ),
      ),
    );
    // Esc drops a clash or a refusal, not Settings. Always there, empty or
    // not, so the row keeps its state as one comes and goes.
    return CallbackShortcuts(
      bindings: {
        if (pending != null || refused != null)
          const SingleActivator(LogicalKeyboardKey.escape): cancel,
      },
      child: row,
    );
  }
}

/// A row of the page: a binding's, which can change, or a fixed key's,
/// its keys as the page shows them.
typedef _Entry = ({String label, Cmd? binding, String keys});

/// A group of the page's rows, as a [SettingsGroup] shows it.
typedef _Group = ({String title, String? about, List<_Entry> rows});

/// Every group and its rows, in the page's order: the menus' groups, then
/// the fixed keys.
List<_Group> _groups() => [
  for (final (name, keys) in shortcutGroups)
    (
      title: name,
      about: null,
      rows: [
        for (final k in keys)
          (label: bindingName(k), binding: k, keys: keyLabel(k)),
      ],
    ),
  (
    title: 'Fixed',
    about: "These keys can't be changed",
    rows: [
      for (final (label, keys) in _fixed())
        (label: label, binding: null, keys: keys),
    ],
  ),
];

/// The key bound beside [key]'s own (Chrome's tab keys, ⇧⌘P for the
/// palette), shown in its row. It can't be changed: it goes when the
/// action gets a chosen key or another binding takes it (ADR 0146), and
/// then reads '' and isn't shown. ⇧⌘} and ⇧⌘{ are the same keys as a
/// keyboard may report them, so not shown apart.
Cmd? _secondOf(Cmd key) => [
  previousTabKeysToo.first,
  nextTabKeysToo.first,
  paletteKeyToo,
].where((a) => a.aliasOf == key.id).firstOrNull;

/// The keys the page shows but doesn't let change: Esc's, the chats' and
/// terminals' numbers, Quit.
List<(String, String)> _fixed() => [
  ('Stop', 'Esc'),
  ('Rewind', 'Esc Esc'),
  (
    'Open chat 1–9',
    '${keyLabel(chatNumberKey(1))}–${keyLabel(chatNumberKey(9))}',
  ),
  ('Terminal 1–9', '${keyLabel(altDigitKey(1))}–${keyLabel(altDigitKey(9))}'),
  ('Quit', keyLabel(quitKey)),
];

/// A key the page lists but doesn't let change: its [label] and [keys]
/// on a quiet cap where a binding's would be, with no hover, hand or
/// focus.
class _FixedRow extends StatelessWidget {
  const new({required this.label, required this.keys});

  final String label;
  final String keys;

  @override
  Widget build(BuildContext context) => ShortcutRow(
    key: ValueKey('shortcut-fixed-$label'),
    label: label,
    slots: false,
    cap: ShortcutCap(keys),
  );
}

/// A refusal's line: the key pressed and why, unless the reason names it
/// (a fixed key's: "⌘1 opens a chat").
String _refusedLine(_Refused f) {
  final label = keyLabel(f.pressed);
  return f.reason.startsWith(label) ? f.reason : '$label: ${f.reason}';
}
