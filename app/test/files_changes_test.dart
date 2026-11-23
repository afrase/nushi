import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/change_marks.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/line_changes.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/source_editor.dart';

import 'change_marks_test.dart' show changeBase, changeShown;
import 'fake_daemon.dart' show FakeDaemon, loadFonts, wrote;
import 'file_edit_helpers.dart';
import 'harness.dart';

// The Files pane with change marks (ADR 0131): a written file's
// right-click Show changes, a new file's note, and full windows of the
// marks and their card to look at (written only with NUSHI_RENDERS set).

/// The chat wrote main.go, notes.md (new), new.go (new), same.go (written
/// back as it was) and plan.md (changed); README.md it didn't.
final List<Item> _items = [
  ...editItems,
  wrote('w1', 'main.go'),
  wrote('w2', 'notes.md'),
  wrote('w3', 'new.go'),
  wrote('w4', 'same.go'),
  wrote('w5', 'plan.md'),
];

final _folder = [
  FolderEntry(name: 'main.go', kind: 'file'),
  FolderEntry(name: 'new.go', kind: 'file'),
  FolderEntry(name: 'notes.md', kind: 'file'),
  FolderEntry(name: 'plan.md', kind: 'file'),
  FolderEntry(name: 'README.md', kind: 'file'),
  FolderEntry(name: 'same.go', kind: 'file'),
];

const _planBase = '# Plan\n\n- Parse the header.\n- Read the body.\n';
const _planNow =
    '# Plan\n\n- Parse the header first.\n- Read the body.\n'
    '- Check the footer.\n- Say what failed.\n';

/// The chat's folder on a branch of its own, off main: the marks count
/// from where it left main (`FakeDaemon.fileDiffs` answers either way).
Object? _onBranch(Object input) => switch (input) {
  GetFolderStatusRequest() => GetFolderStatusResponse(
    git: true,
    branch: 'nushi/parser',
    defaultBase: 'main',
  ),
  _ => null,
};

/// The chat's folder on main itself: the marks count from the last
/// commit.
Object? _onMain(Object input) => switch (input) {
  GetFolderStatusRequest() => GetFolderStatusResponse(
    git: true,
    branch: 'main',
    defaultBase: 'main',
  ),
  _ => null,
};

Future<(Daemon, FakeDaemon)> _open(
  WidgetTester tester, {
  List<String> open = const ['main.go'],
  double width = 1700,
  Brightness brightness = Brightness.light,
  String base = changeBase,
  Object? Function(Object input)? answer = _onBranch,
}) => openEditor(
  tester,
  {
    'main.go': utf8.encode(changeShown),
    'notes.md': utf8.encode('# Notes\n\nWhat the parser still misses.\n'),
    'README.md': utf8.encode('# Parser\n'),
    'new.go': utf8.encode(
      'package main\n\nfunc parse() {}\n\nfunc check() {}\n',
    ),
    'same.go': utf8.encode('package main\n'),
    'plan.md': utf8.encode(_planNow),
  },
  open: open,
  width: width,
  brightness: brightness,
  items: _items,
  folder: _folder,
  answer: answer,
  fileDiffs: {
    '/Users/me/nushi/new.go': FileChange(path: 'new.go', status: 'untracked'),
    '/Users/me/nushi/plan.md': FileChange(
      path: 'plan.md',
      status: 'modified',
      oldText: _planBase,
    ),
    '/Users/me/nushi/main.go': FileChange(
      path: 'main.go',
      status: 'modified',
      oldText: base,
    ),
    '/Users/me/nushi/notes.md': FileChange(
      path: 'notes.md',
      status: 'untracked',
    ),
  },
);

Finder _row(String name) =>
    find.descendant(of: find.byType(FilesTree), matching: find.text(name));

/// The path row's word on the shown file's marks.
Finder _status(String words) =>
    find.descendant(of: find.byType(PathLine), matching: find.text(words));

/// The path row's pill, if it has one.
Finder get _pill =>
    find.descendant(of: find.byType(PathLine), matching: find.byType(NotePill));

/// The marks in the editor or the source, whichever shows.
Finder get _marks => find.byType(ChangeMark);

/// The lines [lineMarks] marks, as the path row counts them.
int sumOfMarks(String base, String now) => lineMarks(
  base,
  now,
).fold(0, (n, m) => n + (m.kind == MarkKind.removed ? m.old.length : m.count));

