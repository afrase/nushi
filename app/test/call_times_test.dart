import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/call_times.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/live_text.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/status.dart';
import 'package:nushi/subagents.dart' hide LiveText;
import 'package:nushi/theme/tokens.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// [fixtureNow] less [s] seconds, as the daemon sends a time.
Int64 _ago(num s) => msAgo(Duration(milliseconds: (s * 1000).round()));

/// A command run [from] seconds ago that ended [to] seconds ago (running
/// while [to] is null).
Item _call(String id, String title, num from, num? to) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'execute',
  title: title,
  status: to == null ? 'in_progress' : 'completed',
  started: _ago(from),
  ended: to == null ? null : _ago(to),
);

/// A transcript with a call of under a second, one of 12 seconds, a run of
/// three, a subagent that worked 3m 12s with its tokens, and a call that
/// runs.
List<Item> _items() => [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Tidy the store package and check it.',
  ),
  Item(
    id: 'r',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'read',
    title: 'Read internal/store/store.go',
    paths: ['internal/store/store.go'],
    status: 'completed',
    started: _ago(600),
    ended: _ago(599.6),
  ),
  agentSays('m1', 'The tests first.'),
  _call('t', 'go test ./internal/store/...', 590, 578),
  agentSays('m2', 'Now the lint, the vet and the build.'),
  _call('g1', 'make lint', 570, 540),
  _call('g2', 'go vet ./...', 538, 530),
  _call('g3', 'go build ./cmd/nushid', 528, 506),
  agentSays('m3', 'An agent looks for the callers.'),
  Item(
    id: 'x',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    title: 'Find every caller of store.Get',
    status: 'completed',
    subagent: Subagent(
      state: 'done',
      started: _ago(500),
      ended: _ago(200),
      worked: Int64(192500),
      tokens: Int64(48120),
    ),
  ),
  agentSays('m4', 'And the whole suite, with a long name to see it give way.'),
  _call(
    'c',
    'go test -race -count=1 ./internal/features/chats/... ./internal/e2e/...',
    12,
    null,
  ),
];

/// Renders the transcript at [size] in [brightness] as [name].
Future<void> _window(
  WidgetTester tester,
  Size size,
  Brightness brightness,
  String name,
) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Tidy the store package');
  final fake = FakeDaemon([c])..chatItems['c'] = _items();
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await frames(tester, 5, const Duration(milliseconds: 100));
  expect(find.text('12s'), findsWidgets); // the run's and the running call's
  expect(find.text('1m 04s'), findsOne); // the run's span
  expect(
    find.textContaining('48.1k tokens, 3m 12s', findRichText: true),
    findsOne,
  );
  expectTextInside(tester, size.width);
  await render(tester, find.byType(NushiApp), name);
  await tester.pumpWidget(const SizedBox());
  d.dispose();
}

