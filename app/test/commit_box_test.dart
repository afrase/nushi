import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commit_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _shown = 'index-1';

List<FileChange> _changes() => [
  FileChange(
    path: 'app/lib/relay.dart',
    status: 'modified',
    oldText: 'final wait = 5;\n',
    newText: 'final wait = 2;\n',
    added: 1,
    removed: 1,
    staged: 'all',
  ),
  FileChange(
    path: 'app/test/relay_test.dart',
    status: 'modified',
    newText: 'final tests = 1;\n',
    added: 1,
    staged: 'part',
  ),
  FileChange(path: 'notes.md', status: 'untracked', newText: 'n\n', added: 1),
];

/// A Changes view on Uncommitted, and the requests made to the daemon.
Future<(Daemon, ChatState, List<Object?>)> _view(
  WidgetTester tester,
  List<FileChange> files, {
  Object? commit,
  Size size = const Size(1100, 700),
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, size, brightness: brightness);
  final asked = <Object?>[];
  final fake = FakeDaemon([])
    ..answer = (input) {
      asked.add(input);
      return switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'b',
          defaultBase: 'main',
        ),
        GetDiffRequest() => GetDiffResponse(files: files, index: _shown),
        StageFilesRequest() => StageFilesResponse(),
        WriteCommitMessageRequest() => WriteCommitMessageResponse(
          message: 'Shorten the relay wait',
        ),
        CommitStagedRequest() =>
          commit == null
              ? CommitStagedResponse(short: 'abc1234')
              : throw StateError('$commit'),
        _ => null,
      };
    };
  final d = await fake.connect(tester);
  final state = ChatState('c', '/x')..scope = Scope.uncommitted.name;
  addTearDown(() => state.scope = null);
  await tester.pumpWidget(
    themed(
      ChangesView(chat: state, daemon: d),
      tokens: brightness == Brightness.dark ? Tokens.dark : Tokens.light,
    ),
  );
  await tester.pumpAndSettle();
  return (d, state, asked);
}

