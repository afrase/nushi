// The README's screenshots: the real app, on a fake daemon with made-up
// demo data (demo.dart), at real window sizes, written to docs/images.
// `make screenshots` runs it; `make test` doesn't (the name doesn't end
// in _test.dart), so the PNGs never fail a check.
import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

import '../fake_daemon.dart';
import 'demo.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// Writes what [finder] shows as docs/images/[name].png.
Future<void> _shoot(String name, [Finder? finder]) => expectLater(
  finder ?? find.byType(NushiApp),
  matchesGoldenFile('../../../docs/images/$name.png'),
);

Future<void> _pump(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// What the fake daemon answers for the demo, beyond its own.
Object? _demo(Object input) => switch (input) {
  GetChatRequest(:final chatId) when chatId == heroChat.id => GetChatResponse(
    chat: heroChat,
    items: heroItems,
    status: heroChat.status,
    usage: Usage(
      contextUsed: Int64(84200),
      contextSize: Int64(200000),
      cost: 1.84,
      currency: 'USD',
      inputTokens: Int64(5120),
      outputTokens: Int64(2310),
      cachedReadTokens: Int64(79400),
    ),
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
          ConfigValue(value: 'plan', name: 'Plan'),
        ],
      ),
    ],
  ),
  GetChatRequest(:final chatId) when chatId == 'rss' => demoQuestion(
    demoChats().firstWhere((c) => c.id == 'rss'),
  ),
  GetDiffRequest() => GetDiffResponse(files: demoChanges()),
  ListCommitsRequest() => ListCommitsResponse(
    commits: [
      for (final (h, s, a, r) in [
        ('c3f9a21', 'Older posts link in the default theme', 1, 0),
        ('8b07d4e', 'Page the feed handler', 46, 1),
        ('41e2c90', 'Keyset cursor in store.ListPosts', 66, 6),
      ])
        Commit(hash: h, short: h, subject: s, added: a, removed: r),
    ],
  ),
  ListJiraSitesRequest() => ListJiraSitesResponse(sites: [demoSite]),
  ListJiraIssuesRequest(list: 'mine') => ListJiraIssuesResponse(
    issues: [
      for (final i in demoSprint)
        if (i.assignee == 'Maya Chen') i,
    ],
  ),
  ListJiraIssuesRequest() => ListJiraIssuesResponse(
    sprint: 'Sprint 14',
    issues: demoSprint,
  ),
  ListTerminalsRequest() => ListTerminalsResponse(
    terminals: [
      Terminal(id: 't1', chatId: heroChat.id, folder: demoTree, shell: 'zsh'),
    ],
  ),
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
  GetGitHubFilesRequest() => GetGitHubFilesResponse(files: demoPullFiles()),
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

