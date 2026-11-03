import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'spell_harness.dart';

const _fixes = {
  'chekc': ['check', 'Cheka', 'chick', 'cheek', 'chalk'],
  'Chekc': ['Check', 'cheka'],
  'thrid': ['third'],
};

FakeSpeller _speller() =>
    FakeSpeller({'chekc', 'Chekc', 'thrid', 'zzyx'}, fixes: _fixes);

/// Where the word [word] of the box's text is drawn, on screen.
Rect _wordRect(WidgetTester tester, ChatState chat, String word) {
  final start = chat.draft.text.text.indexOf(word);
  final box = editable(tester);
  final rect = box
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + word.length),
      )
      .first
      .toRect();
  return box.localToGlobal(rect.topLeft) & rect.size;
}

Future<void> _click(
  WidgetTester tester,
  Offset at, {
  int buttons = kPrimaryButton,
}) async {
  await tester.tapAt(at, kind: PointerDeviceKind.mouse, buttons: buttons);
  await tester.pumpAndSettle();
}

Future<void> _clickWord(
  WidgetTester tester,
  ChatState chat,
  String word,
) async {
  await _click(tester, _wordRect(tester, chat, word).center);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// ⌘; as `app_actions` runs it: a real key needs the whole app, tested
/// below.
Future<void> _next(WidgetTester tester, ChatState chat) async {
  await chat.draft.text.spell!.menu.next();
  await tester.pumpAndSettle();
}

Finder get _menuRow => find.byType(MenuItemButton);

/// The menu's panel, on screen.
Rect _menuPanel(WidgetTester tester) => tester.getRect(
  find.ancestor(of: _menuRow.last, matching: find.byType(Material)).first,
);

double _menuBottom(WidgetTester tester) => _menuPanel(tester).bottom;

/// A widget test on a fake Mac that ends what it opened itself.
void spellTestApp(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(
      name,
      body,
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

bool _open(WidgetTester tester, ChatState chat) =>
    chat.draft.text.spell!.menu.controller.isOpen;

TextSelection _selected(ChatState chat) => chat.draft.text.selection;

void main() {
  setUpAll(loadFonts);

  spellTest('nothing fixes a word while a rewind has the box', (tester) async {
    final (_, chat) = await spellBox(tester, _speller());
    await typed(tester, 'please chekc this ');
    chat.rewinding.value = true;
    await tester.pump();
    await _clickWord(tester, chat, 'chekc');
    expect(_open(tester, chat), isFalse);
    await _next(tester, chat);
    expect(_open(tester, chat), isFalse);
    chat.rewinding.value = false;
    await tester.pump();
    await _next(tester, chat);
    expect(_open(tester, chat), isTrue);
  });

  group('a click', () {
    spellTest('on a flagged word opens its menu above it', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'please chekc this ');
      await _clickWord(tester, chat, 'chekc');
      expect(_open(tester, chat), isTrue);
      final word = _wordRect(tester, chat, 'chekc');
      expect(_menuBottom(tester), lessThanOrEqualTo(word.top));
      expect(tester.getTopLeft(_menuRow.first).dx, closeTo(word.left, 12));
      expect(
        _selected(chat),
        const TextSelection(baseOffset: 7, extentOffset: 12),
      );
    });

    spellTest('offers at most four suggestions, then Ignore and Add to '
        'dictionary', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'chekc ');
      await _clickWord(tester, chat, 'chekc');
      expect(_menuRow, findsExactly(6));
      for (final label in [
        'check',
        'Cheka',
        'chick',
        'cheek',
        'Ignore',
        'Add to dictionary',
      ]) {
        expect(find.text(label), findsOne, reason: label);
      }
      expect(find.text('chalk'), findsNothing);
      expect(find.text('⏎'), findsOne);
      expect(find.text('2'), findsOne);
      expect(find.text('4'), findsOne);
    });

    spellTest('elsewhere is a click', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'fine words chekc ');
      await _clickWord(tester, chat, 'words');
      expect(_open(tester, chat), isFalse);
      expect(_selected(chat).isCollapsed, isTrue);
    });

    spellTest("past the line's end isn't on its last word", (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'chekc ');
      final word = _wordRect(tester, chat, 'chekc');
      await _click(tester, word.centerRight + const Offset(200, 0));
      expect(_open(tester, chat), isFalse);
    });

    spellTest("with no suggestions says so; ⏎ still doesn't send", (
      tester,
    ) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'zzyx ');
      await _clickWord(tester, chat, 'zzyx');
      expect(find.text('No suggestions'), findsOne);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_open(tester, chat), isFalse);
      expect(chat.draft.text.text, 'zzyx ');
      expect(sentPrompts(), isEmpty);
    });
  });

  group('⌘;', () {
    spellTest('goes to the next flagged word after the caret, and wraps', (
      tester,
    ) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'chekc and thrid ');
      chat.draft.text.selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();
      await _next(tester, chat);
      expect(
        _selected(chat),
        const TextSelection(baseOffset: 10, extentOffset: 15),
      );
      expect(find.text('third'), findsOne);
      await _next(tester, chat);
      expect(
        _selected(chat),
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      expect(find.text('check'), findsOne);
      expect(_open(tester, chat), isTrue);
    });

    spellTest('takes in the word still being typed', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'the chekc');
      expect(flagged(chat), isEmpty);
      await _next(tester, chat);
      expect(flagged(chat), ['chekc']);
      expect(find.text('check'), findsOne);
    });

    spellTest('with nothing flagged does nothing', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'all good here ');
      await _next(tester, chat);
      expect(_open(tester, chat), isFalse);
      expect(_selected(chat).isCollapsed, isTrue);
    });

    spellTest('with the setting off does nothing', (tester) async {
      final speller = _speller();
      final (_, chat) = await spellBox(tester, speller);
      await typed(tester, 'chekc ');
      checkSpelling.value = false;
      await tester.pump();
      final calls = speller.asked.length;
      await _next(tester, chat);
      expect(_open(tester, chat), isFalse);
      expect(speller.asked.length, calls);
      expect(speller.guessed, isEmpty);
    });

    spellTest('scrolls a long prompt to a word out of sight', (tester) async {
      final (_, chat) = await spellBox(tester, _speller(), height: 500);
      final lines = List.filled(20, 'fine').join('\n');
      await typed(tester, '$lines\nchekc \n$lines');
      chat.draft.text.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await _next(tester, chat);
      final word = _wordRect(tester, chat, 'chekc');
      final field = tester.getRect(find.byType(EditableText));
      expect(word.top, greaterThanOrEqualTo(field.top - 1));
      expect(word.bottom, lessThanOrEqualTo(field.bottom + 1));
      expect(_menuBottom(tester), lessThanOrEqualTo(word.top));
    });
  });

  group('in the menu', () {
    Future<ChatState> opened(WidgetTester tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'please chekc this ');
      await _next(tester, chat);
      return chat;
    }

    spellTest("⏎ takes the first suggestion and doesn't send", (tester) async {
      final chat = await opened(tester);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(chat.draft.text.text, 'please check this ');
      expect(_open(tester, chat), isFalse);
      expect(sentPrompts(), isEmpty);
      expect(_selected(chat), const TextSelection.collapsed(offset: 12));
    });

    spellTest("⏎ held after it's used doesn't send", (tester) async {
      final chat = await opened(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sentPrompts(), isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // the next one does
      await tester.pumpAndSettle();
      expect(sentPrompts().single.text, 'please check this');
      expect(chat.draft.text.text, isEmpty);
    });

    for (final (key, fix) in [
      (LogicalKeyboardKey.digit1, 'check'),
      (LogicalKeyboardKey.digit2, 'Cheka'),
      (LogicalKeyboardKey.digit3, 'chick'),
      (LogicalKeyboardKey.digit4, 'cheek'),
    ]) {
      spellTest('${key.keyLabel} takes $fix', (tester) async {
        final chat = await opened(tester);
        await _key(tester, key);
        expect(chat.draft.text.text, 'please $fix this ');
      });
    }

    spellTest('esc closes and leaves the text', (tester) async {
      final chat = await opened(tester);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(_open(tester, chat), isFalse);
      expect(chat.draft.text.text, 'please chekc this ');
      expect(find.text('Ignore'), findsNothing);
    });

    spellTest('another key closes it and goes on to the box', (tester) async {
      final chat = await opened(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_open(tester, chat), isFalse);
      expect(_selected(chat).isCollapsed, isTrue); // the field took the key
    });

    spellTest('a digit past the suggestions is just a key', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'thrid ');
      await _next(tester, chat); // one suggestion
      await _key(tester, LogicalKeyboardKey.digit3);
      expect(_open(tester, chat), isFalse);
      expect(chat.draft.text.text, 'thrid ');
    });

    spellTest('shift alone leaves it open', (tester) async {
      final chat = await opened(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(_open(tester, chat), isTrue);
    });

    spellTest('the pointer over a row leaves the keys with the box', (
      tester,
    ) async {
      final chat = await opened(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Cheka')));
      addTearDown(mouse.removePointer);
      await mouse.moveBy(const Offset(1, 0));
      await tester.pumpAndSettle();
      expect(chat.draft.text.spell!.focus.hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.digit1);
      expect(chat.draft.text.text, 'please check this ');
    });

    spellTest('a click on a suggestion takes it, the focus back in the box', (
      tester,
    ) async {
      final chat = await opened(tester);
      await tester.tap(find.text('chick'));
      await tester.pumpAndSettle();
      expect(chat.draft.text.text, 'please chick this ');
      expect(chat.draft.text.spell!.focus.hasPrimaryFocus, isTrue);
    });

    spellTest('Ignore clears the flag and tells the checker', (tester) async {
      final speller = _speller();
      final (_, chat) = await spellBox(tester, speller);
      await typed(tester, 'chekc thrid ');
      await _clickWord(tester, chat, 'chekc');
      await tester.tap(find.text('Ignore'));
      await tester.pumpAndSettle();
      expect(flagged(chat), ['thrid']);
      expect(speller.ignored, ['chekc']);
      expect(speller.learned, isEmpty);
      expect(_selected(chat), const TextSelection.collapsed(offset: 5));
    });

    spellTest('Add to dictionary clears the flag and tells the checker', (
      tester,
    ) async {
      final speller = _speller();
      final (_, chat) = await spellBox(tester, speller);
      await typed(tester, 'chekc ');
      await _clickWord(tester, chat, 'chekc');
      await tester.tap(find.text('Add to dictionary'));
      await tester.pumpAndSettle();
      expect(flagged(chat), isEmpty);
      expect(speller.learned, ['chekc']);
      expect(speller.ignored, isEmpty);
    });

    spellTest('the setting turned off closes it', (tester) async {
      final chat = await opened(tester);
      checkSpelling.value = false;
      await tester.pumpAndSettle();
      expect(_open(tester, chat), isFalse);
    });

    spellTest('a checker that fails still clears the flag', (tester) async {
      final speller = _speller();
      final (_, chat) = await spellBox(tester, speller);
      await typed(tester, 'chekc ');
      await _clickWord(tester, chat, 'chekc');
      speller.failure = PlatformException(code: 'failed');
      await tester.tap(find.text('Ignore'));
      await tester.pumpAndSettle();
      expect(flagged(chat), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  spellTest("a suggestion keeps the word's capital", (tester) async {
    final (_, chat) = await spellBox(
      tester,
      FakeSpeller(
        {'Chekc'},
        fixes: const {
          'Chekc': ['check', 'czech'],
        },
      ),
    );
    await typed(tester, 'Chekc this ');
    await _next(tester, chat);
    expect(find.text('Check'), findsOne);
    expect(find.text('Czech'), findsOne);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(chat.draft.text.text, 'Check this ');
  });

  spellTest('⌘Z undoes a suggestion', (tester) async {
    final (_, chat) = await spellBox(tester, _speller());
    await typed(tester, 'please chekc this ');
    await tester.pump(const Duration(seconds: 1)); // typing's undo step
    await _next(tester, chat);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(chat.draft.text.text, 'please check this ');
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(chat.draft.text.text, 'please chekc this ');
  });

  group('a right-click', () {
    /// Right-clicks at [at] with text on the clipboard, for Paste to show.
    Future<void> rightClick(WidgetTester tester, Offset at) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.hasStrings'
            ? <String, Object?>{'value': true}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final field = tester.state<EditableTextState>(find.byType(EditableText));
      await field.clipboardStatus.update();
      await _click(tester, at, buttons: kSecondaryMouseButton);
    }

    spellTest('on a flagged word shows its suggestions beside Cut, Copy and '
        'Paste', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'please chekc this ');
      await rightClick(tester, _wordRect(tester, chat, 'chekc').center);
      for (final label in [
        'check',
        'Cheka',
        'chick',
        'cheek',
        'Ignore',
        'Add to dictionary',
        'Cut',
        'Copy',
        'Paste',
      ]) {
        expect(find.text(label), findsOne, reason: label);
      }
      await tester.tap(find.text('check'));
      await tester.pumpAndSettle();
      expect(chat.draft.text.text, 'please check this ');
      expect(find.text('Cut'), findsNothing);
    });

    spellTest('elsewhere is unchanged', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'please chekc this ');
      await rightClick(tester, _wordRect(tester, chat, 'please').center);
      for (final label in ['Cut', 'Copy', 'Paste']) {
        expect(find.text(label), findsOne, reason: label);
      }
      expect(find.text('check'), findsNothing);
      expect(find.text('Ignore'), findsNothing);
    });

    spellTest('with the setting off is unchanged', (tester) async {
      final (_, chat) = await spellBox(tester, _speller());
      await typed(tester, 'please chekc this ');
      final at = _wordRect(tester, chat, 'chekc').center;
      checkSpelling.value = false;
      await tester.pump();
      await rightClick(tester, at);
      expect(find.text('Cut'), findsOne);
      expect(find.text('Ignore'), findsNothing);
    });
  });

  spellTest('a message sends as written: typos never hold it up', (
    tester,
  ) async {
    final (_, chat) = await spellBox(tester, _speller());
    await typed(tester, 'please chekc this');
    await _key(tester, LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sentPrompts().single.text, 'please chekc this');
    expect(chat.draft.text.text, isEmpty);
  });

  group('in the whole app', () {
    Future<(Daemon, ChatState)> app(WidgetTester tester) async {
      testSpeller = _speller();
      addTearDown(() => testSpeller = null);
      viewport(tester, const Size(1200, 700));
      final d = await FakeDaemon([
        Chat(id: 'a', title: 'A chat', agent: 'claude', folder: '/Users/me/p'),
      ]).connect(tester);
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      d.select('a');
      await tester.pumpAndSettle();
      return (d, d.chats['a']!);
    }

    Future<void> command(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
    }

    spellTestApp('the real ⌘; reaches Next Typo from the box', (tester) async {
      final (d, chat) = await app(tester);
      await tester.enterText(find.byType(TextField).last, 'chekc and thrid ');
      await checked(tester);
      await command(tester, LogicalKeyboardKey.semicolon);
      expect(find.text('check'), findsOne);
      expect(
        _selected(chat),
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await closeView(tester, d);
    });

    spellTestApp("the palette has it while there's a box to go through", (
      tester,
    ) async {
      final (d, chat) = await app(tester);
      final context = tester.element(find.byType(Composer));
      AppAction row() =>
          appActions(context, d).firstWhere((a) => a.act == Act.nextTypo);
      expect(row().enabled, isTrue);
      expect(row().title, 'Next typo');
      expect(row().shortcut, '⌘;');
      checkSpelling.value = false;
      expect(row().enabled, isFalse);
      checkSpelling.value = true;
      chat.tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      expect(row().enabled, isFalse);
      await closeView(tester, d);
    });

    test('its key is in the Chat menu', () {
      expect(Act.nextTypo.menu, ActMenu.chat);
      expect(Act.nextTypo.menuLabel, 'Next Typo');
      expect(actKeys[nextTypoKey], isA<RunActIntent>());
    });
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    spellTest('golden: the open menu, $name', (tester) async {
      final (_, chat) = await spellBox(tester, _speller(), tokens: tokens);
      await typed(
        tester,
        'Can you chekc why the helper stops at the thrid try?',
      );
      await _clickWord(tester, chat, 'chekc');
      await expectLater(
        find.byKey(const Key('window')),
        matchesGoldenFile('goldens/spell_menu_$name.png'),
      );
    });
  }
}
