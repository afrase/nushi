import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/key_rules.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/terminal_panel.dart';

// The app's shortcuts on each platform (ADR 0104): held with ⌘ on the Mac
// and the phone, with Control on Linux and Windows, and written as each
// writes them (⇧⌘E, Ctrl+Shift+E). Which modifier is read when a key
// arrives, from `conventions`, never from `defaultTargetPlatform`, which
// says android under `flutter test`.

/// The modifier the app's shortcuts are held with now.
CommandKey get commandKey => conventions.commandKey;

/// Whether the command key ([commandKey]) is down: ⌘, or Control.
bool cmdPressed() => switch (commandKey) {
  CommandKey.meta => HardwareKeyboard.instance.isMetaPressed,
  CommandKey.control => HardwareKeyboard.instance.isControlPressed,
};

/// A shortcut held with the command key ([commandKey]), with [shift], [alt]
/// and [ctrl] as given: ⌘ on the Mac, Control on Linux and Windows; or,
/// with [command] false, without it (⌃Tab, ⌥Z). Where Control and the same
/// key won't do there (⌃⌘ keys, Control and `[`, which is Escape), [linux]
/// is its own form, and [windows] where that holds Control and Alt, which
/// are AltGr on Windows. One value for every platform, so it stays const
/// and `identical` to itself, and a test that switches the conventions
/// switches it.
///
/// One the user may rebind has an [id], the binding's name (its Act's, or
/// `palette`), and is held as they chose in Settings › Keyboard shortcuts
/// ([single]); an [aliasOf] is a second key of the binding with that id,
/// bound only while that binding is on its default (ADR 0146).
class Cmd extends ShortcutActivator with MenuSerializableShortcut {
  const new(
    this.trigger, {
    this.shift = false,
    this.alt = false,
    this.ctrl = false,
    this.command = true,
    this.includeRepeats = true,
    this.terminal = false,
    this.linux,
    this.windows,
    this.id,
    this.aliasOf,
  }) : assert(
         !ctrl || !command || linux != null,
         'Control is the command key on Linux',
       );

  /// The key that, with the modifiers, triggers it.
  final LogicalKeyboardKey trigger;

  /// Whether ⇧ is held too.
  final bool shift;

  /// Whether ⌥ (Alt) is held too.
  final bool alt;

  /// Whether ⌃ is held too, on the Mac: with [command], such a key gives
  /// its [linux] form.
  final bool ctrl;

  /// Whether the command key is held: false for a key held with ⌃ or ⌥
  /// alone on every platform (⌃Tab, ⌥Z).
  final bool command;

  /// Whether a held key's repeats trigger it again.
  final bool includeRepeats;

  /// A terminal's own key: where the command key is Control, Shift is held
  /// too, since Control and a letter is the shell's (ADR 0104).
  final bool terminal;

  /// Its form where the command key is Control, when that isn't Control
  /// and the same keys.
  final SingleActivator? linux;

  /// Its form where Control and Alt are AltGr ([Conventions.altGr]), when
  /// [linux]'s holds both.
  final SingleActivator? windows;

  /// The binding's name, for one the user may rebind: its Act's name, or
  /// `palette`. A name and not the value itself, since Dart makes equal
  /// consts one object: a view's own `const Cmd(keyR)` would otherwise be
  /// Reload Page's key.
  final String? id;

  /// The binding this is a second key of ([id]'s), as ⇧⌘] is Next tab's.
  final String? aliasOf;

  /// The Mac's form: ⌘ and the rest.
  SingleActivator get mac => SingleActivator(
    trigger,
    meta: command,
    control: ctrl,
    shift: shift,
    alt: alt,
    includeRepeats: includeRepeats,
  );

  /// The key as it is held by default now, by [commandKey].
  SingleActivator get standard => switch (commandKey) {
    CommandKey.meta => mac,
    CommandKey.control =>
      (conventions.altGr ? windows : null) ??
          linux ??
          SingleActivator(
            trigger,
            control: command || ctrl,
            shift: shift || terminal,
            alt: alt,
            includeRepeats: includeRepeats,
          ),
  };

  /// The key as it is held now: the user's choice for its binding, or the
  /// default ([standard]); null when the binding has none (cleared, or its
  /// default taken by another's choice), and for an alias whose binding is
  /// off its default.
  SingleActivator? get single => switch ((id, aliasOf)) {
    (final id?, _) => effectiveKey(id, standard),
    (_, final of?) => aliasBound(of, standard) ? standard : null,
    _ => standard,
  };

  /// Whether the key held now is one the user chose.
  bool get chosen => id != null && hasChosenKey(id!);

