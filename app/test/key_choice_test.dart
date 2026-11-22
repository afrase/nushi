import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/key_rules.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/native.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';

// The keys the user chooses (ADR 0146): their text form in `app.json`,
// `Cmd.single` holding the choice, the saved choices settled, the aliases
// that step aside, and which keys are refused and why.

const _platforms = <(String, Conventions)>[
  ('Mac', macConventions),
  ('Linux', linuxConventions),
  ('Windows', windowsConventions),
];

/// Whether [key] takes [trigger] pressed with [held] down.
Future<bool> _accepts(
  WidgetTester tester,
  ShortcutActivator key,
  LogicalKeyboardKey trigger, {
  List<LogicalKeyboardKey> held = const [],
  PhysicalKeyboardKey at = PhysicalKeyboardKey.keyA,
}) async {
  for (final h in held) {
    await tester.sendKeyDownEvent(h, platform: 'macos');
  }
  final taken = key.accepts(
    KeyDownEvent(
      physicalKey: at,
      logicalKey: trigger,
      timeStamp: Duration.zero,
    ),
    HardwareKeyboard.instance,
  );
  for (final h in held.reversed) {
    await tester.sendKeyUpEvent(h, platform: 'macos');
  }
  return taken;
}

SingleActivator _k(
  LogicalKeyboardKey key, {
  bool control = false,
  bool alt = false,
  bool shift = false,
  bool meta = false,
}) =>
    SingleActivator(key, control: control, alt: alt, shift: shift, meta: meta);

const _named = <LogicalKeyboardKey>[
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f20,
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.delete,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.add,
];

final _printables = <LogicalKeyboardKey>[
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyZ,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.bracketRight,
  LogicalKeyboardKey.backslash,
  LogicalKeyboardKey.comma,
  const LogicalKeyboardKey(0xe9), // é, a French keyboard's
];

