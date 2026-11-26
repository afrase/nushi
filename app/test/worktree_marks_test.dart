import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/status.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The mark at a Worktrees row's end, for a subagent's worktree and a
// workflow's (ADR 0081): one TaskMark, the running dot while its subagent
// or run runs and isn't stalled, its state otherwise. A workflow's row is
// the latest loaded Workflow item of its run id's, whose name is the
// tooltip's second line. Made-up runs and worktrees.

const _repo = '/Users/me/acme';

RelatedWorktree _worktree(String branch, String call, {String run = ''}) =>
    RelatedWorktree(
      path: '$_repo/.claude/worktrees/$branch',
      branch: branch,
      baseCommit: 'b' * 40,
      lastHead: 'c' * 40,
      callId: call,
      state: 'present',
      runId: run,
    );

/// A Workflow call [id] of run [run], named [name], in [state]. A
/// running one has no time: it would count from the real clock.
Item _workflow(
  String id,
  String run,
  String name,
  String state, {
  bool stalled = false,
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'other',
  title: 'Workflow',
  tool: 'Workflow',
  status: 'completed',
  workflow: Workflow(runId: run, name: name, state: state, stalled: stalled),
);

/// An Agent call [id] whose subagent is in [state].
Item _subagent(String id, String state) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  agent: 'general-purpose',
  title: 'Write the docs',
  status: state == 'running' ? 'in_progress' : 'completed',
  subagent: Subagent(state: state),
);

/// The rows the golden and renders show: a subagent's, running; a
/// finished workflow's; a running workflow's.
final List<RelatedWorktree> _three = [
  _worktree('docs-pass', 'a'),
  _worktree('export-csv', 'wf1', run: 'run-7a'),
  _worktree('worktree-run-9c-1', 'wf2', run: 'run-9c'),
];

final List<Item> _threeItems = [
  _subagent('a', 'running'),
  _workflow('wf1', 'run-7a', 'Export the reports', 'done'),
  _workflow('wf2', 'run-9c', 'Parser rewrite', 'running'),
];

/// The fake daemon of the last [_app], for its events.
late FakeDaemon _fake;

/// The app at [size] on a chat whose transcript is [items] (after a user
/// message), [running] before its page, and whose related worktrees are
/// [list], the details panel shown and its widgets open.
Future<Daemon> _app(
  WidgetTester tester,
  List<Item> items,
  List<RelatedWorktree> list, {
  List<Item> running = const [],
  Size size = const Size(1700, 900),
  Brightness brightness = Brightness.dark,
}) async {
  showDetails.value = true;
  collapsedWidgets.value = {};
  widgetOrder.value = [];
  final fake = _fake =
      FakeDaemon([chat('c', 'claude', 'Split the work', folder: _repo)])
        ..answer = (input) => switch (input) {
          GetChatRequest() => GetChatResponse(
            items: [userSays('u', 'Split the work among subagents.'), ...items],
            running: running,
          ),
          GetRelatedWorktreesRequest() => GetRelatedWorktreesResponse(
            worktrees: list,
          ),
          GetRelatedWorktreeStatsRequest(:final paths) =>
            GetRelatedWorktreeStatsResponse(
              stats: [
                for (final p in paths)
                  RelatedWorktreeStats(
                    path: p,
                    files: 3,
                    added: 42,
                    removed: 7,
                    ahead: 2,
                  ),
              ],
            ),
          _ => null,
        };
  return await openApp(tester, fake, size: size, brightness: brightness);
}

/// The Worktrees widget on screen.
Finder get _widget => find.ancestor(
  of: find.text('Worktrees'),
  matching: find.byType(PanelWidget),
);

/// [branch]'s row in the widget.
Finder _row(String branch) => find
    .ancestor(
      of: find.descendant(of: _widget, matching: find.text(branch)),
      matching: find.byType(Column),
    )
    .first;

/// The running dot on [branch]'s row.
Finder _dot(String branch) =>
    find.descendant(of: _row(branch), matching: find.byType(RunningDot));

