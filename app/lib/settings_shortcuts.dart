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
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// Settings › Keyboard shortcuts (ADR 0146): every key the user may
// change, by the menus' groups, each a field that records a new one, its
// clear and reset; a clash offered to take, a key the system or a field
// owns refused with why; and the keys that stay as they are, read-only at
// the end, so the page is a cheat sheet too.

/// The key field's width beside its label.
const _fieldWidth = 168.0;

/// A row's width (inside its padding) under which its key goes under the
/// label: beside, a clash's buttons, the field and a line of words need
/// it.
const _stackBelow = 620.0;

/// The controls' height: a button's, the field's, a little more.
const _controlHeight = 34.0;

/// The room a clear or reset button keeps, shown or not.
const _slot = 28.0;

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
      if (b.single case final a? when oneKey(a, k)) return b;
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
        for (final (name, keys) in shortcutGroups)
          SettingsGroup(title: name, children: [for (final k in keys) _row(k)]),
        SettingsGroup(
          title: 'Second keys',
          about: 'Each works while its action keeps its default key',
          children: [
            for (final (label, key) in _secondKeys())
              _FixedRow(label: label, keys: keyLabel(key), group: 'second'),
          ],
        ),
        SettingsGroup(
          title: 'Fixed',
          about: "These keys can't be changed",
          children: [
            for (final (label, keys) in _fixed())
              _FixedRow(label: label, keys: keys),
          ],
        ),
      ],
    ),
  );

  Widget _row(Cmd key) {
    final r = resolved(key.id!);
    final pending = _pending?.key.id == key.id ? _pending : null;
    final refused = _refused?.key.id == key.id ? _refused : null;
    void cancel() => _done(key);
    final row = _KeyRow(
      binding: key,
      settled: r,
      pending: pending,
      refused: refused,
      field: _field(key),
      cancelFocus: _cancel,
      onKey: (k) => _propose(key, k),
      onStart: () => setState(() {
        _pending = null;
        _refused = null;
      }),
      onClear: () => _clear(key),
      onReset: () => _reset(key),
      onTake: pending == null ? null : () => _take(pending),
      onCancel: cancel,
    );
    // Esc drops a clash or a refusal, not Settings. Always there, empty or
    // not, so the row's field keeps its state as one comes and goes.
    return CallbackShortcuts(
      bindings: {
        if (pending != null || refused != null)
          const SingleActivator(LogicalKeyboardKey.escape): cancel,
      },
      child: row,
    );
  }
}

/// The keys bound beside an action's own (Chrome's tab keys, ⇧⌘P for the
/// palette), shown so the page is the whole list. They can't be changed:
/// each goes when its action gets a chosen key or another binding takes
/// it (ADR 0146), and then reads Off. ⇧⌘} and ⇧⌘{ are the same keys as
/// a keyboard may report them, so not rows of their own.
List<(String, Cmd)> _secondKeys() => [
  ('Previous tab', previousTabKeysToo.first),
  ('Next tab', nextTabKeysToo.first),
  ('Command palette', paletteKeyToo),
];

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

/// One binding's row: its name, a line under it (a clash, a refusal, why
/// a saved key isn't used, or what a focused terminal does with it), and
/// its controls: its key's field, at the group's edge (or under the label
/// at the left, narrow), and beside it the pill, Reset and Clear, or a
/// clash's Take it and Cancel. Each keeps its place whatever the others
/// show.
class _KeyRow extends StatelessWidget {
  const new({
    required this.binding,
    required this.settled,
    required this.pending,
    required this.refused,
    required this.field,
    required this.cancelFocus,
    required this.onKey,
    required this.onStart,
    required this.onClear,
    required this.onReset,
    required this.onTake,
    required this.onCancel,
  });

  final Cmd binding;
  final Resolved settled;
  final _Pending? pending;
  final _Refused? refused;
  final FocusNode field;
  final FocusNode cancelFocus;
  final ValueChanged<SingleActivator> onKey;
  final VoidCallback onStart;
  final VoidCallback onClear;
  final VoidCallback onReset;
  final VoidCallback? onTake;
  final VoidCallback onCancel;

