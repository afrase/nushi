// The plan pinned over the composer (ADR 0135): which plan, until when,
// what the transcript shows meanwhile, collapsing it, and its place at the
// chat's foot; with goldens of its card collapsed and open.
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pinned_plan.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pinned_plan_fixture.dart';
import 'update_fixtures.dart';

/// The app on chat `c` with [items] (and chat `d` with [other]), working
/// unless [idle], at [size]; with Reduce Motion when [still].
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  List<Item>? items,
  List<Item>? other,
  Size size = const Size(1200, 900),
  bool idle = false,
  bool still = false,
  bool update = false,
}) async {
  if (still) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  showDetails.value = false;
  sidebarHidden.value = true;
  Collapsible.opened.clear();
  final c = chat('c', 'claude', 'Paginate the feed');
  final d2 = chat('d', 'claude', 'Tidy the notes', age: 5);
  final fake = FakeDaemon([c, d2])
    ..answer = ((input) => switch (input) {
      GetChatRequest(chatId: 'd') => GetChatResponse(
        chat: d2,
        items: other ?? const [],
      ),
      GetChatRequest() => GetChatResponse(chat: c, items: items ?? planItems()),
      PingRequest() when update => PingResponse(
        apiVersion: apiVersion,
        version: '0.1.16',
        update: newerUpdate('0.1.17'),
      ),
      _ => null,
    });
  final d = await openApp(tester, fake, size: size);
  if (!idle) {
    d.chats['c']!
      ..busy = true
      ..started = clock().subtract(const Duration(minutes: 1))
      ..notifyListeners();
  }
  await _settle(tester);
  return (d, fake);
}

/// A few frames past what comes and goes: a running plan's ring loops, so
/// nothing settles while the agent works.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await frames(tester, 6, const Duration(milliseconds: 100));
}

var _seq = 10;

/// The daemon's event of [item], changed, or new at [at].
void _item(FakeDaemon fake, Item item, {int at = 0}) => fake.emit(
  EventsResponse(
    chatId: 'c',
    seq: Int64(_seq++),
    item: ItemEvent(item: item, index: at),
  ),
);

/// The pinned card's own finder of [text].
Finder _pinned(String text) => find.descendant(
  of: find.byType(PinnedPlan),
  matching: find.textContaining(text, findRichText: true),
);

/// The transcript's finder of [text], outside the pinned card.
Finder _inTranscript(String text) => find.descendant(
  of: find.byType(Scrollable).first,
  matching: find.textContaining(text, findRichText: true),
);

Item _done(Item plan) => plan.deepCopy()
  ..plan.replace([
    for (final e in plan.plan)
      PlanEntry(content: e.content, status: 'completed'),
  ]);

extension on List<PlanEntry> {
  void replace(List<PlanEntry> to) => this
    ..clear()
    ..addAll(to);
}

/// The chevron's box, whichever way it points.
Rect _chevron(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(PinnedPlan),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Icon &&
          (w.icon == Icons.expand_more || w.icon == Icons.expand_less),
    ),
  ),
);

