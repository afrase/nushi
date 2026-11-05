// The details panel's tests' fixture: a busy chat, its context report.

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// What Claude's /context says of a long chat, as in Claude Code's rail
/// (the owner's screenshot, 2026-11-05).
const reportMarkdown = '''
## Context Usage

**Model:** claude-opus-5-5
**Tokens:** 545.5k / 1m (55%)

### Estimated usage by category

| Category | Tokens | Percentage |
|----------|--------|------------|
| System prompt | 4.5k | 0.4% |
| System tools | 20.9k | 2.1% |
| MCP server instructions | 1.3k | 0.1% |
| MCP tools (deferred) | 78.2k | 7.8% |
| System tools (deferred) | 25.7k | 2.6% |
| Custom agents | 314 | 0.0% |
| Memory files | 2k | 0.2% |
| Skills | 6.6k | 0.7% |
| Messages | 509.9k | 51.0% |
| Free space | 421.4k | 42.1% |
| Autocompact buffer | 33k | 3.3% |

### MCP Tools

| Tool | Server | Tokens |
|------|--------|--------|
| mcp__github__get_me | github | 120 |
| mcp__github__list_issues | github | 410 |
| mcp__docs__read | docs | 250 |

### Custom Agents

| Agent Type | Source | Tokens |
|------------|--------|--------|
| reviewer | User | ~180 |
| explorer | Project | ~134 |
''';

ContextCategory _c(String name, int tokens, double pct, [String kind = '']) =>
    ContextCategory(
      name: name,
      tokens: Int64(tokens),
      percent: pct,
      kind: kind,
    );

/// The categories the daemon reads from [reportMarkdown].
final List<ContextCategory> reportCategories = [
  _c('System prompt', 4500, 0.4),
  _c('System tools', 20900, 2.1),
  _c('MCP server instructions', 1300, 0.1),
  _c('MCP tools', 78200, 7.8, 'deferred'),
  _c('System tools', 25700, 2.6, 'deferred'),
  _c('Custom agents', 314, 0),
  _c('Memory files', 2000, 0.2),
  _c('Skills', 6600, 0.7),
  _c('Messages', 509900, 51),
  _c('Free space', 421400, 42.1, 'free'),
  _c('Autocompact buffer', 33000, 3.3),
];

Item _write(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

int _ago(int minutes) =>
    clock().subtract(Duration(minutes: minutes)).millisecondsSinceEpoch;

Item _subagent(String id, String title, String state, {int ran = 3}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  agent: 'general-purpose',
  title: title,
  status: state == 'running' ? 'in_progress' : 'completed',
  agentId: 'agent-$id',
  subagent: Subagent(
    state: state,
    started: Int64(_ago(ran + 4)),
    ended: Int64(state == 'running' ? 0 : _ago(4)),
  ),
);

Item _command(String id, String command, String state) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'execute',
  title: command,
  status: 'completed',
  backgroundCommand: BackgroundCommand(
    id: id,
    state: state,
    started: Int64(_ago(5)),
    ended: Int64(state == 'running' ? 0 : _ago(1)),
    output: 'ok  nushi/app 12.3s\n',
    end: state == 'running' ? '' : 'exited with code 0',
  ),
);

/// A busy chat's items: files written, subagents and commands running and
/// finished.
List<Item> get busyItems => [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Redesign the details panel as Claude Code’s right rail.',
  ),
  for (final (i, f) in [
    'docs/adr/0092-the-details-rail.md',
    'docs/rail-colors.md',
    'mock/rail.html',
    'mock/rail-dark.png',
    'docs/rail.svg',
    'docs/flows.mmd',
    'docs/sizes.csv',
  ].indexed)
    _write('w$i', f),
  _subagent('s1', 'Review the rail against the screenshot', 'running'),
  _command('b1', 'make check-app', 'running'),
  _subagent('s2', 'Find every PanelWidget', 'done'),
  _subagent('s3', 'Check the phone sheet', 'done', ran: 1),
  _command('b2', 'make golden-diff', 'done'),
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The sections are flat now; the context block is next.',
  ),
];

/// The app at [size] on a busy chat whose agent reported [usage] and, asked,
/// what fills its context ([context]; null: it can't be asked).
Future<(Daemon, FakeDaemon)> railApp(
  WidgetTester tester, {
  Size size = const Size(1700, 1000),
  Brightness brightness = Brightness.dark,
  GetContextUsageResponse? context,
  Usage? usage,
  List<Item>? items,
}) async {
  viewport(tester, size, brightness: brightness);
  forgetContext('c'); // another test's
  showDetails.value = true;
  sidebarHidden.value = true;
  collapsedWidgets.value = {};
  widgetOrder.value = [];
  final c = chat(
    'c',
    'claude',
    'Redesign the details rail',
    status: ChatStatus(canAskContext: context != null),
  );
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: items ?? busyItems,
        status: ChatStatus(canAskContext: context != null),
        commands: [Command(name: 'compact')],
        usage:
            usage ??
            Usage(contextUsed: Int64(545500), contextSize: Int64(1000000)),
      ),
      GetContextUsageRequest() => context,
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2)); // the panel asks
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
  await tester.pumpAndSettle();
  return (d, fake);
}

final fullContext = GetContextUsageResponse(
  categories: reportCategories,
  markdown: reportMarkdown,
);

Finder get railPanel => find.byType(DetailsPanel);

Finder inRail(Finder f) => find.descendant(of: railPanel, matching: f);

final macOnly = TargetPlatformVariant.only(TargetPlatform.macOS);