  String get _id => binding.id!;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final r = settled;
    final (String? line, Color? color) = switch ((pending, refused)) {
      // The field still shows the row's key: the line names the one
      // pressed.
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
    return LayoutBuilder(
      builder: (context, box) {
        // As SettingsRow decides it, inside its padding.
        final inner = box.maxWidth - 28;
        final stacked = inner < _stackBelow;
        return SettingsRow(
          bindingName(binding),
          key: ValueKey('shortcut-row-$_id'),
          description: line,
          descriptionColor: color,
          keepDescriptionLine: true,
          stackBelow: _stackBelow,
          // One height whatever shows beside the field, so it never
          // shifts.
          control: SizedBox(
            height: _controlHeight,
            child: stacked
                ? _stacked(context, inner)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [..._actions(context), _field(_fieldWidth)],
                  ),
          ),
        );
      },
    );
  }

  /// Narrow: the field at the label's left, as wide as beside it on every
  /// row, so its key is never shrunk past reading; the rest after it in
  /// the reverse order, so each keeps its place there too. A clash's
  /// pill gives way to its buttons where the row has no room for both:
  /// the line under the label names the clash.
  Widget _stacked(BuildContext context, double inner) {
    final actions = _actions(context).reversed.toList();
    return SizedBox(
      width: inner,
      child: Row(
        spacing: 8,
        children: [
          _field(_fieldWidth),
          Expanded(
            child: pending != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: GivesWay(
                      gap: 8,
                      lead: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: actions.sublist(0, 2),
                      ),
                      extra: actions.last,
                    ),
                  )
                : Row(
                    spacing: 8,
                    children: [
                      for (final a in actions)
                        if (a is NotePill) Flexible(child: a) else a,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Its field, keyed by its focus so it keeps its state (listening, its
  /// ring) when the window crosses [_stackBelow] and it moves.
  Widget _field(double width) => KeyedSubtree(
    key: GlobalObjectKey(field),
    child: ShortcutField(
      key: ValueKey('shortcut-key-$_id'),
      label: keyLabel(binding),
      focusNode: field,
      width: width,
      onKey: onKey,
      onStart: onStart,
    ),
  );

  /// The controls beside the field, in the order they stand before it.
  List<Widget> _actions(BuildContext context) {
    if (pending != null) {
      return [
        const NotePill('In use', tone: NoteTone.needs),
        Button(
          key: ValueKey('shortcut-take-$_id'),
          label: 'Take it',
          kind: ButtonKind.primary,
          onPressed: onTake,
        ),
        Button(
          key: ValueKey('shortcut-cancel-$_id'),
          label: 'Cancel',
          kind: ButtonKind.quiet,
          focusNode: cancelFocus,
          onPressed: onCancel,
        ),
      ];
    }
    final r = settled;
    final pill = refused != null
        ? const NotePill('Not allowed', tone: NoteTone.crashed)
        : r.issue != null
        ? const NotePill('Not used', tone: NoteTone.needs)
        : r.chosen
        ? const NotePill('Edited', tone: NoteTone.accent)
        : null;
    return [
      ?pill,
      _slotted(
        // Saved, or its default another binding's chosen key holds:
        // Reset offers to take it back.
        r.stored != null || (!r.chosen && r.key == null),
        IconTap(
          Icons.restart_alt,
          key: ValueKey('shortcut-reset-$_id'),
          tooltip: 'Back to ${keyLabel(binding.standard)}',
          onTap: onReset,
        ),
      ),
      _slotted(
        r.key != null,
        IconTap(
          Icons.close,
          key: ValueKey('shortcut-clear-$_id'),
          tooltip: 'No key',
          onTap: onClear,
        ),
      ),
    ];
  }

  /// [button] in its slot, which keeps its room when it isn't [shown].
  Widget _slotted(bool shown, Widget button) => SizedBox(
    width: _slot,
    height: _slot,
    child: shown ? Center(child: button) : null,
  );
}

/// A key the page lists but doesn't let change: its [label] and [keys],
/// where a binding's field would show its key, in the same width.
class _FixedRow extends StatelessWidget {
  const new({required this.label, required this.keys, this.group = 'fixed'});

  final String label;
  final String keys;

  /// Its key's prefix, so a label two groups share stays two rows.
  final String group;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return SettingsRow(
      label,
      key: ValueKey('shortcut-$group-$label'),
      control: SizedBox(
        width: _fieldWidth,
        height: ShortcutField.height,
        child: Center(
          // An empty label is a second key that's gone.
          child: keys.isEmpty
              ? Text(
                  'Off',
                  maxLines: 1,
                  style: theme.ui(theme.t.textMuted, size: 12),
                )
              : keyText(keys, theme.code(theme.t.textSecondary, size: 12)),
        ),
      ),
    );
  }
}

/// A refusal's line: the key pressed and why, unless the reason names it
/// (a fixed key's: "⌘1 opens a chat").
String _refusedLine(_Refused f) {
  final label = keyLabel(f.pressed);
  return f.reason.startsWith(label) ? f.reason : '$label: ${f.reason}';
}
