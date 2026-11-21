import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/app_actions.dart' show quitKey;
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/keys.dart';

// Which keys the user may choose in Settings › Keyboard shortcuts, and why
// not the rest (ADR 0146): the system's, an input method's, a text
// field's own (it would lose it: the app's keys sit closer to the focus
// than Flutter's text editing shortcuts, flutter's
// `widgets/default_text_editing_shortcuts.dart`), and a character ⌥
// types. Some (⌘Tab, ⌘Space, ⇧⌘3–5) never reach the app on a Mac; they
// are listed for the record. And what a focused terminal does with one.

/// ⌘ keys macOS keeps for itself, its apps' menus and the screenshots.
const _macSystem = [
  SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
  SingleActivator(LogicalKeyboardKey.keyQ, meta: true, shift: true),
  SingleActivator(LogicalKeyboardKey.keyQ, meta: true, control: true),
  SingleActivator(LogicalKeyboardKey.keyQ, meta: true, shift: true, alt: true),
  SingleActivator(LogicalKeyboardKey.keyH, meta: true),
  SingleActivator(LogicalKeyboardKey.keyH, meta: true, alt: true),
  SingleActivator(LogicalKeyboardKey.keyM, meta: true),
  SingleActivator(LogicalKeyboardKey.keyD, meta: true, alt: true),
  SingleActivator(LogicalKeyboardKey.tab, meta: true),
  SingleActivator(LogicalKeyboardKey.tab, meta: true, shift: true),
  SingleActivator(LogicalKeyboardKey.tab, meta: true, alt: true),
  SingleActivator(LogicalKeyboardKey.tab, meta: true, alt: true, shift: true),
  SingleActivator(LogicalKeyboardKey.backquote, meta: true),
  SingleActivator(LogicalKeyboardKey.backquote, meta: true, shift: true),
  SingleActivator(LogicalKeyboardKey.space, meta: true),
  SingleActivator(LogicalKeyboardKey.space, meta: true, alt: true),
  SingleActivator(LogicalKeyboardKey.digit3, meta: true, shift: true),
  SingleActivator(LogicalKeyboardKey.digit4, meta: true, shift: true),
  SingleActivator(LogicalKeyboardKey.digit5, meta: true, shift: true),
  SingleActivator(
    LogicalKeyboardKey.digit3,
    meta: true,
    shift: true,
    control: true,
  ),
  SingleActivator(
    LogicalKeyboardKey.digit4,
    meta: true,
    shift: true,
    control: true,
  ),
];

/// The Mac's editing keys every text field has.
const _macField = [
  SingleActivator(LogicalKeyboardKey.keyC, meta: true),
  SingleActivator(LogicalKeyboardKey.keyV, meta: true),
  SingleActivator(LogicalKeyboardKey.keyX, meta: true),
  SingleActivator(LogicalKeyboardKey.keyA, meta: true),
  SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
  SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
];

/// The letters ⌃ moves or edits with in a Mac's text field (Emacs's, in
/// Flutter's map and Cocoa's text bindings).
const _macControlLetters = <LogicalKeyboardKey>[
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyB,
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.keyE,
  LogicalKeyboardKey.keyF,
  LogicalKeyboardKey.keyH,
  LogicalKeyboardKey.keyK,
  LogicalKeyboardKey.keyN,
  LogicalKeyboardKey.keyO,
  LogicalKeyboardKey.keyP,
  LogicalKeyboardKey.keyT,
  LogicalKeyboardKey.keyV,
  LogicalKeyboardKey.keyY,
];

/// The editing keys every text field has on Linux and Windows (Ctrl+Insert
/// too, which the text form has no word for, so it's refused anyway).
const _linuxField = [
  SingleActivator(LogicalKeyboardKey.keyC, control: true),
  SingleActivator(LogicalKeyboardKey.keyV, control: true),
  SingleActivator(LogicalKeyboardKey.keyX, control: true),
  SingleActivator(LogicalKeyboardKey.keyA, control: true),
  SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
  SingleActivator(LogicalKeyboardKey.keyY, control: true),
];

