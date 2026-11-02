import 'dart:typed_data';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_find.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// UX review, finding 23: ⌘F in a transcript and in Changes.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Item _msg(String id, ItemKind kind, String text) =>
    Item(id: id, kind: kind, text: text);

/// The app on chat c, its transcript four messages, two naming the relay;
/// its Changes two files, one with Sub in it.
Future<Daemon> _app(WidgetTester tester) async {
  viewport(tester, const Size(1700, 700), brightness: Brightness.dark);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  paneWidths.value = {};
  showDetails.value = false;
  const user = ItemKind.ITEM_KIND_USER_MESSAGE;
  const agent = ItemKind.ITEM_KIND_AGENT_MESSAGE;
  final c = chat('c', 'claude', 'Flaky relay');
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          _msg('u1', user, 'Why does the relay test fail?'),
          _msg('a1', agent, 'It waits on a fixed sleep.'),
          _msg('u2', user, 'Use a fake clock.'),
          _msg('a2', agent, 'Done: the relay test uses the fake clock now.'),
        ],
      ),
      GetFolderStatusRequest() => GetFolderStatusResponse(
        git: true,
        branch: 'fix',
        defaultBase: 'main',
      ),
      GetDiffRequest() => GetDiffResponse(
        files: [
          FileChange(
            path: 'sub.go',
            oldText: 'func Sub() {}\n\nfunc unchanged() {}\n',
            newText: 'func Sub(n int) {}\n\nfunc unchanged() {}\n',
            added: 1,
            removed: 1,
          ),
          FileChange(path: 'add.go', newText: 'func Add() {}\n', added: 1),
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<void> _cmdF(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// The marks of the find on the transcript.
List<TextMark> _marks(WidgetTester tester) {
  final scope = tester.widget<TextMarksScope>(find.byType(TextMarksScope));
  return scope.marks.marks;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('⌘F in the chat: its matches marked, ⏎ and ⇧⏎ through them, '
      'Esc closes', (tester) async {
    final d = await _app(tester);
    final chat = d.chats['c']!;
    await _cmdF(tester);
    expect(find.byType(FindBar), findsOne);
    await tester.enterText(
      find.descendant(
        of: find.byType(FindBar),
        matching: find.byType(EditableText),
      ),
      'relay',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOne);
    expect(_marks(tester), hasLength(2));
    expect(chat.find.current, 'u1 0');
    for (final (mode, name) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      viewport(tester, const Size(1700, 700), brightness: mode);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(NushiApp),
        matchesGoldenFile('goldens/find_chat_$name.png'),
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOne);
    expect(chat.find.current, 'a2 0');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(chat.find.current, 'u1 0');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsNothing);
    expect(_marks(tester), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('⌘F in Changes: the files with the text, its hits in the diff', (
    tester,
  ) async {
    final d = await _app(tester);
    final chat = d.chats['c']!..tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    await _cmdF(tester);
    expect(find.byType(FindBar), findsOne);
    await tester.enterText(
      find.descendant(
        of: find.byType(FindBar),
        matching: find.byType(EditableText),
      ),
      'sub(',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOne);
    expect(find.textContaining('add.go', findRichText: true), findsNothing);
    expect(find.textContaining('sub.go', findRichText: true), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsNothing);
    expect(find.textContaining('add.go', findRichText: true), findsWidgets);
    expect(chat.changesFind.query, isNull);
    d.dispose();
  }, variant: _mac);

  testWidgets('⌘F in Changes: ⏎ goes on to the next file with the text, and '
      '⇧⏎ back to the end of the one before', (tester) async {
    final d = await _app(tester);
    final chat = d.chats['c']!..tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    await _cmdF(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(FindBar),
        matching: find.byType(EditableText),
      ),
      'func',
    );
    await tester.pumpAndSettle();
    final find_ = chat.changesFind;
    expect(find.text('1 of 3 · file 1 of 2'), findsOne);
    for (final (mode, name) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      viewport(tester, const Size(1700, 700), brightness: mode);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(NushiApp),
        matchesGoldenFile('goldens/find_changes_$name.png'),
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find_.files, (1, 2));
    expect(find.text('2 of 3 · file 1 of 2'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find_.files, (2, 2));
    expect(find.text('1 of 1 · file 2 of 2'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find_.files, (1, 2));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find_.files, (2, 2));
    d.dispose();
  }, variant: _mac);

  test('a diff is found through top to bottom, an unchanged line once', () {
    final diff = TextDiff.compute(
      'keep a\ngone a\nend\n',
      'keep a\nnew a\nend\n',
      path: 'f',
    );
    final doc = diff.document;
    final hits = findInDiff(
      diff.lines,
      doc.oldLineCount,
      doc.newLineCount,
      'A',
    );
    expect(
      [for (final h in hits.steps) (h.side, h.line)],
      [(PaneSide.neu, 0), (PaneSide.old, 1), (PaneSide.neu, 1)],
    );
    expect([for (final h in hits.also) (h.side, h.line)], [(PaneSide.old, 0)]);
  });

  test('a hit takes the place of the syntax under it', () {
    final line = DiffLine(
      line: 0,
      text: 'return value',
      syntax: Uint32List.fromList([0, 6, 1, 7, 5, 2]),
    );
    const hit = (side: PaneSide.neu, line: 0, start: 3, length: 6);
    final marked = markHits(line, [hit], hit, mark: 8, markNow: 9);
    expect(marked.syntax, [0, 3, 1, 3, 6, 9, 9, 3, 2]);
    expect(marked.inner, [3, 6, innerChanged]);
  });
}
