import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';

/// Switching what the Changes view shows: a load that takes a moment dims
/// what's shown under a spinner; a quick one doesn't; an answer overtaken
/// by another switch is dropped.
void main() {
  late FakeDaemon fake;
  late ChatState chat;
  // GetDiff's answers, by scope ("" for Uncommitted, the base for Branch,
  // the commit for Commits), to give when the test says.
  late Map<String, Completer<GetDiffResponse>> diffs;
  late Daemon daemon;

  GetDiffResponse files(List<String> paths) => GetDiffResponse(
    files: [
      for (final p in paths)
        FileChange(path: p, oldText: 'a\n', newText: 'b\n', added: 1),
    ],
  );

  Future<void> open(WidgetTester tester) async {
    fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'feature',
          defaultBase: 'main',
        ),
        ListCommitsRequest() => ListCommitsResponse(
          commits: [
            for (final n in ['two', 'one'])
              Commit(hash: n, short: n, subject: 'Commit $n'),
          ],
        ),
        GetDiffRequest(:final base, :final commit) =>
          (diffs[base + commit] ??= Completer()).future,
        _ => null,
      };
    diffs = {};
    chat = ChatState('c', '/x')..scope = 'uncommitted';
    addTearDown(() => chat.scope = null);
    daemon = await fake.connect(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: ChangesView(chat: chat, daemon: daemon),
        ),
      ),
    );
    await tester.pump();
    diffs['']!.complete(files(['uncommitted.txt']));
    await tester.pump();
    await tester.pump();
    expect(find.text('uncommitted.txt  +1', findRichText: true), findsOne);
  }

  Future<void> answer(WidgetTester tester, String key, String path) async {
    diffs[key]!.complete(files([path]));
    await tester.pump();
    await tester.pump();
  }

  setUpAll(loadFonts);

  bool spinning() =>
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
  double opacity(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('a quick switch neither dims nor spins', (tester) async {
    await open(tester);
    chat.scope = 'branch';
    await tester.pump(const Duration(milliseconds: 50));
    diffs['main']!.complete(files(['branch.txt']));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(spinning(), isFalse);
    expect(opacity(tester), 1);
    expect(find.text('branch.txt  +1', findRichText: true), findsOne);
    expect(find.textContaining('uncommitted.txt'), findsNothing);
    daemon.dispose();
  });

  testWidgets("a slow one dims the other scope's files under a spinner", (
    tester,
  ) async {
    await open(tester);
    chat.scope = 'branch';
    await tester.pump(const Duration(milliseconds: 100));
    // Before the moment's up: as it was, the scope still Uncommitted.
    expect(spinning(), isFalse);
    expect(opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(spinning(), isTrue);
    expect(opacity(tester), lessThan(1));
    // Uncommitted's file stays, dimmed and not to be clicked, but the
    // toolbar doesn't count it as Branch's.
    expect(find.text('uncommitted.txt  +1', findRichText: true), findsOne);
    expect(find.text('1 file'), findsNothing);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(AnimatedOpacity),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    diffs['main']!.complete(files(['branch.txt']));
    await tester.pump();
    await tester.pump();
    expect(spinning(), isFalse);
    expect(opacity(tester), 1);
    expect(find.text('branch.txt  +1', findRichText: true), findsOne);
    expect(find.text('1 file'), findsOne);
    daemon.dispose();
  });

  testWidgets('an answer overtaken by another switch is dropped', (
    tester,
  ) async {
    await open(tester);
    chat.scope = 'branch';
    await tester.pump(const Duration(milliseconds: 200));
    diffs.remove('');
    chat.scope = 'uncommitted';
    await tester.pump();
    await tester.pump();
    diffs['']!.complete(files(['again.txt']));
    await tester.pump();
    await tester.pump();
    diffs['main']!.complete(files(['branch.txt'])); // too late
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('again.txt  +1', findRichText: true), findsOne);
    expect(find.textContaining('branch.txt'), findsNothing);
    expect(spinning(), isFalse);
    daemon.dispose();
  });

  testWidgets('picking another commit dims its files until they come', (
    tester,
  ) async {
    await open(tester);
    chat.scope = 'commits';
    for (var i = 0; i < 5; i++) {
      await tester.pump(); // the status, the commits
    }
    await answer(tester, 'two', 'two.txt');
    await tester.tap(find.text('Commit one'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(spinning(), isTrue);
    expect(find.text('two.txt  +1', findRichText: true), findsOne);
    expect(opacity(tester), lessThan(1));
    await answer(tester, 'one', 'one.txt');
    expect(spinning(), isFalse);
    expect(find.text('one.txt  +1', findRichText: true), findsOne);
    daemon.dispose();
  });

  testWidgets('a commit picked during a reload is read after it', (
    tester,
  ) async {
    await open(tester);
    chat.scope = 'commits';
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await answer(tester, 'two', 'two.txt');
    diffs.remove('two');
    await tester.tap(find.byTooltip('Reload'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(); // the status, the commits, then two's files
    }
    await tester.tap(find.text('Commit one'));
    await answer(tester, 'two', 'two again.txt');
    await answer(tester, 'one', 'one.txt');
    expect(find.text('one.txt  +1', findRichText: true), findsOne);
    expect(spinning(), isFalse);
    expect(tester.widget<IconTap>(find.byType(IconTap).last).onTap, isNotNull);
    daemon.dispose();
  });
}
