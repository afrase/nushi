// The phone's screens and the browser's history (history.dart), through
// the stub's history: one entry per screen over the root, the browser's
// back (iOS's edge swipe) takes a screen away, the app's own back takes
// the history back with it, and neither answers the other in a loop.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final List<Chat> _chats = [
  chat('a', 'claude', 'Fix the flaky relay test'),
  chat('b', 'codex', 'Review the Noise channel', age: 5),
];

Future<(Phone, PhonePlatform)> _app(WidgetTester tester) async {
  viewport(tester, const Size(390, 844), ratio: 2);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final platform = PhonePlatform()..saved = pairedRecord();
  final phone = Phone(
    platform,
    connectTo: (_) => Daemon(transport: FakeDaemon(_chats), remote: true),
  );
  await tester.pumpWidget(PhoneApp(phone));
  await phone.start();
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  return (phone, platform);
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  testWidgets('opening a chat pushes an entry; the browser’s back pops it', (
    tester,
  ) async {
    final (phone, platform) = await _app(tester);
    expect(platform.entries, [0]);
    await tester.tap(find.text('Fix the flaky relay test'));
    // The entry comes with the tap, before the screen is drawn.
    expect(platform.entries, [0, 1]);
    expect(platform.at, 1);
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsNothing);

    // iOS's edge swipe: the browser goes back, the chat goes at once.
    expect(platform.back(), isTrue);
    await tester.pump();
    expect(find.text('Chats'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    expect(_nav(tester).canPop(), isFalse);
    // No loop: the browser stays where it went, nothing pushed again.
    await tester.pumpAndSettle();
    expect(platform.entries, [0, 1]);
    expect(platform.at, 0);

    // At the root a back leaves the page: nothing of the app's stops it.
    expect(platform.back(), isFalse);
    // The chats take taps again: the chat opens anew, with its entry.
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsNothing);
    expect(platform.entries, [0, 1]);
    expect(platform.at, 1);
    await endPhone(tester, phone);
  });

  testWidgets('the app’s back takes the history back with it, once', (
    tester,
  ) async {
    final (phone, platform) = await _app(tester);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(platform.entries, [0, 1]);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
    // One go back, whose popstate changes nothing more.
    expect(platform.at, 0);
    expect(platform.entries, [0, 1]);
    // The next screen's entry replaces the old one (no forward left).
    await tester.tap(find.bySemanticsLabel('New chat'));
    await tester.pumpAndSettle();
    expect(platform.entries, [0, 1]);
    expect(platform.at, 1);
    expect(find.text('New chat'), findsWidgets);
    await endPhone(tester, phone);
  });

  testWidgets('a notification’s chat: back goes to the chats', (tester) async {
    final (phone, platform) = await _app(tester);
    // Settings open, then a notification opens a chat: what was over the
    // root goes, and the chat is next to it.
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    phone.opening.value = 'b';
    await tester.pumpAndSettle();
    expect(find.text('Review the Noise channel'), findsWidgets);
    expect(platform.entries, [0, 1]);
    expect(platform.at, 1);
    expect(platform.back(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
    expect(_nav(tester).canPop(), isFalse);
    expect(platform.at, 0);
    await endPhone(tester, phone);
  });

  testWidgets('a dialog over a screen goes with it on the browser’s back', (
    tester,
  ) async {
    final (phone, platform) = await _app(tester);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget this Mac'));
    await tester.pumpAndSettle();
    expect(find.text('Forget this Mac?'), findsOneWidget);
    // A dialog has no entry of its own.
    expect(platform.entries, [0, 1]);
    expect(platform.back(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Forget this Mac?'), findsNothing);
    expect(find.text('Chats'), findsOneWidget);
    expect(platform.at, 0);
    expect(phone.daemon, isNotNull, reason: 'nothing was forgotten');
    await endPhone(tester, phone);
  });

  testWidgets('the edge swipe is the browser’s, not Flutter’s', (tester) async {
    final (phone, platform) = await _app(tester);
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    // A drag from the left edge that iOS takes for its own back: Flutter
    // starts no back of its own (which would never end, the app then
    // deaf to taps).
    await tester.dragFrom(const Offset(1, 400), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsNothing);
    expect(_nav(tester).userGestureInProgress, isFalse);
    expect(platform.at, 1);
    await endPhone(tester, phone);
  });

  testWidgets('forward onto a screen that’s gone goes back again', (
    tester,
  ) async {
    final (phone, platform) = await _app(tester);
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    platform.back();
    await tester.pumpAndSettle();
    // Safari's forward: the entry's chat is gone, so back to the root.
    platform
      ..at = 1
      ..onEntry!(1);
    await tester.pumpAndSettle();
    expect(platform.at, 0);
    expect(find.text('Chats'), findsOneWidget);
    await endPhone(tester, phone);
  });
}
