import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Commit sends the index of what Changes showed, never a newer one's
// (ADR 0079).

/// A folder's changes, [staged] being the paths in the index.
List<FileChange> _changes(Set<String> staged) => [
  for (final p in {
    'app/lib/relay.dart',
    'notes.md',
    ...staged,
  }.toList()..sort())
    FileChange(
      path: p,
      status: 'modified',
      newText: 'x\n',
      added: 1,
      staged: staged.contains(p) ? 'all' : '',
    ),
];

/// A folder whose index can move under the view: what GetDiff answers is
/// as [staged] and [index] stand when its [gate], if any, opens.
class _Folder {
  Set<String> staged = {'app/lib/relay.dart'};
  String index = 'index-1';
  Completer<void>? gate;
  final asked = <Object?>[];

  Object? answer(Object input) {
    asked.add(input);
    GetDiffResponse diff() =>
        GetDiffResponse(files: _changes(staged), index: index);
    return switch (input) {
      GetFolderStatusRequest() => GetFolderStatusResponse(
        git: true,
        branch: 'b',
        defaultBase: 'main',
      ),
      GetDiffRequest() => switch (gate) {
        null => diff(),
        final g => g.future.then((_) => diff()),
      },
      StageFilesRequest() => StageFilesResponse(),
      CommitStagedRequest() => CommitStagedResponse(short: 'abc1234'),
      _ => null,
    };
  }

  Iterable<CommitStagedRequest> get commits =>
      asked.whereType<CommitStagedRequest>();
}

Future<(Daemon, ChatState, _Folder)> _view(
  WidgetTester tester, {
  Size size = const Size(1100, 700),
}) async {
  viewport(tester, size);
  paneWidths.value = {};
  final folder = _Folder();
  final fake = FakeDaemon([])..answer = folder.answer;
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/x')..scope = Scope.uncommitted.name;
  addTearDown(() => chat.scope = null);
  await tester.pumpWidget(themed(ChangesView(chat: chat, daemon: d)));
  await tester.pumpAndSettle();
  chat.commitMessage.text = 'Shorten the relay wait';
  return (d, chat, folder);
}

