import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/native.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/terminal_panel.dart';

// The app's keys on each platform (ADR 0102): the same values held with ⌘
// on the Mac and Control on Linux, written as each platform writes them,
// none taken twice.

/// Every key the app binds wherever the focus is, and the preview's.
List<ShortcutActivator> get _appKeys => {
  ...actKeys.keys,
  ...chatKeys.keys,
  paletteKey,
  paletteKeyToo,
  wrapKey,
}.toList();

/// The labels [keys] have more than once.
Iterable<String> _twice(Iterable<ShortcutActivator> keys) {
  final seen = <String>{};
  return [
    for (final k in keys)
      if (!seen.add(keyLabel(k))) keyLabel(k),
  ];
}

void main() {
  test('on the Mac, ⌘ keys written as its menus write them', () {
    expect(commandKey, CommandKey.meta);
    expect(
      [
        keyLabel(filesKey),
        keyLabel(chatTabKey),
        keyLabel(nextTypoKey),
        keyLabel(previousChatKey),
        keyLabel(chatNumberKey(3)),
        keyLabel(altDigitKey(1)),
        keyLabel(nextTabKey),
        keyLabel(toggleTerminalKey),
        keyLabel(wrapKey),
      ],
      ['⇧⌘E', '⌃⌘1', '⌘;', '⌘[', '⌘3', '⌥⌘1', '⌃⇥', '⌃`', '⌥Z'],
    );
    expect(filesKey.single.meta, isTrue);
    expect(filesKey.single.control, isFalse);
  });

  test('on Linux, Control in ⌘’s place, written Ctrl+Shift+E; ⌃⌘, ⌥⌘, '
      '⌘[ and ⌘; take their own keys', () {
    native.conventions = linuxConventions;
    expect(commandKey, CommandKey.control);
    expect(
      [
        keyLabel(filesKey),
        keyLabel(chatTabKey),
        keyLabel(nextTypoKey),
        keyLabel(previousChatKey),
        keyLabel(nextChatKey),
        keyLabel(chatNumberKey(3)),
        keyLabel(altDigitKey(1)),
        keyLabel(nextTabKey),
        keyLabel(previousTabKey),
        keyLabel(toggleTerminalKey),
        keyLabel(wrapKey),
      ],
      [
        'Ctrl+Shift+E',
        'Ctrl+Alt+1',
        'F7',
        'Ctrl+Page Up',
        'Ctrl+Page Down',
        'Ctrl+3',
        'Alt+1',
        'Ctrl+Tab',
        'Ctrl+Shift+Tab',
        'Ctrl+`',
        'Alt+Z',
      ],
    );
    expect(filesKey.single.meta, isFalse);
    expect(filesKey.single.control, isTrue);
    // A ShortcutManager indexes both forms' keys, so a switch of the
    // conventions after it was built still reaches the Linux form.
    expect(previousChatKey.triggers, [
      LogicalKeyboardKey.bracketLeft,
      LogicalKeyboardKey.pageUp,
    ]);
  });

  test('Enter and the command key with it, as each platform writes them', () {
    expect((enterLabel, cmdEnterLabel), ('⏎', '⌘⏎'));
    native.conventions = linuxConventions;
    expect((enterLabel, cmdEnterLabel), ('Enter', 'Ctrl+Enter'));
  });

  for (final (name, c) in [
    ('Mac', macConventions),
    ('Linux', linuxConventions),
  ]) {
    test('on $name no two of the app’s keys are the same', () {
      native.conventions = c;
      expect(_twice(_appKeys), isEmpty);
    });
  }
}
