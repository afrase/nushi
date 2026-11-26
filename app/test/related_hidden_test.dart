import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_elsewhere.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A run's removed record with nothing to show is held back by the daemon
// while it is its path's last, and sent again once a later record at its
// path is ([relatedSent]; ADR 0081). The Worktrees widget drops its row
// and brings it back, and no other record's review comments move: each
// record's key is its place among its path's records, which never moves.
// Made-up runs and worktrees.

const _repo = '/Users/me/acme';
const _export = '$_repo/.claude/worktrees/export';
const _docs = '$_repo/.claude/worktrees/docs';

/// A record at [path] on [branch]; [empty] has no commit of its own.
RelatedWorktree _record(
  String path,
  String branch, {
  String run = '',
  String call = 'a',
  String state = 'present',
  bool empty = false,
}) => RelatedWorktree(
  path: path,
  branch: branch,
  baseCommit: 'b' * 40,
  lastHead: empty ? 'b' * 40 : 'c' * 40,
  callId: call,
  runId: run,
  state: state,
);

/// A comment on line 1 of notes.md, in [key]'s uncommitted changes.
ReviewComment _comment(String id, String key) => ReviewComment(
  id: id,
  where: whereIn('uncommitted', worktree: key),
  path: 'notes.md',
  old: false,
  start: 1,
  end: 1,
  quote: 'notes',
  text: 'On $id',
);

/// The Worktrees widget on screen.
Finder get _widget => find.ancestor(
  of: find.text('Worktrees'),
  matching: find.byType(PanelWidget),
);

/// The branches the widget shows, its folded rows opened.
List<String> _branches(WidgetTester tester) => [
  for (final b in ['subagent-docs', 'first-try', 'second-try', 'third-try'])
    if (find
        .descendant(of: _widget, matching: find.text(b))
        .evaluate()
        .isNotEmpty)
      b,
];

void main() {
  setUpAll(loadFonts);

  testWidgets("a hidden record's row goes and comes back, and the comments "
      'on the records beside it stay on them', (tester) async {
    showDetails.value = true;
    collapsedWidgets.value = {};
    widgetOrder.value = [];
    // What the daemon keeps of the chat's related worktrees.
    var stored = <RelatedWorktree>[
      _record(_docs, 'subagent-docs'),
      _record(
        _export,
        'first-try',
        run: 'run-1',
        call: 'wf1',
        state: 'removed',
        empty: true,
      ),
    ];
    final fake = FakeDaemon([chat('c', 'claude', 'Export', folder: _repo)])
      ..answer = (input) => switch (input) {
        GetRelatedWorktreesRequest() => GetRelatedWorktreesResponse(
          worktrees: relatedSent(stored),
        ),
        GetRelatedWorktreeStatsRequest(:final paths) =>
          GetRelatedWorktreeStatsResponse(
            stats: [for (final p in paths) RelatedWorktreeStats(path: p)],
          ),
        _ => null,
      };
    final d = await openApp(tester, fake);
    expect(find.byType(DetailsPanel), findsOne);
    final related = d.chats['c']!.related;
    Future<void> keeps(List<RelatedWorktree> now) async {
      stored = now;
      fake.emit(
        EventsResponse(
          chatId: 'c',
          relatedWorktrees: ChatRelatedWorktrees(worktrees: relatedSent(now)),
        ),
      );
      await tester.pumpAndSettle();
      // The gone ones' fold opened, wherever it is.
      final fold = find.descendant(
        of: _widget,
        matching: find.textContaining(RegExp(r'^\d removed')),
      );
      if (fold.evaluate().isNotEmpty &&
          find
              .descendant(of: _widget, matching: find.text('Removed'))
              .evaluate()
              .isEmpty) {
        await tester.tap(fold);
        await tester.pumpAndSettle();
      }
    }

    // The first try at the export path, empty and removed: held back.
    expect(_branches(tester), ['subagent-docs']);

    // A second try is made there: the first is sent again, before it.
    final second = _record(_export, 'second-try', run: 'run-2', call: 'wf2');
    await keeps([...stored, second]);
    expect(_branches(tester), ['subagent-docs', 'first-try', 'second-try']);
    final onSecond = relatedKey(_export, 1);
    final onDocs = relatedKey(_docs, 0);
    expect(related.recordOf(onSecond)!.branch, 'second-try');
    setComments('c', [_comment('docs', onDocs), _comment('2', onSecond)]);
    addTearDown(() => setComments('c', []));
    String label(String id) => whereLabel(
      commentsOf('c').singleWhere((c) => c.id == id).where,
      related.list,
    );
    expect(label('2'), 'second-try, Uncommitted');

    // The second try is removed, empty too: now it is held back, its row
    // gone; its comment names no other record, the first try's least of
    // all, and the subagent's stays on it.
    await keeps([
      ...stored.take(2),
      second.deepCopy()
        ..state = 'removed'
        ..lastHead = 'b' * 40,
    ]);
    expect(_branches(tester), ['subagent-docs', 'first-try']);
    expect(related.recordOf(onSecond), isNull);
    expect(label('2'), 'export, Uncommitted'); // its folder's name
    expect(label('docs'), 'subagent-docs, Uncommitted');

    // A third try: both earlier ones are sent, each in its place, and the
    // second try's comment is on it again.
    await keeps([
      ...stored,
      _record(_export, 'third-try', run: 'run-3', call: 'wf3'),
    ]);
    expect(_branches(tester), [
      'subagent-docs',
      'first-try',
      'second-try',
      'third-try',
    ]);
    expect(related.recordOf(onSecond)!.branch, 'second-try');
    expect(label('2'), 'second-try, Uncommitted');
    expect(label('docs'), 'subagent-docs, Uncommitted');
    expect(related.keyOf(related.list.last), relatedKey(_export, 2));
    await closeView(tester, d);
  }, variant: onMac);

  test("the fake holds back only a run's empty removed record, and only "
      "while it is its path's last", () {
    final runEmpty = _record(
      _export,
      'first-try',
      run: 'run-1',
      state: 'removed',
      empty: true,
    );
    expect(relatedSent([runEmpty]), isEmpty);
    // A subagent's, one with commits, one still there: all sent.
    for (final w in [
      runEmpty.deepCopy()..runId = '',
      runEmpty.deepCopy()..lastHead = 'c' * 40,
      runEmpty.deepCopy()..state = 'present',
    ]) {
      expect(relatedSent([w]), [w]);
    }
    final later = _record(_export, 'second-try');
    expect(relatedSent([runEmpty, later]), [runEmpty, later]);
  });
}
