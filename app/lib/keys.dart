import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/conventions.dart';

// The app's shortcuts on each platform (ADR 0102): held with ⌘ on the Mac
// and the phone, with Control on Linux, and written as each writes them
// (⇧⌘E, Ctrl+Shift+E). Which modifier is read when a key arrives, from
// `conventions`, never from `defaultTargetPlatform`, which says android
// under `flutter test`.

/// The modifier the app's shortcuts are held with now.
CommandKey get commandKey => conventions.commandKey;

/// Whether the command key ([commandKey]) is down: ⌘, or Control.
bool cmdPressed() => switch (commandKey) {
  CommandKey.meta => HardwareKeyboard.instance.isMetaPressed,
  CommandKey.control => HardwareKeyboard.instance.isControlPressed,
};

/// A shortcut held with the command key ([commandKey]), with [shift], [alt]
/// and [ctrl] as given: ⌘ on the Mac, Control on Linux. Where Control and
/// the same key won't do there (⌃⌘ keys, Control and `[`, which is Escape),
/// [linux] is its own form. One value for both platforms, so it stays const
/// and `identical` to itself, and a test that switches the conventions
/// switches it.
class Cmd extends ShortcutActivator with MenuSerializableShortcut {
  const new(
    this.trigger, {
    this.shift = false,
    this.alt = false,
    this.ctrl = false,
    this.includeRepeats = true,
    this.linux,
  }) : assert(!ctrl || linux != null, 'Control is the command key on Linux');

  /// The key that, with the modifiers, triggers it.
  final LogicalKeyboardKey trigger;

  /// Whether ⇧ is held too.
  final bool shift;

  /// Whether ⌥ (Alt) is held too.
  final bool alt;

  /// Whether ⌃ is held too, on the Mac: such a key gives its [linux] form.
  final bool ctrl;

  /// Whether a held key's repeats trigger it again.
  final bool includeRepeats;

  /// Its form where the command key is Control, when that isn't Control
  /// and the same keys.
  final SingleActivator? linux;

  /// The Mac's form: ⌘ and the rest.
  SingleActivator get mac => SingleActivator(
    trigger,
    meta: true,
    control: ctrl,
    shift: shift,
    alt: alt,
    includeRepeats: includeRepeats,
  );

  /// The key as it is held now, by [commandKey].
  SingleActivator get single => switch (commandKey) {
    CommandKey.meta => mac,
    CommandKey.control =>
      linux ??
          SingleActivator(
            trigger,
            control: true,
            shift: shift,
            alt: alt,
            includeRepeats: includeRepeats,
          ),
  };

  /// Both forms' keys: a [ShortcutManager] indexes them once, and the
  /// conventions may change after (a test's).
  @override
  Iterable<LogicalKeyboardKey> get triggers => [trigger, ?linux?.trigger];

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      single.accepts(event, state);

  @override
  ShortcutSerialization serializeForMenu() => single.serializeForMenu();

  @override
  String debugDescribeKeys() => single.debugDescribeKeys();
}

/// ⌥⌘ and the digit [n] (1–9), which picks one of a view's own (a terminal,
/// a Jira list); Alt and the digit on Linux, as GNOME Terminal's tabs.
Cmd altDigitKey(int n) {
  final digit = LogicalKeyboardKey(0x30 + n);
  return Cmd(digit, alt: true, linux: SingleActivator(digit, alt: true));
}

/// [key] as the platform's menus write it: ⌃⌥⇧⌘ and then the key on the
/// Mac (and the phone), Ctrl+Alt+Shift+ and then the key on Linux. [key] is
/// a [Cmd] or a [SingleActivator].
String keyLabel(ShortcutActivator key) {
  final a = key is Cmd ? key.single : key as SingleActivator;
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

/// [key] alone as the platform writes it: ⏎ and ⇥ on the Mac, Enter and
/// Tab on Linux.
String keyName(LogicalKeyboardKey key) => switch (commandKey) {
  CommandKey.meta => switch (key) {
    LogicalKeyboardKey.enter => '⏎',
    LogicalKeyboardKey.tab => '⇥',
    _ => key.keyLabel.toUpperCase(),
  },
  CommandKey.control => switch (key) {
    LogicalKeyboardKey.escape => 'Esc',
    _ => key.keyLabel,
  },
};