void main() {
  setUpAll(loadFonts);

  test('times read as a row shows them', () {
    expect(elapsed(const Duration(seconds: 12)), '12s');
    expect(elapsed(const Duration(seconds: 64)), '1m 04s');
    expect(tokenCount(950), '950 tokens');
    expect(tokenCount(12400), '12.4k tokens');
    expect(tokenCount(48000), '48k tokens');
    expect(tokenCount(1000000), '1M tokens');
    expect(tokenCount(9400), '9.4k tokens');
    expect(tokenCount(1240000), '1.2M tokens');
    // Under a second, replayed (no times), or never ended: nothing.
    expect(runTime([_call('a', 'ls', 1, 0.4)]), isNull);
    expect(runTime([Item(status: 'completed')]), isNull);
    expect(runTime([Item(status: 'failed', started: _ago(5))]), isNull);
    expect(runTime([_call('a', 'ls', 72, 8)]), const Duration(seconds: 64));
    // Running, to now; its turn's end stops it.
    expect(runTime([_call('a', 'ls', 12, null)]), const Duration(seconds: 12));
    expect(
      runTime([_call('a', 'ls', 12, null)..ended = _ago(2)]),
      const Duration(seconds: 10),
    );
  });

  test("a run's time is its first call's start to its last's end", () {
    final run = [
      _call('a', 'one', 60, 50),
      Item(id: 'b', status: 'completed'), // replayed: left out
      _call('c', 'two', 40, 4),
    ];
    expect(runTime(run), const Duration(seconds: 56));
    expect(
      runTime([...run, _call('d', 'three', 3, null)]),
      const Duration(seconds: 60),
    );
    expect(runTime([Item(id: 'b', status: 'completed')]), isNull);
  });

  testWidgets('a running call ticks on the one clock; one ended stops', (
    tester,
  ) async {
    var now = fixtureNow;
    clock = () => now;
    final calls = ValueNotifier([_call('c', 'sleep 30', 12, null)]);
    addTearDown(calls.dispose);
    await tester.pumpWidget(
      themed(
        ValueListenableBuilder(
          valueListenable: calls,
          builder: (context, c, _) => Column(
            children: [
              ToolCallView(c.single),
              RunView([...c, c.single]),
            ],
          ),
        ),
      ),
    );
    expect(find.text('12s'), findsNWidgets(2));
    expect(secondClock.ticking, isTrue);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('13s'), findsNWidgets(2));
    calls.value = [
      calls.value.single.deepCopy()
        ..status = 'completed'
        ..ended = Int64(now.millisecondsSinceEpoch),
    ];
    await tester.pump();
    expect(secondClock.ticking, isFalse);
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('13s'), findsNWidgets(2));
  });

  testWidgets('a live time scrolled out of view waits', (tester) async {
    viewport(tester, const Size(400, 300));
    var built = 0;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: [
              LiveText(
                () => '${++built}',
                live: true,
                style: const TextStyle(),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(built, 2);
    scroll.jumpTo(1000);
    await tester.pump();
    final hidden = built;
    await frames(tester, 4, const Duration(seconds: 1));
    expect(built, hidden);
    scroll.jumpTo(0);
    await tester.pump(const Duration(seconds: 1));
    expect(built, hidden + 1);
  });

  testWidgets('narrow, the title gives way and the time stays at the end', (
    tester,
  ) async {
    viewport(tester, const Size(800, 400));
    final width = ValueNotifier(266.0);
    addTearDown(width.dispose);
    final long = _call('c', 'go test -race ./internal/features/...', 64, null);
    final run = [_call('a', 'make lint', 90, 70), long];
    final sub = subagentsOf(_items()).single;
    for (final tokens in [Tokens.dark, Tokens.light]) {
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          ValueListenableBuilder(
            valueListenable: width,
            builder: (context, w, _) => Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: w,
                child: Column(
                  children: [
                    ToolCallView(long),
                    RunView(run),
                    // Narrower than a chat gets, its line has no room.
                    if (w >= 200)
                      SubagentLine(sub, ChatState('c', '/x'), still: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // A row that overflows fails the test.
      for (var w = 266.0; w >= 120; w -= 2) {
        width.value = w;
        await tester.pump();
        final row = tester.getRect(find.byType(ToolCallView));
        final time = find.descendant(
          of: find.byType(ToolCallView),
          matching: find.text('1m 04s'),
        );
        // The subagent's line keeps its time and tokens before its words.
        if (w >= 200) {
          expect(
            find.textContaining('3m 12s', findRichText: true),
            findsOne,
            reason: 'at $w',
          );
          expect(time, findsOne, reason: 'at $w');
          expect(tester.getRect(time).right, closeTo(row.right - 12, 12));
          expect(tester.getSize(time).width, lessThan(callTimeRoom));
        }
      }
      width.value = 266;
      await tester.pump();
    }
  });

  testWidgets("a narrow subagent line never cuts its state to a bare '…'", (
    tester,
  ) async {
    viewport(tester, const Size(800, 400));
    // A stopped one keeps its word; a done one has none (its check).
    final done = subagentsOf(_items()).single;
    expect(subagentStatesNarrow(done), ['48.1k tokens, 3m 12s', '3m 12s']);
    final sub = (
      call: done.call.deepCopy()..subagent.state = 'stopped',
      items: done.items,
    );
    final states = subagentStatesNarrow(sub);
    expect(states, [
      'stopped, 48.1k tokens, 3m 12s',
      '48.1k tokens, 3m 12s',
      '3m 12s',
    ]);
    final width = ValueNotifier(419.0);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      themed(
        ValueListenableBuilder(
          valueListenable: width,
          builder: (context, w, _) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: w,
              child: SubagentLine(sub, ChatState('c', '/x'), still: true),
            ),
          ),
        ),
      ),
    );
    final seen = <String>{};
    // The word goes whole: in the room a third of the line gives, never
    // "stopped, 48.1k tokens, 3m 1…".
    for (var w = 419.0; w >= 200; w -= 1) {
      width.value = w;
      await tester.pump();
      final state = find.descendant(
        of: find.byType(SubagentState),
        matching: find.byType(Text),
      );
      final text = tester.widget<Text>(state).data!;
      final cut = tester
          .renderObject<RenderParagraph>(
            find.descendant(of: state, matching: find.byType(RichText)),
          )
          .didExceedMaxLines;
      expect(states, contains(text), reason: 'at $w');
      expect(cut, isFalse, reason: '"$text" cut at $w');
      // Down to a chat's least (a side pane open), its tokens and time.
      if (w >= 276) expect(text, contains('48.1k tokens'), reason: 'at $w');
      seen.add(text);
    }
    expect(seen, contains('3m 12s')); // narrower still, the time alone
    // Wide, the whole of it, one way as narrow (issue 119).
    width.value = 600;
    await tester.pump();
    expect(find.text('stopped, 48.1k tokens, 3m 12s'), findsOne);
  });

  for (final (size, label) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(720, 1000), 'narrow'),
  ]) {
    for (final brightness in renderThemes) {
      testWidgets('the times in a transcript, $label, ${brightness.name}', (
        tester,
      ) async {
        await _window(
          tester,
          size,
          brightness,
          'call_times_${label}_${brightness.name}',
        );
      }, variant: onMac);
    }
  }
}