/// The chat shows [path] in Files.
Future<void> _show(WidgetTester tester, Daemon d, String path) async {
  chatC(d).openInFiles(path);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets("a written file's right-click opens it in Changes; others "
      'have no menu', (tester) async {
    final (d, _) = await _open(tester);
    await tester.tap(_row('README.md'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Show changes'), findsNothing);

    await tester.tap(_row('main.go'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Show changes'), findsOneWidget);
    expect(find.byType(ChangesView), findsNothing);
    await tester.tap(find.text('Show changes'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangesView), findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a new file: every line barred, New file on its path row, '
      'its card says so', (tester) async {
    final (d, _) = await _open(tester, open: ['new.go']);
    expect(_status('New file'), findsOneWidget);
    final pill = tester.widget<NotePill>(_pill);
    expect(pill.tone, NoteTone.done);
    expect(pill.onTap, isNull);
    // Its five lines, each barred as added.
    final marks = tester.widgetList<ChangeMark>(_marks).toList();
    expect(marks, hasLength(5));
    expect(marks.every((m) => m.cell.bar?.kind == MarkKind.added), isTrue);
    await tester.tap(_marks.first);
    await tester.pumpAndSettle();
    expect(find.text('Not in main'), findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a changed file: marks in its editor, and how many lines '
      'since what on its path row', (tester) async {
    final (d, _) = await _open(tester);
    expect(
      find.descendant(
        of: find.byType(SourceEditor),
        matching: find.byType(ChangeMark),
      ),
      findsNWidgets(7),
    );
    final n = sumOfMarks(changeBase, changeShown);
    expect(_status('$n changed lines since main'), findsOneWidget);
    expect(tester.widget<NotePill>(_pill).tone, NoteTone.accent);
    expect(find.text('New file'), findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a written file the same as its base: No changes since main; '
      'a file the chat never wrote says nothing', (tester) async {
    final (d, _) = await _open(tester, open: ['same.go']);
    expect(_status('No changes since main'), findsOneWidget);
    expect(_marks, findsNothing);
    await _show(tester, d, 'README.md');
    expect(_pill, findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("a rendered Markdown file's changes: a pill that leads to "
      'its source, where they are marked', (tester) async {
    final (d, _) = await _open(tester, open: ['plan.md']);
    // Markdown opens rendered: no gutter there.
    expect(find.byType(SourceEditor), findsNothing);
    expect(_marks, findsNothing);
    final words = '${sumOfMarks(_planBase, _planNow)} changed lines since main';
    expect(_status(words), findsOneWidget);
    expect(tester.widget<NotePill>(_pill).onTap, isNotNull);
    await tester.tap(_pill);
    await tester.pumpAndSettle();
    expect(_marks, findsWidgets);
    // In the source the pill only says.
    expect(_status(words), findsOneWidget);
    expect(tester.widget<NotePill>(_pill).onTap, isNull);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a new rendered Markdown file: New file leads to its source', (
    tester,
  ) async {
    final (d, _) = await _open(tester, open: ['notes.md']);
    expect(_status('New file'), findsOneWidget);
    await tester.tap(_pill);
    await tester.pumpAndSettle();
    expect(_marks, findsNWidgets(3));
    await endEditor(tester, d);
  }, variant: onMac);

  group('a chat on main itself', () {
    final began = fixtureNow.millisecondsSinceEpoch ~/ 1000;
    Object? Function(Object) onMain(List<Commit> commits) =>
        (input) => switch (input) {
          ListCommitsRequest() => ListCommitsResponse(commits: commits),
          _ => _onMain(input),
        };

    testWidgets('with commits of its own: from before them, and says so', (
      tester,
    ) async {
      final (d, fake) = await _open(
        tester,
        answer: onMain([
          Commit(hash: 'c2', unixSeconds: Int64(began + 90)),
          Commit(hash: 'c1', unixSeconds: Int64(began + 30)),
          Commit(hash: 'c0', unixSeconds: Int64(began - 3600)),
        ]),
      );
      final asked = fake.calls.whereType<GetDiffRequest>().where(
        (r) => r.path == 'main.go',
      );
      expect(asked.last.base, 'c1^');
      expect(_marks, findsNWidgets(7));
      final n = sumOfMarks(changeBase, changeShown);
      expect(_status('$n changed lines since this chat began'), findsOneWidget);
      await tester.tap(_marks.first);
      await tester.pumpAndSettle();
      expect(find.text('Before this chat'), findsOneWidget);
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('no commit since it began: since the last commit', (
      tester,
    ) async {
      final (d, _) = await _open(
        tester,
        answer: onMain([Commit(hash: 'c0', unixSeconds: Int64(began - 60))]),
      );
      final n = sumOfMarks(changeBase, changeShown);
      expect(_status('$n changed lines since the last commit'), findsOneWidget);
      await endEditor(tester, d);
    }, variant: onMac);
  });

  for (final (what, change, words, tone) in [
    (
      'not in a repository',
      ConnectException(
        Code.failedPrecondition,
        '/Users/me/nushi is not in a git repository',
      ),
      'Not in a git repository',
      NoteTone.quiet,
    ),
    (
      'ignored',
      FileChange(path: 'same.go', status: 'untracked', skipped: 'not tracked'),
      'Ignored by git',
      NoteTone.quiet,
    ),
    (
      'a link',
      FileChange(path: 'same.go', status: 'modified', skipped: 'a link'),
      'A link: no change marks',
      NoteTone.quiet,
    ),
    (
      'binary',
      FileChange(path: 'same.go', status: 'modified', skipped: 'binary'),
      'Not text: no change marks',
      NoteTone.quiet,
    ),
    (
      'too large',
      FileChange(path: 'same.go', status: 'modified', skipped: 'too large'),
      'Too large for change marks',
      NoteTone.quiet,
    ),
  ]) {
    testWidgets('$what: its path row says so', (tester) async {
      final (d, fake) = await _open(tester, open: []);
      fake.fileDiffs['/Users/me/nushi/same.go'] = change;
      await _show(tester, d, 'same.go');
      expect(_status(words), findsOneWidget);
      expect(tester.widget<NotePill>(_pill).tone, tone);
      expect(_marks, findsNothing);
      await endEditor(tester, d);
    }, variant: onMac);
  }

  testWidgets('a failure says so, its words a click away', (tester) async {
    final (d, fake) = await _open(tester, open: []);
    fake.fileDiffs['/Users/me/nushi/same.go'] = ConnectException(
      Code.internal,
      'git diff: exit status 128',
    );
    await _show(tester, d, 'same.go');
    expect(_status('Couldn’t compare with git'), findsOneWidget);
    final pill = tester.widget<NotePill>(_pill);
    expect(pill.tone, NoteTone.crashed);
    expect(pill.tip, contains('exit status 128'));
    await tester.tap(_pill);
    await tester.pumpAndSettle();
    expect(find.textContaining('exit status 128'), findsWidgets);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('an older daemon: says marks need a newer one', (tester) async {
    final (d, _) = await _open(tester, open: []);
    d.daemonApi = oneFileDiffApi - 1;
    await _show(tester, d, 'same.go');
    expect(_status('Change marks need a newer daemon'), findsOneWidget);
    expect(tester.widget<NotePill>(_pill).tone, NoteTone.needs);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a slow answer: nothing at first, then a quiet Comparing…, '
      'then the word', (tester) async {
    final answer = Completer<Object?>();
    final (d, _) = await _open(
      tester,
      open: [],
      answer: (input) => switch (input) {
        GetDiffRequest(path: 'main.go') => answer.future,
        _ => _onBranch(input),
      },
    );
    chatC(d).openInFiles('main.go');
    await tester.pump();
    await tester.pump();
    expect(find.text('Comparing…'), findsNothing);
    expect(_pill, findsNothing);
    await tester.pump(Waits.slow);
    expect(find.text('Comparing…'), findsOneWidget);
    answer.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Comparing…'), findsNothing);
    expect(_pill, findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("on the chat's branch, the marks count from main and stay "
      'after a commit; the card says so', (tester) async {
    var committed = false;
    final (d, fake) = await _open(
      tester,
      answer: (input) => switch (input) {
        // Committed, HEAD has the text: only the branch's base differs.
        GetDiffRequest(:final base) when committed && base.isEmpty =>
          GetDiffResponse(),
        _ => _onBranch(input),
      },
    );
    await tester.pumpAndSettle();
    List<GetDiffRequest> asked() => [
      for (final r in fake.calls.whereType<GetDiffRequest>())
        if (r.path == 'main.go') r,
    ];
    expect(asked().last.base, 'main');
    expect(find.byType(ChangeMark), findsNWidgets(7));

    committed = true;
    chatC(d).committed();
    await tester.pumpAndSettle();
    expect(asked().last.base, 'main');
    expect(find.byType(ChangeMark), findsNWidgets(7));
    await tester.tap(find.byType(ChangeMark).first);
    await tester.pumpAndSettle();
    expect(find.text('Before this branch'), findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('on main itself, from the last commit, and the card says '
      'Before', (tester) async {
    final (d, fake) = await _open(tester, answer: _onMain);
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<GetDiffRequest>().where(
      (r) => r.path == 'main.go',
    );
    expect(asked.last.base, isEmpty);
    await tester.tap(find.byType(ChangeMark).first);
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('Before this branch'), findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    for (final width in [1700.0, 720.0]) {
      final w = width.toInt();
      renderTest('renders: marks, a card, a new file, the menu, $w, $theme', (
        tester,
      ) async {
        final (d, _) = await _open(
          tester,
          width: width,
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        final app = find.byType(NushiApp);
        await render(tester, app, 'cl_${w}_marks_$theme');

        // A changed run's card, and the removal's.
        await tester.tap(find.byType(ChangeMark).first);
        await tester.pumpAndSettle();
        expect(find.byType(ChangeCard), findsOneWidget);
        await render(tester, app, 'cl_${w}_card_changed_$theme');
        // A second click hides it.
        await tester.tap(find.byType(ChangeMark).first);
        await tester.pumpAndSettle();
        expect(find.byType(ChangeCard), findsNothing);
        await tester.tap(find.byType(ChangeMark).at(3));
        await tester.pumpAndSettle();
        expect(find.text('2 lines removed'), findsOneWidget);
        await render(tester, app, 'cl_${w}_card_removed_$theme');
        await tester.tap(find.byType(ChangeMark).at(3));
        await tester.pumpAndSettle();

        // The pointer on an added line's mark.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(ChangeMark).last));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('New lines'), findsOneWidget);
        await render(tester, app, 'cl_${w}_card_added_$theme');
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        await mouse.removePointer();

        // The written file's menu, if the tree shows.
        if (_row('main.go').evaluate().isNotEmpty) {
          await tester.tap(_row('main.go'), buttons: kSecondaryButton);
          await tester.pumpAndSettle();
          await render(tester, app, 'cl_${w}_menu_$theme');
          await tester.tapAt(tester.getCenter(find.byType(PathLine)));
          await tester.pumpAndSettle();
        }

        chatC(d).openInFiles('notes.md');
        await tester.pumpAndSettle();
        await render(tester, app, 'cl_${w}_new_file_$theme');
        await endEditor(tester, d);
      }, variant: onMac);
      renderTest(
        "renders: the path row's word on each kind of file, $w, $theme",
        (tester) async {
          final app = find.byType(NushiApp);
          var (d, fake) = await _open(
            tester,
            open: ['new.go'],
            width: width,
            brightness: brightness,
          );
          await render(tester, app, 'marks_${w}_new_file_$theme');
          await _show(tester, d, 'main.go');
          await render(tester, app, 'marks_${w}_edited_$theme');
          await _show(tester, d, 'same.go');
          await render(tester, app, 'marks_${w}_unchanged_$theme');
          await _show(tester, d, 'plan.md');
          await render(tester, app, 'marks_${w}_markdown_$theme');
          await tester.tap(_pill);
          await tester.pumpAndSettle();
          await render(tester, app, 'marks_${w}_markdown_source_$theme');
          await endEditor(tester, d);

          (d, fake) = await _open(
            tester,
            open: [],
            width: width,
            brightness: brightness,
            answer: (input) => switch (input) {
              GetFolderStatusRequest() => GetFolderStatusResponse(),
              _ => null,
            },
          );
          fake.fileDiffs['/Users/me/nushi/main.go'] = ConnectException(
            Code.failedPrecondition,
            '/Users/me/nushi is not in a git repository',
          );
          await _show(tester, d, 'main.go');
          expect(_status('Not in a git repository'), findsOneWidget);
          await render(tester, app, 'marks_${w}_no_repository_$theme');
          expectTextInside(tester, width);
          await endEditor(tester, d);
        },
        variant: onMac,
      );
      renderTest("renders: a long old line's card, $w, $theme", (tester) async {
        // The comment was 130 columns long before.
        final long = '// greet says hello. ${'and more words ' * 7}end.';
        final (d, _) = await _open(
          tester,
          width: width,
          brightness: brightness,
          base: changeBase.replaceFirst('// greet says hello.', long),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ChangeMark).first);
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'cl_${w}_card_long_$theme');
        await endEditor(tester, d);
      }, variant: onMac);
    }
  }
}
