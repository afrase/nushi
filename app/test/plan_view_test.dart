import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/plan_view.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Item _plan(List<(String, String)> steps) => Item(
  id: 'plan',
  kind: ItemKind.ITEM_KIND_PLAN,
  plan: [
    for (final (content, status) in steps)
      PlanEntry(content: content, status: status),
  ],
);

/// A chat whose running turn has [plan] as its plan.
ChatState _chat(Item plan) => ChatState('c', '/x')
  ..busy = true
  ..items.addAll([
    Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'tidy'),
    plan,
  ]);

Widget _app(Widget child, {Tokens tokens = Tokens.light, bool still = false}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Material(
          color: tokens.base,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    );

/// How far each drawn check is drawn, in the plan's order.
List<double> _checks(WidgetTester tester) => [
  for (final p in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (p.painter case final CheckPainter c) c.drawn,
];

bool _ringing(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((p) => p.painter is StatusMark && (p.painter! as StatusMark).ringing);

void main() {
  setUpAll(loadFonts);

  final running = _plan([
    ('Read the notes', 'completed'),
    ('Merging the duplicates', 'in_progress'),
    ('Write an index', 'pending'),
  ]);
  final merged = _plan([
    ('Read the notes', 'completed'),
    ('Merge the duplicates', 'completed'),
    ('Writing an index', 'in_progress'),
  ]);

  testWidgets('a step done while the chat is open draws its check once', (
    tester,
  ) async {
    final chat = _chat(running);
    await tester.pumpWidget(_app(PlanView(running, chat)));
    expect(_checks(tester), [1]); // what it opened with: still

    chat.items[1] = merged;
    await tester.pumpWidget(_app(PlanView(merged, chat)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    final drawing = _checks(tester);
    expect(drawing.first, 1);
    expect(drawing.last, inExclusiveRange(0, 1));
    expect(find.text('Plan · 2 of 3 done'), findsOneWidget); // at once

    await tester.pumpAndSettle();
    expect(_checks(tester), [1, 1]);
    expect(tester.binding.hasScheduledFrame, isFalse); // nothing at rest
  });

  testWidgets('a loaded plan shows still', (tester) async {
    await tester.pumpWidget(_app(PlanView(merged, _chat(merged))));
    expect(_checks(tester), [1, 1]);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_checks(tester), [1, 1]);
  });

  testWidgets('the running step shines only while the agent works on it', (
    tester,
  ) async {
    final chat = _chat(running);
    await tester.pumpWidget(_app(PlanView(running, chat)));
    expect(find.byType(ShaderMask), findsOneWidget);

    chat.listed(ChatStatus()); // the turn ended
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);

    // A later turn's plan is the turn's: this one stays still.
    chat
      ..items.add(Item(id: 'u2', kind: ItemKind.ITEM_KIND_USER_MESSAGE))
      ..listed(ChatStatus(busy: true));
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('with Reduce Motion only colors change', (tester) async {
    final chat = _chat(running);
    await tester.pumpWidget(_app(PlanView(running, chat), still: true));
    expect(find.byType(ShaderMask), findsNothing);
    expect(_ringing(tester), isFalse);

    chat.items[1] = merged;
    await tester.pumpWidget(_app(PlanView(merged, chat), still: true));
    expect(_checks(tester), [1, 1]); // whole at once
    await tester.pumpAndSettle();
  });

  testWidgets('the line over the box crossfades to the next step', (
    tester,
  ) async {
    await tester.pumpWidget(_app(PlanStatus(running)));
    expect(find.text('1/3'), findsOneWidget);

    await tester.pumpWidget(_app(PlanStatus(merged)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('2/3'), findsOneWidget); // the count at once
    expect(find.text('Merging the duplicates'), findsOneWidget);
    expect(find.text('Writing an index'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Merging the duplicates'), findsNothing);
    expect(find.text('Writing an index'), findsOneWidget);
  });

  for (final (name, tokens) in [
    ('light', Tokens.light),
    ('dark', Tokens.dark),
  ]) {
    testWidgets('plan view ($name)', (tester) async {
      viewport(tester, const Size(460, 300));
      final plan = _plan([
        ('Read the notes', 'completed'),
        ('Merging the duplicates', 'in_progress'),
        ('Write an index', 'pending'),
        (
          'Move every note that has no date into an archive folder, '
              'and say in the index where each one went',
          'pending',
        ),
        ('Run the link checker', 'pending'),
      ]);
      await tester.pumpWidget(
        _app(
          tokens: tokens,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [PlanView(plan, _chat(plan)), PlanStatus(plan)],
          ),
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/plan_view_$name.png'),
      );
    });
  }
}