/// The state of the TaskMark on [branch]'s row, null for none.
String? _mark(WidgetTester tester, String branch) {
  final f = find.descendant(of: _row(branch), matching: find.byType(TaskMark));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<TaskMark>(f).state;
}

/// How far the check on [branch]'s row is drawn, null for none.
double? _drawn(WidgetTester tester, String branch) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: _row(branch), matching: find.byType(CustomPaint)),
    )
    .map((p) => p.painter)
    .whereType<CheckPainter>()
    .firstOrNull
    ?.drawn;

/// The daemon says [it], the chat's item at [index] (1 is the first after
/// the user's message).
Future<void> _itemIs(WidgetTester tester, Item it, int index, int seq) async {
  _fake.emit(
    EventsResponse(
      chatId: 'c',
      seq: Int64(seq),
      item: ItemEvent(item: it, index: index),
    ),
  );
  await tester.pump();
}

String _path(String branch) => '$_repo/.claude/worktrees/$branch';

void main() {
  setUpAll(loadFonts);

  testWidgets('a finished run shows its check, and its name under the '
      "folder's path", (tester) async {
    final d = await _app(tester, [_threeItems[1]], [_three[1]]);
    expect(_mark(tester, 'export-csv'), 'done');
    expect(_dot('export-csv'), findsNothing);
    expect(
      find.byTooltip('${_path('export-csv')}\nExport the reports'),
      findsOne,
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a failed run shows its failure, a stopped one its stop', (
    tester,
  ) async {
    for (final state in ['failed', 'stopped']) {
      final d = await _app(
        tester,
        [_workflow('wf1', 'run-7a', 'Export the reports', state)],
        [_three[1]],
      );
      expect(_mark(tester, 'export-csv'), state, reason: state);
      expect(_dot('export-csv'), findsNothing, reason: state);
      await closeView(tester, d);
    }
  }, variant: onMac);

  testWidgets('a running run shows the running dot; a stalled one has no '
      'dot', (tester) async {
    var d = await _app(tester, [_threeItems[2]], [_three[2]]);
    expect(_dot('worktree-run-9c-1'), findsOne);
    expect(_mark(tester, 'worktree-run-9c-1'), 'running'); // its dot
    await closeView(tester, d);
    d = await _app(
      tester,
      [_workflow('wf2', 'run-9c', 'Parser rewrite', 'running', stalled: true)],
      [_three[2]],
    );
    expect(_dot('worktree-run-9c-1'), findsNothing);
    expect(_mark(tester, 'worktree-run-9c-1'), 'running'); // its blank
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a running subagent's row shows the running dot, a finished "
      "one's its check", (tester) async {
    var d = await _app(tester, [_subagent('a', 'running')], [_three[0]]);
    expect(_dot('docs-pass'), findsOne);
    expect(_mark(tester, 'docs-pass'), 'running'); // its dot
    // A subagent's tooltip is its path alone.
    expect(find.byTooltip(_path('docs-pass')), findsOne);
    await closeView(tester, d);
    d = await _app(tester, [_subagent('a', 'done')], [_three[0]]);
    expect(_dot('docs-pass'), findsNothing);
    expect(_mark(tester, 'docs-pass'), 'done');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a subagent that ends while its row shows: the dot turns into '
      'a check that draws itself, whole at once with Reduce Motion', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    for (final still in [false, true]) {
      if (still) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
      }
      final d = await _app(tester, [_subagent('a', 'running')], [_three[0]]);
      expect(_drawn(tester, 'docs-pass'), isNull);
      await _itemIs(tester, _subagent('a', 'done'), 1, 1);
      await tester.pump(); // the item reaches the row
      expect(_mark(tester, 'docs-pass'), 'done');
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _drawn(tester, 'docs-pass'),
        still ? 1 : inExclusiveRange(0, 1),
        reason: still ? 'Reduce Motion' : 'drawing',
      );
      await tester.pumpAndSettle();
      expect(_drawn(tester, 'docs-pass'), 1);
      await closeView(tester, d);
    }
  }, variant: onMac);

  testWidgets("a removed worktree's row shows nothing live while its run "
      'or subagent still runs, and its end once it ends', (tester) async {
    final gone = [
      _worktree('docs-pass', 'a')..state = 'removed',
      _worktree('worktree-run-9c-1', 'wf2', run: 'run-9c')..state = 'removed',
    ];
    final d = await _app(tester, [_threeItems[0], _threeItems[2]], gone);
    await tester.tap(find.text('2 removed'));
    await tester.pumpAndSettle();
    for (final branch in ['docs-pass', 'worktree-run-9c-1']) {
      expect(_dot(branch), findsNothing, reason: branch);
      expect(_mark(tester, branch), 'running', reason: '$branch, its blank');
    }
    await _itemIs(tester, _subagent('a', 'done'), 1, 1);
    await _itemIs(
      tester,
      _workflow('wf2', 'run-9c', 'Parser rewrite', 'failed'),
      2,
      2,
    );
    await tester.pumpAndSettle();
    expect(_mark(tester, 'docs-pass'), 'done');
    expect(_mark(tester, 'worktree-run-9c-1'), 'failed');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the mark's place is kept: the branch's box is as wide with "
      'its item loaded or not, running, stalled or ended', (tester) async {
    double width(String branch) => tester
        .getSize(find.descendant(of: _widget, matching: find.text(branch)))
        .width;
    final widths = <String, double>{};
    for (final (name, items) in [
      ('not loaded', <Item>[]),
      ('running', [_threeItems[2]]),
      (
        'stalled',
        [
          _workflow(
            'wf2',
            'run-9c',
            'Parser rewrite',
            'running',
            stalled: true,
          ),
        ],
      ),
      ('done', [_workflow('wf2', 'run-9c', 'Parser rewrite', 'done')]),
    ]) {
      final d = await _app(tester, items, [_three[2]]);
      widths[name] = width('worktree-run-9c-1');
      await closeView(tester, d);
    }
    expect(widths.values.toSet(), hasLength(1), reason: '$widths');
    // A subagent's too.
    for (final (name, items) in [
      ('not loaded', <Item>[]),
      ('running', [_subagent('a', 'running')]),
    ]) {
      final d = await _app(tester, items, [_three[0]]);
      widths['subagent $name'] = width('docs-pass');
      await closeView(tester, d);
    }
    expect(widths['subagent not loaded'], widths['subagent running']);
  }, variant: onMac);

  testWidgets('a resumed run: the mark and the name follow the latest '
      'Workflow item of its run id, not the call that has it', (tester) async {
    final d = await _app(
      tester,
      [
        _workflow('wf1', 'run-7a', 'Export the reports', 'stopped'),
        agentSays('s', 'Resuming the export.'),
        _workflow('wf3', 'run-7a', 'Export the reports again', 'running'),
      ],
      [_three[1]], // its call is wf1, the stopped launch
    );
    expect(_dot('export-csv'), findsOne);
    expect(_mark(tester, 'export-csv'), 'running'); // its dot
    expect(
      find.byTooltip('${_path('export-csv')}\nExport the reports again'),
      findsOne,
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a resumed run whose launch is not loaded is still found by '
      'its run id', (tester) async {
    final d = await _app(
      tester,
      [_workflow('wf3', 'run-7a', 'Export the reports', 'done')],
      [_three[1]], // its call, wf1, is further back
    );
    expect(_mark(tester, 'export-csv'), 'done');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a run running before the loaded page is found among the '
      'running items', (tester) async {
    final d = await _app(
      tester,
      [agentSays('s', 'The run goes on.')],
      [_three[2]],
      running: [_threeItems[2]],
    );
    expect(_dot('worktree-run-9c-1'), findsOne);
    expect(
      find.byTooltip('${_path('worktree-run-9c-1')}\nParser rewrite'),
      findsOne,
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('no loaded item of its run: an empty mark, and the path alone', (
    tester,
  ) async {
    final d = await _app(
      tester,
      [_workflow('wf9', 'run-other', 'Another run', 'done')],
      [_three[1]],
    );
    expect(_dot('export-csv'), findsNothing);
    expect(_mark(tester, 'export-csv'), ''); // its place, empty
    expect(find.byTooltip(_path('export-csv')), findsOne);
    await closeView(tester, d);
  }, variant: onMac);

  // The widget with a subagent's running row, a finished run's and a
  // running run's is its golden.
  for (final brightness in Brightness.values) {
    testWidgets('golden: a subagent and two runs, ${brightness.name}', (
      tester,
    ) async {
      final d = await _app(tester, _threeItems, _three, brightness: brightness);
      await expectLater(
        _widget,
        matchesGoldenFile(
          'goldens/worktrees_widget_runs_${brightness.name}.png',
        ),
      );
      await closeView(tester, d);
    }, variant: onMac);
  }

  // Every state a row's mark has, at 1700 and 1080 wide: a run running,
  // done, failed and stalled, a subagent running and done, and a removed
  // worktree whose run still runs; the folds opened.
  for (final width in [1700.0, 1080.0]) {
    for (final brightness in renderThemes) {
      renderTest('every mark, ${width.toInt()} wide, ${brightness.name}', (
        tester,
      ) async {
        final d = await _app(
          tester,
          [
            _subagent('a', 'running'),
            _subagent('b', 'done'),
            _workflow('wf1', 'run-7a', 'Export the reports', 'done'),
            _workflow('wf2', 'run-9c', 'Parser rewrite', 'running'),
            _workflow('wf4', 'run-4f', 'Migrate the store', 'failed'),
            _workflow(
              'wf5',
              'run-5s',
              'Audit the docs',
              'running',
              stalled: true,
            ),
            _workflow('wf6', 'run-6g', 'Merge the parts', 'running'),
          ],
          [
            _worktree('docs-running', 'a'),
            _worktree('docs-done', 'b'),
            _worktree('run-done', 'wf1', run: 'run-7a'),
            _worktree('run-running', 'wf2', run: 'run-9c'),
            _worktree('run-failed', 'wf4', run: 'run-4f'),
            _worktree('run-stalled', 'wf5', run: 'run-5s'),
            _worktree('gone-run-running', 'wf6', run: 'run-6g')
              ..state = 'removed',
          ],
          size: Size(width, 1000),
          brightness: brightness,
        );
        await tester.tap(find.text('1 more'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1 removed'));
        await tester.pumpAndSettle();
        expect(_dot('gone-run-running'), findsNothing);
        expect(_dot('run-stalled'), findsNothing);
        expect(_dot('run-running'), findsOne);
        expectTextInside(tester, width);
        final name = 'worktree_every_mark_${width.toInt()}_${brightness.name}';
        await render(tester, find.byType(NushiApp), name);
        await render(tester, _widget, '${name}_widget');
        await closeView(tester, d);
      }, variant: onMac);
    }
  }

  // The window about 1700 wide, 1080, the narrowest that shows the panel
  // (ADR 0092), and 720 wide, where it can't show (ADR 0123).
  for (final width in [1700.0, 1080.0, 720.0]) {
    for (final brightness in renderThemes) {
      renderTest('worktree marks, ${width.toInt()} wide, ${brightness.name}', (
        tester,
      ) async {
        final d = await _app(
          tester,
          _threeItems,
          _three,
          size: Size(width, 900),
          brightness: brightness,
        );
        final shown = width >= 1080;
        expect(find.byType(DetailsPanel), shown ? findsOne : findsNothing);
        if (shown) expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'worktree_marks_${width.toInt()}_${brightness.name}',
        );
        if (shown) {
          // The finished run's tooltip: its folder, then its name.
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(
            location: tester.getCenter(_row('export-csv')),
          );
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(seconds: 1)); // faded in
          expect(
            find.textContaining('worktrees/export-csv\nExport the reports'),
            findsOne,
          );
          await render(
            tester,
            find.byType(NushiApp),
            'worktree_marks_${width.toInt()}_${brightness.name}_tooltip',
          );
          await mouse.removePointer();
        }
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