  /// None: a [ShortcutManager] that indexed the keys once would keep a key
  /// the user has since changed (or the conventions a test switched), so
  /// every [Cmd] is asked about every key, in its map's order.
  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    final a = single;
    if (a == null) return false;
    if (a.accepts(event, state)) return true;
    // A chosen ⇧⌘] may arrive as the key ⇧ makes of it, `}`, from where
    // a US keyboard has `]` (another layout's `}` is another key).
    if (!a.shift || !chosen) return false;
    if (recordedKey(event.logicalKey, event.physicalKey, shift: true) !=
        a.trigger) {
      return false;
    }
    return switch (shiftedTwin(a.trigger)) {
      final twin? => SingleActivator(
        twin,
        control: a.control,
        shift: true,
        alt: a.alt,
        meta: a.meta,
        includeRepeats: a.includeRepeats,
      ).accepts(event, state),
      null => false,
    };
  }

  @override
  ShortcutSerialization serializeForMenu() =>
      (single ?? standard).serializeForMenu();

  @override
  String debugDescribeKeys() => (single ?? standard).debugDescribeKeys();
}

// A terminal's own keys: ⌘ and a letter, as Terminal has them; on Linux
// Ctrl+Shift and the letter, as GNOME Terminal has them, since Ctrl and a
// letter is the shell's (ADR 0104). Here beside the app's, which a key the
// user chooses is checked against (`key_rules.dart`).

/// Copies the terminal's selection.
const terminalCopyKey = Cmd(LogicalKeyboardKey.keyC, terminal: true);

/// Pastes into the terminal.
const terminalPasteKey = Cmd(LogicalKeyboardKey.keyV, terminal: true);

/// Clears the terminal's screen and scrollback.
const terminalClearKey = Cmd(LogicalKeyboardKey.keyK, terminal: true);

/// Opens another terminal for the chat.
const newTerminalKey = Cmd(LogicalKeyboardKey.keyT, terminal: true);

/// Closes the terminal.
const closeTerminalKey = Cmd(LogicalKeyboardKey.keyW, terminal: true);

/// Finds in the terminal.
const terminalFindKey = Cmd(LogicalKeyboardKey.keyF, terminal: true);

/// ⌥⌘ and the digit [n] (1–9), which picks one of a view's own (a terminal,
/// a Jira list); Alt and the digit on Linux, as GNOME Terminal's tabs.
Cmd altDigitKey(int n) {
  final digit = LogicalKeyboardKey(0x30 + n);
  return Cmd(digit, alt: true, linux: SingleActivator(digit, alt: true));
}

/// [key] as the platform's menus write it: ⌃⌥⇧⌘ and then the key on the
/// Mac (and the phone), Ctrl+Alt+Shift+ and then the key on Linux. [key] is
/// a [Cmd] or a [SingleActivator]; '' for a [Cmd] with no key now.
String keyLabel(ShortcutActivator key) {
  final a = key is Cmd ? key.single : key as SingleActivator;
  if (a == null) return '';
  final name = keyName(a.trigger);
  return switch (commandKey) {
    CommandKey.meta =>
      '${a.control ? '⌃' : ''}${a.alt ? '⌥' : ''}'
          '${a.shift ? '⇧' : ''}${a.meta ? '⌘' : ''}$name',
    CommandKey.control => [
      if (a.control) 'Ctrl',
      if (a.alt) 'Alt',
      if (a.shift) 'Shift',
      if (a.meta) 'Super',
      name,
    ].join('+'),
  };
}

/// The command key and [key], as [keyLabel] writes them (⌘⏎, Ctrl+Enter).
String cmdLabel(LogicalKeyboardKey key) => keyLabel(Cmd(key));

/// ⏎, or Enter on Linux.
String get enterLabel => keyName(LogicalKeyboardKey.enter);

/// ⌘⏎, or Ctrl+Enter on Linux: what sends now, posts or commits.
String get cmdEnterLabel => cmdLabel(LogicalKeyboardKey.enter);