/// Keys Linux's desktops and Windows keep (Alt+Space opens the window's
/// menu in GNOME, KDE and Windows).
const _linuxSystem = [
  SingleActivator(LogicalKeyboardKey.space, alt: true),
  SingleActivator(LogicalKeyboardKey.tab, alt: true),
  SingleActivator(LogicalKeyboardKey.tab, alt: true, shift: true),
  SingleActivator(LogicalKeyboardKey.f4, alt: true),
  SingleActivator(LogicalKeyboardKey.delete, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.keyT, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.keyL, control: true, alt: true),
];

/// Keys Linux's desktops keep that Windows doesn't: GNOME's and KDE's
/// Alt+F1 and Alt+F2 (the launcher, Run), mutter's Alt+F7, Alt+F8 and
/// Alt+F10 (move, resize, maximize), GNOME's Alt+` (the app's windows),
/// Ctrl+Alt+Tab, and Ctrl+Alt+F1–F12 (a text console).
const _linuxDesktop = [
  SingleActivator(LogicalKeyboardKey.f1, alt: true),
  SingleActivator(LogicalKeyboardKey.f2, alt: true),
  SingleActivator(LogicalKeyboardKey.f7, alt: true),
  SingleActivator(LogicalKeyboardKey.f8, alt: true),
  SingleActivator(LogicalKeyboardKey.f10, alt: true),
  SingleActivator(LogicalKeyboardKey.backquote, alt: true),
  SingleActivator(LogicalKeyboardKey.tab, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f1, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f2, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f3, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f4, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f5, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f6, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f7, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f8, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f9, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f10, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f11, control: true, alt: true),
  SingleActivator(LogicalKeyboardKey.f12, control: true, alt: true),
];

/// Keys IBus takes on Linux (Windows has none of them): its two emoji keys
/// (so Next typo is F7 there) and its Unicode entry. Ctrl+Space, an input
/// method's switch, is refused on both.
const _ibus = [
  SingleActivator(LogicalKeyboardKey.semicolon, control: true),
  SingleActivator(LogicalKeyboardKey.period, control: true),
  SingleActivator(LogicalKeyboardKey.keyU, control: true, shift: true),
];

const _arrows = <LogicalKeyboardKey>[
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
];

const _erase = <LogicalKeyboardKey>[
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.delete,
];

bool _among(SingleActivator k, List<SingleActivator> keys) =>
    keys.any((s) => sameKey(k, s));

bool _isLetter(LogicalKeyboardKey k) =>
    k.keyId >= LogicalKeyboardKey.keyA.keyId &&
    k.keyId <= LogicalKeyboardKey.keyZ.keyId;

/// Why [k] can't be a binding's key; null when it can. [own]'s default is
/// always allowed back on its own row (⌥Z is Wrap lines', which only the
/// preview binds, though ⌥Z types Ω elsewhere).
String? refusal(SingleActivator k, {Cmd? own}) {
  if (own != null && sameKey(k, own.standard)) return null;
  if (shortcutText(k) == null) return "This key can't be used";
  final mac = commandKey == CommandKey.meta;
  if (!k.control && !k.alt && !k.meta && !functionKeys.contains(k.trigger)) {
    return mac ? 'Hold ⌘, ⌃ or ⌥ with it' : 'Hold Ctrl or Alt with it';
  }
  final why = mac ? _macRefusal(k) : _linuxRefusal(k);
  if (why != null) return why;
  if (k.trigger == LogicalKeyboardKey.enter) return 'The composer keeps it';
  return null;
}

