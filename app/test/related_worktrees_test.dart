import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commit_box.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/review.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/worktrees_widget.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final String _base = 'b' * 40;
final String _head = 'c' * 40;

RelatedWorktree _worktree(
  String name, {
  String state = 'present',
  bool merged = false,
  String call = '',
  String? head,
}) => RelatedWorktree(
  path: '/x/.claude/worktrees/$name',
  branch: name,
  baseCommit: _base,
  lastHead: head ?? _head,
  callId: call,
  state: state,
  merged: merged,
);

Item _subagent(String id, String state) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  agent: 'general-purpose',
  title: 'Task $id',
  status: 'completed',
  subagent: Subagent(state: state),
);

/// The calls of type [T] the app made.
List<T> _calls<T>(FakeDaemon fake) => fake.calls.whereType<T>().toList();

void main() {
  setUpAll(loadFonts);

  late FakeDaemon fake;
  late Daemon daemon;
  late ChatState chatState;

  // Stats by path, as the daemon counts them.
  late Map<String, RelatedWorktreeStats> counted;

  Object? answers(Object input) => switch (input) {
    GetRelatedWorktreesRequest() => GetRelatedWorktreesResponse(
      worktrees: chatState.related.list,
    ),
    GetRelatedWorktreeStatsRequest(:final paths) =>
      GetRelatedWorktreeStatsResponse(
        stats: [
          for (final p in paths)
            counted[p] ?? RelatedWorktreeStats(path: p, files: 1, added: 2),
        ],
      ),
    GetFolderStatusRequest() => GetFolderStatusResponse(
      git: true,
      branch: 'main',
      defaultBase: 'main',
      ahead: 1,
    ),
    ListCommitsRequest() => ListCommitsResponse(
      commits: [Commit(hash: _head, short: 'ccccccc', subject: 'Work')],
    ),
    GetDiffRequest(:final folder) => GetDiffResponse(
      files: [
        FileChange(
          path: folder.endsWith('a') ? 'in_worktree.txt' : 'in_chat.txt',
          oldText: 'a\n',
          newText: 'b\n',
          added: 1,
        ),
      ],
    ),
    _ => null,
  };

  Future<void> setUpChat(WidgetTester tester) async {
    counted = {};
    fake = FakeDaemon([])..answer = answers;
    daemon = await fake.connect(tester);
    chatState = ChatState('c', '/x')..scope = 'uncommitted';
    chatState.related.client = daemon.client;
    addTearDown(() => chatState.scope = null);
  }

  Future<void> showChanges(WidgetTester tester) async {
    await tester.pumpWidget(
      themed(ChangesView(chat: chatState, daemon: daemon)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickFromMenu(
    WidgetTester tester,
    String entry, {
    bool detail = false,
  }) async {
    await tester.tap(find.byType(MenuField));
    await tester.pumpAndSettle();
    await tester.tap(
      detail ? find.textContaining(entry).last : find.text(entry).last,
    );
    await tester.pumpAndSettle();
  }

  group('the daemon keeps it current', () {
    testWidgets('read as a chat opens, and an unnumbered event moves it', (
      tester,
    ) async {
      final fake = FakeDaemon([chat('c', 'claude', 'T')])
        ..answer = (input) => input is GetRelatedWorktreesRequest
            ? GetRelatedWorktreesResponse(worktrees: [_worktree('a')])
            : null;
      final d = await fake.connect(tester);
      d.select('c');
      await tester.pump();
      await tester.pump();
      final related = d.chats['c']!.related;
      expect(related.list.single.branch, 'a');
      fake.emit(
        EventsResponse(
          chatId: 'c',
          relatedWorktrees: ChatRelatedWorktrees(
            worktrees: [_worktree('a'), _worktree('b')],
          ),
        ),
      );
      await tester.pump();
      expect(related.list, hasLength(2));
      await closeView(tester, d);
    });

    testWidgets('an event overtakes the answer it raced', (tester) async {
      await setUpChat(tester);
      final related = chatState.related;
      fake.answer = (input) => input is GetRelatedWorktreesRequest
          ? Future<GetRelatedWorktreesResponse>.delayed(
              const Duration(seconds: 1),
              () => GetRelatedWorktreesResponse(worktrees: [_worktree('old')]),
            )
          : null;
      final reading = related.read();
      related.take([_worktree('new')]);
      await tester.pump(const Duration(seconds: 2));
      await reading;
      expect(related.list.single.branch, 'new');
      await closeView(tester, daemon);
    });
  });

  group('stats cost little', () {
    testWidgets('one call for the rows of a frame, and read once', (
      tester,
    ) async {
      await setUpChat(tester);
      final related = chatState.related
        ..take([_worktree('a'), _worktree('b')])
        ..want('/x/.claude/worktrees/a')
        ..want('/x/.claude/worktrees/b');
      await tester.pump();
      await tester.pump();
      final first = _calls<GetRelatedWorktreeStatsRequest>(fake).single;
      expect(first.paths, hasLength(2));
      related.want('/x/.claude/worktrees/a'); // a second row of the same
      await tester.pump();
      await tester.pump();
      expect(_calls<GetRelatedWorktreeStatsRequest>(fake), hasLength(1));
      expect(_calls<GetFolderStatusRequest>(fake), isEmpty);
      expect(_calls<GetDiffRequest>(fake), isEmpty);
      await closeView(tester, daemon);
    });

    testWidgets('a turn ends: only what is there and on screen is read', (
      tester,
    ) async {
      await setUpChat(tester);
      chatState.related
        ..take([
          _worktree('a'),
          _worktree('gone', state: 'removed'),
          _worktree('off-screen'),
        ])
        ..want('/x/.claude/worktrees/a')
        ..want('/x/.claude/worktrees/gone');
      await tester.pump();
      await tester.pump();
      fake.calls.clear();
      chatState
        ..status(ChatStatus(busy: true))
        ..status(ChatStatus());
      await tester.pump();
      await tester.pump();
      final asked = _calls<GetRelatedWorktreeStatsRequest>(fake).single;
      expect(asked.paths, ['/x/.claude/worktrees/a']);
      await closeView(tester, daemon);
    });

    testWidgets('an event re-reads only the worktree whose commits moved', (
      tester,
    ) async {
      await setUpChat(tester);
      final a = _worktree('a');
      final b = _worktree('b');
      chatState.related
        ..take([a, b])
        ..want(a.path)
        ..want(b.path);
      await tester.pump();
      await tester.pump();
      fake.calls.clear();
      chatState.related.take([a, _worktree('b', head: 'd' * 40)]);
      await tester.pump();
      await tester.pump();
      final asked = _calls<GetRelatedWorktreeStatsRequest>(fake).single;
      expect(asked.paths, [b.path]);
      await closeView(tester, daemon);
    });

    testWidgets('nothing happens with time alone', (tester) async {
      await setUpChat(tester);
      final a = _worktree('a');
      chatState.related
        ..take([a])
        ..want(a.path);
      await tester.pump();
      await tester.pump();
      fake.calls.clear();
      await tester.pump(const Duration(hours: 1));
      expect(_calls<GetRelatedWorktreeStatsRequest>(fake), isEmpty);
      expect(_calls<GetRelatedWorktreesRequest>(fake), isEmpty);
      await closeView(tester, daemon);
    });
  });

  group('the switcher', () {
    testWidgets('no menu without related worktrees', (tester) async {
      await setUpChat(tester);
      await showChanges(tester);
      expect(find.byType(MenuField), findsNothing);
      await closeView(tester, daemon);
    });

    testWidgets('a worktree reads, and nothing there writes or comments', (
      tester,
    ) async {
      await setUpChat(tester);
      chatState.related.take([_worktree('a')]);
      await showChanges(tester);
      // The chat's own, which can be staged.
      expect(find.byType(CommitBox), findsOne);
      expect(find.byType(Checkbox), findsWidgets);
      fake.calls.clear();
      await pickFromMenu(tester, 'a');
      final diff = _calls<GetDiffRequest>(fake).single;
      expect(diff.folder, '/x/.claude/worktrees/a');
      expect(diff.base, _base);
      expect(find.text('in_worktree.txt  +1', findRichText: true), findsOne);
      expect(find.byType(CommitBox), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.widget<DiffBox>(find.byType(DiffBox)).review, isNull);
      await tester.tap(find.text('Uncommitted'));
      await tester.pumpAndSettle();
      expect(find.byType(CommitBox), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(_calls<StageFilesRequest>(fake), isEmpty);
      expect(chatState.scope, 'uncommitted', reason: "the chat's stays");
      await pickFromMenu(tester, "Chat's folder");
      expect(find.text('in_chat.txt  +1', findRichText: true), findsOne);
      expect(find.byType(CommitBox), findsOne);
      await closeView(tester, daemon);
    });

    testWidgets("the chat's comments stay out of it, and stay", (tester) async {
      await setUpChat(tester);
      addTearDown(() => setComments('c', []));
      setComments('c', [
        ReviewComment(
          id: '1',
          where: 'branch',
          path: 'in_worktree.txt',
          old: false,
          start: 1,
          end: 1,
          quote: 'b',
          text: 'Hm',
          sent: true,
          seen: 1,
        ),
      ]);
      chatState.related.take([_worktree('a')]);
      await showChanges(tester);
      await pickFromMenu(tester, 'a');
      // In Branch, on a file of the name, with another hash: that would
      // have dropped it as changed.
      expect(commentsOf('c'), hasLength(1));
      await closeView(tester, daemon);
    });

    testWidgets('a turn ending never runs a GetDiff there, and says so', (
      tester,
    ) async {
      await setUpChat(tester);
      final a = _worktree('a');
      chatState.related.take([a]);
      await showChanges(tester);
      await pickFromMenu(tester, 'a');
      expect(find.text('Changed: Reload'), findsNothing);
      fake.calls.clear();
      counted[a.path] = RelatedWorktreeStats(path: a.path, files: 9, added: 9);
      chatState
        ..status(ChatStatus(busy: true))
        ..notifyListeners()
        ..status(ChatStatus())
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(_calls<GetDiffRequest>(fake), isEmpty);
      expect(_calls<GetRelatedWorktreeStatsRequest>(fake), hasLength(1));
      expect(find.text('Changed: Reload'), findsOne);
      expect(find.text('in_worktree.txt  +1', findRichText: true), findsOne);
      await tester.tap(find.byTooltip('Reload'));
      await tester.pumpAndSettle();
      expect(_calls<GetDiffRequest>(fake), hasLength(1));
      expect(find.text('Changed: Reload'), findsNothing);
      await closeView(tester, daemon);
    });

    testWidgets('an event never runs one either', (tester) async {
      await setUpChat(tester);
      chatState.related.take([_worktree('a')]);
      await showChanges(tester);
      await pickFromMenu(tester, 'a');
      fake.calls.clear();
      chatState.related.take([_worktree('a', state: 'removed')]);
      await tester.pumpAndSettle();
      expect(_calls<GetDiffRequest>(fake), isEmpty);
      expect(find.text('Changed: Reload'), findsOne);
      await closeView(tester, daemon);
    });

    testWidgets('coming back to the tab reads nothing until asked', (
      tester,
    ) async {
      await setUpChat(tester);
      chatState.related.take([_worktree('a')]);
      await showChanges(tester);
      await pickFromMenu(tester, 'a');
      await tester.pumpWidget(const SizedBox());
      fake.calls.clear();
      await showChanges(tester);
      expect(_calls<GetDiffRequest>(fake), isEmpty);
      expect(find.byType(CommitBox), findsNothing);
      await tester.tap(find.text('Show its changes'));
      await tester.pumpAndSettle();
      expect(_calls<GetDiffRequest>(fake).single.base, _base);
      expect(find.text('in_worktree.txt  +1', findRichText: true), findsOne);
      await closeView(tester, daemon);
    });

    testWidgets("a link to a file means the chat's folder", (tester) async {
      await setUpChat(tester);
      chatState.related.take([_worktree('a')]);
      await showChanges(tester);
      await pickFromMenu(tester, 'a');
      fake.calls.clear();
      chatState.showFile('in_chat.txt');
      await tester.pumpAndSettle();
      expect(chatState.related.shown, isNull);
      expect(_calls<GetDiffRequest>(fake).last.folder, '/x');
      await closeView(tester, daemon);
    });
  });

  group('a removed worktree', () {
    testWidgets('reads its commits in the chat folder, after its base', (
      tester,
    ) async {
      await setUpChat(tester);
      chatState.related.take([_worktree('a', state: 'removed')]);
      await showChanges(tester);
      fake.calls.clear();
      await pickFromMenu(tester, 'removed', detail: true);
      final diff = _calls<GetDiffRequest>(fake).single;
      expect(diff.folder, '/x');
      expect(diff.after, _base);
      expect(diff.commit, _head);
      expect(diff.since, isEmpty, reason: 'since counts the base itself');
      expect(find.text('Uncommitted'), findsNothing);
      await tester.tap(find.text('Commits'));
      await tester.pumpAndSettle();
      final log = _calls<ListCommitsRequest>(fake).single;
      expect(log.folder, '/x');
      expect(log.base, _base);
      expect(log.head, _head);
      await closeView(tester, daemon);
    });

    testWidgets('whose commits went says so, not an empty diff', (
      tester,
    ) async {
      await setUpChat(tester);
      final a = _worktree('a', state: 'removed');
      counted[a.path] = RelatedWorktreeStats(path: a.path, commitsGone: true);
      chatState.related.take([a]);
      await showChanges(tester);
      fake.calls.clear();
      await pickFromMenu(tester, 'removed', detail: true);
      expect(
        find.text("This worktree's commits are gone: git no longer has them."),
        findsOne,
      );
      expect(find.text('No changes'), findsNothing);
      expect(_calls<GetDiffRequest>(fake), isEmpty);
      await closeView(tester, daemon);
    });

    testWidgets('one whose folder went since the look reads as removed', (
      tester,
    ) async {
      await setUpChat(tester);
      fake.answer = (input) =>
          input is GetFolderStatusRequest && input.folder != '/x'
          ? GetFolderStatusResponse(gone: true)
          : answers(input);
      chatState.related.take([_worktree('a')]);
      await showChanges(tester);
      fake.calls.clear();
      await pickFromMenu(tester, 'a');
      final diff = _calls<GetDiffRequest>(fake).single;
      expect((diff.folder, diff.after, diff.commit), ('/x', _base, _head));
      await closeView(tester, daemon);
    });
  });

  group('the Worktrees widget', () {
    Future<void> showWidget(WidgetTester tester, {VoidCallback? onOpen}) async {
      final w = worktreesWidget(chatState, onChanges: onOpen ?? () {})!;
      await tester.pumpWidget(
        themed(
          SizedBox(
            width: 240,
            child: Column(children: [for (final r in w.rows) r.$2 as Widget]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('none without related worktrees', (tester) async {
      await setUpChat(tester);
      expect(worktreesWidget(chatState, onChanges: () {}), isNull);
      await closeView(tester, daemon);
    });

    testWidgets('a row: branch, mark, work and end; a click opens it', (
      tester,
    ) async {
      await setUpChat(tester);
      final a = _worktree('a', call: 'x');
      counted[a.path] = RelatedWorktreeStats(
        path: a.path,
        files: 4,
        added: 12,
        removed: 3,
        ahead: 2,
      );
      chatState.items.add(_subagent('x', 'running'));
      chatState.related.take([a]);
      var opened = 0;
      await showWidget(tester, onOpen: () => opened++);
      expect(find.text('a'), findsOne);
      expect(
        find.text('+12 −3 · 4 files · 2 ahead', findRichText: true),
        findsOne,
      );
      await tester.tap(find.text('a'));
      expect(opened, 1);
      expect(chatState.related.shown, a.path);
      await closeView(tester, daemon);
    });

    testWidgets('merged is what git shows, and a squash reads as removed', (
      tester,
    ) async {
      await setUpChat(tester);
      chatState.related.take([
        _worktree('kept'),
        _worktree('squashed', state: 'removed'),
        _worktree('merged', state: 'removed', merged: true),
      ]);
      await showWidget(tester);
      expect(find.text('merged'), findsNWidgets(2)); // the branch and the end
      expect(find.text('removed'), findsOne);
      await closeView(tester, daemon);
    });

    testWidgets('rows folded away ask for nothing, until opened', (
      tester,
    ) async {
      await setUpChat(tester);
      chatState.related.take([for (var i = 0; i < 10; i++) _worktree('w$i')]);
      await showWidget(tester);
      final first = _calls<GetRelatedWorktreeStatsRequest>(fake).single;
      expect(first.paths, hasLength(5));
      expect(find.text('5 more'), findsOne);
      await tester.tap(find.text('5 more'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(_calls<GetRelatedWorktreeStatsRequest>(fake), hasLength(2));
      await closeView(tester, daemon);
    });
  });

  group('a subagent', () {
    testWidgets('tagged by call id, in the transcript and the widget', (
      tester,
    ) async {
      await setUpChat(tester);
      chatState.items
        ..add(_subagent('x', 'done'))
        ..add(_subagent('y', 'done'));
      chatState.related.take([_worktree('a-branch', call: 'x')]);
      final runs = subagentsOf(chatState.items);
      await tester.pumpWidget(
        themed(
          Column(
            children: [
              SubagentLine(runs[0], chatState),
              SubagentLine(runs[1], chatState),
              for (final r in backgroundTasksWidget(chatState, daemon)!.rows)
                r.$2 as Widget,
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('2 finished'));
      await tester.pump();
      // In the first line, and the widget's first row's tooltip (the row
      // keeps its room for the task); the other has none.
      expect(find.text('a-branch'), findsOneWidget);
      bool tagged(Tap t) => t.tooltip.contains('In the worktree a-branch');
      expect(
        tester.widgetList<Tap>(find.byType(Tap)).where(tagged),
        hasLength(1),
      );
      chatState.related.take([]);
      await tester.pump();
      // The line follows; the widget's rows are built again by the panel.
      expect(find.text('a-branch'), findsNothing);
      await closeView(tester, daemon);
    });
  });

  group('names', () {
    test('control and bidi characters go, a branch is plain text', () {
      final evil = RelatedWorktree(
        path: '/x/w',
        branch: 'ma\u202ein\n\u2066x\u0007',
        lastHead: _head,
      );
      expect(worktreeName(evil), 'main x');
      expect(ChatState('c', '/x').related.tagFor('none'), '');
    });

    test('a detached worktree goes by its commit, then its folder', () {
      expect(
        worktreeName(RelatedWorktree(path: '/x/w', lastHead: _head)),
        'ccccccc',
      );
      expect(worktreeName(RelatedWorktree(path: '/x/w')), 'w');
    });

    testWidgets('a bidi name in the file list is dropped too', (tester) async {
      await setUpChat(tester);
      fake.answer = (input) => input is GetDiffRequest
          ? GetDiffResponse(files: [FileChange(path: 'a\u202eb.txt', added: 1)])
          : answers(input);
      await showChanges(tester);
      expect(find.text('ab.txt  +1', findRichText: true), findsOne);
      await closeView(tester, daemon);
    });
  });
}