void main() {
  setUpAll(loadFonts);

  testWidgets('a running turn’s plan is pinned, a line in its place in the '
      'transcript', (tester) async {
    final (d, _) = await _app(tester);
    expect(_pinned('Plan 2 of 4 done'), findsOneWidget);
    expect(_pinned('A cursor in store.ListPosts'), findsOneWidget);
    expect(_inTranscript('shown over the box'), findsOneWidget);
    // The card is the pinned one only: no duplicate of its steps.
    expect(find.text('A cursor in store.ListPosts'), findsOneWidget);
    // Over the composer, its width.
    final card = tester.getRect(find.byType(PinnedPlan));
    final box = tester.getRect(find.byType(TextField));
    expect(card.bottom, lessThanOrEqualTo(box.top));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('it stays once the turn ends with steps not done, and goes '
      'once they all are, its card back in the transcript', (tester) async {
    final (d, fake) = await _app(tester);
    fake.emit(
      EventsResponse(chatId: 'c', seq: Int64(_seq++), status: ChatStatus()),
    );
    await _settle(tester);
    expect(d.chats['c']!.busy, isFalse);
    expect(_pinned('Plan 2 of 4 done'), findsOneWidget);

    _item(fake, _done(runningPlan()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Its last check draws where it is first.
    expect(_pinned('Plan 4 of 4 done'), findsOneWidget);
    await tester.pump(CheckPainter.drawFor + Motion.standard);
    await _settle(tester);
    expect(find.byType(PinnedPlan), findsOneWidget);
    expect(_pinned('Plan'), findsNothing);
    expect(_inTranscript('Plan 4 of 4 done'), findsOneWidget);
    expect(_inTranscript('shown over the box'), findsNothing);
    expect(find.text('A cursor in store.ListPosts'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a new plan takes the old one’s place', (tester) async {
    final (d, fake) = await _app(tester);
    _item(
      fake,
      Item(id: 'u2', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go on'),
      at: planItems().length,
    );
    _item(
      fake,
      plan(id: 'plan2', [
        ('Write the changelog', 'in_progress'),
        ('Tag the release', 'pending'),
      ]),
      at: planItems().length + 1,
    );
    await _settle(tester);
    expect(_pinned('Plan 0 of 2 done'), findsOneWidget);
    expect(_pinned('Write the changelog'), findsOneWidget);
    // The old one, pinned no longer, is a card where it was made.
    expect(_inTranscript('Plan 2 of 4 done'), findsOneWidget);
    expect(_inTranscript('A cursor in store.ListPosts'), findsOneWidget);
    expect(_inTranscript('shown over the box'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a chat without a plan, or with one all done, pins none', (
    tester,
  ) async {
    final (d, _) = await _app(
      tester,
      items: planItems(plan: _done(runningPlan())),
      idle: true,
    );
    expect(_pinned('Plan'), findsNothing);
    expect(_inTranscript('Plan 4 of 4 done'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('the line collapses and expands it, its chevron staying put, '
      'remembered for every chat', (tester) async {
    final (d, _) = await _app(
      tester,
      other: planItems(plan: longPlan(id: 'other')),
    );
    expect(_pinned('Page the feed handler'), findsOneWidget); // open
    final open = _chevron(tester);
    await tester.tap(find.byTooltip('Collapse the plan'));
    await _settle(tester);
    expect(_pinned('Page the feed handler'), findsNothing);
    // Collapsed: the running step's words on the line.
    expect(_pinned('Older posts link'), findsOneWidget);
    expect(_chevron(tester), open);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(readSaved()['planCollapsed'], isTrue);

    // Another chat's plan shows collapsed too.
    d.select('d');
    await _settle(tester);
    expect(_pinned('Plan 3 of 12 done'), findsOneWidget);
    expect(_pinned('Step 1 of the long plan'), findsNothing);

    // From the keyboard: the line takes the focus and Enter opens it.
    final line = find.descendant(
      of: find.descendant(
        of: find.byType(PinnedPlan),
        matching: find.byType(Tap),
      ),
      matching: find.byType(GestureDetector),
    );
    Focus.of(tester.element(line.first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(_pinned('Step 1 of the long plan'), findsOneWidget);
    expect(planCollapsed.value, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('open, a long plan scrolls inside it, the composer in its '
      'place', (tester) async {
    final (d, _) = await _app(tester);
    final box = tester.getRect(find.byType(TextField));
    await closeView(tester, d);

    final (d2, _) = await _app(tester, items: planItems(plan: longPlan()));
    expect(tester.getRect(find.byType(TextField)), box);
    final card = tester.getRect(find.byType(PinnedPlan));
    expect(card.height, lessThan(900 * PinnedPlan.maxShare));
    final steps = find.descendant(
      of: find.byType(PinnedPlan),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(steps).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(_pinned('Step 12 of the long plan'), findsOneWidget); // laid out
    await closeView(tester, d2);
  }, variant: onMac);

  testWidgets('the update card and Jump to latest sit above it', (
    tester,
  ) async {
    final (d, _) = await _app(tester, size: const Size(900, 700), update: true);
    await d.ping();
    await _settle(tester);
    final card = tester.getRect(find.byType(PinnedPlan));
    expect(updateToast, findsOneWidget);
    expect(tester.getRect(updateToast).bottom, lessThanOrEqualTo(card.top));

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await _settle(tester);
    expect(find.byType(JumpChip), findsOneWidget);
    expect(
      tester.getRect(find.byType(JumpChip)).bottom,
      lessThanOrEqualTo(card.top),
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a plan pinned no longer keeps what the reader sees in place', (
    tester,
  ) async {
    final (d, fake) = await _app(tester, size: const Size(900, 600));
    // Scrolled up a little: the plan's line is above what shows.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 80));
    await _settle(tester);
    final anchor = find.text('Read templates/base.html');
    final shows = find.textContaining('The AMP one');
    expect(_inTranscript('shown over the box'), findsOneWidget);
    final before = tester.getRect(shows).top;
    expect(
      tester.getRect(_inTranscript('shown over the box')).bottom,
      lessThan(before),
    );
    _item(fake, _done(runningPlan()));
    await tester.pump();
    expect(tester.getRect(shows).top, before);
    await _settle(tester);
    expect(anchor, findsOneWidget);
    expect(_inTranscript('Plan 4 of 4 done'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('with Reduce Motion it comes, goes and folds at once', (
    tester,
  ) async {
    final (d, fake) = await _app(tester, still: true);
    await tester.tap(find.byTooltip('Collapse the plan'));
    await tester.pump();
    expect(_pinned('Page the feed handler'), findsNothing);
    expect(_pinned('Older posts link'), findsOneWidget);
    _item(fake, _done(runningPlan()));
    await tester.pump();
    expect(_pinned('Plan'), findsNothing);
    expect(_inTranscript('Plan 4 of 4 done'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  for (final (name, tokens) in [
    ('light', Tokens.light),
    ('dark', Tokens.dark),
  ]) {
    for (final open in [true, false]) {
      final look = open ? 'open' : 'collapsed';
      testWidgets('the pinned plan $look ($name)', (tester) async {
        viewport(tester, const Size(560, 600));
        planCollapsed.value = !open;
        final chat = ChatState('c', '/x')..items.addAll(planItems());
        const shot = ValueKey('shot');
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(560, 600),
                disableAnimations: true,
              ),
              child: Material(
                color: tokens.base,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: RepaintBoundary(
                    key: shot,
                    child: ColoredBox(
                      color: tokens.base,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: PinnedPlan(chat),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byKey(shot),
          matchesGoldenFile('goldens/pinned_plan_${look}_$name.png'),
        );
      });
    }
  }
}
