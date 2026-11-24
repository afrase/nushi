import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/line_base.dart';
import 'package:nushi/line_changes.dart';
import 'package:nushi/marks_base.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/preview.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart' show sumOf;
import 'harness.dart';

// A file preview's change marks (ADR 0131): which lines differ from the
// chat's branch base (else the last commit), and its text, asked of the
// daemon.

const _base = 'one\ntwo\nthree\nfour\nfive\n';

/// The GetDiff questions with a path [fake] was asked.
List<GetDiffRequest> _asked(FakeDaemon fake) =>
    fake.calls.whereType<GetDiffRequest>().toList();

void main() {
  group('lineMarks', () {
    test('equal texts have none', () {
      expect(lineMarks(_base, _base), isEmpty);
    });

    test('added, changed and removed lines', () {
      const shown = 'one\nTWO\nthree\nnew a\nnew b\nfour\n';
      expect(lineMarks(_base, shown), [
        const LineMark(MarkKind.changed, 1, 1, ['two']),
        const LineMark(MarkKind.added, 3, 2),
        const LineMark(MarkKind.removed, 6, 0, ['five']),
      ]);
    });

    test('lines removed at the top', () {
      expect(lineMarks(_base, 'three\nfour\nfive\n'), [
        const LineMark(MarkKind.removed, 0, 0, ['one', 'two']),
      ]);
    });

    test('line endings and a BOM aside, the same text has none', () {
      expect(lineMarks(_base.replaceAll('\n', '\r\n'), _base), isEmpty);
      expect(lineMarks('﻿$_base', _base), isEmpty);
      expect(lineMarks(_base, '﻿$_base'), isEmpty);
    });

    test("a CRLF base's old lines have no CR", () {
      expect(lineMarks('a\r\nb\r\n', 'a\nB\n'), [
        const LineMark(MarkKind.changed, 1, 1, ['b']),
      ]);
    });

    test('past 10,000 lines on a side, none', () {
      final long = List.filled(10001, 'x').join('\n');
      expect(lineMarks(long, '$long\ny'), isEmpty);
      expect(lineMarks('y', long), isEmpty);
    });

    test('a long text is diffed off the UI thread, alike', () async {
      final base = [for (var i = 0; i < 3000; i++) 'line $i'].join('\n');
      final shown = base.replaceFirst('line 1500', 'line X');
      final soon = lineMarksSoon(base, shown);
      expect(soon, isA<Future<List<LineMark>>>());
      expect(await soon, lineMarks(base, shown));
      expect(lineMarksSoon(_base, _base), isA<List<LineMark>>());
    });
  });

  test('markCells puts each mark on its lines', () {
    final cells = markCells(const [
      LineMark(MarkKind.changed, 1, 2, ['b']),
      LineMark(MarkKind.removed, 0, 0, ['z']),
      LineMark(MarkKind.removed, 4, 0, ['end']),
    ], 4);
    expect(cells[0]!.top!.old, ['z']);
    expect(cells[0]!.bar, isNull);
    expect(cells[1]!.bar!.kind, MarkKind.changed);
    expect(cells[2]!.bar!.kind, MarkKind.changed);
    // Removed at the end: the last line's bottom edge.
    expect(cells[3]!.bottom!.old, ['end']);
    expect(markCells(const [], 0), isEmpty);
  });

  group('LineBase', () {
    late FakeDaemon fake;
    late Daemon d;
    late ChatState c;
    late FileWatch watch;
    late LineBase lines;

    /// [path] on the fake's disk as [text], its change [change] (a
    /// FileChange or an exception; none: unchanged), watched and asked.
    Future<LineBase> start(
      WidgetTester tester, {
      String path = 'src/a.go',
      String text = _base,
      Object? change,
      int api = oneFileDiffApi,
      Object? Function(Object input)? answer,
      Worktree? worktree,
    }) async {
      final made = chat('c', 'claude', 'Fix');
      if (worktree != null) made.worktree = worktree;
      fake = FakeDaemon([made])..answer = answer;
      fake.files[path] = utf8.encode(text);
      if (change != null) fake.fileDiffs['/Users/me/nushi/$path'] = change;
      d = (await fake.connect(tester))..daemonApi = api;
      c = d.chats['c']!;
      watch = FileWatch(d, 'c', path);
      lines = LineBase(d, c, watch);
      await tester.pumpAndSettle();
      return lines;
    }

    Future<void> end(WidgetTester tester) async {
      lines.dispose();
      watch.dispose();
      await closeView(tester, d);
    }

    testWidgets("asks of the file's own folder, its name as the path", (
      tester,
    ) async {
      await start(tester);
      expect(_asked(fake).single.folder, '/Users/me/nushi/src');
      expect(_asked(fake).single.path, 'a.go');
      // No change: its text now is the last commit's.
      expect(lines.value, _base);
      expect(lines.isNew, isFalse);
      await end(tester);
    });

    testWidgets("an absolute path's folder, as the daemon names it", (
      tester,
    ) async {
      const path = '/elsewhere/lib/b.dart';
      await start(tester, path: path);
      final data = utf8.encode('b\n');
      fake.sendWatch(
        path,
        WatchChatFileResponse(path: path, data: data, sha256: sumOf(data)),
      );
      await tester.pumpAndSettle();
      expect(_asked(fake).last.folder, '/elsewhere/lib');
      expect(_asked(fake).last.path, 'b.dart');
      await end(tester);
    });

    testWidgets("a modified file's base is the last commit's text", (
      tester,
    ) async {
      await start(
        tester,
        path: 'a.go',
        text: 'new\n',
        change: FileChange(path: 'a.go', status: 'modified', oldText: 'old\n'),
      );
      expect(lines.value, 'old\n');
      await end(tester);
    });

    for (final what in ['untracked', 'added']) {
      testWidgets('$what: new, its base empty, every line added', (
        tester,
      ) async {
        await start(
          tester,
          path: 'a.go',
          change: FileChange(path: 'a.go', status: what),
        );
        expect(lines.value, '');
        expect(lines.isNew, isTrue);
        expect(lines.none, isNull);
        expect(lines.changed, 5);
        expect(lineMarks(lines.value!, _base), [
          const LineMark(MarkKind.added, 0, 5),
        ]);
        await end(tester);
      });
    }

    for (final (what, change, why) in [
      (
        'ignored',
        FileChange(status: 'untracked', skipped: 'not tracked'),
        NoMarks.ignored,
      ),
      (
        'a link',
        FileChange(status: 'modified', skipped: 'a link'),
        NoMarks.link,
      ),
      (
        'binary',
        FileChange(status: 'modified', skipped: 'binary'),
        NoMarks.binary,
      ),
      (
        'too large',
        FileChange(status: 'modified', skipped: 'too large'),
        NoMarks.tooLarge,
      ),
      (
        'a submodule',
        FileChange(status: 'modified', skipped: 'a submodule'),
        NoMarks.otherRepository,
      ),
      (
        'unreadable',
        FileChange(status: 'modified', skipped: 'unreadable'),
        NoMarks.failed,
      ),
      ('deleted', FileChange(status: 'deleted'), NoMarks.failed),
    ]) {
      testWidgets('$what: no base, and why', (tester) async {
        await start(tester, path: 'a.go', change: change..path = 'a.go');
        expect(lines.value, isNull);
        expect(lines.isNew, isFalse);
        expect(lines.none, why);
        expect(lines.loaded, isTrue);
        await end(tester);
      });
    }

    testWidgets('not in a repository: no base, and says so', (tester) async {
      await start(
        tester,
        change: ConnectException(
          Code.failedPrecondition,
          '/Users/me/nushi/src is not in a git repository',
        ),
      );
      expect(lines.value, isNull);
      expect(lines.isNew, isFalse);
      expect(lines.none, NoMarks.notRepository);
      await end(tester);
    });

    testWidgets("a failure: no base, the daemon's words kept", (tester) async {
      await start(
        tester,
        change: ConnectException(Code.unavailable, 'the daemon went'),
      );
      expect(lines.value, isNull);
      expect(lines.none, NoMarks.failed);
      expect(lines.error, contains('the daemon went'));
      await end(tester);
    });

    testWidgets('the same as its base: no changes, counted none', (
      tester,
    ) async {
      await start(tester);
      expect(lines.value, _base);
      expect(lines.none, isNull);
      expect(lines.changed, 0);
      await end(tester);
    });

    testWidgets('a modified file counts its lines added, changed and '
        'removed', (tester) async {
      await start(
        tester,
        path: 'a.go',
        text: 'one\nTWO\nthree\nnew a\nnew b\nfour\n',
        change: FileChange(path: 'a.go', status: 'modified', oldText: _base),
      );
      // One changed, two added, one removed.
      expect(lines.changed, 4);
      await end(tester);
    });

    testWidgets('past 10,000 lines: no marks, and why', (tester) async {
      final long = '${List.filled(10001, 'x').join('\n')}\n';
      await start(
        tester,
        path: 'a.go',
        text: long,
        change: FileChange(path: 'a.go', status: 'modified', oldText: 'x\n'),
      );
      expect(lines.value, isNull);
      expect(lines.none, NoMarks.tooManyLines);
      await end(tester);
    });

    testWidgets('a slow first answer says so after a moment; nothing '
        'before', (tester) async {
      await start(
        tester,
        path: 'a.go',
        answer: (input) => input is GetDiffRequest
            ? Future<Object?>.delayed(
                const Duration(seconds: 1),
                GetDiffResponse.new,
              )
            : null,
      );
      // start's settling waited the answer out: ask again from afresh.
      lines.dispose();
      lines = LineBase(d, c, watch);
      await tester.pump(Waits.slow ~/ 2);
      expect(lines.slow, isFalse);
      await tester.pump(Waits.slow);
      expect(lines.slow, isTrue);
      expect(lines.loaded, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(lines.slow, isFalse);
      expect(lines.loaded, isTrue);
      await end(tester);
    });

    testWidgets('asks again as the file changes, a turn ends and the chat '
        'commits', (tester) async {
      await start(tester, path: 'a.go');
      expect(_asked(fake), hasLength(1));
      fake.putFile('a.go', utf8.encode('changed\n'));
      await tester.pumpAndSettle();
      expect(_asked(fake), hasLength(2));
      // An empty answer: the text when it was asked.
      expect(lines.value, 'changed\n');
      // The same file again: nothing to ask.
      fake.putFile('a.go', utf8.encode('changed\n'));
      await tester.pumpAndSettle();
      expect(_asked(fake), hasLength(2));

      // A turn's state as the daemon's events set it.
      c
        ..busy = true
        ..notifyListeners();
      await tester.pump();
      expect(_asked(fake), hasLength(2));
      c
        ..busy = false
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(_asked(fake), hasLength(3));

      c.committed();
      await tester.pumpAndSettle();
      expect(_asked(fake), hasLength(4));
      await end(tester);
    });

    testWidgets('only the latest answer lands', (tester) async {
      var n = 0;
      await start(
        tester,
        path: 'a.go',
        text: 'v1\n',
        answer: (input) {
          if (input is! GetDiffRequest) return null;
          // The first answer comes last.
          if (++n == 1) {
            return Future<Object?>.delayed(
              const Duration(seconds: 1),
              () => GetDiffResponse(
                files: [
                  FileChange(
                    path: 'a.go',
                    status: 'modified',
                    oldText: 'old\n',
                  ),
                ],
              ),
            );
          }
          return GetDiffResponse();
        },
      );
      fake.putFile('a.go', utf8.encode('v2\n'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(lines.value, 'v2\n');
      await end(tester);
    });

    group("from the chat's branch base, as the Branch view counts", () {
      /// GetFolderStatus as [status] answers it (by the base asked; a
      /// thrown error fails it), and GetDiff with a base as [diff] does.
      Object? Function(Object) git(
        GetFolderStatusResponse Function(String base) status, {
        Object? Function(GetDiffRequest)? diff,
      }) =>
          (input) => switch (input) {
            GetFolderStatusRequest(:final base) => status(base),
            final GetDiffRequest r when r.base.isNotEmpty => diff?.call(r),
            _ => null,
          };
      GetFolderStatusResponse onBranch(String _) => GetFolderStatusResponse(
        git: true,
        branch: 'nushi/fix',
        defaultBase: 'main',
      );
      final change = GetDiffResponse(
        files: [FileChange(path: 'a.go', status: 'modified', oldText: 'old\n')],
      );

      testWidgets("a worktree's base", (tester) async {
        await start(
          tester,
          path: 'a.go',
          worktree: Worktree(base: 'dev', baseCommit: 'abc123'),
          answer: git(onBranch, diff: (_) => change),
        );
        expect(_asked(fake).single.base, 'dev');
        expect(lines.value, 'old\n');
        expect(lines.from, MarksFrom.branch);
        await end(tester);
      });

      testWidgets('its base branch gone, the commit it started from', (
        tester,
      ) async {
        await start(
          tester,
          path: 'a.go',
          worktree: Worktree(base: 'dev', baseCommit: 'abc123'),
          answer: git(
            (base) => base == 'dev'
                ? throw ConnectException(Code.failedPrecondition, 'gone')
                : onBranch(base),
            diff: (_) => change,
          ),
        );
        expect(_asked(fake).single.base, 'abc123');
        expect(lines.from, MarksFrom.branch);
        await end(tester);
      });

      testWidgets('no worktree: the default branch', (tester) async {
        await start(
          tester,
          path: 'a.go',
          answer: git(onBranch, diff: (_) => change),
        );
        expect(_asked(fake).single.base, 'main');
        expect(lines.from, MarksFrom.branch);
        await end(tester);
      });

      for (final (what, status) in [
        (
          'on the default branch itself',
          GetFolderStatusResponse(
            git: true,
            branch: 'main',
            defaultBase: 'main',
          ),
        ),
        (
          'on its remote copy',
          GetFolderStatusResponse(
            git: true,
            branch: 'main',
            defaultBase: 'origin/main',
          ),
        ),
        ('no base found', GetFolderStatusResponse(git: true, branch: 'x')),
        ('not a repository', GetFolderStatusResponse()),
      ]) {
        testWidgets('$what: the last commit', (tester) async {
          await start(
            tester,
            path: 'a.go',
            answer: git((_) => status),
            change: FileChange(
              path: 'a.go',
              status: 'modified',
              oldText: 'old\n',
            ),
          );
          expect(_asked(fake).single.base, isEmpty);
          expect(lines.value, 'old\n');
          expect(lines.from, MarksFrom.lastCommit);
          await end(tester);
        });
      }

      testWidgets("a file outside the chat's folder: its last commit", (
        tester,
      ) async {
        const path = '/elsewhere/lib/b.dart';
        await start(tester, path: path, answer: git(onBranch));
        final data = utf8.encode('b\n');
        fake.sendWatch(
          path,
          WatchChatFileResponse(path: path, data: data, sha256: sumOf(data)),
        );
        await tester.pumpAndSettle();
        expect(_asked(fake).last.base, isEmpty);
        expect(lines.from, MarksFrom.lastCommit);
        await end(tester);
      });

      testWidgets("a base its file's repository lacks: its last commit", (
        tester,
      ) async {
        final bases = <String>[];
        await start(
          tester,
          path: 'a.go',
          answer: (input) {
            if (input is GetDiffRequest) bases.add(input.base);
            return git(
              onBranch,
              diff: (_) =>
                  throw ConnectException(Code.failedPrecondition, 'no main'),
            )(input);
          },
          change: FileChange(path: 'a.go', status: 'modified', oldText: 'x\n'),
        );
        expect(bases, ['main', '']);
        expect(lines.value, 'x\n');
        expect(lines.from, MarksFrom.lastCommit);
        await end(tester);
      });

      testWidgets('added on the branch: new, every line added', (tester) async {
        await start(
          tester,
          path: 'a.go',
          answer: git(
            onBranch,
            diff: (_) => GetDiffResponse(
              files: [FileChange(path: 'a.go', status: 'added')],
            ),
          ),
        );
        expect(lines.value, '');
        expect(lines.isNew, isTrue);
        expect(lines.since, 'since main');
        await end(tester);
      });

      group('on the default branch itself, from before the chat', () {
        final began = fixtureNow.millisecondsSinceEpoch ~/ 1000;
        Commit at(String hash, int secs) =>
            Commit(hash: hash, unixSeconds: Int64(began + secs));
        Object? Function(Object) onMain(List<Commit> commits) =>
            (input) => switch (input) {
              GetFolderStatusRequest() => GetFolderStatusResponse(
                git: true,
                branch: 'main',
                defaultBase: 'origin/main',
              ),
              ListCommitsRequest() => ListCommitsResponse(commits: commits),
              final GetDiffRequest r when r.base.isNotEmpty => GetDiffResponse(
                files: [
                  FileChange(path: 'a.go', status: 'modified', oldText: 'x\n'),
                ],
              ),
              _ => null,
            };

        testWidgets("two commits of the chat's own: the first one's parent", (
          tester,
        ) async {
          await start(
            tester,
            path: 'a.go',
            answer: onMain([
              at('c3', 120),
              at('c2', 60),
              at('c1', -60), // the user's, before the chat
            ]),
          );
          final listed = fake.calls.whereType<ListCommitsRequest>().single;
          expect(listed.folder, '/Users/me/nushi');
          expect(listed.base, isEmpty);
          expect(_asked(fake).single.base, 'c2^');
          expect(lines.from, MarksFrom.chat);
          expect(lines.since, 'since this chat began');
          expect(lines.value, 'x\n');
          await end(tester);
        });

        testWidgets("the chat's commits not listed: a failure, not the last "
            'commit; asked again, the base is found', (tester) async {
          final main = onMain([at('c2', 60)]);
          var refuse = true;
          await start(
            tester,
            path: 'a.go',
            answer: (input) => input is ListCommitsRequest && refuse
                ? throw ConnectException(Code.unavailable, 'daemon away')
                : main(input),
          );
          expect(_asked(fake), isEmpty);
          expect(lines.none, NoMarks.failed);
          expect(lines.error, contains('daemon away'));
          refuse = false;
          final again = marksBaseOf(c).find(d);
          await tester.pumpAndSettle();
          expect(await again, (base: 'c2^', from: MarksFrom.chat));
          await end(tester);
        });

        testWidgets('none since the chat began: the last commit', (
          tester,
        ) async {
          await start(
            tester,
            path: 'a.go',
            answer: onMain([at('c1', -60)]),
            change: FileChange(
              path: 'a.go',
              status: 'modified',
              oldText: 'y\n',
            ),
          );
          expect(_asked(fake).single.base, isEmpty);
          expect(lines.from, MarksFrom.lastCommit);
          expect(lines.since, 'since the last commit');
          await end(tester);
        });

        testWidgets("the chat's first commit was the repository's first: "
            'the last commit', (tester) async {
          final bases = <String>[];
          final main = onMain([at('c1', 60)]);
          await start(
            tester,
            path: 'a.go',
            answer: (input) {
              if (input is GetDiffRequest) {
                bases.add(input.base);
                if (input.base.isNotEmpty) {
                  throw ConnectException(Code.failedPrecondition, 'no c1^');
                }
              }
              return main(input);
            },
            change: FileChange(
              path: 'a.go',
              status: 'modified',
              oldText: 'z\n',
            ),
          );
          expect(bases, ['c1^', '']);
          expect(lines.from, MarksFrom.lastCommit);
          await end(tester);
        });

        testWidgets("a commit made in the app finds the chat's start again", (
          tester,
        ) async {
          var commits = [at('c1', -60)];
          await start(
            tester,
            path: 'a.go',
            answer: (input) => onMain(commits)(input),
          );
          expect(_asked(fake).last.base, isEmpty);
          commits = [at('c2', 30), ...commits];
          c.committed();
          await tester.pumpAndSettle();
          expect(_asked(fake).last.base, 'c2^');
          expect(lines.from, MarksFrom.chat);
          await end(tester);
        });
      });

      testWidgets('the marks stay after a commit; the base is found again '
          'when a turn ends or the chat moves, not as the file changes', (
        tester,
      ) async {
        await start(
          tester,
          path: 'a.go',
          text: 'new\n',
          answer: git(onBranch, diff: (_) => change),
        );
        int statuses() => fake.calls.whereType<GetFolderStatusRequest>().length;
        expect(statuses(), 1);
        expect(lines.value, 'old\n');

        // Committed: HEAD has the text, the branch's base still not.
        // The base is found again (a commit can be a chat's first).
        c.committed();
        await tester.pumpAndSettle();
        expect(_asked(fake), hasLength(2));
        expect(_asked(fake).last.base, 'main');
        expect(lines.value, 'old\n');
        expect(statuses(), 2);
        fake.putFile('a.go', utf8.encode('newer\n'));
        await tester.pumpAndSettle();
        expect(_asked(fake), hasLength(3));
        expect(statuses(), 2);

        // The turn ends on main itself (the agent checked it out).
        fake.answer = git(
          (_) => GetFolderStatusResponse(
            git: true,
            branch: 'main',
            defaultBase: 'main',
          ),
        );
        c
          ..busy = true
          ..notifyListeners();
        await tester.pump();
        c
          ..busy = false
          ..notifyListeners();
        await tester.pumpAndSettle();
        expect(statuses(), 3);
        expect(_asked(fake).last.base, isEmpty);
        expect(lines.from, MarksFrom.lastCommit);

        // Moved into a worktree off dev.
        fake.answer = git(onBranch, diff: (_) => change);
        c
          ..worktree = Worktree(base: 'dev')
          ..notifyListeners();
        await tester.pumpAndSettle();
        // The chat's changes read it (ChatChanges): from dev, then counted
        // as Uncommitted, which its details and Changes show.
        expect(statuses(), 5);
        expect(_asked(fake).last.base, 'dev');
        expect(lines.from, MarksFrom.branch);
        await end(tester);
      });
    });

    testWidgets('an older daemon is never asked', (tester) async {
      await start(tester, api: oneFileDiffApi - 1);
      expect(_asked(fake), isEmpty);
      expect(lines.value, isNull);
      expect(lines.none, NoMarks.oldDaemon);
      await end(tester);
    });
  });
}
