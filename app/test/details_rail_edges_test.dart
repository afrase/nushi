import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/context_report.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'details_rail_fixture.dart';
import 'fake_daemon.dart';
import 'harness.dart';

/// The color at ([x], [y]) in logical points of [image], drawn at [ratio].
Color _at(ui.Image image, ByteData bytes, double x, double y, double ratio) {
  final i = ((y * ratio).floor() * image.width + (x * ratio).floor()) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

void main() {
  setUpAll(loadFonts);

  for (final (name, brightness, tokens) in [
    ('dark', Brightness.dark, Tokens.dark),
    ('light', Brightness.light, Tokens.light),
  ]) {
    testWidgets('a hairline sets the panel off from the chat, $name', (
      tester,
    ) async {
      final (d, _) = await railApp(tester, brightness: brightness);
      final left = tester.getRect(railPanel).left;
      final ratio = tester.view.devicePixelRatio;
      final element = find.byType(NushiApp).evaluate().single;
      await tester.runAsync(() async {
        final image = await captureImage(element);
        final bytes = (await image.toByteData())!;
        // Down the panel's whole height: the rule, then its own fill.
        for (final y in [100.0, 400.0, 900.0]) {
          expect(_at(image, bytes, left, y, ratio), tokens.borderSubtle);
          expect(_at(image, bytes, left + 4, y, ratio), tokens.base);
        }
        image.dispose();
      });
      await closeView(tester, d);
    }, variant: macOnly);
  }

  testWidgets("an answer the daemon can't read kinds from keeps the line and "
      'the bar, its words under them', (tester) async {
    final (d, _) = await railApp(
      tester,
      context: GetContextUsageResponse(
        markdown: '## Context Usage\n\nA format Nushi has not seen.',
      ),
    );
    expect(inRail(find.text('55% used')), findsOne);
    expect(inRail(find.text('545.5k / 1M')), findsOne);
    expect(inRail(find.byType(AgentMarkdown)), findsOne);
    expect(
      tester.getTopLeft(inRail(find.byType(AgentMarkdown))).dy,
      greaterThan(tester.getBottomLeft(inRail(find.text('55% used'))).dy),
    );
    await closeView(tester, d);
  }, variant: macOnly);

  // The panel hides when the window narrows as it did at 264 points wide:
  // the transcript gives up some of its least width to keep it.
  for (final (width, shows) in [
    (1070.0, false),
    (1080.0, true),
    (1120.0, true),
  ]) {
    testWidgets('with the sidebar, ${width.toInt()} wide: the panel '
        '${shows ? 'shows' : 'hides'}', (tester) async {
      final (d, _) = await railApp(tester, size: Size(width, 900));
      sidebarHidden.value = false;
      await tester.pumpAndSettle();
      expect(railPanel, shows ? findsOne : findsNothing);
      expectTextInside(tester, width);
      if (width == 1080) {
        await render(tester, find.byType(NushiApp), 'details_rail_1080_sb');
      }
      await closeView(tester, d);
    }, variant: macOnly);
  }

  testWidgets('an opened "n finished" stays open as a task finishes', (
    tester,
  ) async {
    final (d, fake) = await railApp(tester);
    await tester.tap(inRail(find.text('3 finished')));
    await tester.pumpAndSettle();
    expect(inRail(find.text('Find every PanelWidget')), findsOne);
    // make check-app (the busy chat's 10th item) ends.
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        item: ItemEvent(
          index: 9,
          item: Item(
            id: 'b1',
            kind: ItemKind.ITEM_KIND_TOOL_CALL,
            toolKind: 'execute',
            title: 'make check-app',
            status: 'completed',
            backgroundCommand: BackgroundCommand(
              id: 'b1',
              state: 'done',
              started: Int64(fixtureNow.millisecondsSinceEpoch - 300000),
              ended: Int64(fixtureNow.millisecondsSinceEpoch),
              end: 'exited with code 0',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(inRail(find.text('4 finished')), findsOne);
    expect(inRail(find.text('Find every PanelWidget')), findsOne);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('every task row, running or finished, on one pitch; four '
      'running, then Show more', (tester) async {
    final (d, _) = await railApp(
      tester,
      size: const Size(1700, 1400),
      items: [
        ...busyItems,
        for (var i = 0; i < 4; i++)
          Item(
            id: 'r$i',
            kind: ItemKind.ITEM_KIND_TOOL_CALL,
            agent: 'general-purpose',
            title: 'Running $i',
            status: 'in_progress',
            agentId: 'agent-r$i',
            subagent: Subagent(state: 'running'),
          ),
      ],
    );
    // Six running: four, then Show more.
    expect(inRail(find.text('Running 3')), findsNothing);
    expect(inRail(find.text('make check-app')), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(ShowMore),
        matching: find.text('Show more'),
      ),
    );
    await tester.pumpAndSettle();
    expect(inRail(find.text('Running 3')), findsOne);
    await tester.tap(inRail(find.text('3 finished')));
    await tester.pumpAndSettle();
    final names = [
      'Review the rail against the screenshot',
      'Running 0',
      'Running 1',
      'Running 2',
      'Running 3', // shown by Show more
      'make check-app',
    ];
    double y(String s) => tester.getCenter(inRail(find.text(s))).dy;
    final pitch = y(names[1]) - y(names[0]);
    expect(pitch, closeTo(30, 0.5));
    for (final (i, n) in names.indexed.skip(1)) {
      expect(y(n) - y(names[i - 1]), closeTo(pitch, 0.5), reason: n);
    }
    // The finished: the same pitch from their line and between them.
    final finished = ['Check the phone sheet', 'Find every PanelWidget'];
    expect(y(finished[0]) - y('3 finished'), closeTo(pitch, 0.5));
    expect(y(finished[1]) - y(finished[0]), closeTo(pitch, 0.5));
    await closeView(tester, d);
  }, variant: macOnly);

  // Claude's rail colors System tools orange and the System prompt gold;
  // a light theme darkens both its orange and its amber to brown to read
  // as text, so the prompt takes a swatch's gold there (old: 55 apart).
  test('System tools and System prompt are two colors in every theme', () {
    double apart(Color a, Color b) {
      final (r, g, bl) = (a.r - b.r, a.g - b.g, a.b - b.b);
      return 255 * sqrt(r * r + g * g + bl * bl);
    }

    for (final theme in builtInThemes) {
      for (final b in Brightness.values) {
        final t = theme.of(b);
        Color of(String name) =>
            ContextReport.colorOf(t, ContextCategory(name: name));
        expect(
          apart(of('System tools'), of('System prompt')),
          greaterThan(b == Brightness.light ? 80 : 40),
          reason: '${theme.id} ${b.name}',
        );
      }
    }
  });
}