/// Clicks [file]'s checkbox.
Future<void> _check(WidgetTester tester, String file) async {
  await tester.tap(
    find.descendant(
      of: find
          .ancestor(
            of: find.textContaining(file, findRichText: true),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(Checkbox),
    ),
  );
  await tester.pump();
}

/// A turn ends, which reloads the view.
void _turnEnds(ChatState chat) => chat
  ..busy = true
  ..notifyListeners()
  ..busy = false
  ..notifyListeners();

void main() {
  setUpAll(loadFonts);

  testWidgets("a file the agent stages between Stage and Commit isn't "
      'committed', (tester) async {
    final (d, chat, folder) = await _view(tester);
    // Staged; its reload held.
    final staging = folder.gate = Completer<void>();
    await _check(tester, 'notes.md');
    // A turn ends meanwhile: its reload, held too.
    final turn = folder.gate = Completer<void>();
    _turnEnds(chat);
    await tester.pump();
    await tester.tap(find.text('Commit 2 files'));
    await tester.pump();
    folder
      ..staged = {'app/lib/relay.dart', 'notes.md'}
      ..index = 'index-2';
    staging.complete();
    await tester.pump();
    // The agent staged a file of its own before the turn's reload read.
    folder
      ..staged = {'agent.env', 'app/lib/relay.dart', 'notes.md'}
      ..index = 'index-3';
    turn.complete();
    await tester.pumpAndSettle();
    expect(folder.commits, isEmpty);
    expect(
      find.text(
        'Staged files changed since you looked: agent.env. Look them over '
        'and commit again.',
      ),
      findsOne,
    );
    expect(chat.commitMessage.text, 'Shorten the relay wait');
    // Shown now: the next click commits it.
    folder.gate = null;
    await tester.tap(find.text('Commit 3 files'));
    await tester.pumpAndSettle();
    expect(folder.commits.single.index, 'index-3');
    d.dispose();
  });

  testWidgets("Commit waits for a turn's reload that overtook staging's, "
      'and asks for the index that shows', (tester) async {
    final (d, chat, folder) = await _view(tester);
    final staging = folder.gate = Completer<void>();
    await _check(tester, 'notes.md');
    final turn = folder.gate = Completer<void>();
    _turnEnds(chat);
    await tester.pump();
    await tester.tap(find.text('Commit 2 files'));
    await tester.pump();
    folder
      ..staged = {'app/lib/relay.dart', 'notes.md'}
      ..index = 'index-2';
    staging.complete();
    await tester.pump();
    // The same files, reread (a file the user staged, changed and staged
    // again by the user's click, is what the click asked for).
    folder.index = 'index-3';
    turn.complete();
    await tester.pumpAndSettle();
    expect(folder.commits.single.index, 'index-3');
    d.dispose();
  });

  testWidgets('with nothing staged since the view read, Commit sends the '
      "index it showed, not a later reload's", (tester) async {
    final (d, chat, folder) = await _view(tester);
    final turn = folder.gate = Completer<void>();
    _turnEnds(chat);
    await tester.pump();
    await tester.tap(find.text('Commit 1 file'));
    await tester.pump();
    // The agent staged the same file again, with newer text.
    folder.index = 'index-2';
    turn.complete();
    await tester.pumpAndSettle();
    // The daemon refuses it: the index moved.
    expect(folder.commits.single.index, 'index-1');
    d.dispose();
  });

  testWidgets("a file the agent stages after Commit's click isn't committed", (
    tester,
  ) async {
    final (d, chat, folder) = await _view(tester);
    final turn = folder.gate = Completer<void>();
    _turnEnds(chat);
    await tester.pump();
    await tester.tap(find.text('Commit 1 file'));
    await tester.pump();
    folder
      ..staged = {'agent.env', 'app/lib/relay.dart'}
      ..index = 'index-2';
    turn.complete();
    await tester.pumpAndSettle();
    expect(folder.commits, isEmpty);
    expect(
      find.textContaining('Staged files changed since you looked: agent.env.'),
      findsOne,
    );
    d.dispose();
  });

  for (final (size, name) in [
    (const Size(1700, 900), '1700'),
    (const Size(720, 700), '720'),
  ]) {
    testWidgets('the refusal at $name', (tester) async {
      final (d, chat, folder) = await _view(tester, size: size);
      final turn = folder.gate = Completer<void>();
      _turnEnds(chat);
      await tester.pump();
      await tester.tap(find.text('Commit 1 file'));
      await tester.pump();
      folder.staged = {
        'agent.env',
        'app/lib/relay.dart',
        'notes.md',
        'a/b.dart',
        'c.dart',
      };
      turn.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'a/b.dart, agent.env, c.dart and 1 more. Look them',
        ),
        findsOne,
      );
      await render(tester, find.byType(ChangesView), 'commit_moved_$name');
      d.dispose();
    });
  }

  testWidgets("a reload shown before the click is what's committed", (
    tester,
  ) async {
    final (d, chat, folder) = await _view(tester);
    folder
      ..staged = {'agent.env', 'app/lib/relay.dart'}
      ..index = 'index-2';
    _turnEnds(chat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commit 2 files'));
    await tester.pumpAndSettle();
    expect(folder.commits.single.index, 'index-2');
    d.dispose();
  });

  testWidgets("the user's own Unstage counts as seen", (tester) async {
    final (d, _, folder) = await _view(tester);
    final staging = folder.gate = Completer<void>();
    await _check(tester, 'notes.md');
    await _check(tester, 'relay.dart');
    await tester.tap(find.text('Commit 1 file'));
    await tester.pump();
    folder
      ..staged = {'notes.md'}
      ..index = 'index-2';
    staging.complete();
    await tester.pumpAndSettle();
    expect(folder.commits.single.index, 'index-2');
    d.dispose();
  });
}
