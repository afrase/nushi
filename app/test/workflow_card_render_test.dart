import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/workflow_card.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A chat with subagents and workflows, running and finished, rendered at
// full size to look at (#103, #106): never compared.

/// A tool call of a subagent's, under [parent].
Item _step(String id, String parent, String title) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'read',
  title: title,
  status: 'completed',
  parent: parent,
);

/// A subagent's call in [state], with [steps] tool calls of its own.
List<Item> _subagent(
  String id,
  String title,
  String state, {
  int steps = 0,
  int tokens = 0,
  int worked = 0,
}) => [
  Item(
    id: id,
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    title: title,
    status: state == 'running' ? 'in_progress' : 'completed',
    subagent: Subagent(
      state: state,
      started: msAgo(const Duration(minutes: 9)),
      ended: state == 'running' ? null : msAgo(const Duration(minutes: 1)),
      worked: Int64(worked),
      workingSince: state == 'running'
          ? msAgo(const Duration(seconds: 40))
          : null,
      tokens: Int64(tokens),
    ),
  ),
  for (var i = 0; i < steps; i++) _step('$id-$i', id, 'Read lib/part_$i.dart'),
];

/// A workflow's call: running in its second phase with two more planned,
/// or [ended].
Item _workflow(String id, {bool ended = false, int tokens = 0}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  tool: 'Workflow',
  title: 'Workflow',
  status: 'completed',
  text: 'Workflow launched in background.',
  workflow: Workflow(
    runId: 'wf_$id',
    name: ended ? 'tidy-guides' : 'audit-docs',
    description: ended
        ? 'Tidy the guide pages in two passes'
        : 'Check every guide page for stale steps, then fix them',
    state: ended ? 'done' : 'running',
    end: ended ? 'completed' : '',
    started: msAgo(Duration(minutes: ended ? 30 : 6, seconds: 12)),
    ended: ended ? msAgo(const Duration(minutes: 16)) : null,
    agents: ended ? 9 : 11,
    done: ended ? 9 : 7,
    phases: [
      WorkflowPhase(title: 'Survey', started: 3, done: 3),
      WorkflowPhase(title: 'Check', started: ended ? 4 : 8, done: 4),
      if (ended) WorkflowPhase(title: 'Fix', started: 2, done: 2),
    ],
    planned: ended
        ? null
        : [WorkflowPhase(title: 'Fix'), WorkflowPhase(title: 'Verify')],
    running: ended ? null : ['check:install', 'check:setup', 'check:themes'],
    runningPhases: ended ? null : [1, 1, 1],
    runningCount: ended ? 0 : 4,
    tokens: Int64(tokens),
  ),
);

List<Item> _items() => [
  userSays('u', 'Look over the guide pages and tidy what is stale.'),
  agentSays('m1', 'First a quick look at how the theme loads.'),
  ..._subagent(
    's1',
    'find the theme loader',
    'done',
    steps: 39,
    tokens: 182400,
    worked: 475000,
  ),
  ..._subagent('s2', 'list the guide pages', 'running', steps: 6),
  agentSays('m2', 'Now a workflow checks each page.'),
  _workflow('w1', tokens: 412300),
  agentSays('m3', 'An earlier pass, for comparison.'),
  _workflow('w2', ended: true, tokens: 96500),
  agentSays('m4', 'And one stopped before its last phase.'),
  _stopped('w3'),
];

/// A workflow stopped in its second phase: its third never reached, as
/// its snapshot lists it.
Item _stopped(String id) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  tool: 'Workflow',
  title: 'Workflow',
  status: 'completed',
  text: 'Workflow launched in background.',
  workflow: Workflow(
    runId: 'wf_$id',
    name: 'rename-pages',
    description: 'Rename the pages, then fix their links',
    state: 'stopped',
    end: 'killed',
    started: msAgo(const Duration(minutes: 12)),
    ended: msAgo(const Duration(minutes: 8)),
    agents: 5,
    done: 3,
    phases: [
      WorkflowPhase(title: 'Rename', started: 3, done: 3),
      WorkflowPhase(title: 'Links', started: 2),
      WorkflowPhase(title: 'Check'),
    ],
    tokens: Int64(40100),
  ),
);

