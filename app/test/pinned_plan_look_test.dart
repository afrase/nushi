// The pinned plan over the composer, drawn whole: the window at 1700 and
// 720 in both themes, a 360-wide chat, and the phone
// (`make renders TEST=test/pinned_plan_look_test.dart`), with what shares
// the chat's foot with it: a question, queued messages, the update card.
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pinned_plan_fixture.dart';
import 'update_fixtures.dart';

/// The app on a chat with [items], working unless [idle], its details
/// hidden, at [size] in [brightness].
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  List<Item>? items,
  bool idle = false,
  bool update = false,
}) async {
  showDetails.value = false;
  sidebarHidden.value = true;
  final c = chat('c', 'claude', 'Paginate the feed');
  final fake = FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c, items: items ?? planItems()),
      PingRequest() when update => PingResponse(
        apiVersion: apiVersion,
        version: '0.1.16',
        update: newerUpdate('0.1.17'),
      ),
      _ => null,
    });
  final d = await openApp(tester, fake, size: size, brightness: brightness);
  if (!idle) {
    d.chats['c']!
      ..busy = true
      ..started = clock().subtract(const Duration(minutes: 3, seconds: 12))
      ..notifyListeners();
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return (d, fake);
}

const _sizes = [('1700', Size(1700, 1000)), ('720', Size(720, 900))];

void main() {
  setUpAll(loadFonts);

  for (final b in Brightness.values) {
    for (final (w, size) in _sizes) {
      testWidgets('a running plan, ${b.name}, $w wide', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'plan_running_${w}_${b.name}',
        );
        d.dispose();
      }, variant: onMac);

      testWidgets('a running plan collapsed, ${b.name}, $w wide', (
        tester,
      ) async {
        planCollapsed.value = true;
        final (d, _) = await _app(tester, size: size, brightness: b);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'plan_collapsed_${w}_${b.name}',
        );
        d.dispose();
      }, variant: onMac);

      testWidgets('a long plan, ${b.name}, $w wide', (tester) async {
        final (d, _) = await _app(
          tester,
          size: size,
          brightness: b,
          items: planItems(plan: longPlan()),
        );
        expectTextInside(tester, size.width);
        await render(tester, find.byType(NushiApp), 'plan_long_${w}_${b.name}');
        d.dispose();
      }, variant: onMac);

      testWidgets('a question under a plan, ${b.name}, $w wide', (
        tester,
      ) async {
        final (d, _) = await _app(
          tester,
          size: size,
          brightness: b,
          items: [...planItems(), question()],
        );
        d.chats['c']!
          ..waiting = true
          ..notifyListeners();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'plan_question_${w}_${b.name}',
        );
        d.dispose();
      }, variant: onMac);

      testWidgets('queued messages under a plan, ${b.name}, $w wide', (
        tester,
      ) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        d.chats['c']!
          ..queue = [
            QueuedMessage(id: 'q1', text: 'Then the docs'),
            QueuedMessage(id: 'q2', text: 'And a changelog line'),
          ]
          ..notifyListeners();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Then the docs'), findsOneWidget);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'plan_queued_${w}_${b.name}',
        );
        d.dispose();
      }, variant: onMac);

      testWidgets('the update card over a plan, ${b.name}, $w wide', (
        tester,
      ) async {
        final (d, _) = await _app(
          tester,
          size: size,
          brightness: b,
          update: true,
        );
        await d.ping();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await render(
          tester,
          find.byType(NushiApp),
          'plan_update_${w}_${b.name}',
        );
        d.dispose();
      }, variant: onMac);
    }

    testWidgets('a 360-wide chat, ${b.name}', (tester) async {
      final (d, _) = await _app(
        tester,
        size: const Size(376, 800),
        brightness: b,
        items: planItems(plan: longPlan()),
      );
      expect(tester.takeException(), isNull);
      expectTextInside(tester, 376);
      await render(tester, find.byType(NushiApp), 'plan_narrow_${b.name}');
      planCollapsed.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expectTextInside(tester, 376);
      await render(
        tester,
        find.byType(NushiApp),
        'plan_narrow_collapsed_${b.name}',
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('the phone, ${b.name}', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 2, brightness: b);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final c = chat('c', 'claude', 'Paginate the feed');
      final fake = FakeDaemon([c])
        ..answer = ((input) => input is GetChatRequest
            ? GetChatResponse(chat: c, items: planItems())
            : null);
      final phone = await startPhone(tester, fake);
      await tester.tap(find.text('Paginate the feed'));
      await tester.pumpAndSettle();
      fake.emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(3),
          status: ChatStatus(busy: true),
        ),
      );
      await tester.pumpAndSettle();
      await render(tester, find.byType(PhoneApp), 'plan_phone_${b.name}');
      await tester.tap(find.byTooltip('Expand the plan'));
      await tester.pumpAndSettle();
      await render(tester, find.byType(PhoneApp), 'plan_phone_open_${b.name}');
      await endPhone(tester, phone);
    }, variant: onPhone);
  }
}
