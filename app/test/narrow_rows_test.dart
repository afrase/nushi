import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Deep review 2026-11-13, finding 5: a run of a subagent's tool calls lost
// its title and its failed count at the pane's widths.

/// A chat whose running subagent read, edited a Markdown file (so its run
/// previews, with +n −m) and ran a command that failed, then went on.
List<Item> _items() => [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Find every caller of store.Get and write them up.',
  ),
  Item(
    id: 'x',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    title: 'Find every caller of store.Get',
    status: 'in_progress',
    subagent: Subagent(
      state: 'running',
      started: Int64(
        fixtureNow.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
      ),
    ),
  ),
  Item(
    id: 'x1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'x',
    toolKind: 'read',
    title: 'Read internal/store/get.go',
    paths: ['internal/store/get.go'],
    status: 'completed',
  ),
  Item(
    id: 'x2',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'x',
    toolKind: 'edit',
    title: 'Edit report.md',
    paths: ['report.md'],
    diffs: [FileChange(path: 'report.md', newText: '# Callers\n\nNone.\n')],
    status: 'completed',
  ),
  Item(
    id: 'x3',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'x',
    toolKind: 'execute',
    title: 'make check',
    status: 'failed',
  ),
  Item(
    id: 'x4',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    parent: 'x',
    text: 'The check fails before my change too; going on.',
  ),
  Item(
    id: 'x5',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'x',
    toolKind: 'search',
    title: 'grep -rn "store.Get" internal/ cmd/ relay/',
    status: 'in_progress',
  ),
];

Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The run's title: its words, as wide as the row gives them.
Finder get _runTitle => find.descendant(
  of: find.byType(RunView),
  matching: find.textContaining('Read 1 file', findRichText: true),
);

void main() {
  setUpAll(loadFonts);
  setUp(Collapsible.opened.clear); // what a test opened stays open
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  for (final width in [264.0, 220.0]) {
    testWidgets("a subagent's pane at $width: its run keeps its title and "
        'its failed count', (tester) async {
      viewport(tester, const Size(1700, 1000));
      showDetails.value = false;
      paneWidths.value = {'subagent': width};
      final c = chat('c', 'claude', 'Callers of store.Get');
      final fake = FakeDaemon([c])
        ..answer = (input) => input is GetChatRequest
            ? GetChatResponse(chat: c, items: _items())
            : null;
      final d = await fake.connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await _pump(tester);
      await tester.tap(find.byType(SubagentLine));
      await _pump(tester);
      final pane = find.byType(SubagentPane);
      expect(pane, findsOne);
      final run = find.descendant(of: pane, matching: find.byType(RunView));
      final title = find.descendant(of: run, matching: _runTitle);
      expect(tester.getSize(title).width, greaterThan(40));
      final failed = find.descendant(of: run, matching: find.text('1 failed'));
      expect(failed, findsOne);
      expect(
        tester.getRect(failed).right,
        lessThanOrEqualTo(tester.getRect(run).right),
      );
      // Open, its rows; the edit's keeps its path, and its Preview once
      // it's open.
      await tester.tap(title);
      await _pump(tester);
      final edit = find.byWidgetPredicate(
        (w) => w is ToolCallView && w.item.id == 'x2',
      );
      final path = find.descendant(
        of: edit,
        matching: find.textContaining('report.md', findRichText: true),
      );
      expect(tester.getSize(path.first).width, greaterThan(60));
      await tester.tap(path.first);
      await _pump(tester);
      expect(
        find.descendant(of: edit, matching: find.byType(PreviewButton)),
        findsOne,
      );
      await render(tester, find.byType(NushiApp), 'narrow_rows_pane_$width');
      d.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  testWidgets('a run and its rows fit from a narrow pane up, with big '
      'counts and a failed one', (tester) async {
    viewport(tester, const Size(800, 600));
    // Many lines, so the counts are as wide as they get.
    final lines = List.filled(1200, 'x').join('\n');
    final calls = [
      for (final it in _items().where((i) => i.parent == 'x').take(3))
        if (it.toolKind == 'edit')
          it.deepCopy()
            ..diffs.first.newText = lines
            ..diffs.first.oldText = List.filled(345, 'y').join('\n')
        else
          it,
    ];
    final width = ValueNotifier(160.0);
    addTearDown(width.dispose);
    Collapsible.opened.addAll(['group x1', 'x2']);
    await tester.pumpWidget(
      themed(
        Previews(
          open: (_) {},
          child: ValueListenableBuilder(
            valueListenable: width,
            builder: (context, w, _) => Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: w,
                child: Column(children: [RunView(calls, still: true)]),
              ),
            ),
          ),
        ),
      ),
    );
    // A row too narrow overflows: the test fails on it.
    for (var w = 160.0; w <= 560; w += 10) {
      width.value = w;
      await tester.pump();
    }
    expect(find.text('1 failed'), findsOne);
  });
}
