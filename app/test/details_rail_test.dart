import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/context_report.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'details_rail_fixture.dart';
import 'fake_daemon.dart';
import 'github_fixture.dart' show pull, testRepo;
import 'harness.dart';

/// A chat on a branch with changes and a pull request, in a folder with
/// MCP servers.
Object? _filled(Object input) => switch (input) {
  GetFolderStatusRequest() => GetFolderStatusResponse(
    git: true,
    branch: 'rail-cards',
    defaultBase: 'main',
    ahead: 2,
    files: 4,
    added: 120,
    removed: 31,
  ),
  FindChatPullRequest() => FindChatPullResponse(
    host: 'github.com',
    repo: testRepo,
    branch: 'rail-cards',
    pull: GitHubLink(
      host: 'github.com',
      repo: testRepo,
      number: 1,
      id: 'PR_1',
      pull: true,
    ),
  ),
  GetGitHubPullRequest() => GetGitHubPullResponse(pull: pull()),
  ListMcpServersRequest() => ListMcpServersResponse(
    servers: [
      McpServer(name: 'github', scope: 'user', state: 'connected'),
      McpServer(
        name: 'web',
        scope: 'project',
        state: 'connected',
        approved: true,
      ),
      McpServer(name: 'docs', scope: 'project', state: 'failed'),
    ],
  ),
  _ => null,
};

