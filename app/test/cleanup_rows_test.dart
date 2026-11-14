import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

// ADR 0117: Clean up… on one of several pull requests takes its branch on
// GitHub only, until every pull request on the chat's branch has merged
// or closed.

const _repo = 'lumen-dev/lumen';

final _wt = Worktree(
  repo: '/Users/me/lumen',
  path: '/Users/me/lumen/.worktrees/cursor-ties',
  branch: 'cursor-ties',
  base: 'main',
);

GitHubLink _link(int n) => GitHubLink(
  host: 'github.com',
  repo: _repo,
  number: n,
  id: 'PR_$n',
  pull: true,
);

GitHubItem _item(int n, String state, String head) => GitHubItem(
  ref: GitHubRef(host: 'github.com', repo: _repo, number: n),
  id: 'PR_$n',
  pull: true,
  title: 'Pull request $n',
  url: 'https://github.com/$_repo/pull/$n',
  state: state,
  author: 'mira-k',
  createdMs: Int64(fixtureNow.millisecondsSinceEpoch),
  base: 'main',
  head: head,
);

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The app on a chat in the worktree of cursor-ties, with #215 merged
/// (feed-cursor), #221 on cursor-ties ([state221]) and #224 open on
/// another branch; the details panel shown.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  required String state221,
}) async {
  viewport(tester, const Size(1700, 900));
  showDetails.value = true;
  collapsedWidgets.value = {};
  widgetOrder.value = ['Pull request'];
  cleanUpLater.value = {};
  pullSeen.value = {};
  final items = {
    215: _item(215, 'merged', 'feed-cursor'),
    221: _item(221, state221, 'cursor-ties'),
    224: _item(224, 'open', 'older-posts'),
  };
  final numbers = [215, 221, 224];
  final c = chat('c', 'claude', 'Paginate the feed')
    ..worktree = _wt
    ..folder = _wt.path
    ..pull = _link(215)
    ..pulls.addAll([for (final n in numbers) _link(n)]);
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      FindChatPullRequest() => FindChatPullResponse(
        host: 'github.com',
        repo: _repo,
        branch: 'cursor-ties',
        pull: _link(215),
        pulls: [for (final n in numbers) _link(n)],
      ),
      GetGitHubItemsRequest(:final refs) => GetGitHubItemsResponse(
        items: [for (final r in refs) ?items[r.number]],
      ),
      GetGitHubPullRequest(:final ref) => GetGitHubPullResponse(
        pull: fixturePull()
          ..item = items[ref.number]!
          ..head = items[ref.number]!.head
          ..base = 'main',
      ),
      GetCleanUpRequest() => GetCleanUpResponse(
        worktree: _wt,
        state: WorktreeState(commits: 1),
      ),
      DeleteGitHubBranchRequest() => DeleteGitHubBranchResponse(deleted: true),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

/// Opens Clean up… from [n]'s row's ⋯.
Future<void> _cleanUp(WidgetTester tester, int n) async {
  final row = find.byWidgetPredicate((w) => w is PullRow && w.link.number == n);
  await tester.tap(
    find.descendant(of: row, matching: find.byTooltip('Pull request')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Clean up…').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('one still open on the branch: only the branch on GitHub, '
      'and the dialog says which keeps the rest', (tester) async {
    final (d, fake) = await _app(tester, state221: 'open');
    final cp = ChatPull.of(d, d.chats['c']!);
    expect(openOnBranch(cp, _link(215)), [221]);
    expect(openOnBranch(cp, _link(221)), isEmpty);
    await _cleanUp(tester, 215);
    expect(find.text('Clean up after #215'), findsOneWidget);
    expect(
      find.text(
        '#221 is still open on cursor-ties. The worktree, its branch and '
        'this chat stay until it merges or closes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Delete the branch on GitHub'), findsOneWidget);
    expect(find.text('Delete the worktree'), findsNothing);
    expect(find.text('Delete the local branch'), findsNothing);
    expect(find.text('Archive this chat'), findsNothing);
    await render(tester, find.byType(NushiApp), 'cleanup_row_open_others');
    await tester.tap(find.text('Clean up'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<DeleteGitHubBranchRequest>().single.ref.number,
      215,
    );
    expect(fake.calls.whereType<RemoveChatWorktreeRequest>(), isEmpty);
    expect(fake.calls.whereType<DeleteChatBranchRequest>(), isEmpty);
    expect(fake.calls.whereType<ArchiveChatRequest>(), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('every one on the branch merged or closed: the worktree, the '
      'local branch and archiving come back', (tester) async {
    final (d, _) = await _app(tester, state221: 'closed');
    await _cleanUp(tester, 215);
    expect(find.byKey(const ValueKey('cleanup-still-open')), findsNothing);
    expect(find.text('Delete the worktree'), findsOneWidget);
    expect(find.text('Delete the local branch'), findsOneWidget);
    expect(find.text('Delete the branch on GitHub'), findsOneWidget);
    expect(find.text('Archive this chat'), findsOneWidget);
    d.dispose();
  }, variant: _mac);
}
