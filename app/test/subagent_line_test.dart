import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A failed subagent that made two tool calls, read 48.1k tokens and
/// worked 3m 12s.
SubagentRun _failed() => (
  call: Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    title: 'Find every caller of the parcel map',
    status: 'failed',
    subagent: Subagent(
      state: 'failed',
      worked: Int64(192500),
      tokens: Int64(48120),
    ),
  ),
  items: [
    for (final id in ['s1', 's2'])
      Item(
        id: id,
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        title: 'Read parcel.go',
        status: 'completed',
      ),
  ],
);

void main() {
  setUpAll(loadFonts);

  // Issue 119: one way wide as narrow, as the workflow's card says it:
  // the state's words, then its tokens and time, joined by commas.
  testWidgets('a subagent row says its parts one way, wide as narrow', (
    tester,
  ) async {
    Future<List<String>> shown(double width) async {
      await tester.pumpWidget(
        themed(
          SizedBox(
            width: width,
            child: SubagentLine(_failed(), ChatState('c', '/x'), still: true),
          ),
        ),
      );
      return [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          t.data ?? t.textSpan?.toPlainText() ?? '',
      ];
    }

    // Wide, the whole of it in one text.
    expect(await shown(900), contains('failed, 2 tools, 48.1k tokens, 3m 12s'));
    // Narrow, the fullest that fits, the same way: its time and tokens
    // last, never apart.
    final narrow = await shown(380);
    expect(narrow.where(subagentStatesNarrow(_failed()).contains), [
      '48.1k tokens, 3m 12s',
    ], reason: '$narrow');
    await tester.pumpWidget(const SizedBox());
  });

  for (final b in Brightness.values) {
    testWidgets('golden: a subagent row, wide (${b.name})', (tester) async {
      viewport(tester, const Size(760, 80));
      await tester.pumpWidget(
        themed(
          Padding(
            padding: const EdgeInsets.all(16),
            child: SubagentLine(_failed(), ChatState('c', '/x'), still: true),
          ),
          tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
          still: true,
          banner: false,
        ),
      );
      await expectLater(
        find.byType(SubagentLine),
        matchesGoldenFile('goldens/subagent_row_wide_${b.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a subagent line keeps its state at the end, by its mark', (
    tester,
  ) async {
    final run = (
      call: Item(
        id: 'a',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        agent: 'general-purpose',
        title: 'Verify the steps',
        status: 'completed',
        subagent: Subagent(state: 'done', tokens: Int64(182400)),
      ),
      items: <Item>[],
    );
    await tester.pumpWidget(
      themed(SubagentLine(run, ChatState('c', '/x'), still: true)),
    );
    // Done says no word: its check does (#106).
    expect(find.textContaining('done'), findsNothing);
    final state = tester.getRect(find.text('182k tokens'));
    final chevron = tester.getRect(find.byIcon(paneIcon));
    // The state, its mark (a check) and the chevron end the line, not its
    // middle.
    expect(chevron.left - state.right, lessThan(40));
    final line = tester.getRect(find.byType(SubagentLine));
    expect(chevron.right, greaterThan(line.right - 20));
  });

  testWidgets('a running subagent whose start isn’t known ends its words '
      'with no dot', (tester) async {
    final run = (
      call: Item(
        id: 'a',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        agent: 'general-purpose',
        title: 'Verify the steps',
        status: 'in_progress',
        subagent: Subagent(state: 'running'),
      ),
      items: <Item>[],
    );
    await tester.pumpWidget(
      themed(
        SizedBox(width: 900, child: SubagentLine(run, ChatState('c', '/x'))),
      ),
    );
    expect(subagentTime(run), '');
    final texts = [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        t.data ?? t.textSpan?.toPlainText() ?? '',
    ];
    expect(texts.where((t) => t.contains('·')), isEmpty, reason: '$texts');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a live line ticks each second; one done no longer does', (
    tester,
  ) async {
    var built = 0;
    Widget line({required bool live}) => Directionality(
      textDirection: TextDirection.ltr,
      child: LiveText(() => '${++built}', live: live, style: const TextStyle()),
    );
    await tester.pumpWidget(line(live: true));
    await frames(tester, 2, const Duration(seconds: 1));
    expect(built, 3);
    await tester.pumpWidget(line(live: false));
    final done = built;
    await frames(tester, 5, const Duration(seconds: 1));
    expect(built, done);
    await tester.pumpWidget(line(live: true)); // live again: ticks again
    await tester.pump(const Duration(seconds: 1));
    expect(built, done + 2);
  });
}
