import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/key_rules.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart';

// The keys the user chooses in Settings › Keyboard shortcuts (ADR 0146):
// how one is written in `app.json`, which binding holds which key now
// once the saved choices are settled, and the changes the page makes.
// The key constants stay the defaults; `Cmd.single` asks here.

/// The bindings the user may rebind, by the menus' groups, in the app's
/// order: what Settings › Keyboard shortcuts lists, and the order in which
/// two saved choices of one key settle (the first keeps it). Each is an
/// Act's with a [Act.keyName], listed in its [Act.keysIn] group, in the
/// Acts' order.
final List<(String, List<Cmd>)> shortcutGroups = [
  for (final (title, group) in const [
    ('Nushi', ActMenu.nushi),
    ('File', ActMenu.file),
    ('View', ActMenu.view),
    ('Chat', ActMenu.chat),
    ('Other', null),
  ])
    (
      title,
      [
        for (final a in Act.values)
          if (a.keyName != null && a.keysIn == group) ?(a.key ?? a.shows),
      ],
    ),
];

/// [shortcutGroups]' bindings in one list.
final List<Cmd> rebindable = [for (final (_, keys) in shortcutGroups) ...keys];

/// What Settings › Keyboard shortcuts calls [key]'s binding: its Act's
/// [Act.keyName].
String bindingName(Cmd key) => switch (key.id) {
  final id? => Act.values.byName(id).keyName ?? id,
  null => '',
};

// The text form: `Ctrl+Alt+Shift+Cmd+Super+Key`, only the modifiers held,
// in that order. Cmd is the command key (⌘ on the Mac, Control elsewhere),
// so a choice reads the same on every platform; Ctrl is the Mac's ⌃ and
// Super Linux's. The key is a named one or any one printable character
// (a letter upper-cased), so another layout's symbols work too.

/// F1–F20: the keys that need no modifier.
const functionKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
  LogicalKeyboardKey.f13,
  LogicalKeyboardKey.f14,
  LogicalKeyboardKey.f15,
  LogicalKeyboardKey.f16,
  LogicalKeyboardKey.f17,
  LogicalKeyboardKey.f18,
  LogicalKeyboardKey.f19,
  LogicalKeyboardKey.f20,
];

/// The keys the text form names, by name. `+` is Plus, since `+` joins.
final Map<String, LogicalKeyboardKey> _named = {
  for (final (i, f) in functionKeys.indexed) 'F${i + 1}': f,
  'Tab': LogicalKeyboardKey.tab,
  'Enter': LogicalKeyboardKey.enter,
  'Space': LogicalKeyboardKey.space,
  'Backspace': LogicalKeyboardKey.backspace,
  'Delete': LogicalKeyboardKey.delete,
  'Up': LogicalKeyboardKey.arrowUp,
  'Down': LogicalKeyboardKey.arrowDown,
  'Left': LogicalKeyboardKey.arrowLeft,
  'Right': LogicalKeyboardKey.arrowRight,
  'Home': LogicalKeyboardKey.home,
  'End': LogicalKeyboardKey.end,
  'PageUp': LogicalKeyboardKey.pageUp,
  'PageDown': LogicalKeyboardKey.pageDown,
  'Plus': LogicalKeyboardKey.add,
};

final Map<int, String> _names = {
  for (final MapEntry(:key, :value) in _named.entries) value.keyId: key,
};

/// Whether [k] types one printable character: its id is that character.
bool isPrintable(LogicalKeyboardKey k) =>
    k.keyId & LogicalKeyboardKey.planeMask == LogicalKeyboardKey.unicodePlane &&
    k.keyId > 0x20 &&
    k.keyId != 0x7f;

String? _keyText(LogicalKeyboardKey k) {
  if (_names[k.keyId] case final name?) return name;
  if (!isPrintable(k)) return null;
  final c = String.fromCharCode(k.keyId);
  final upper = c.toUpperCase();
  // A letter whose capital is another length (ß) is written as it is.
  return upper.toLowerCase() == c ? upper : c;
}

