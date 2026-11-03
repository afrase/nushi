import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spell_check.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'spell_harness.dart';

void main() {
  setUpAll(loadFonts);

  spellTest("a misspelled word gets the error color's dotted underline", (
    tester,
  ) async {
    final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
    await typed(tester, 'please chekc the logs');
    expect(flagged(chat), ['chekc']);
    expect(underlined(tester), [('chekc', Tokens.dark.crashed)]);
  });

  spellTest('both themes use their own error color', (tester) async {
    await spellBox(
      tester,
      FakeSpeller({'chekc'}),
      text: 'please chekc it',
      tokens: Tokens.light,
    );
    await checked(tester);
    expect(underlined(tester), [('chekc', Tokens.light.crashed)]);
  });

  spellTest('what the box opens with is checked', (tester) async {
    final speller = FakeSpeller({'chekc'});
    final (_, chat) = await spellBox(tester, speller, text: 'chekc');
    await checked(tester);
    expect(flagged(chat), ['chekc']); // no typing, so nothing waits
  });

  spellTest('every kind of skipped word reaches neither the checker nor '
      'an underline', (tester) async {
    final speller = FakeSpeller({'chekc', 'thrid'});
    final (_, chat) = await spellBox(tester, speller);
    await typed(
      tester,
      r'chekc `thrid` ```thrid``` /thrid @thrid #thrid ~thrid $thrid -thrid '
      'app/lib/thrid.dart https://example.com/thrid thrid2 thrid.x thrid_x '
      'a:thrid thridThrid THRID Thrid ok ',
    );
    expect(speller.asked.expand((w) => w), isNot(contains('thrid')));
    expect(flagged(chat), ['chekc']);
  });

  spellTest('a hyphenated word is underlined only in its bad part', (
    tester,
  ) async {
    await spellBox(tester, FakeSpeller({'knwon'}));
    await typed(tester, 'a well-knwon fact');
    expect(underlined(tester).map((u) => u.$1), ['knwon']);
  });

  group('the word the caret is in', () {
    spellTest("isn't asked about while it's typed", (tester) async {
      final speller = FakeSpeller({'chekc'});
      final (_, chat) = await spellBox(tester, speller);
      await typed(tester, 'the chekc');
      expect(speller.asked.expand((w) => w), isNot(contains('chekc')));
      expect(flagged(chat), isEmpty);
    });

    spellTest('is flagged after a space', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
      await typed(tester, 'the chekc');
      await typed(tester, 'the chekc ');
      expect(flagged(chat), ['chekc']);
    });

    spellTest('is flagged after punctuation', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
      await typed(tester, 'the chekc');
      await typed(tester, 'the chekc,');
      expect(flagged(chat), ['chekc']);
    });

    spellTest('is flagged once the caret moves', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
      await typed(tester, 'the chekc');
      chat.draft.text.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      await checked(tester);
      expect(flagged(chat), ['chekc']);
    });

    spellTest('is flagged when the box loses the focus', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
      await typed(tester, 'the chekc');
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      await checked(tester);
      expect(flagged(chat), ['chekc']);
    });

    spellTest("loses its flag when typed in again, until it's left", (
      tester,
    ) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc', 'chkc'}));
      await typed(tester, 'chekc ');
      expect(flagged(chat), ['chekc']);
      chat.draft.text.value = const TextEditingValue(
        text: 'chekcs ',
        selection: TextSelection.collapsed(offset: 6),
      );
      await tester.pump();
      expect(flagged(chat), isEmpty); // nothing flashes mid-word
      chat.draft.text.value = const TextEditingValue(
        text: 'chekc ',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      expect(flagged(chat), isEmpty);
      chat.draft.text.selection = const TextSelection.collapsed(offset: 6);
      await tester.pump();
      expect(flagged(chat), ['chekc']); // moved on: known, so at once
    });
  });

  spellTest('a flag follows its word as text goes in before it', (
    tester,
  ) async {
    final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
    await typed(tester, 'chekc ');
    await typed(tester, 'ok chekc ');
    expect(chat.draft.text.marks, [(start: 3, end: 8, word: 'chekc')]);
    expect(underlined(tester).map((u) => u.$1), ['chekc']);
  });

  spellTest('each word is asked about once', (tester) async {
    final speller = FakeSpeller({'chekc'});
    await spellBox(tester, speller);
    await typed(tester, 'chekc this ');
    await typed(tester, 'chekc this chekc this ');
    expect(speller.asked, [
      ['chekc', 'this'],
    ]);
  });

  spellTest('fast typing asks nothing until it pauses', (tester) async {
    final speller = FakeSpeller({});
    await spellBox(tester, speller);
    for (final text in ['one ', 'one two ', 'one two three ']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(spellPause ~/ 2);
    }
    expect(speller.asked, isEmpty);
    await checked(tester);
    expect(speller.asked, [
      ['one', 'two', 'three'],
    ]);
  });

  spellTest('an answer that comes late lands on the text as it is now', (
    tester,
  ) async {
    final speller = FakeSpeller({'chekc'})..hold = Completer();
    final (_, chat) = await spellBox(tester, speller);
    await typed(tester, 'chekc ');
    await tester.enterText(find.byType(TextField), 'ok then ');
    await tester.pump();
    speller.hold!.complete();
    await tester.pump();
    expect(flagged(chat), isEmpty); // the word has gone
    await tester.enterText(find.byType(TextField), 'ok chekc ');
    await tester.pump();
    expect(chat.draft.text.marks, [(start: 3, end: 8, word: 'chekc')]);
  });

  spellTest('only the start of a long paste is checked, whole words', (
    tester,
  ) async {
    final speller = FakeSpeller({'late'});
    final (_, chat) = await spellBox(tester, speller);
    final start = 'word ' * (spellLimit ~/ 5);
    await typed(tester, '${start}late ');
    expect(speller.asked.expand((w) => w), isNot(contains('late')));
    expect(flagged(chat), isEmpty);
  });

  spellTest("during an input method's composing nothing is asked and the "
      'composing text keeps its look', (tester) async {
    final speller = FakeSpeller({'chekc', 'thrid'});
    final (_, chat) = await spellBox(tester, speller);
    await typed(tester, 'chekc ');
    final calls = speller.asked.length;
    chat.draft.text.value = const TextEditingValue(
      text: 'chekc thrid',
      selection: TextSelection.collapsed(offset: 11),
      composing: TextRange(start: 6, end: 11),
    );
    await tester.pump();
    await checked(tester);
    expect(speller.asked.length, calls);
    expect(underlined(tester).map((u) => u.$1), ['chekc']);
    // Committed, it's a word like any other.
    chat.draft.text.value = const TextEditingValue(
      text: 'chekc thrid ',
      selection: TextSelection.collapsed(offset: 12),
    );
    await tester.pump();
    await checked(tester);
    expect(flagged(chat), ['chekc', 'thrid']);
  });

  group("the agent's words", () {
    Item agent(String text) =>
        Item(kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

    spellTest("are known, and the checker isn't asked", (tester) async {
      final speller = FakeSpeller({'nushid', 'chekc'});
      final (_, chat) = await spellBox(tester, speller);
      chat
        ..items.add(agent('The Nushid daemon is up.'))
        ..revision += 1;
      await typed(tester, 'nushid chekc ');
      expect(speller.asked.expand((w) => w), isNot(contains('nushid')));
      expect(flagged(chat), ['chekc']);
    });

    spellTest("your own messages aren't", (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
      chat
        ..items.add(Item(kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'chekc'))
        ..revision += 1;
      await typed(tester, 'chekc ');
      expect(flagged(chat), ['chekc']);
    });

    spellTest('are read again when the transcript changes', (tester) async {
      final speller = FakeSpeller({'nushid'});
      final (_, chat) = await spellBox(tester, speller);
      await typed(tester, 'nushid ');
      expect(flagged(chat), ['nushid']);
      chat
        ..items.add(agent('nushid'))
        ..revision += 1;
      await typed(tester, 'nushid more ');
      expect(flagged(chat), isEmpty);
    });
  });

  group('the setting off', () {
    spellTest('removes the underlines at once', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
      await typed(tester, 'chekc ');
      expect(underlined(tester), isNotEmpty);
      checkSpelling.value = false;
      await tester.pump();
      expect(flagged(chat), isEmpty);
      expect(underlined(tester), isEmpty);
    });

    spellTest('asks nothing', (tester) async {
      checkSpelling.value = false;
      final speller = FakeSpeller({'chekc'});
      await spellBox(tester, speller, text: 'chekc ');
      await checked(tester);
      await typed(tester, 'chekc thrid ');
      expect(speller.asked, isEmpty);
    });

    spellTest('drops an answer on its way', (tester) async {
      final speller = FakeSpeller({'chekc'})..hold = Completer();
      final (_, chat) = await spellBox(tester, speller);
      await typed(tester, 'chekc ');
      checkSpelling.value = false;
      await tester.pump();
      speller.hold!.complete();
      await tester.pump();
      expect(flagged(chat), isEmpty);
    });

    spellTest('and on again, the box checks again', (tester) async {
      final (_, chat) = await spellBox(tester, FakeSpeller({'chekc'}));
      await typed(tester, 'chekc ');
      checkSpelling.value = false;
      await tester.pump();
      checkSpelling.value = true;
      await tester.pump();
      expect(flagged(chat), ['chekc']);
    });
  });

  spellTest('a failing checker leaves typing as it was, and flags nothing', (
    tester,
  ) async {
    final speller = FakeSpeller({'chekc'})
      ..failure = PlatformException(code: 'failed');
    final (_, chat) = await spellBox(tester, speller);
    await typed(tester, 'chekc ');
    await typed(tester, 'chekc thrid ');
    expect(chat.draft.text.text, 'chekc thrid ');
    expect(flagged(chat), isEmpty);
    expect(tester.takeException(), isNull);
    speller.failure = null; // back: the next change tries again
    await typed(tester, 'chekc thrid and ');
    expect(flagged(chat), ['chekc']);
  });

  spellTest('a missing channel flags nothing and throws nothing', (
    tester,
  ) async {
    final speller = FakeSpeller({'chekc'})..failure = MissingPluginException();
    final (_, chat) = await spellBox(tester, speller);
    await typed(tester, 'chekc ');
    expect(flagged(chat), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no speller, on a phone, nothing is asked or flagged', (
    tester,
  ) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/Users/me/project')..loaded = true;
    d.chats['c'] = chat;
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Composer(chat: chat, daemon: d),
        ),
      ),
    );
    expect(speller, isNull); // tests run as Android unless they say
    await tester.enterText(find.byType(TextField), 'chekc thrid ');
    await checked(tester);
    expect(chat.draft.text.spell!.on, isFalse);
    expect(flagged(chat), isEmpty);
    expect(underlined(tester), isEmpty);
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    spellTest('golden: an underlined prompt, $name', (tester) async {
      await spellBox(tester, FakeSpeller({'chekc', 'thrid'}), tokens: tokens);
      await typed(
        tester,
        'Can you chekc why the `chekc` helper stops after the thrid failure?',
      );
      await expectLater(
        find.byKey(const Key('window')),
        matchesGoldenFile('goldens/spell_underline_$name.png'),
      );
    });
  }
}