/// [key] alone as the platform writes it: ⏎, ⇥ and ↑ on the Mac, Enter,
/// Tab and Up on Linux.
String keyName(LogicalKeyboardKey key) => switch (commandKey) {
  CommandKey.meta => switch (key) {
    LogicalKeyboardKey.enter => '⏎',
    LogicalKeyboardKey.tab => '⇥',
    LogicalKeyboardKey.arrowUp => '↑',
    LogicalKeyboardKey.arrowDown => '↓',
    LogicalKeyboardKey.arrowLeft => '←',
    LogicalKeyboardKey.arrowRight => '→',
    LogicalKeyboardKey.space => 'Space',
    LogicalKeyboardKey.backspace => '⌫',
    LogicalKeyboardKey.delete => '⌦',
    LogicalKeyboardKey.home => '↖',
    LogicalKeyboardKey.end => '↘',
    LogicalKeyboardKey.pageUp => '⇞',
    LogicalKeyboardKey.pageDown => '⇟',
    _ => key.keyLabel.toUpperCase(),
  },
  CommandKey.control => switch (key) {
    LogicalKeyboardKey.escape => 'Esc',
    LogicalKeyboardKey.arrowUp => 'Up',
    LogicalKeyboardKey.arrowDown => 'Down',
    LogicalKeyboardKey.arrowLeft => 'Left',
    LogicalKeyboardKey.arrowRight => 'Right',
    LogicalKeyboardKey.space => 'Space',
    LogicalKeyboardKey.backspace => 'Backspace',
    LogicalKeyboardKey.delete => 'Delete',
    LogicalKeyboardKey.home => 'Home',
    LogicalKeyboardKey.end => 'End',
    LogicalKeyboardKey.pageUp => 'Page Up',
    LogicalKeyboardKey.pageDown => 'Page Down',
    _ => key.keyLabel,
  },
};

/// The app's keys a focused terminal passes on where the command key is
/// Control, as GNOME Terminal leaves them: those Ctrl and a letter can't be
/// meant for the shell (Ctrl and a digit, a symbol or Page Up, and Ctrl+Shift
/// keys the terminal doesn't keep), each held with Ctrl. Every other key is
/// the shell's: Ctrl+D ends its input, Ctrl+R searches its history, Ctrl+\
/// quits its program (SIGQUIT), though it hides the sidebar elsewhere, and
/// F7, the next typo elsewhere, is its program's (htop's Nice -, Midnight
/// Commander's Mkdir).
final List<ShortcutActivator> _linuxTerminalPasses = [
  paletteKeyToo, // Ctrl+Shift+P
  sideChatKey, // Ctrl+Shift+B
  filesKey, // Ctrl+Shift+E
  fileTreeKey, // Ctrl+Shift+Y
  settingsKey, // Ctrl+,
  toggleTerminalKey, // Ctrl+`
  chatTabKey, // Ctrl+Alt+1 (Ctrl+Shift+1 on Windows)
  changesTabKey, // Ctrl+Alt+2
  pullTabKey, // Ctrl+Alt+3
  for (var n = 1; n <= 9; n++) chatNumberKey(n), // Ctrl+1–9
  previousChatKey, // Ctrl+Page Up
  nextChatKey, // Ctrl+Page Down
  nextTabKey, // Ctrl+Tab
  previousTabKey, // Ctrl+Shift+Tab
];

/// Whether a focused terminal passes [key], one of the app's, on to the
/// app: never a key it has none of now, nor one of the terminal's own
/// (⌘F finds in it, ⌘W closes it, ⌘K clears it). On the Mac every other
/// default, and a chosen key held with ⌘ (a chosen ⌃ or ⌥ key is the
/// shell's); where the command key is Control, of the defaults only
/// [_linuxTerminalPasses], and a chosen key held with Ctrl that no shell
/// reads as a control character (ADR 0146, amending 0104).
bool terminalPasses(ShortcutActivator key) {
  final a = key is Cmd ? key.single : key as SingleActivator?;
  if (a == null || terminalOwns(a)) return false;
  final chosen = key is Cmd && key.chosen;
  return switch (commandKey) {
    CommandKey.meta => !chosen || a.meta,
    CommandKey.control =>
      chosen ? a.control && !shellKey(a) : _linuxTerminalPasses.contains(key),
  };
}

/// [key] as the menu bar's item shows it and takes it: none while
/// Settings › Keyboard shortcuts is taking a key (so the key comes to the
/// page), nor for a binding with no key now. A chosen key with ⇧ on a
/// symbol is given as the character ⇧ makes (⇧⌘] as ⇧⌘}), which is what
/// the menu bar compares a key with.
MenuSerializableShortcut? menuShortcut(ShortcutActivator? key) {
  if (key == null || shortcutRecording.value) return null;
  if (key is! Cmd) return key as MenuSerializableShortcut;
  final a = key.single;
  if (a == null) return null;
  if (a.shift && key.chosen) {
    if (shiftedTwin(a.trigger) case final twin?) {
      return SingleActivator(
        twin,
        control: a.control,
        shift: true,
        alt: a.alt,
        meta: a.meta,
      );
    }
  }
  return key;
}