/// The Mac app at [size] in [brightness], on the demo's chats.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester,
  Size size, {
  Brightness brightness = Brightness.dark,
  String? select,
  bool details = true,
  Object? Function(Object input)? more,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  clock = () => demoNow;
  addTearDown(() => clock = DateTime.now);
  showDetails.value = details;
  paneWidths.value = {};
  subagentWide.value = false;
  collapsedCards.value = {};
  cardOrder.value = [];
  pullSeen.value = {};
  final open = <StreamController<Object>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final fake = FakeDaemon(demoChats())
    ..answer = ((input) => more?.call(input) ?? _demo(input))
    ..streams = (input) {
      final first = switch (input) {
        WatchChatFileRequest(:final path) => WatchChatFileResponse(
          path: '$demoTree/$path',
          data: utf8.encode(designDoc),
          size: Int64(designDoc.length),
        ),
        AttachTerminalRequest() => AttachTerminalResponse(
          data: utf8.encode(demoTerminal),
        ),
        _ => null,
      };
      if (first == null) return null;
      final s = StreamController<Object>()..add(first);
      open.add(s);
      return s.stream;
    };
  final d = await fake.connect(tester);
  if (select != null) d.select(select);
  // A draft in the hero chat's box (its hint's ⏎ and ⌘ need the Mac's
  // fallback fonts, which tests don't have).
  d.chats[heroChat.id]!.draft.text.text =
      'Also keep the cursor in the URL, so a shared link opens the same page.';
  await tester.pumpWidget(NushiApp(daemon: d));
  await _pump(tester, 10);
  return (d, fake);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('hero: a chat mid-turn, its subagent beside it, the details '
      'panel', (tester) async {
    rememberContext(
      heroChat.id,
      GetContextUsageResponse(
        categories: [
          for (final (name, n, kind) in [
            ('System prompt', 3100, ''),
            ('System tools', 14800, ''),
            ('MCP tools', 6200, ''),
            ('Memory files', 2400, ''),
            ('Messages', 57700, ''),
            ('Free space', 115800, 'free'),
          ])
            ContextCategory(
              name: name,
              tokens: Int64(n),
              percent: n / 2000,
              kind: kind,
            ),
        ],
      ),
    );
    Collapsible.opened.add('e2');
    addTearDown(Collapsible.opened.clear);
    final (d, _) = await _app(tester, const Size(1600, 1000), select: 'feed');
    collapsedCards.value = {'Environment', 'Changes', 'Artifacts'};
    d.chats['feed']!.pane.value = 'x';
    await _pump(tester);
    await _shoot('hero');
    d.dispose();
  }, variant: _mac);

  testWidgets('agents: New chat asks which one', (tester) async {
    final (d, _) = await _app(tester, _small, select: 'feed');
    await tester.tap(find.text('New chat').first);
    await _pump(tester);
    await _shoot('agents');
    d.dispose();
  }, variant: _mac);

  testWidgets('changes: the branch with review comments', (tester) async {
    final cursor = demoChanges().first;
    ReviewComment at(String id, String quote, String text) => ReviewComment(
      id: id,
      where: 'branch',
      path: cursor.path,
      old: false,
      start: lineOf(cursor, quote),
      end: lineOf(cursor, quote),
      quote: quote,
      text: text,
    );
    setComments(heroChat.id, [
      at(
        '1',
        'var errBadCursor = errors.New("feed: bad cursor")',
        'Export it (ErrBadCursor), so a theme’s handler can tell a bad '
            'link from a failure.',
      ),
      at(
        '2',
        '\traw := c.Published.Format(time.RFC3339Nano) + "|" +',
        'UnixNano would make a shorter cursor than RFC 3339 here.',
      ),
    ]);
    final (d, _) = await _app(tester, _small, select: 'feed', details: false);
    d.chats['feed']!.tab.value = ChatTab.changes;
    await _pump(tester, 10);
    await tester.tap(
      find.textContaining('cursor.go', findRichText: true).first,
    );
    await _pump(tester, 10);
    await _shoot('changes');
    d.dispose();
  }, variant: _mac);

  testWidgets('preview: the design note the agent wrote', (tester) async {
    final (d, _) = await _app(tester, _small, select: 'feed', details: false);
    d.chats['feed']!.openPreview('docs/design/feed-cursor.md');
    await _pump(tester, 10);
    await _shoot('preview');
    d.dispose();
  }, variant: _mac);

  testWidgets('pull request: the tab', (tester) async {
    final (d, _) = await _app(tester, _small, select: 'feed', details: false);
    d.chats['feed']!.tab.value = ChatTab.pull;
    await _pump(tester, 10);
    await _shoot('pull-request');
    d.dispose();
  }, variant: _mac);

  testWidgets('jira: the sprint', (tester) async {
    final (d, _) = await _app(tester, _small, select: 'feed', details: false);
    await tester.tap(find.text('Jira').first);
    await _pump(tester, 10);
    await tester.tap(find.text('Sprint').first);
    await _pump(tester, 10);
    await _shoot('jira');
    d.dispose();
  }, variant: _mac);

  testWidgets('phone: a question, answered with a tap', (tester) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(390, 760) * 2;
    tester.platformDispatcher
      ..platformBrightnessTestValue = Brightness.dark
      ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    clock = () => demoNow;
    addTearDown(() => clock = DateTime.now);
    final fake = FakeDaemon(demoChats())..answer = _demo;
    final platform = PhonePlatform()
      ..saved = {
        'key': Uint8List(32)..[0] = 7,
        'name': 'iPhone',
        'relay': 'wss://relay.example.com',
        'daemon': 'demo-daemon',
        'daemonKey': Uint8List(32)..[0] = 9,
      };
    final phone = Phone(
      platform,
      connectTo: (_) => Daemon(transport: fake, remote: true),
    );
    await tester.pumpWidget(PhoneApp(phone));
    await phone.start();
    await _pump(tester, 8);
    await tester.tap(find.text('Atom feed drops the summary'));
    await _pump(tester, 10);
    await _shoot('phone', find.byType(PhoneApp));
    await phone.close();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }, variant: _mac);

  testWidgets('terminal: beside the chat', (tester) async {
    terminalChats.value = {heroChat.id};
    final (d, _) = await _app(tester, _small, select: 'feed', details: false);
    await _pump(tester, 10);
    await _shoot('terminal');
    d.dispose();
  }, variant: _mac);
}

/// The highlights' window.
const _small = Size(1280, 800);