Future<void> _window(
  WidgetTester tester,
  Size size,
  Brightness brightness,
  String name,
) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Tidy the guides');
  final fake = FakeDaemon([c])..chatItems['c'] = _items();
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await frames(tester, 5, const Duration(milliseconds: 100));
  expectTextInside(tester, size.width);
  await render(tester, find.byType(NushiApp), '$name-collapsed');
  // Opened in place by their chevrons (#103), which stay put on their
  // card (the transcript, held at its end, may scroll as a card grows).
  final cards = find.byType(WorkflowCard);
  for (var i = 0; i < 3; i++) {
    final chevron = find.descendant(
      of: cards.at(i),
      matching: find.byTooltip('Show its phases'),
    );
    final at = tester.getRect(chevron).shift(-tester.getTopLeft(cards.at(i)));
    await tester.tap(chevron);
    await frames(tester, 5, const Duration(milliseconds: 100));
    final open = find.descendant(
      of: cards.at(i),
      matching: find.byTooltip('Hide its phases'),
    );
    expect(tester.getRect(open).shift(-tester.getTopLeft(cards.at(i))), at);
  }
  expect(find.text('check:install, check:setup, check:themes'), findsOne);
  expectTextInside(tester, size.width);
  await render(tester, find.byType(NushiApp), '$name-expanded');
  await tester.pumpWidget(const SizedBox());
  d.dispose();
}

/// The phone's chat at [size], its cards as the Mac's, as far as they fit:
/// no pane to open, so no pane chevron and no Stop; a tap opens a card in
/// place.
Future<void> _phone(
  WidgetTester tester,
  Size size,
  Brightness brightness,
  String name,
) async {
  viewport(tester, size, ratio: 3, brightness: brightness);
  final c = chat('c', 'claude', 'Tidy the guides');
  final fake = FakeDaemon([c])..chatItems['c'] = _items();
  final phone = await startPhone(tester, fake);
  await tester.tap(find.text('Tidy the guides'));
  await frames(tester, 10, const Duration(milliseconds: 100));
  final cards = find.byType(WorkflowCard);
  expect(cards, findsNWidgets(3));
  final pane = find.descendant(
    of: cards,
    matching: find.byIcon(Icons.chevron_right),
  );
  // The chevrons that open it in place, at rest, are its only ones.
  expect(pane, findsNWidgets(3));
  expect(find.byTooltip('Stop'), findsNothing);
  expect(find.textContaining('412k tokens'), findsOne);
  expectTextInside(tester, size.width);
  await render(tester, find.byType(PhoneApp), '$name-collapsed');
  for (var i = 0; i < 3; i++) {
    await tester.ensureVisible(cards.at(i));
    await tester.tap(cards.at(i), warnIfMissed: false);
    await frames(tester, 5, const Duration(milliseconds: 100));
  }
  expect(find.text('Tidy the guide pages in two passes'), findsOne);
  expectTextInside(tester, size.width);
  await render(tester, find.byType(PhoneApp), '$name-expanded');
  await endPhone(tester, phone);
}

void main() {
  setUpAll(loadFonts);
  setUp(() => Shine.stopAt = 0.3);
  tearDown(() => Shine.stopAt = null);

  for (final (size, label) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(720, 1000), 'narrow'),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('subagents and workflows, $label, ${brightness.name}', (
        tester,
      ) async {
        await _window(
          tester,
          size,
          brightness,
          'workflow-card-$label-${brightness.name}',
        );
      }, variant: onMac);
    }
  }
  for (final (size, label) in [
    (const Size(390, 844), 'phone-390'),
    (const Size(430, 932), 'phone-430'),
    (const Size(844, 390), 'phone-landscape'),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('on the phone, $label, ${brightness.name}', (tester) async {
        await _phone(
          tester,
          size,
          brightness,
          'workflow-card-$label-${brightness.name}',
        );
      });
    }
  }
}