void main() {
  group('the text form', () {
    for (final (name, c) in _platforms.take(2)) {
      test('on $name every named key and printables round-trip with every '
          'set of modifiers', () {
        native.conventions = c;
        for (final key in [..._named, ..._printables]) {
          for (var m = 1; m < 16; m++) {
            if (m == 4) continue; // ⇧ alone: no key
            final k = _k(
              key,
              control: m & 1 != 0,
              alt: m & 2 != 0,
              shift: m & 4 != 0,
              meta: m & 8 != 0,
            );
            final text = shortcutText(k)!;
            final back = parseShortcut(text);
            expect(back, isNotNull, reason: text);
            expect(sameKey(back!, k), isTrue, reason: text);
            expect(shortcutText(back), text);
          }
        }
      });
    }

    test('Shift+Cmd+] is ⇧⌘] on the Mac and Ctrl+Shift+] on Linux', () {
      final k = parseShortcut('Shift+Cmd+]')!;
      expect(keyLabel(k), '⇧⌘]');
      expect(shortcutText(k), 'Shift+Cmd+]');
      native.conventions = linuxConventions;
      expect(keyLabel(parseShortcut('Shift+Cmd+]')!), 'Ctrl+Shift+]');
      expect(keyLabel(parseShortcut('ctrl+alt+r')!), 'Ctrl+Alt+R');
    });

    test('an unknown word, a lone letter, Shift+A and Esc don’t read; '
        'Cmd+! is itself, F5 alone is a key', () {
      expect(parseShortcut('Hyper+A'), isNull);
      expect(parseShortcut('A'), isNull);
      expect(parseShortcut('Shift+A'), isNull);
      expect(parseShortcut('Cmd+Esc'), isNull);
      expect(parseShortcut('Cmd+'), isNull);
      expect(parseShortcut(''), isNull);
      expect(shortcutText(_k(LogicalKeyboardKey.escape, meta: true)), isNull);
      final bang = parseShortcut('Cmd+!')!;
      expect(bang.trigger, LogicalKeyboardKey.exclamation);
      expect(bang.shift, isFalse);
      expect(parseShortcut('F5')!.trigger, LogicalKeyboardKey.f5);
      // A symbol is kept as written: on a French keyboard ⇧ù comes as %.
      expect(
        parseShortcut('Shift+Cmd+}')!.trigger,
        LogicalKeyboardKey.braceRight,
      );
      expect(parseShortcut('Shift+Cmd+%')!.trigger, LogicalKeyboardKey.percent);
    });

    test('a shifted symbol is its key only with ⇧ held, where a US '
        'keyboard has that key', () {
      expect(
        recordedKey(
          LogicalKeyboardKey.braceRight,
          PhysicalKeyboardKey.bracketRight,
          shift: true,
        ),
        LogicalKeyboardKey.bracketRight,
      );
      expect(
        recordedKey(
          LogicalKeyboardKey.braceRight,
          PhysicalKeyboardKey.bracketRight,
          shift: false,
        ),
        LogicalKeyboardKey.braceRight,
      );
      // A French Mac: ⇧ù reports %, and ⇧ and its , key reports ?.
      expect(
        recordedKey(
          LogicalKeyboardKey.percent,
          PhysicalKeyboardKey.quote,
          shift: true,
        ),
        LogicalKeyboardKey.percent,
      );
      expect(
        recordedKey(
          LogicalKeyboardKey.question,
          PhysicalKeyboardKey.keyM,
          shift: true,
        ),
        LogicalKeyboardKey.question,
      );
      const percent = SingleActivator(
        LogicalKeyboardKey.percent,
        shift: true,
        meta: true,
      );
      expect(refusal(percent), isNull);
      expect(
        shiftedTwin(LogicalKeyboardKey.bracketRight),
        LogicalKeyboardKey.braceRight,
      );
      expect(shiftedTwin(LogicalKeyboardKey.keyA), isNull);
    });
  });

  group('the override', () {
    test('a chosen key replaces the Linux and Windows forms too', () {
      shortcutKeys.value = {'chat': 'Cmd+J'};
      expect(keyLabel(chatTabKey), '⌘J');
      native.conventions = windowsConventions;
      expect(keyLabel(chatTabKey), 'Ctrl+J');
      expect(chatTabKey.chosen, isTrue);
      expect(changesTabKey.chosen, isFalse);
    });

    testWidgets('a cleared binding takes nothing and shows no key', (
      tester,
    ) async {
      shortcutKeys.value = {'pin': ''};
      expect(pinKey.single, isNull);
      expect(keyLabel(pinKey), '');
      expect(Act.pin.shortcut, isNull);
      expect(
        await _accepts(
          tester,
          pinKey,
          LogicalKeyboardKey.keyD,
          held: [LogicalKeyboardKey.metaLeft],
        ),
        isFalse,
      );
      expect(Act.find.shortcut, '⌘F');
    });

    test('an unknown name and an unreadable key are ignored, and kept by '
        'the next change', () async {
      shortcutKeys.value = {'x': 'Cmd+J', 'pin': 'nonsense'};
      expect(keyLabel(pinKey), '⌘D');
      expect(resolved('pin').issue, isNull);
      chooseKey(sidebarKey, parseShortcut('Alt+Cmd+S'));
      await pumpEventQueue();
      expect(readSaved()['shortcuts'], {
        'x': 'Cmd+J',
        'pin': 'nonsense',
        'sidebar': 'Alt+Cmd+S',
      });
    });

    test('an entry in another shape (a newer app’s) is ignored, and kept by '
        'the next change', () async {
      shortcutKeys.readFrom({
        'shortcuts': {
          'nextTab': ['Ctrl+Tab', 'Shift+Cmd+]'],
          'pin': 'Alt+Cmd+P',
        },
      });
      expect(shortcutKeys.value, {'pin': 'Alt+Cmd+P'});
      expect(nextTabKey.chosen, isFalse);
      chooseKey(sidebarKey, parseShortcut('Alt+Cmd+S'));
      await pumpEventQueue();
      expect(readSaved()['shortcuts'], {
        'nextTab': ['Ctrl+Tab', 'Shift+Cmd+]'],
        'pin': 'Alt+Cmd+P',
        'sidebar': 'Alt+Cmd+S',
      });
      // A key chosen for it here replaces it.
      chooseKey(nextTabKey, parseShortcut('Alt+Cmd+N'));
      await pumpEventQueue();
      expect(readSaved()['shortcuts'], containsPair('nextTab', 'Alt+Cmd+N'));
      // For good: Reset is then the default, not the other shape again.
      resetKey(nextTabKey);
      await pumpEventQueue();
      expect(readSaved()['shortcuts'], {
        'pin': 'Alt+Cmd+P',
        'sidebar': 'Alt+Cmd+S',
      });
    });

    test('choosing the default takes the entry away; Reset all keeps '
        'unknown names', () {
      chooseKey(pinKey, parseShortcut('Alt+Cmd+P'));
      expect(shortcutKeys.value, {'pin': 'Alt+Cmd+P'});
      chooseKey(pinKey, pinKey.standard);
      expect(shortcutKeys.value, isEmpty);
      chooseKey(pinKey, null);
      expect(shortcutKeys.value, {'pin': ''});
      resetKey(pinKey);
      expect(shortcutKeys.value, isEmpty);
      shortcutKeys.value = {'x': 'Cmd+J', 'pin': '', 'find': 'Cmd+G'};
      resetAllKeys();
      expect(shortcutKeys.value, {'x': 'Cmd+J'});
    });

    test('taking a key leaves the other binding with none, in one change', () {
      var notices = 0;
      void count() => notices++;
      shortcutKeys.addListener(count);
      addTearDown(() => shortcutKeys.removeListener(count));
      takeKey(sidebarKey, findKey.standard, findKey);
      expect(notices, 1);
      expect(shortcutKeys.value, {'find': '', 'sidebar': 'Cmd+F'});
      expect(keyLabel(sidebarKey), '⌘F');
      expect(keyLabel(findKey), '');
    });

    test('a view’s own ⌘R is not Reload page’s', () {
      expect(
        identical(reloadPageKey, const Cmd(LogicalKeyboardKey.keyR)),
        isFalse,
      );
      shortcutKeys.value = {'reloadPage': 'Alt+Cmd+R'};
      expect(keyLabel(const Cmd(LogicalKeyboardKey.keyR)), '⌘R');
    });

    test('every Act’s key is a Cmd named for it, but Quit’s; every one is '
        'listed', () {
      final ids = <String>{};
      for (final a in Act.values) {
        final key = a.key ?? a.shows;
        if (key == null) continue;
        if (a == Act.quit) {
          expect(key.id, isNull);
          continue;
        }
        expect(key.id, a.name);
        ids.add(a.name);
      }
      expect({for (final k in rebindable) k.id}, {...ids, 'palette'});
      expect(rebindable, hasLength(ids.length + 1));
      for (final k in rebindable) {
        expect(bindingName(k), isNotEmpty, reason: k.id);
      }
    });

    testWidgets('a chosen ⇧⌘] takes the key reported as `}` too; a chosen '
        'Ctrl+! not Ctrl+1', (tester) async {
      shortcutKeys.value = {'sidebar': 'Shift+Cmd+]', 'pin': 'Ctrl+!'};
      const shiftMeta = [
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.shiftLeft,
      ];
      expect(
        await _accepts(
          tester,
          sidebarKey,
          LogicalKeyboardKey.braceRight,
          held: shiftMeta,
          at: PhysicalKeyboardKey.bracketRight,
        ),
        isTrue,
      );
      // Another layout's } is another key.
      expect(
        await _accepts(
          tester,
          sidebarKey,
          LogicalKeyboardKey.braceRight,
          held: shiftMeta,
          at: PhysicalKeyboardKey.minus,
        ),
        isFalse,
      );
      expect(
        await _accepts(
          tester,
          sidebarKey,
          LogicalKeyboardKey.bracketRight,
          held: shiftMeta,
        ),
        isTrue,
      );
      const control = [LogicalKeyboardKey.controlLeft];
      expect(
        await _accepts(
          tester,
          pinKey,
          LogicalKeyboardKey.exclamation,
          held: control,
        ),
        isTrue,
      );
      expect(
        await _accepts(
          tester,
          pinKey,
          LogicalKeyboardKey.digit1,
          held: control,
        ),
        isFalse,
      );
    });

    test('the aliases step aside once their binding has a chosen key, or '
        'another binding holds them, and come back on reset', () {
      final alias = nextTabKeysToo.first;
      expect(alias.single, isNotNull);
      expect(paletteKeyToo.single, isNotNull);
      shortcutKeys.value = {'nextTab': 'Alt+Cmd+N'};
      expect(nextTabKeysToo.every((k) => k.single == null), isTrue);
      expect(previousTabKeysToo.every((k) => k.single != null), isTrue);
      shortcutKeys.value = {'nextTab': ''};
      expect(alias.single, isNull);
      shortcutKeys.value = {'sidebar': 'Shift+Cmd+]'};
      expect(nextTabKeysToo.every((k) => k.single == null), isTrue);
      shortcutKeys.value = {'sidebar': 'Shift+Cmd+}'};
      expect(nextTabKeysToo.every((k) => k.single == null), isTrue);
      shortcutKeys.value = {'palette': 'Alt+Cmd+K'};
      expect(paletteKeyToo.single, isNull);
      resetAllKeys();
      expect(alias.single, isNotNull);
      expect(paletteKeyToo.single, isNotNull);
    });

    test('Cmd has no triggers to index', () {
      expect(sidebarKey.triggers, isNull);
      expect(nextTabKey.triggers, isNull);
    });
  });

  group('the saved choices settled', () {
    test('a chosen key beats a default', () {
      shortcutKeys.value = {'sidebar': 'Cmd+K'};
      expect(paletteKey.single, isNull);
      expect(keyLabel(sidebarKey), '⌘K');
      expect(
        resolved('palette').issue,
        "Not used: ⌘K is Show or hide sidebar's",
      );
      expect(resolved('palette').chosen, isFalse);
    });

    test('the first listed keeps a key two chose', () {
      shortcutKeys.value = {'sidebar': 'Cmd+J', 'pin': 'Cmd+J'};
      // Jira's default ⌘J goes too.
      expect(keyLabel(sidebarKey), '⌘J');
      expect(pinKey.single, isNull);
      expect(resolved('pin').issue, "Not used: ⌘J is Show or hide sidebar's");
      expect(jiraKey.single, isNull);
    });

    test('a refused or fixed saved key isn’t used: the default, and why', () {
      shortcutKeys.value = {'pin': 'Cmd+C', 'find': 'Cmd+1'};
      expect(keyLabel(pinKey), '⌘D');
      expect(
        resolved('pin').issue,
        "Your ⌘C isn't used: A text field keeps it",
      );
      expect(resolved('pin').stored, 'Cmd+C');
      expect(keyLabel(findKey), '⌘F');
      expect(resolved('find').issue, "Your ⌘1 isn't used: ⌘1 opens a chat");
    });

    test('a saved key that is its own default is no choice', () {
      shortcutKeys.value = {
        'nextTab': 'Ctrl+Tab',
        'palette': 'Cmd+K',
        'wrap': 'Alt+Z',
      };
      for (final b in [nextTabKey, paletteKey, wrapKey]) {
        expect(b.chosen, isFalse, reason: b.id);
        expect(sameKey(b.single!, b.standard), isTrue, reason: b.id);
        expect(resolved(b.id!).stored, isNull, reason: b.id);
        expect(resolved(b.id!).issue, isNull, reason: b.id);
      }
      expect(nextTabKeysToo.every((k) => k.single != null), isTrue);
      expect(paletteKeyToo.single, isNotNull);
      // The file is left as it was.
      expect(shortcutKeys.value, hasLength(3));
    });

    test('two chosen keys clash only as saved: another layout’s ⇧⌘? and '
        '⇧⌘/ are two keys', () {
      shortcutKeys.value = {'sidebar': 'Shift+Cmd+?', 'pin': 'Shift+Cmd+/'};
      expect(keyLabel(sidebarKey), '⇧⌘?');
      expect(keyLabel(pinKey), '⇧⌘/');
      expect(resolved('pin').issue, isNull);
    });

    test('a conventions switch settles again', () {
      shortcutKeys.value = {'pin': 'Ctrl+R'};
      expect(keyLabel(pinKey), '⌃R');
      native.conventions = linuxConventions;
      expect(keyLabel(pinKey), 'Ctrl+R');
      expect(reloadPageKey.single, isNull); // Ctrl+R is Reload page's there
    });
  });

  group('plain keys as Cmds', () {
    test('the tab, terminal and wrap keys keep their labels', () {
      final keys = [nextTabKey, previousTabKey, toggleTerminalKey, wrapKey];
      expect([for (final k in keys) keyLabel(k)], ['⌃⇥', '⌃⇧⇥', '⌃`', '⌥Z']);
      native.conventions = linuxConventions;
      expect(
        [for (final k in keys) keyLabel(k)],
        ['Ctrl+Tab', 'Ctrl+Shift+Tab', 'Ctrl+`', 'Alt+Z'],
      );
      native.conventions = windowsConventions;
      expect(
        [for (final k in keys) keyLabel(k)],
        ['Ctrl+Tab', 'Ctrl+Shift+Tab', 'Ctrl+`', 'Alt+Z'],
      );
    });

    for (final (name, c) in _platforms) {
      testWidgets('on $name they take their keys as before', (tester) async {
        native.conventions = c;
        const control = LogicalKeyboardKey.controlLeft;
        expect(
          await _accepts(
            tester,
            nextTabKey,
            LogicalKeyboardKey.tab,
            held: [control],
          ),
          isTrue,
        );
        expect(
          await _accepts(
            tester,
            previousTabKey,
            LogicalKeyboardKey.tab,
            held: [control, LogicalKeyboardKey.shiftLeft],
          ),
          isTrue,
        );
        expect(
          await _accepts(
            tester,
            toggleTerminalKey,
            LogicalKeyboardKey.backquote,
            held: [control],
          ),
          isTrue,
        );
        expect(
          await _accepts(
            tester,
            wrapKey,
            LogicalKeyboardKey.keyZ,
            held: [LogicalKeyboardKey.altLeft],
          ),
          isTrue,
        );
        expect(
          await _accepts(tester, wrapKey, LogicalKeyboardKey.keyZ),
          isFalse,
        );
      });
    }

    test('named keys’ labels on the Mac and Linux', () {
      const keys = [
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.backspace,
        LogicalKeyboardKey.delete,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.f7,
      ];
      expect(
        [for (final k in keys) keyName(k)],
        ['Space', '⌫', '⌦', '↖', '↘', '⇞', '⇟', 'F7'],
      );
      native.conventions = linuxConventions;
      expect(
        [for (final k in keys) keyName(k)],
        [
          'Space',
          'Backspace',
          'Delete',
          'Home',
          'End',
          'Page Up',
          'Page Down',
          'F7',
        ],
      );
    });
  });

  group('refusals', () {
    test('on the Mac', () {
      const cases = <(SingleActivator, String?)>[
        (SingleActivator(LogicalKeyboardKey.keyR), 'Hold ⌘, ⌃ or ⌥ with it'),
        (
          SingleActivator(LogicalKeyboardKey.keyR, shift: true),
          'Hold ⌘, ⌃ or ⌥ with it',
        ),
        (SingleActivator(LogicalKeyboardKey.f5), null),
        (
          SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
          'macOS keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyH, meta: true),
          'macOS keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyM, meta: true),
          'macOS keeps it',
        ),
        (SingleActivator(LogicalKeyboardKey.tab, meta: true), 'macOS keeps it'),
        (
          SingleActivator(LogicalKeyboardKey.space, meta: true),
          'macOS keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.digit4, meta: true, shift: true),
          'macOS keeps it',
        ),
        // A digit's key reports its digit on any layout (Flutter maps the
        // digits first), so a key reported as $ is another key: a French
        // keyboard's own $ key.
        (
          SingleActivator(LogicalKeyboardKey.dollar, meta: true, shift: true),
          null,
        ),
        (
          SingleActivator(LogicalKeyboardKey.arrowLeft, control: true),
          'macOS keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.space, control: true),
          'The input method takes it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyC, meta: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.arrowUp, meta: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.arrowUp, alt: true, shift: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.arrowUp, alt: true, meta: true),
          null,
        ),
        (
          SingleActivator(
            LogicalKeyboardKey.backspace,
            meta: true,
            shift: true,
          ),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyA, control: true),
          'A text field keeps it',
        ),
        (SingleActivator(LogicalKeyboardKey.keyR, control: true), null),
        (
          SingleActivator(LogicalKeyboardKey.keyZ, alt: true),
          '⌥ and a key types a character',
        ),
        (
          SingleActivator(LogicalKeyboardKey.enter, meta: true, alt: true),
          'The composer keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.escape, meta: true),
          "This key can't be used",
        ),
        (SingleActivator(LogicalKeyboardKey.keyG, meta: true), null),
      ];
      for (final (k, why) in cases) {
        expect(refusal(k), why, reason: keyLabel(k));
      }
    });

    test('on Linux', () {
      native.conventions = linuxConventions;
      const cases = <(SingleActivator, String?)>[
        (SingleActivator(LogicalKeyboardKey.tab), 'Hold Ctrl or Alt with it'),
        (
          SingleActivator(LogicalKeyboardKey.keyE, meta: true),
          'The system keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.tab, alt: true),
          'The system keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.f4, alt: true),
          'The system keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.space, alt: true),
          'The system keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyT, control: true, alt: true),
          'The system keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.semicolon, control: true),
          'The input method takes it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.period, control: true),
          'The input method takes it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyU, control: true, shift: true),
          'The input method takes it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.keyY, control: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.insert, control: true),
          "This key can't be used",
        ),
        (
          SingleActivator(LogicalKeyboardKey.arrowUp, alt: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true, shift: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.end, control: true, shift: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.backspace, alt: true),
          'A text field keeps it',
        ),
        (
          SingleActivator(LogicalKeyboardKey.enter, control: true),
          'The composer keeps it',
        ),
        (SingleActivator(LogicalKeyboardKey.keyR, control: true), null),
        (
          SingleActivator(LogicalKeyboardKey.keyR, control: true, alt: true),
          null,
        ),
        (SingleActivator(LogicalKeyboardKey.keyZ, alt: true), null),
      ];
      for (final (k, why) in cases) {
        expect(refusal(k), why, reason: keyLabel(k));
      }
    });

    test('the desktop keys that never reach the recorder are refused, so '
        'a saved one is', () {
      for (final k in [
        _k(LogicalKeyboardKey.keyQ, meta: true, shift: true, alt: true),
        _k(LogicalKeyboardKey.tab, meta: true, alt: true),
        _k(LogicalKeyboardKey.tab, meta: true, alt: true, shift: true),
        _k(LogicalKeyboardKey.backquote, meta: true, shift: true),
      ]) {
        expect(refusal(k), 'macOS keeps it', reason: keyLabel(k));
      }
      native.conventions = linuxConventions;
      for (final k in [
        for (final f in [
          LogicalKeyboardKey.f1,
          LogicalKeyboardKey.f2,
          LogicalKeyboardKey.f7,
          LogicalKeyboardKey.f8,
          LogicalKeyboardKey.f10,
          LogicalKeyboardKey.backquote,
        ])
          _k(f, alt: true),
        for (final f in [
          LogicalKeyboardKey.tab,
          LogicalKeyboardKey.f1,
          LogicalKeyboardKey.f3,
          LogicalKeyboardKey.f12,
        ])
          _k(f, control: true, alt: true),
      ]) {
        expect(refusal(k), 'The system keeps it', reason: keyLabel(k));
      }
    });

    test('on Windows, Ctrl+Alt is AltGr; IBus’s keys are free', () {
      native.conventions = windowsConventions;
      expect(
        refusal(_k(LogicalKeyboardKey.keyR, control: true, alt: true)),
        'Ctrl+Alt is AltGr on Windows',
      );
      expect(refusal(_k(LogicalKeyboardKey.keyR, control: true)), isNull);
      expect(
        refusal(_k(LogicalKeyboardKey.space, alt: true)),
        'The system keeps it',
      );
      // Linux's desktop keys aren't Windows's either.
      expect(refusal(_k(LogicalKeyboardKey.f2, alt: true)), isNull);
      expect(
        refusal(_k(LogicalKeyboardKey.f3, control: true, alt: true)),
        'Ctrl+Alt is AltGr on Windows',
      );
      // An input method's switch, but IBus's keys aren't Windows's.
      expect(
        refusal(_k(LogicalKeyboardKey.space, control: true)),
        'The input method takes it',
      );
      for (final k in [
        _k(LogicalKeyboardKey.keyU, control: true, shift: true),
        _k(LogicalKeyboardKey.semicolon, control: true),
        _k(LogicalKeyboardKey.period, control: true),
      ]) {
        expect(refusal(k), isNull, reason: keyLabel(k));
      }
    });

    for (final (name, c) in _platforms) {
      test('on $name no binding’s own default is refused on its row', () {
        native.conventions = c;
        for (final k in rebindable) {
          expect(refusal(k.standard, own: k), isNull, reason: k.id);
        }
      });
    }

    test('⌥Z is refused for Sidebar but not for Wrap lines', () {
      final altZ = _k(LogicalKeyboardKey.keyZ, alt: true);
      expect(refusal(altZ, own: sidebarKey), '⌥ and a key types a character');
      expect(refusal(altZ, own: wrapKey), isNull);
    });

    test('the fixed keys, and what a focused terminal does with a key', () {
      expect(fixedReason(chatNumberKey(3).standard), '⌘3 opens a chat');
      expect(fixedReason(altDigitKey(2).standard), '⌥⌘2 picks a terminal');
      expect(fixedReason(quitKey.standard), 'It quits Nushi');
      expect(fixedReason(findKey.standard), isNull);
      expect(
        note(_k(LogicalKeyboardKey.keyK, meta: true)),
        'A focused terminal keeps it',
      );
      expect(
        note(_k(LogicalKeyboardKey.keyR, control: true)),
        'A focused terminal keeps it for the shell',
      );
      expect(note(_k(LogicalKeyboardKey.keyG, meta: true)), isNull);
      native.conventions = linuxConventions;
      expect(
        note(_k(LogicalKeyboardKey.keyR, control: true)),
        'A focused terminal keeps it for the shell',
      );
      expect(
        note(_k(LogicalKeyboardKey.keyR, control: true, alt: true)),
        'A focused terminal keeps it for the shell',
      );
      expect(
        note(_k(LogicalKeyboardKey.keyO, control: true, shift: true)),
        isNull,
      );
      expect(
        note(_k(LogicalKeyboardKey.keyF, control: true, shift: true)),
        'A focused terminal keeps it',
      );
    });

    test('on Linux a chosen key without Ctrl notes the shell keeps it', () {
      // A focused terminal passes a chosen key only when it holds Ctrl
      // (terminalPasses), so F5 or Alt+P stays the shell's there.
      native.conventions = linuxConventions;
      for (final k in [
        _k(LogicalKeyboardKey.f5),
        _k(LogicalKeyboardKey.keyP, alt: true),
        _k(LogicalKeyboardKey.keyK, alt: true, shift: true),
      ]) {
        chooseKey(pinKey, k);
        expect(terminalPasses(pinKey), isFalse, reason: keyLabel(k));
        expect(
          note(k),
          'A focused terminal keeps it for the shell',
          reason: keyLabel(k),
        );
      }
    });
  });
}
