import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/grow.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/turn_status.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The composer and the lines around it grow and fold, not jump (the
// fluidity review's idea 3); the text field itself never animates.

Future<(Daemon, ChatState)> _box(WidgetTester tester) async {
  final d = await FakeDaemon([]).connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true;
  d.chats['c'] = chat;
  await tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 640,
          child: ListenableBuilder(
            listenable: chat,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TurnStatus(chat),
                Composer(chat: chat, daemon: d),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (d, chat);
}

double _height(WidgetTester tester, Finder f) => tester.getSize(f).height;

/// What shows of each GrowLine, by height.
List<double> _lines(WidgetTester tester) => [
  for (final e in find.byType(GrowLine).evaluate())
    (e.renderObject! as RenderBox).size.height,
];

void main() {
  testWidgets('the turn line grows in as a turn starts', (tester) async {
    final (d, chat) = await _box(tester);
    expect(_height(tester, find.byType(TurnStatus)), 0);
    chat
      ..busy = true
      ..started = clock()
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _height(tester, find.byType(TurnStatus));
    await tester.pump(TurnStatus.foldFor);
    final full = _height(tester, find.byType(TurnStatus));
    expect(mid, inExclusiveRange(0, full));
    expect(full, greaterThan(15));
    chat
      ..busy = false
      ..started = null
      ..notifyListeners();
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('with Reduce Motion the turn line and the lines over the box '
      'are there at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final (d, chat) = await _box(tester);
    chat
      ..busy = true
      ..started = clock()
      ..error = 'The agent stopped.'
      ..queue = [QueuedMessage(id: 'q1', text: 'Then docs')]
      ..notifyListeners();
    await tester.pump();
    expect(_height(tester, find.byType(TurnStatus)), greaterThan(15));
    expect(find.text('The agent stopped.'), findsOneWidget);
    expect(find.text('Then docs'), findsOneWidget);
    final shown = _lines(tester);
    await tester.pump(Motion.standard);
    expect(_lines(tester), shown); // nothing moved after
    // And they go at once.
    chat
      ..error = ''
      ..queue = []
      ..notifyListeners();
    await tester.pump();
    expect(find.text('The agent stopped.'), findsNothing);
    expect(find.text('Then docs'), findsNothing);
    chat
      ..busy = false
      ..started = null
      ..notifyListeners();
    await tester.pumpAndSettle();
    await closeView(tester, d);
  });

  testWidgets('a line over the box grows in and folds away; typing goes on '
      'meanwhile', (tester) async {
    final (d, chat) = await _box(tester);
    final before = _lines(tester);
    expect(before.every((h) => h == 0), isTrue);
    chat
      ..error = 'The agent stopped.'
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final growing = _lines(tester).reduce((a, b) => a + b);
    // The box takes text mid-way.
    await tester.enterText(find.byType(TextField), 'Again');
    await tester.pump();
    expect(find.text('Again'), findsOneWidget);
    await tester.pump(Motion.standard);
    final full = _lines(tester).reduce((a, b) => a + b);
    expect(growing, inExclusiveRange(0, full));

    chat
      ..error = ''
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Still folding, its text there, and no click lands on it.
    expect(find.text('The agent stopped.'), findsOneWidget);
    final folding = _lines(tester).reduce((a, b) => a + b);
    expect(folding, inExclusiveRange(0, full));
    expect(
      find
          .ancestor(
            of: find.text('The agent stopped.'),
            matching: find.byWidgetPredicate(
              (w) => w is IgnorePointer && w.ignoring,
            ),
          )
          .evaluate(),
      isNotEmpty,
    );
    await tester.pump(Motion.exit);
    expect(find.text('The agent stopped.'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('a queued pill pops in; one going fades where it was', (
    tester,
  ) async {
    final (d, chat) = await _box(tester);
    chat
      ..queue = [QueuedMessage(id: 'q1', text: 'Then docs')]
      ..notifyListeners();
    await tester.pumpAndSettle();
    chat
      ..queue = [
        QueuedMessage(id: 'q1', text: 'Then docs'),
        QueuedMessage(id: 'q2', text: 'And tests'),
      ]
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    double opacity(String text) => tester
        .widgetList<Opacity>(
          find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
        )
        .fold(1, (v, o) => v * o.opacity);
    expect(opacity('And tests'), inExclusiveRange(0, 1));
    expect(opacity('Then docs'), 1);
    await tester.pumpAndSettle();
    final at = tester.getTopLeft(find.text('And tests'));

    // q1 sent: it fades out where it was, and q2 stays put till it's gone.
    chat
      ..queue = [QueuedMessage(id: 'q2', text: 'And tests')]
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity('Then docs'), inExclusiveRange(0, 1));
    expect(tester.getTopLeft(find.text('And tests')), at);
    await tester.pump(Motion.exit);
    await tester.pump();
    expect(find.text('Then docs'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('Send pops in as text comes; the field is never animated', (
    tester,
  ) async {
    final (d, _) = await _box(tester);
    expect(find.byTooltip('Send\u2002⏎'), findsNothing);
    final field = tester.getSize(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    expect(find.byTooltip('Send\u2002⏎'), findsOneWidget);
    final pop = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byTooltip('Send\u2002⏎'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(pop.opacity, lessThan(1));
    await tester.pump(Motion.quick);
    // A second line: the field grows at once, in the same frame.
    await tester.enterText(find.byType(TextField), 'Hello\nthere');
    await tester.pump();
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThan(field.height),
    );
    await closeView(tester, d);
  });
}
