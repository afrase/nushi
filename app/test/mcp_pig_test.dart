import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart' show NotePill, Toggle;
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/mcp_widget.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'mcp_pig_fixtures.dart';

/// The tooltips of the switch on one of yours and on a project's server.
const _yours =
    'On in every folder, for you only: set in /Users/me/.pig/agent/mcp.json. '
    'Chats pick up a change when they restart.';
const _projects =
    'On in this project, for everyone on it: set in '
    '/Users/me/site/.pig/mcp.json. Chats pick up a change when they restart.';

void main() {
  setUpAll(loadFonts);

  testWidgets('PiG’s page has yours and the project’s, by the shape the '
      'daemon gives it: no local scope, plugins or connectors', (tester) async {
    final (fake, d) = await pigPage(tester);
    expect(
      fake.calls.whereType<ListMcpServersRequest>().map((r) => r.agent).toSet(),
      {'pig'},
    );
    // Its heading, though it's the only agent with MCP servers here.
    expect(find.text('PiG'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    for (final gone in ['Local', 'Plugins', 'claude.ai']) {
      expect(find.text(gone), findsNothing);
    }
    expect(find.textContaining('.pig/mcp.json'), findsOneWidget);
    expect(find.textContaining('.mcp.json, shared'), findsNothing);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Failed to connect'), findsOneWidget);
    expect(find.text('connect: connection refused'), findsOneWidget);
    expect(find.text('SEARCH_KEY=••••'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('project servers PiG doesn’t load each say the folder isn’t '
      'trusted, the group how to trust it, once; no switch, not dimmed', (
    tester,
  ) async {
    final (_, d) = await pigPage(
      tester,
      servers: () => [
        ...pigUntrusted(),
        McpServer(
          name: 'docs',
          scope: 'project',
          source: '/Users/me/site/.pig/mcp.json',
          configJson: '{"command":"docs-mcp"}',
          // As a daemon before API 157 said of one its check didn't load.
          state: 'disabled',
          detail: 'Not in use here',
          untrusted: true,
        ),
      ],
    );
    expect(find.text('Folder not trusted'), findsNWidgets(2));
    expect(find.text('Off'), findsNothing);
    expect(find.textContaining('Not in use here'), findsNothing);
    expect(
      find.text(
        'Folder not trusted: run pig here in a terminal and trust it, then '
        'Check again.',
      ),
      findsOneWidget,
    );
    // Yours have their switches; the untrusted ones have none, but keep
    // the place, so the pills still line up.
    expect(find.byType(Toggle), findsNWidgets(2));
    final ends = {
      for (final e in find.byType(NotePill).evaluate())
        tester.getTopRight(find.byWidget(e.widget)).dx,
    };
    expect(ends, hasLength(1), reason: '$ends');
    // Not used isn't off: the row is drawn whole, not faded.
    for (final name in ['lint', 'docs']) {
      final fade = tester.widget<Opacity>(
        find.ancestor(of: find.text(name), matching: find.byType(Opacity)),
      );
      expect(fade.opacity, 1, reason: name);
    }
    await closeView(tester, d);
  });

  testWidgets('a failed server’s error is its own text in the failure '
      'colour, its masked env names a muted code line; no middle dot', (
    tester,
  ) async {
    const error =
        'MCP connection closed\nindexer: config not found\nexit status 3';
    final (_, d) = await pigPage(
      tester,
      servers: () => [
        McpServer(
          name: 'indexer',
          scope: 'user',
          source: '/Users/me/.pig/agent/mcp.json',
          configJson:
              '{"command":"indexer-mcp",'
              '"env":{"INDEX_TOKEN":"••••","INDEX_ROOT":"••••"}}',
          state: 'failed',
          detail: error,
        ),
      ],
    );
    final theme = NushiTheme.of(tester.element(find.byType(McpView)));
    final failed = tester.widget<Text>(find.text(error));
    expect(failed.style?.color, theme.t.crashed);
    expect(failed.style?.fontFamily, theme.ui(theme.t.crashed).fontFamily);
    final names = tester.widget<Text>(
      find.text('INDEX_TOKEN=••••  INDEX_ROOT=••••'),
    );
    expect(names.style?.color, theme.t.textMuted);
    expect(names.style?.fontFamily, theme.code(theme.t.textMuted).fontFamily);
    final words = [
      for (final t in find.byType(Text).evaluate())
        (t.widget as Text).data ?? '',
    ];
    expect(words.where((w) => w.contains('·')), isEmpty);
    await closeView(tester, d);
  });

  testWidgets('a server the check said nothing of reads Not checked, not '
      'Checking…, once the check is done', (tester) async {
    // A folder PiG trusts only by defaultProjectTrust "always", which a
    // session honours and PiG's list doesn't: the project's server comes
    // back from the check without a state.
    final (_, d) = await pigPage(
      tester,
      servers: () => [
        McpServer(
          name: 'lint',
          scope: 'project',
          source: '/Users/me/site/.pig/mcp.json',
          configJson: '{"command":"lint-mcp"}',
        ),
      ],
    );
    expect(find.text('Not checked'), findsOneWidget);
    expect(find.text('Checking…'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('once PiG trusts the folder the project’s server has its '
      'switch, which PiG’s own config turns off', (tester) async {
    final (fake, d) = await pigPage(tester, servers: pigTrusted);
    expect(find.text('Folder not trusted'), findsNothing);
    expect(find.text('Connected'), findsNWidgets(2));
    expect(find.byType(Toggle), findsNWidgets(3));
    await tester.tap(find.byType(Toggle).last);
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetMcpServerOnRequest>().single;
    expect(
      (set.agent, set.scope, set.name, set.on),
      ('pig', 'project', 'lint', false),
    );
    await closeView(tester, d);
  });

  testWidgets('the switch on one of yours reaches every folder and says '
      'where it writes; a project server’s is in this project', (tester) async {
    final (fake, d) = await pigPage(tester, servers: pigTrusted);
    expect(find.text('in every folder'), findsNWidgets(2));
    // Whole in its slot, not cut.
    for (final e in find.text('in every folder').evaluate()) {
      expect((e.renderObject! as RenderParagraph).didExceedMaxLines, isFalse);
    }
    expect(find.text('in this project'), findsOneWidget);
    expect(tooltips(), containsAll([_yours, _projects]));
    await tester.tap(find.byType(Toggle).first);
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetMcpServerOnRequest>().single;
    expect(
      (set.agent, set.scope, set.name, set.on),
      ('pig', 'user', 'search', false),
    );
    await closeView(tester, d);
  });

  testWidgets('a held switch says why in a line on its row, keeps its place '
      'drawn off, promises no reach, and sends nothing', (tester) async {
    const held = 'Set by this folder’s .pig/mcp.json';
    final (fake, d) = await pigPage(
      tester,
      servers: () => [
        McpServer(
          name: 'search',
          scope: 'user',
          source: '/Users/me/.pig/agent/mcp.json',
          configJson: '{"command":"search-mcp"}',
          state: 'disabled',
          off: true,
          held: held,
        ),
        McpServer(
          name: 'notes',
          scope: 'user',
          source: '/Users/me/.pig/agent/mcp.json',
          configJson: '{"command":"notes-mcp"}',
          state: 'connected',
        ),
      ],
    );
    // Said in words on the row, not only on hover.
    final line = tester.widget<Text>(find.text(held));
    final theme = NushiTheme.of(tester.element(find.byType(McpView)));
    expect(line.style?.color, theme.t.textMuted);
    expect(
      tester.getTopLeft(find.text(held)).dy,
      greaterThan(tester.getBottomLeft(find.text('search')).dy),
    );
    expect(tooltips(), contains(held));
    // No label that promises a switch that works: only the live one's.
    expect(find.text('in every folder'), findsOneWidget);
    expect(find.text('in this project'), findsNothing);
    // In the same place as the live one's, and off.
    final toggles = find.byType(Toggle);
    expect(
      tester.getTopLeft(toggles.first).dx,
      tester.getTopLeft(toggles.last).dx,
    );
    expect(tester.widget<Toggle>(toggles.first).onChanged, isNull);
    await tester.tap(toggles.first);
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<SetMcpServerOnRequest>(), isEmpty);
    await closeView(tester, d);
  });

  testWidgets('the state pills line up down the page, across agents: the '
      'switch’s label has a slot of its own width', (tester) async {
    final (_, d) = await pigDaemon(
      tester,
      servers: () => [
        ...pigTrusted(),
        McpServer(
          name: 'docs',
          scope: 'user',
          source: '/Users/me/.pig/agent/mcp.json',
          configJson: '{"command":"docs-mcp"}',
          state: 'connected',
          held: 'Set by this folder’s .pig/mcp.json',
        ),
      ],
      claude: true,
    );
    viewport(tester, const Size(1000, 1100), ratio: 3);
    await tester.pumpWidget(
      themed(McpView(daemon: d, folder: '/Users/me/site'), banner: false),
    );
    await tester.pumpAndSettle();
    final pills = find.byType(NotePill);
    expect(pills, findsAtLeastNWidgets(5));
    final ends = {
      for (final e in pills.evaluate())
        tester.getTopRight(find.byWidget(e.widget)).dx,
    };
    expect(ends, hasLength(1), reason: '$ends');
    await closeView(tester, d);
  });

  testWidgets('a project server PiG has no approval for has no Approve, '
      'whatever its state says', (tester) async {
    final (_, d) = await pigPage(
      tester,
      servers: () => [
        McpServer(
          name: 'odd',
          scope: 'project',
          configJson: '{"command":"odd"}',
          state: 'pending',
        ),
      ],
    );
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.byType(Toggle), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets('a trusted folder says nothing of trust, whatever a row says', (
    tester,
  ) async {
    final (_, d) = await pigPage(tester, trusted: true);
    expect(find.text(pigNotTrusted), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('removing a project server names PiG’s file', (tester) async {
    final (_, d) = await pigPage(tester);
    await tester.tap(find.byTooltip('More').last); // lint's
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove…'));
    await tester.pumpAndSettle();
    expect(find.text('Remove lint?'), findsOneWidget);
    expect(find.textContaining('.pig/mcp.json'), findsWidgets);
    expect(find.textContaining('repository’s .mcp.json'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('a PiG chat’s widget: switches for what is used, the '
      'untrusted one said so', (tester) async {
    final (_, d) = await pigDaemon(tester);
    final chat = ChatState('c1', '/Users/me/site')..agent = 'pig';
    viewport(tester, const Size(340, 500), ratio: 3);
    await tester.pumpWidget(themed(PanelWidgets([mcpWidget(chat, d)])));
    await tester.pumpAndSettle();
    expect(find.textContaining('its own config'), findsNothing);
    expect(find.text('search'), findsOneWidget);
    expect(find.text('Folder not trusted'), findsOneWidget);
    expect(find.byType(Toggle), findsNWidgets(2));
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, PiG’s servers in an untrusted folder, $name', (
      tester,
    ) async {
      final (_, d) = await pigPage(tester, tokens: tokens);
      await expectLater(
        find.byType(McpView),
        matchesGoldenFile('goldens/mcp_pig_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
