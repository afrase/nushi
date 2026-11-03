import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/spell_check.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Daemon? _open;

/// A widget test on a fake Mac, where spell check runs, that ends the
/// [spellBox] it opened.
void spellTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      if (_open case final d?) await closeView(tester, d);
      _open = null;
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

/// A stand-in for the Mac's checker: [wrong] are misspelled, and it records
/// what it was asked. It never reaches the real one, whose `learnWord` writes
/// the owner's dictionary.
class FakeSpeller implements Speller {
  new(this.wrong, {this.fixes = const {}});

  final Set<String> wrong;
  final Map<String, List<String>> fixes;
  final asked = <List<String>>[];
  final guessed = <String>[];
  final ignored = <String>[];
  final learned = <String>[];

  /// Set, every call fails with it, as a missing channel does.
  Exception? failure;

  /// Set, `misspelled` answers only when it completes.
  Completer<void>? hold;

  @override
  Future<List<String>> misspelled(List<String> words) async {
    asked.add(words);
    await hold?.future;
    if (failure case final f?) throw f;
    return words.where(wrong.contains).toList();
  }

  @override
  Future<List<String>> guesses(String word) async {
    guessed.add(word);
    if (failure case final f?) throw f;
    return fixes[word] ?? const [];
  }

  @override
  Future<void> ignore(String word) async {
    ignored.add(word);
    if (failure case final f?) throw f;
  }

  @override
  Future<void> learn(String word) async {
    learned.add(word);
    if (failure case final f?) throw f;
  }
}

/// The prompt box of a new chat on [speller], at the bottom of a window
/// of [width] by [height], with [text] in it; a test's speller goes when the
/// test ends.
Future<(Daemon, ChatState)> spellBox(
  WidgetTester tester,
  Speller speller, {
  String text = '',
  Tokens tokens = Tokens.dark,
  double width = 640,
  double height = 320,
}) async {
  testSpeller = speller;
  addTearDown(() => testSpeller = null);
  final d = await FakeDaemon([]).connect(tester);
  final chat = ChatState('c', '/Users/me/project')
    ..agent = 'claude'
    ..loaded = true;
  chat.draft.text.text = text;
  d.chats['c'] = chat;
  _open = d;
  viewport(tester, Size(width, height));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('window'),
      child: MaterialApp(
        theme: NushiTheme(tokens).toThemeData(),
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              ColoredBox(
                color: tokens.base,
                child: ListenableBuilder(
                  listenable: chat,
                  builder: (context, _) => Composer(chat: chat, daemon: d),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (d, chat);
}

/// Lets the pause in typing pass, and the checker's answer come.
Future<void> checked(WidgetTester tester) async {
  await tester.pump(spellPause);
  await tester.pump();
}

/// Types [text] into the box, all of it at once, caret at its end.
Future<void> typed(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await checked(tester);
}

/// The words flagged.
List<String> flagged(ChatState chat) => [
  for (final m in chat.draft.text.marks) m.word,
];

/// The field's text as laid out.
RenderEditable editable(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

/// The text drawn with the dotted underline, and that underline's color.
List<(String, Color?)> underlined(WidgetTester tester) {
  final found = <(String, Color?)>[];
  editable(tester).text!.visitChildren((span) {
    final style = span.style;
    if (span is TextSpan &&
        style?.decoration == TextDecoration.underline &&
        style?.decorationStyle == TextDecorationStyle.dotted) {
      found.add((span.text!, style!.decorationColor));
    }
    return true;
  });
  return found;
}