String? _macRefusal(SingleActivator k) {
  final t = k.trigger;
  // ⌃ and an arrow are Spaces' and Mission Control's.
  if (_among(k, _macSystem) || k.control && _arrows.contains(t)) {
    return 'macOS keeps it';
  }
  if (t == LogicalKeyboardKey.space && k.control && !k.shift && !k.meta) {
    return 'The input method takes it';
  }
  final controlAlone = k.control && !k.alt && !k.shift && !k.meta;
  // ⌥⌘ and an arrow is no field's: Previous and Next chat's.
  if (_among(k, _macField) ||
      _arrows.contains(t) && k.meta != k.alt ||
      _erase.contains(t) ||
      controlAlone && _macControlLetters.contains(t)) {
    return 'A text field keeps it';
  }
  if (k.alt &&
      !k.meta &&
      !k.control &&
      (isPrintable(t) || t == LogicalKeyboardKey.space)) {
    return '⌥ and a key types a character';
  }
  return null;
}

String? _linuxRefusal(SingleActivator k) {
  final t = k.trigger;
  final linux = !identical(conventions, windowsConventions);
  if (k.meta || _among(k, _linuxSystem) || linux && _among(k, _linuxDesktop)) {
    return 'The system keeps it';
  }
  if (sameKey(
        k,
        const SingleActivator(LogicalKeyboardKey.space, control: true),
      ) ||
      linux && _among(k, _ibus)) {
    return 'The input method takes it';
  }
  if (_among(k, _linuxField) ||
      (k.control || k.alt) && _arrows.contains(t) ||
      k.control &&
          !k.alt &&
          (t == LogicalKeyboardKey.home || t == LogicalKeyboardKey.end) ||
      _erase.contains(t)) {
    return 'A text field keeps it';
  }
  if (conventions.altGr && k.control && k.alt) {
    return 'Ctrl+Alt is AltGr on Windows';
  }
  return null;
}

/// Why [k] is no binding's: a key the page lists as fixed (⌘1–9, ⌥⌘1–9,
/// Quit); null for any other.
String? fixedReason(SingleActivator k) {
  for (var n = 1; n <= 9; n++) {
    if (sameKey(k, chatNumberKey(n).standard)) {
      return '${keyLabel(chatNumberKey(n))} opens a chat';
    }
    if (sameKey(k, altDigitKey(n).standard)) {
      return '${keyLabel(altDigitKey(n))} picks a terminal';
    }
  }
  if (sameKey(k, quitKey.standard)) return 'It quits Nushi';
  return null;
}

/// Whether [a] is one a shell reads where the command key is Control:
/// Ctrl (and Alt) and a letter or one of `[ \ ] / -` and Space, which
/// send a control character (ADR 0104).
bool shellKey(SingleActivator a) =>
    a.control &&
    !a.shift &&
    !a.meta &&
    (_isLetter(a.trigger) ||
        const [
          LogicalKeyboardKey.bracketLeft,
          LogicalKeyboardKey.backslash,
          LogicalKeyboardKey.bracketRight,
          LogicalKeyboardKey.slash,
          LogicalKeyboardKey.minus,
          LogicalKeyboardKey.space,
        ].contains(a.trigger));

/// Whether [a] is one of a focused terminal's own keys.
bool terminalOwns(SingleActivator a) => [
  terminalCopyKey,
  terminalPasteKey,
  terminalClearKey,
  newTerminalKey,
  closeTerminalKey,
  terminalFindKey,
  for (var n = 1; n <= 9; n++) altDigitKey(n),
].any((t) => sameKey(a, t.standard));

/// What to know of a chosen [k]: a focused terminal keeps it, for itself
/// or its shell; null when it passes it on. The same test as
/// terminalPasses: a chosen key passes only with the command key held, and
/// where that is Control, not as a shell's control character.
String? note(SingleActivator k) {
  if (terminalOwns(k)) return 'A focused terminal keeps it';
  final mac = commandKey == CommandKey.meta;
  if (mac ? !k.meta : !k.control || shellKey(k)) {
    return 'A focused terminal keeps it for the shell';
  }
  return null;
}