/// Where the card of the widget at [widget] is: what takes its pointer.
Rect _card(Element widget) {
  RenderBox? box;
  void visit(Element e) {
    if (box != null) return;
    if (e.widget is MouseRegion) {
      box = e.renderObject! as RenderBox;
    } else {
      e.visitChildren(visit);
    }
  }

  widget.visitChildren(visit);
  return box!.localToGlobal(Offset.zero) & box!.size;
}

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
    final (d, fake) = await railApp(tester, context: fullContext);
    expect(inRail(find.text('55% used')), findsOne);
    expect(inRail(find.text('545.5k / 1M')), findsOne);
    // Largest first; the buffer and the free space last.
    double y(String s) => tester.getTopLeft(inRail(find.text(s)).first).dy;
    expect(y('Messages'), lessThan(y('System tools')));
    expect(y('System tools'), lessThan(y('Skills')));
    expect(y('Custom agents'), lessThan(y('Autocompact buffer')));
    expect(y('Autocompact buffer'), lessThan(y('Free space')));
    expect(inRail(find.text('51.0%')), findsOne);
    expect(inRail(find.text('—')), findsNWidgets(2)); // the deferred
    // The shares line up at the panel's right.
    final right = tester.getRect(inRail(find.text('51.0%'))).right;
    expect(tester.getRect(inRail(find.text('42.1%'))).right, right);
    expect(right, closeTo(1700 - NushiTheme.windowPad - 16, 1));
    // A list opens to its rows.
    expect(inRail(find.text('MCP tools (deferred)')), findsOne);
    expect(inRail(find.text('mcp__docs__read')), findsNothing);
    await tester.tap(inRail(find.text('MCP tools')));
    await tester.pumpAndSettle();
    expect(inRail(find.text('mcp__docs__read')), findsOne);
    expect(inRail(find.text('421.5k until auto-compact')), findsOne);
    // Compact (Claude's Compact session) sends /compact, as typed.
    await tester.tap(inRail(find.text('Compact')));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<SendPromptRequest>().single.text, '/compact');
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('an agent that reports only a total: the line and the bar', (
    tester,
  ) async {
    final (d, _) = await railApp(tester);
    expect(inRail(find.text('55% used')), findsOne);
    expect(inRail(find.text('545.5k / 1M')), findsOne);
    expect(inRail(find.text('Messages')), findsNothing);
    expect(inRail(find.textContaining('until auto-compact')), findsNothing);
    expect(inRail(find.textContaining('fills it')), findsNothing);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('nothing reported: one line', (tester) async {
    final (d, _) = await railApp(tester, usage: Usage());
    expect(inRail(find.text('Not reported yet')), findsOne);
    expect(inRail(find.byType(ContextReport)), findsNothing);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('background tasks: the running ones, the finished folded', (
    tester,
  ) async {
    final (d, _) = await railApp(tester, context: fullContext);
    expect(
      inRail(find.text('Review the rail against the screenshot')),
      findsOne,
    );
    expect(inRail(find.text('make check-app')), findsOne);
    expect(inRail(find.byTooltip('Stop')), findsNWidgets(2));
    expect(inRail(find.text('Find every PanelWidget')), findsNothing);
    await tester.tap(inRail(find.text('3 finished')));
    await tester.pumpAndSettle();
    expect(inRail(find.text('Find every PanelWidget')), findsOne);
    expect(inRail(find.text('make golden-diff')), findsOne);
    expect(inRail(find.text('1m 00s')), findsOne); // s3's
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('artifacts: five, their kind on the right, then Show more', (
    tester,
  ) async {
    final (d, _) = await railApp(
      tester,
      size: const Size(1700, 1400),
      context: fullContext,
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
  }, variant: macOnly);

  testWidgets('one width at every size it shows at, and no edge to drag', (
    tester,
  ) async {
    for (final width in [1000.0, 1400.0, 2400.0]) {
      final (d, _) = await railApp(tester, size: Size(width, 900));
      expect(tester.getRect(railPanel).width, DetailsPanel.width);
      expect(tester.getRect(railPanel).right, width - NushiTheme.windowPad);
      expect(
        find.ancestor(of: railPanel, matching: find.byType(Resizable)),
        findsNothing,
      );
      // A drag from its left edge moves nothing.
      final left = tester.getRect(railPanel).left;
      await tester.dragFrom(Offset(left + 1, 400), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(railPanel).left, left);
      await closeView(tester, d);
    }
  }, variant: macOnly);

  testWidgets("an older app's dragged width is dropped", (tester) async {
    paneWidths.value = {'details': 400, 'preview': 600};
    final (d, _) = await railApp(tester);
    expect(tester.getRect(railPanel).width, DetailsPanel.width);
    await closeView(tester, d);
  }, variant: macOnly);

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
          context: fullContext,
        );
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'details_rail_${width.toInt()}_$name',
        );
        await closeView(tester, d);
      }, variant: macOnly);
    }

    testWidgets('golden: the panel, a busy chat, $name', (tester) async {
      final (d, _) = await railApp(
        tester,
        size: const Size(1400, 1000),
        brightness: brightness,
        context: fullContext,
      );
      await tester.tap(inRail(find.text('3 finished')));
      await tester.pumpAndSettle();
      await expectLater(
        railPanel,
        matchesGoldenFile('goldens/details_rail_$name.png'),
      );
      await closeView(tester, d);
    }, variant: macOnly);
  }

  // Every widget with something in it (a branch with changes, a pull
  // request, MCP servers with their switches), each a card (ADR 0111): no
  // card inside a card, no text past a card's edge, the cards 8 in from
  // the column's sides and 8 apart.
  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final (w, size) in [
      ('1700', const Size(1700, 1000)),
      ('1700_tall', const Size(1700, 1900)),
      ('720', const Size(720, 1000)),
    ]) {
      testWidgets('render: every widget filled, $w, $name', (tester) async {
        final (d, _) = await railApp(
          tester,
          size: size,
          brightness: brightness,
          context: fullContext,
          also: _filled,
          mcp: true,
        );
        expectTextInside(tester, size.width);
        if (size.width < 1000) {
          // Too narrow for the details: they hide, as before.
          expect(railPanel, findsNothing);
        } else {
          final panel = tester.getRect(railPanel);
          // Those under the window's foot too: every one is built.
          final cards = [
            for (final e
                in find.byType(PanelWidget, skipOffstage: false).evaluate())
              _card(e),
          ];
          expect(cards.length, greaterThanOrEqualTo(7));
          expect(cards.first.top, panel.top + PanelType.inset);
          for (final (i, card) in cards.indexed) {
            expect(card.left, panel.left + PanelType.inset);
            expect(card.right, panel.right - PanelType.inset);
            if (i > 0) expect(card.top, cards[i - 1].bottom + PanelType.inset);
          }
          for (final title in ['Pull request', 'MCP', 'Artifacts', 'github']) {
            expect(
              find.descendant(
                of: railPanel,
                matching: find.text(title, skipOffstage: false),
                skipOffstage: false,
              ),
              findsOne,
            );
          }
          // A card's text is where the flat widget's was: 16 in.
          expect(
            tester.getTopLeft(inRail(find.text('Environment'))).dx,
            panel.left + PanelType.side,
          );
        }
        await render(tester, find.byType(NushiApp), 'details_cards_${w}_$name');
        if (w == '1700') {
          // Scrolled, the pointer at its bar, which is then at its widest:
          // beside the cards, in their margin.
          final panel = tester.getRect(railPanel);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: panel.center);
          addTearDown(mouse.removePointer);
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: panel.center,
              scrollDelta: const Offset(0, 260),
            ),
          );
          await tester.pump();
          await mouse.moveTo(Offset(panel.right - 5, panel.center.dy));
          await tester.pump(const Duration(milliseconds: 300));
          await render(
            tester,
            find.byType(NushiApp),
            'details_cards_${w}_scrolled_$name',
          );
        }
        await closeView(tester, d);
      }, variant: macOnly);
    }
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
          context: fullContext,
        );
        await render(tester, railPanel, 'details_rail_${theme.id}_${b.name}');
        await closeView(tester, d);
      }, variant: macOnly);
    }
  }

  testWidgets('MoreRows starts folded', (tester) async {
    await tester.pumpWidget(
      themed(const MoreRows('2 finished', [Text('a'), Text('b')], open: false)),
    );
    expect(find.text('a'), findsNothing);
  });
}