LogicalKeyboardKey? _textKey(String text) {
  final lower = text.toLowerCase();
  for (final MapEntry(:key, :value) in _named.entries) {
    if (key.toLowerCase() == lower) return value;
  }
  if (text.runes.length != 1) return null;
  final rune = lower.runes.length == 1 ? lower.runes.single : text.runes.single;
  final k = LogicalKeyboardKey(rune);
  return isPrintable(k) ? k : null;
}

/// [k] in the text form; null for a key it has no word for (Esc).
String? shortcutText(SingleActivator k) {
  final key = _keyText(k.trigger);
  if (key == null) return null;
  final mac = commandKey == CommandKey.meta;
  return [
    if (mac && k.control) 'Ctrl',
    if (k.alt) 'Alt',
    if (k.shift) 'Shift',
    if (mac ? k.meta : k.control) 'Cmd',
    if (!mac && k.meta) 'Super',
    key,
  ].join('+');
}

/// The key [text] (the text form) is held with now; null for an unknown
/// word, no key, or a key without ⌘, ⌃, ⌥ or Super that isn't F1–F20.
SingleActivator? parseShortcut(String text) {
  final parts = text.split('+');
  final mac = commandKey == CommandKey.meta;
  var (control, alt, shift, meta) = (false, false, false, false);
  for (final word in parts.take(parts.length - 1)) {
    switch (word.toLowerCase()) {
      case 'cmd' when mac:
        meta = true;
      case 'cmd' || 'ctrl':
        control = true;
      case 'alt':
        alt = true;
      case 'shift':
        shift = true;
      case 'super':
        meta = true;
      default:
        return null;
    }
  }
  final key = _textKey(parts.last);
  if (key == null) return null;
  // A symbol is kept as written: `%` with ⇧ may be ⇧5 on one layout and
  // another key's on the next (the recorder folds by the key's place).
  if (!control && !alt && !meta && !functionKeys.contains(key)) {
    return null;
  }
  return SingleActivator(
    key,
    control: control,
    alt: alt,
    shift: shift,
    meta: meta,
  );
}

/// The symbols ⇧ makes of a US keyboard's keys, each to its key: a
/// keyboard may report ⇧] as `}`.
const _shifted = {
  '{': '[',
  '}': ']',
  '|': r'\',
  ':': ';',
  '"': "'",
  '<': ',',
  '>': '.',
  '?': '/',
  '~': '`',
  '_': '-',
  '+': '=',
  '!': '1',
  '@': '2',
  '#': '3',
  r'$': '4',
  '%': '5',
  '^': '6',
  '&': '7',
  '*': '8',
  '(': '9',
  ')': '0',
};

final Map<int, int> _toBase = {
  for (final MapEntry(:key, :value) in _shifted.entries)
    key.codeUnitAt(0): value.codeUnitAt(0),
};

final Map<int, int> _toTwin = {
  for (final MapEntry(:key, :value) in _toBase.entries) value: key,
};