void main() {
  setUpAll(loadFonts);

  testWidgets("a file's checkbox stages it, by every path of a rename", (
    tester,
  ) async {
    final files = _changes()
      ..add(
        FileChange(
          path: 'new.dart',
          oldPath: 'old.dart',
          status: 'renamed',
          staged: '',
        ),
      )
      ..sort((a, b) => a.path.compareTo(b.path));
    final (d, _, asked) = await _view(tester, files);
    final boxes = find.byType(Checkbox);
    expect(boxes, findsNWidgets(8)); // the box's, 3 folders' and 4 files'
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.textContaining('new.dart', findRichText: true),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    final stage = asked.whereType<StageFilesRequest>().single;
    expect(stage.staged, isTrue);
    expect(stage.paths, ['new.dart', 'old.dart']);
    d.dispose();
  });

  testWidgets('a repository inside the folder has no checkbox', (tester) async {
    final (d, _, _) = await _view(tester, [
      FileChange(
        path: 'vendored',
        status: 'untracked',
        skipped: 'a repository of its own',
      ),
    ]);
    expect(find.byType(Checkbox), findsNothing);
    d.dispose();
  });

  testWidgets('Commit asks for what was shown, and waits for a message', (
    tester,
  ) async {
    final (d, state, asked) = await _view(tester, _changes());
    expect(find.text('2 of 3 staged'), findsOne);
    final commit = find.text('Commit 2 files');
    await tester.tap(commit);
    await tester.pumpAndSettle();
    expect(asked.whereType<CommitStagedRequest>(), isEmpty);
    state.commitMessage.text = 'Shorten the relay wait';
    await tester.pumpAndSettle();
    await tester.tap(commit);
    await tester.pumpAndSettle();
    final ask = asked.whereType<CommitStagedRequest>().single;
    expect(ask.message, 'Shorten the relay wait');
    expect(ask.index, _shown);
    expect(state.commitMessage.text, isEmpty);
    expect(find.text('Committed abc1234'), findsOne);
    d.dispose();
  });

  testWidgets('a checkbox clicked while another stages is sent, though the '
      'view goes first', (tester) async {
    final hold = Completer<void>();
    var stages = 0;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'b',
          defaultBase: 'main',
        ),
        GetDiffRequest() => GetDiffResponse(files: _changes(), index: _shown),
        StageFilesRequest() when ++stages == 1 => hold.future.then(
          (_) => StageFilesResponse(),
        ),
        StageFilesRequest() => StageFilesResponse(),
        _ => null,
      };
    viewport(tester, const Size(1100, 700));
    final d = await fake.connect(tester);
    final state = ChatState('c', '/x')..scope = Scope.uncommitted.name;
    addTearDown(() => state.scope = null);
    await tester.pumpWidget(themed(ChangesView(chat: state, daemon: d)));
    await tester.pumpAndSettle();
    Finder box(String file) => find.descendant(
      of: find
          .ancestor(
            of: find.textContaining(file, findRichText: true),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(Checkbox),
    );
    await tester.tap(box('notes.md'));
    await tester.pump();
    await tester.tap(box('relay_test.dart'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox()); // another tab
    hold.complete();
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<StageFilesRequest>(), hasLength(2));
    d.dispose();
  });

  testWidgets('a commit that fails says why and keeps the message', (
    tester,
  ) async {
    final (d, state, _) = await _view(
      tester,
      _changes(),
      commit: StateError('git commit: lint: bad file'),
    );
    state.commitMessage.text = 'Keep me';
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commit 2 files'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lint: bad file'), findsOne);
    expect(state.commitMessage.text, 'Keep me');
    d.dispose();
  });

  testWidgets('the agent writes the message, into the field', (tester) async {
    final (d, state, asked) = await _view(tester, _changes());
    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    state.canWriteCommit = true;
    state.commitMessage.text = 'x'; // rebuilds the box
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    expect(state.commitMessage.text, 'Shorten the relay wait');
    expect(asked.whereType<WriteCommitMessageRequest>().single.chatId, 'c');
    expect(asked.whereType<CommitStagedRequest>(), isEmpty);
    // It's the user's to change: what commits is what the field says then.
    await tester.enterText(
      find.byType(TextField),
      'Shorten the relay wait to 2s',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commit 2 files'));
    await tester.pumpAndSettle();
    expect(
      asked.whereType<CommitStagedRequest>().single.message,
      'Shorten the relay wait to 2s',
    );
    d.dispose();
  });

  testWidgets('no commit box outside Uncommitted', (tester) async {
    final (d, state, _) = await _view(tester, _changes());
    expect(find.byType(CommitBox), findsOne);
    state.scope = Scope.branch.name;
    await tester.pumpAndSettle();
    expect(find.byType(CommitBox), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    d.dispose();
  });

  // The box under the staged files' checks, as Uncommitted's side shows
  // them: a component golden. The view at the window's sizes is a render
  // with its layout asserted below (docs/development.md's Goldens and
  // renders: Changes' window golden is related_worktrees_golden's, on
  // Branch, which has no box).
  for (final (tokens, theme) in [
    (Tokens.dark, 'dark'),
    (Tokens.light, 'light'),
  ]) {
    testWidgets('stage and commit: the box under the files staged, $theme', (
      tester,
    ) async {
      viewport(tester, const Size(300, 420));
      final chat = ChatState('c', '/x')
        ..canWriteCommit = true
        ..commitMessage.text = 'Shorten the relay wait';
      final files = _changes();
      void stage(List<FileChange> _, {required bool on}) {}
      await tester.pumpWidget(
        themed(
          RepaintBoundary(
            key: const Key('side'),
            // On the pane's fill, as the Changes view backs it: without it
            // the PNG is transparent and its light text reads as faint.
            child: ColoredBox(
              color: tokens.base,
              child: SizedBox(
                width: 260,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: FileList(
                        files: files,
                        selected: 'app/lib/relay.dart',
                        onSelect: (_) {},
                        onStage: stage,
                      ),
                    ),
                    CommitBox(
                      chat: chat,
                      files: files,
                      onStage: stage,
                      onCommit: (_) async {},
                      onWrite: () async => '',
                    ),
                  ],
                ),
              ),
            ),
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 of 3 staged'), findsOne);
      await expectLater(
        find.byKey(const Key('side')),
        matchesGoldenFile('goldens/commit_box_$theme.png'),
      );
    });
  }

  for (final (size, name) in [
    (const Size(1700, 900), '1700'),
    (const Size(720, 700), '720'),
  ]) {
    for (final (mode, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      if (!lightCopy(mode)) {
        testWidgets('stage and commit at $name, $theme', (tester) async {
          final (d, state, _) = await _view(
            tester,
            _changes(),
            size: size,
            brightness: mode,
          );
          state
            ..canWriteCommit = true
            ..commitMessage.text = 'Shorten the relay wait';
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // The view's own layout at the window's size, which the
          // component golden above builds a copy of: Uncommitted's bar
          // above, and the box at the foot of the files' column, as wide
          // as it, under the last file.
          final view = tester.getRect(find.byType(ChangesView));
          for (final label in ['Uncommitted', '3 files']) {
            final r = tester.getRect(find.text(label));
            expect(r.bottom, lessThan(view.top + 44), reason: label);
          }
          final files = tester.getRect(find.byType(FileList));
          final box = tester.getRect(find.byType(CommitBox));
          expect(files.left, view.left);
          expect(files.width, 240);
          expect(box.left, files.left);
          expect(box.width, files.width);
          expect(box.top, greaterThanOrEqualTo(files.bottom));
          expect(
            box.top,
            greaterThan(
              tester
                  .getRect(find.textContaining('notes.md', findRichText: true))
                  .bottom,
            ),
          );
          expect(box.bottom, lessThanOrEqualTo(view.bottom));
          expect(box.bottom, greaterThan(view.bottom - 16));
          expect(
            tester.getRect(find.text('Commit 2 files')).bottom,
            lessThan(box.bottom),
          );
          await render(
            tester,
            find.byType(ChangesView),
            'changes_commit_${name}_$theme',
          );
          d.dispose();
        });
      }

      testWidgets('nothing changed, at $name, $theme', (tester) async {
        final (d, _, _) = await _view(
          tester,
          const [],
          size: size,
          brightness: mode,
        );
        expect(find.text('No changes'), findsOne);
        expect(find.byType(CommitBox), findsNothing);
        // No block of code's surface with no file to show in it.
        final t = mode == Brightness.dark ? Tokens.dark : Tokens.light;
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                (w.decoration as BoxDecoration?)?.color == t.codeBlock,
          ),
          findsNothing,
        );
        await render(
          tester,
          find.byType(ChangesView),
          'changes_empty_${name}_$theme',
        );
        d.dispose();
      });
    }
  }
}
