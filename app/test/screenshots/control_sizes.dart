// The views a change to the controls' sizes touches, to look at before and
// after (ADR 0122): each at 1700 and 720 wide, dark and light, written by
// `render` (`make renders TEST=test/screenshots/control_sizes.dart`). Not
// part of `make test` (the name doesn't end in _test.dart).
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cleanup_dialog.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import '../fake_daemon.dart';
import '../github_fixture.dart';
import '../harness.dart';
import '../pull_fixture.dart';
import 'demo.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A permission the agent asks for, beside the demo's question.
final _permission = Item(
  id: 'p',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  status: 'pending',
  title: 'go test ./internal/feed/...',
  options: [
    Option(id: 'y', name: 'Allow once'),
    Option(id: 'a', name: 'Always allow go test'),
    Option(id: 'n', name: 'Reject'),
  ],
);

Object? _demo(Object input) => switch (input) {
  GetChatRequest(:final chatId) when chatId == heroChat.id => GetChatResponse(
    chat: heroChat,
    items: heroItems,
    status: heroChat.status,
    config: [
      ConfigOption(
        id: 'model',
        category: 'model',
        current: 'opus',
        values: [ConfigValue(value: 'opus', name: 'Opus')],
      ),
      ConfigOption(
        id: 'mode',
        category: 'mode',
        current: 'acceptEdits',
        values: [
          ConfigValue(value: 'default', name: 'Default'),
          ConfigValue(value: 'acceptEdits', name: 'Accept edits'),
        ],
      ),
    ],
  ),
  GetChatRequest(:final chatId) when chatId == 'rss' => demoQuestion(
    demoChats().firstWhere((c) => c.id == 'rss'),
  )..items.insert(3, _permission),
  GetFolderStatusRequest() => GetFolderStatusResponse(
    git: true,
    branch: demoBranch,
    files: 9,
    added: 142,
    removed: 37,
    defaultBase: 'main',
    ahead: 3,
  ),
  FindChatPullRequest() => FindChatPullResponse(
    host: 'github.com',
    repo: demoRepo,
    branch: demoBranch,
    pull: demoLink,
  ),
  GetGitHubPullRequest() => GetGitHubPullResponse(pull: demoPull()),
  ListGitHubHostsRequest() => ListGitHubHostsResponse(
    hosts: [GitHubHost(host: 'github.com', login: 'maya-chen', source: 'gh')],
  ),
  GetMemoryRequest() => GetMemoryResponse(
    daemon: Int64(48 << 20),
    app: Int64(212 << 20),
    chats: {MapEntry(heroChat.id, Int64(388 << 20))},
  ),
  _ => null,
};

/// The Mac app at [size] in [brightness] on the demo's chats.
Future<Daemon> _app(
  WidgetTester tester,
  Size size,
  Brightness brightness, {
  String select = 'feed',
  bool details = false,
}) async {
  viewport(tester, size, brightness: brightness);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  clock = () => demoNow;
  showDetails.value = details;
  paneWidths.value = {};
  collapsedWidgets.value = {};
  widgetOrder.value = [];
  pullSeen.value = {};
  final fake = FakeDaemon(demoChats())..answer = _demo;
  final d = await fake.connect(tester);
  d.select(select);
  d.chats[select]?.draft.text.text =
      'Also keep the cursor in the URL, so a shared link opens the same page.';
  await tester.pumpWidget(NushiApp(daemon: d));
  await _pump(tester, 10);
  return d;
}

GitHubLink _link(int n) => GitHubLink(
  host: 'github.com',
  repo: demoRepo,
  number: n,
  id: 'PR_$n',
  pull: true,
);

GitHubItem _item(
  int n,
  String title, {
  String state = 'open',
  bool draft = false,
  String base = 'main',
  String head = '',
  (int, int, int) checks = (0, 0, 0),
  int threads = 0,
}) => GitHubItem(
  ref: GitHubRef(host: 'github.com', repo: demoRepo, number: n),
  id: 'PR_$n',
  pull: true,
  title: title,
  url: 'https://github.com/$demoRepo/pull/$n',
  state: state,
  draft: draft,
  author: 'mira-k',
  createdMs: Int64(
    fixtureNow.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
  ),
  additions: 40,
  deletions: 8,
  changedFiles: 3,
  base: base,
  head: head.isEmpty ? 'branch-$n' : head,
  unresolved: threads,
  mergeState: 'blocked',
  checkCounts: GitHubCheckCounts(
    passed: checks.$1,
    failed: checks.$2,
    running: checks.$3,
  ),
  checks: checks.$2 > 0
      ? 'failure'
      : checks.$3 > 0
      ? 'pending'
      : checks.$1 > 0
      ? 'success'
      : '',
);

final Map<int, GitHubItem> _stack = {
  215: _item(215, 'Cursor in store.ListPosts', state: 'merged', head: 'a'),
  221: _item(
    221,
    'Break cursor ties by post id',
    base: 'a',
    checks: (4, 0, 6),
    threads: 2,
  ),
  224: _item(224, 'Older posts link in the templates', draft: true),
};

