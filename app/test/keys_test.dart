import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/native.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminal_screen.dart';

// The app's keys on each platform (ADR 0104): the same values held with ⌘
// on the Mac and Control on Linux, written as each platform writes them,
// none taken twice, and in a focused terminal on Linux only the listed ones
// passed on.

/// Every key the app binds wherever the focus is, and the preview's.
List<ShortcutActivator> get _appKeys => {
  ...actKeys.keys,
  ...chatKeys.keys,
  paletteKey,
  paletteKeyToo,
  wrapKey,
  quitKey,
}.toList();

/// The app's keys a terminal is given to pass on or not.
List<ShortcutActivator> get _toTerminal => [
  ...actKeys.keys,
  paletteKeyToo,
  ...chatKeys.keys,
];

/// The terminal's own keys.
const _terminalKeys = <ShortcutActivator>[
  terminalCopyKey,
  terminalPasteKey,
  terminalClearKey,
  newTerminalKey,
  closeTerminalKey,
  terminalFindKey,
];

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

  test('a terminal’s own keys: ⌘ and the letter on the Mac, Ctrl+Shift and '
      'it on Linux', () {
    expect(keyLabel(newTerminalKey), '⌘T');
    native.conventions = linuxConventions;
    expect(
      [for (final k in _terminalKeys) keyLabel(k)],
      [
        'Ctrl+Shift+C',
        'Ctrl+Shift+V',
        'Ctrl+Shift+K',
        'Ctrl+Shift+T',
        'Ctrl+Shift+W',
        'Ctrl+Shift+F',
      ],
    );
  });

  test('Quit: ⌘Q, and Ctrl+Q on Linux', () {
    expect(keyLabel(quitKey), '⌘Q');
    native.conventions = linuxConventions;
    expect(keyLabel(quitKey), 'Ctrl+Q');
  });

  for (final (name, c) in [
    ('Mac', macConventions),
    ('Linux', linuxConventions),
  ]) {
    test('on $name no two of the app’s keys are the same, nor the '
        'terminal’s own', () {
      native.conventions = c;
      expect(_twice(_appKeys), isEmpty);
      expect(_twice(_terminalKeys), isEmpty);
    });
  }

  test('a terminal on the Mac passes every ⌘ key on but ⌘F and ⌘W', () {
    expect([
      for (final k in _toTerminal)
        if (!terminalPasses(k)) keyLabel(k),
    ], unorderedEquals(['⌘F', '⌘W']));
  });

  test('a terminal on Linux passes on only Ctrl keys Ctrl and a letter '
      r'isn’t: the shell keeps Ctrl+D, Ctrl+R, Ctrl+\ (SIGQUIT), F7 and the '
      'rest; none it passes is its own', () {
    native.conventions = linuxConventions;
    final passed = _toTerminal.where(terminalPasses).toList();
    for (final k in passed) {
      final a = k is Cmd ? k.single : k as SingleActivator;
      final letter =
          a.trigger.keyId >= LogicalKeyboardKey.keyA.keyId &&
          a.trigger.keyId <= LogicalKeyboardKey.keyZ.keyId;
      expect(
        !a.control || letter && !a.shift,
        isFalse,
        reason: '${keyLabel(k)} is the shell’s',
      );
    }
    for (final k in [
      sidebarKey,
      pinKey,
      reloadPageKey,
      newChatKey,
      quitKey,
      nextTypoKey,
    ]) {
      expect(terminalPasses(k), isFalse, reason: keyLabel(k));
    }
    expect(
      [for (final k in passed) keyLabel(k)],
      containsAll([
        'Ctrl+Shift+P',
        'Ctrl+Shift+B',
        'Ctrl+Shift+E',
        'Ctrl+,',
        'Ctrl+Alt+2',
        'Ctrl+1',
        'Ctrl+Page Down',
        'Ctrl+Tab',
        'Ctrl+`',
      ]),
    );
    expect(_twice([...passed, ..._terminalKeys]), isEmpty);
  });
}
