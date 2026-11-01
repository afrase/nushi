import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commit_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
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
  paneWidths.value = {};
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
    MaterialApp(
      theme: NushiTheme(
        brightness == Brightness.dark ? Tokens.dark : Tokens.light,
      ).toThemeData(),
      home: Scaffold(
        body: ChangesView(chat: state, daemon: d),
      ),
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

  testWidgets('no commit box outside Uncommitted', (tester) async {
    final (d, state, _) = await _view(tester, _changes());
    expect(find.byType(CommitBox), findsOne);
    state.scope = Scope.branch.name;
    await tester.pumpAndSettle();
    expect(find.byType(CommitBox), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    d.dispose();
  });

  for (final (size, name) in [
    (const Size(1700, 900), '1700'),
    (const Size(720, 700), '720'),
  ]) {
    for (final (mode, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      testWidgets('stage and commit at $name, $theme', (tester) async {
        final (d, state, _) = await _view(
          tester,
          _changes(),
          size: size,
          brightness: mode,
        );
        state.commitMessage.text = 'Shorten the relay wait';
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(ChangesView),
          matchesGoldenFile('goldens/stage_commit_${name}_$theme.png'),
        );
        d.dispose();
      });
    }
  }
}