/// Where a US keyboard has each key ⇧ makes a symbol of.
final Map<int, PhysicalKeyboardKey> _usPlace = {
  for (final (base, at) in const [
    ('[', PhysicalKeyboardKey.bracketLeft),
    (']', PhysicalKeyboardKey.bracketRight),
    (r'\', PhysicalKeyboardKey.backslash),
    (';', PhysicalKeyboardKey.semicolon),
    ("'", PhysicalKeyboardKey.quote),
    (',', PhysicalKeyboardKey.comma),
    ('.', PhysicalKeyboardKey.period),
    ('/', PhysicalKeyboardKey.slash),
    ('`', PhysicalKeyboardKey.backquote),
    ('-', PhysicalKeyboardKey.minus),
    ('=', PhysicalKeyboardKey.equal),
    ('1', PhysicalKeyboardKey.digit1),
    ('2', PhysicalKeyboardKey.digit2),
    ('3', PhysicalKeyboardKey.digit3),
    ('4', PhysicalKeyboardKey.digit4),
    ('5', PhysicalKeyboardKey.digit5),
    ('6', PhysicalKeyboardKey.digit6),
    ('7', PhysicalKeyboardKey.digit7),
    ('8', PhysicalKeyboardKey.digit8),
    ('9', PhysicalKeyboardKey.digit9),
    ('0', PhysicalKeyboardKey.digit0),
  ])
    base.codeUnitAt(0): at,
};

/// The key a keyboard reported as [k] at [at], with ⇧ held ([shift]): a
/// US symbol ⇧ makes (`}`) is its key (`]`) only where a US keyboard has
/// that key. Elsewhere the symbol is the key: the Mac and GTK report the
/// shifted character for a symbol key whose own is no letter or digit,
/// so on a French keyboard ⇧ù comes as `%`, which is not ⇧5 there.
LogicalKeyboardKey recordedKey(
  LogicalKeyboardKey k,
  PhysicalKeyboardKey at, {
  required bool shift,
}) => switch (shift ? _toBase[k.keyId] : null) {
  final base? when _usPlace[base] == at => LogicalKeyboardKey(base),
  _ => k,
};

/// The symbol ⇧ makes of [base] (`}` of `]`), if it has one.
LogicalKeyboardKey? shiftedTwin(LogicalKeyboardKey base) =>
    switch (_toTwin[base.keyId]) {
      final twin? => LogicalKeyboardKey(twin),
      null => null,
    };

/// Whether [a] and [b] are held the same: the same modifiers and key. A
/// recorded key is already folded ([recordedKey]), so a symbol is only
/// itself.
bool sameKey(SingleActivator a, SingleActivator b) =>
    a.control == b.control &&
    a.shift == b.shift &&
    a.alt == b.alt &&
    a.meta == b.meta &&
    a.trigger == b.trigger;

/// Whether [a] is the second key [b] or its other form: held the same, a
/// US symbol ⇧ makes taken as its key (⇧⌘} is ⇧⌘]), as a keyboard may
/// report either. Only for the second keys, which are US keys: two chosen
/// keys are compared as saved ([sameKey]), since another layout's `?` and
/// `/` are two keys.
bool oneKey(SingleActivator a, SingleActivator b) =>
    sameKey(_unshifted(a), _unshifted(b));

/// [a] with a US symbol ⇧ makes as its key (⇧⌘} as ⇧⌘]).
SingleActivator _unshifted(SingleActivator a) =>
    switch (a.shift ? _toBase[a.trigger.keyId] : null) {
      final base? => SingleActivator(
        LogicalKeyboardKey(base),
        control: a.control,
        shift: true,
        alt: a.alt,
        meta: a.meta,
      ),
      null => a,
    };

/// A binding as settled now: its key (null for none), whether the user's
/// choice decides it (`chosen`: a key, a cleared one, or one taken by an
/// earlier choice), why a saved choice isn't used or its default is gone
/// (`issue`), and what's saved for it (`stored`).
typedef Resolved = ({
  SingleActivator? key,
  bool chosen,
  String? issue,
  String? stored,
});

Map<String, String>? _from;
CommandKey? _fromKey;
bool? _fromAltGr;
Map<String, Resolved> _settled = const {};

/// Every binding settled, kept until the choices or the conventions (a
/// test's) change.
Map<String, Resolved> get _now {
  final saved = shortcutKeys.value;
  if (!identical(saved, _from) ||
      commandKey != _fromKey ||
      conventions.altGr != _fromAltGr) {
    _settled = _settle(saved);
    _from = saved;
    _fromKey = commandKey;
    _fromAltGr = conventions.altGr;
  }
  return _settled;
}

/// The saved choices settled, which can clash without the page: a later
/// release's new default, a hand-edited `app.json`. A chosen key beats a
/// default, the first listed beats a later one, and a saved key that is
/// refused or fixed isn't used: its binding keeps its default and says so.
Map<String, Resolved> _settle(Map<String, String> saved) {
  final settled = <String, Resolved>{};
  final unused = <String, String>{};
  final used = <(Cmd, SingleActivator)>[];
  final asDefault = <String>{};
  for (final b in rebindable) {
    final id = b.id!;
    final text = saved[id];
    if (text == null) continue;
    if (text.isEmpty) {
      settled[id] = (key: null, chosen: true, issue: null, stored: text);
      continue;
    }
    final k = parseShortcut(text);
    if (k == null) continue; // unreadable: the default, the text kept
    // Its own default is no choice: as if nothing were saved (the file
    // is left as it is).
    if (sameKey(k, b.standard)) {
      asDefault.add(id);
      continue;
    }
    if (refusal(k, own: b) case final why?) {
      unused[id] = "Your ${keyLabel(k)} isn't used: $why";
      continue;
    }
    final holder = [
      for (final (h, a) in used)
        if (sameKey(a, k)) h,
    ];
    settled[id] = holder.isEmpty
        ? (key: k, chosen: true, issue: null, stored: text)
        : (
            key: null,
            chosen: true,
            issue:
                'Not used: ${keyLabel(k)} is '
                "${bindingName(holder.first)}'s",
            stored: text,
          );
    if (holder.isEmpty) used.add((b, k));
  }
  for (final b in rebindable) {
    final id = b.id!;
    if (settled.containsKey(id)) continue;
    final stored = asDefault.contains(id) ? null : saved[id];
    final holder = [
      for (final (h, a) in used)
        if (sameKey(a, b.standard)) h,
    ];
    settled[id] = holder.isEmpty
        ? (key: b.standard, chosen: false, issue: unused[id], stored: stored)
        : (
            key: null,
            chosen: false,
            issue:
                'Not used: ${keyLabel(b.standard)} is '
                "${bindingName(holder.first)}'s",
            stored: stored,
          );
  }
  return settled;
}

/// The key binding [id] is held with now: the user's, its default
/// ([standard]), or null for none.
SingleActivator? effectiveKey(String id, SingleActivator standard) =>
    switch (_now[id]) {
      final r? => r.key,
      null => standard,
    };

/// Whether the user's choice decides binding [id]'s key.
bool hasChosenKey(String id) => _now[id]?.chosen ?? false;

/// Binding [id] as settled now.
Resolved resolved(String id) =>
    _now[id] ?? (key: null, chosen: false, issue: null, stored: null);

/// Whether [alias], a second key of binding [of], is bound: only while
/// [of] is on its default and no binding is held with [alias].
bool aliasBound(String of, SingleActivator alias) {
  final now = _now;
  final r = now[of];
  if (r == null || r.chosen || r.key == null) return false;
  return !now.values.any((o) => o.key != null && oneKey(o.key!, alias));
}

/// Whether Settings › Keyboard shortcuts is taking a key: the menu bar's
/// key equivalents are off meanwhile, so the key comes to the page.
final ValueNotifier<bool> shortcutRecording = runValue(false);

/// [change] made to a fresh copy of the choices: one notice, one save.
void _change(void Function(Map<String, String> keys) change) {
  final keys = {...shortcutKeys.value};
  change(keys);
  shortcutKeys.value = keys;
}

/// [key]'s binding held with [chosen], or with none (null); its default
/// takes the entry away.
void chooseKey(Cmd key, SingleActivator? chosen) {
  final id = key.id!;
  if (chosen == null) {
    _change((m) => m[id] = '');
  } else if (sameKey(chosen, key.standard)) {
    _change((m) => m.remove(id));
  } else if (shortcutText(chosen) case final text?) {
    _change((m) => m[id] = text);
  }
}

/// [key]'s binding back on its default.
void resetKey(Cmd key) => _change((m) => m.remove(key.id));

/// [to]'s binding held with [chosen], which [from]'s had: [from]'s is
/// left with none. One change, one save.
void takeKey(Cmd to, SingleActivator chosen, Cmd from) => _change((m) {
  m[from.id!] = '';
  if (sameKey(chosen, to.standard)) {
    m.remove(to.id);
  } else if (shortcutText(chosen) case final text?) {
    m[to.id!] = text;
  }
});

/// Every listed binding back on its default; a name this app doesn't
/// know (a newer one's) is kept.
void resetAllKeys() => _change((m) {
  for (final b in rebindable) {
    m.remove(b.id);
  }
});