/// The app on a chat with three pull requests, the details panel shown.
Future<Daemon> _pulls(WidgetTester tester, Size size, Brightness b) async {
  viewport(tester, size, brightness: b);
  showDetails.value = true;
  collapsedWidgets.value = {};
  widgetOrder.value = ['Pull request'];
  pullSeen.value = {};
  final c = chat('c', 'claude', 'Paginate the feed')
    ..pull = _link(221)
    ..pulls.addAll([
      for (final n in [221, 224, 215]) _link(n),
    ]);
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      FindChatPullRequest() => FindChatPullResponse(
        host: 'github.com',
        repo: demoRepo,
        branch: 'branch-221',
        pull: _link(221),
        pulls: [
          for (final n in [221, 224, 215]) _link(n),
        ],
      ),
      GetGitHubItemsRequest(:final refs) => GetGitHubItemsResponse(
        items: [for (final r in refs) ?_stack[r.number]],
      ),
      GetGitHubPullRequest(:final ref) => GetGitHubPullResponse(
        pull: fixturePull()..item = _stack[ref.number]!,
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

void main() {
  setUpAll(loadFonts);

  for (final b in Brightness.values) {
    for (final w in [1700.0, 720.0]) {
      final at = '${w.round()}_${b.name}';
      final size = Size(w, 900);

      testWidgets('confirm $at', (tester) async {
        final d = await _app(tester, size, b);
        unawaited(
          confirm(
            tester.state<NavigatorState>(find.byType(Navigator).first).context,
            'Delete this chat?',
            'Its transcript and its worktree go. The branch stays.',
            'Delete',
            destructive: true,
          ),
        );
        await _pump(tester);
        await render(tester, find.byType(NushiApp), 'confirm_$at');
        d.dispose();
      }, variant: _mac);

      testWidgets('cleanup $at', (tester) async {
        final wt = Worktree(
          repo: '/Users/me/shop',
          path: '/Users/me/shop/.worktrees/filters-malformed-q',
          branch: 'filters-malformed-q',
          base: 'main',
        );
        final (d, _) = await openPullTab(
          tester,
          fixturePull()..item.state = 'merged',
          details: true,
          open: false,
          worktree: wt,
          brightness: b,
          size: size,
          more: (input) => switch (input) {
            GetCleanUpRequest() => GetCleanUpResponse(
              worktree: wt,
              state: WorktreeState(changed: 2, commits: 1),
              changes: [
                'M app/notebooks/page_spec.rb',
                '?? tmp/q_params_repro.rb',
              ],
            ),
            _ => null,
          },
        );
        final pull = fixturePull()..item.state = 'merged';
        unawaited(
          showCleanUp(
            tester.state<NavigatorState>(find.byType(Navigator).first).context,
            d,
            d.chats['c']!,
            pull: pull,
          ),
        );
        await _pump(tester);
        await render(tester, find.byType(NushiApp), 'cleanup_$at');
        d.dispose();
      }, variant: _mac);

      testWidgets('settings general $at', (tester) async {
        final d = await _app(tester, size, b)
          ..openSettings(section: SettingsSection.general);
        await _pump(tester);
        await render(tester, find.byType(NushiApp), 'settings_general_$at');
        d.dispose();
      }, variant: _mac);

      testWidgets('cards $at', (tester) async {
        final d = await _app(tester, size, b, select: 'rss');
        await _pump(tester);
        await render(tester, find.byType(NushiApp), 'cards_$at');
        d.dispose();
      }, variant: _mac);

      testWidgets('chat $at', (tester) async {
        Collapsible.opened.add('e2');
        addTearDown(Collapsible.opened.clear);
        final d = await _app(tester, size, b);
        await render(tester, find.byType(NushiApp), 'chat_$at');
        d.dispose();
      }, variant: _mac);

      testWidgets('pull rows $at', (tester) async {
        final d = await _pulls(tester, size, b);
        await render(tester, find.byType(NushiApp), 'pull_rows_$at');
        d.dispose();
      }, variant: _mac);

      testWidgets('github $at', (tester) async {
        final (_, d) = await openView(
          tester,
          tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
          size: size,
          window: true,
        );
        await render(tester, find.byType(NushiApp), 'github_inbox_$at');
        await tester.tap(find.text('Add Sub and Neg'));
        await tester.pumpAndSettle();
        await render(tester, find.byType(NushiApp), 'github_pull_$at');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('mcp form $at', (tester) async {
        final d = await _app(tester, size, b);
        unawaited(
          mcpForm(
            tester.state<NavigatorState>(find.byType(Navigator).first).context,
            McpServers.of(d, demoTree),
          ),
        );
        await _pump(tester);
        await render(tester, find.byType(NushiApp), 'mcp_form_$at');
        d.dispose();
      }, variant: _mac);
    }
  }
}
