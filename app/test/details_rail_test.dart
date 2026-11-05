import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/context_report.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

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

final _full = GetContextUsageResponse(
  categories: reportCategories,
  markdown: reportMarkdown,
);

Finder get _panel => find.byType(DetailsPanel);

Finder _inPanel(Finder f) => find.descendant(of: _panel, matching: f);

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  test("the lists /context gives beside its categories, named as the rail's "
      'rows', () {
    final lists = contextLists(reportMarkdown);
    expect([for (final l in lists) l.name], ['MCP tools', 'Custom agents']);
    expect(lists.first.rows, hasLength(3));
    expect(lists.last.rows.last, ('explorer', 134));
    expect(contextLists('## Context Usage'), isEmpty);
    expect(untilCompact(reportCategories), 421400);
    expect(untilCompact(reportCategories.take(9).toList()), isNull);
  });

  testWidgets('a full report: the line, a row per kind with its share, the '
      'deferred dimmed, the lists, and how far from compacting', (
    tester,
  ) async {
    final (d, fake) = await railApp(tester, context: _full);
    expect(_inPanel(find.text('55% used')), findsOne);
    expect(_inPanel(find.text('545.5k / 1M')), findsOne);
    // Largest first; the buffer and the free space last.
    double y(String s) => tester.getTopLeft(_inPanel(find.text(s)).first).dy;
    expect(y('Messages'), lessThan(y('System tools')));
    expect(y('System tools'), lessThan(y('Skills')));
    expect(y('Custom agents'), lessThan(y('Autocompact buffer')));
    expect(y('Autocompact buffer'), lessThan(y('Free space')));
    expect(_inPanel(find.text('51.0%')), findsOne);
    expect(_inPanel(find.text('—')), findsNWidgets(2)); // the deferred
    // The shares line up at the panel's right.
    final right = tester.getRect(_inPanel(find.text('51.0%'))).right;
    expect(tester.getRect(_inPanel(find.text('42.1%'))).right, right);
    expect(right, closeTo(1700 - 16, 1));
    // A list opens to its rows.
    expect(_inPanel(find.text('MCP tools (deferred)')), findsOne);
    expect(_inPanel(find.text('mcp__docs__read')), findsNothing);
    await tester.tap(_inPanel(find.text('MCP tools')));
    await tester.pumpAndSettle();
    expect(_inPanel(find.text('mcp__docs__read')), findsOne);
    expect(_inPanel(find.text('421.5k until auto-compact')), findsOne);
    // Compact (Claude's Compact session) sends /compact, as typed.
    await tester.tap(_inPanel(find.text('Compact')));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<SendPromptRequest>().single.text, '/compact');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('an agent that reports only a total: the line and the bar', (
    tester,
  ) async {
    final (d, _) = await railApp(tester);
    expect(_inPanel(find.text('55% used')), findsOne);
    expect(_inPanel(find.text('545.5k / 1M')), findsOne);
    expect(_inPanel(find.text('Messages')), findsNothing);
    expect(_inPanel(find.textContaining('until auto-compact')), findsNothing);
    expect(_inPanel(find.textContaining('fills it')), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('nothing reported: one line', (tester) async {
    final (d, _) = await railApp(tester, usage: Usage());
    expect(_inPanel(find.text('Not reported yet')), findsOne);
    expect(_inPanel(find.byType(ContextReport)), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('background tasks: the running ones, the finished folded', (
    tester,
  ) async {
    final (d, _) = await railApp(tester, context: _full);
    expect(
      _inPanel(find.text('Review the rail against the screenshot')),
      findsOne,
    );
    expect(_inPanel(find.text('make check-app')), findsOne);
    expect(_inPanel(find.byTooltip('Stop')), findsNWidgets(2));
    expect(_inPanel(find.text('Find every PanelWidget')), findsNothing);
    await tester.tap(_inPanel(find.text('3 finished')));
    await tester.pumpAndSettle();
    expect(_inPanel(find.text('Find every PanelWidget')), findsOne);
    expect(_inPanel(find.text('make golden-diff')), findsOne);
    expect(_inPanel(find.text('1m 00s')), findsOne); // s3's
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('artifacts: five, their kind on the right, then Show more', (
    tester,
  ) async {
    final (d, _) = await railApp(
      tester,
      size: const Size(1700, 1400),
      context: _full,
    );
    final rows = find.byType(FileRows);
    Finder inRows(Finder f) => find.descendant(of: rows, matching: f);
    expect(inRows(find.text('sizes.csv')), findsOne); // the newest first
    expect(inRows(find.text('CSV')), findsOne);
    expect(inRows(find.text('0092-the-details-rail.md')), findsNothing);
    expect(inRows(find.byIcon(Icons.image_outlined)), findsOne);
    await tester.tap(inRows(find.text('Show more')));
    await tester.pumpAndSettle();
    expect(inRows(find.text('0092-the-details-rail.md')), findsOne);
    await tester.tap(inRows(find.text('Show less')));
    await tester.pumpAndSettle();
    expect(inRows(find.text('0092-the-details-rail.md')), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('one width at every size it shows at, and no edge to drag', (
    tester,
  ) async {
    for (final width in [1000.0, 1400.0, 2400.0]) {
      final (d, _) = await railApp(tester, size: Size(width, 900));
      expect(tester.getRect(_panel).width, DetailsPanel.width);
      expect(tester.getRect(_panel).right, width);
      expect(
        find.ancestor(of: _panel, matching: find.byType(Resizable)),
        findsNothing,
      );
      // A drag from its left edge moves nothing.
      final left = tester.getRect(_panel).left;
      await tester.dragFrom(Offset(left + 1, 400), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(_panel).left, left);
      await closeView(tester, d);
    }
  }, variant: _mac);

  testWidgets("an older app's dragged width is dropped", (tester) async {
    paneWidths.value = {'details': 400, 'preview': 600};
    final (d, _) = await railApp(tester);
    expect(tester.getRect(_panel).width, DetailsPanel.width);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final width in [1700.0, 1180.0, 720.0]) {
      testWidgets('render: a busy chat, ${width.toInt()} wide, $name', (
        tester,
      ) async {
        final (d, _) = await railApp(
          tester,
          size: Size(width, 1000),
          brightness: brightness,
          context: _full,
        );
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'details_rail_${width.toInt()}_$name',
        );
        await closeView(tester, d);
      }, variant: _mac);
    }

    testWidgets('golden: the panel, a busy chat, $name', (tester) async {
      final (d, _) = await railApp(
        tester,
        size: const Size(1400, 1000),
        brightness: brightness,
        context: _full,
      );
      await tester.tap(_inPanel(find.text('3 finished')));
      await tester.pumpAndSettle();
      await expectLater(
        _panel,
        matchesGoldenFile('goldens/details_rail_$name.png'),
      );
      await closeView(tester, d);
    }, variant: _mac);
  }

  // Every built-in theme, both ways: the panel only (the window's render
  // is above), to look at.
  for (final theme in builtInThemes) {
    for (final b in Brightness.values) {
      testWidgets('render: the panel in ${theme.name}, ${b.name}', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        final (d, _) = await railApp(
          tester,
          size: const Size(1200, 1000),
          brightness: b,
          context: _full,
        );
        await render(tester, _panel, 'details_rail_${theme.id}_${b.name}');
        await closeView(tester, d);
      }, variant: _mac);
    }
  }

  testWidgets('MoreRows starts folded', (tester) async {
    await tester.pumpWidget(
      themed(const MoreRows('2 finished', [Text('a'), Text('b')], open: false)),
    );
    expect(find.text('a'), findsNothing);
  });
}
