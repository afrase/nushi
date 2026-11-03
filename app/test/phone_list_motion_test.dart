// The phone's chat list: rows and sections come and go with motion (the
// fluidity review's idea 9): a chat that starts needing you leaves its
// project, fading and folding, and comes into "Needs you", which grows in
// with it and folds once none needs you; with Reduce Motion, at once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/list_motion.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';

import 'fake_daemon.dart';
import 'harness.dart';

List<Chat> _chats() => [
  chat('a', 'claude', 'Fix the flaky relay test'),
  chat('b', 'codex', 'Review the Noise channel', age: 5),
];

Future<Phone> _app(
  WidgetTester tester,
  FakeDaemon fake, {
  bool still = false,
}) async {
  viewport(tester, const Size(390, 760), ratio: 2);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: still);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final phone = Phone(
    PhonePlatform()..saved = pairedRecord(),
    connectTo: (_) => Daemon(transport: fake, remote: true),
  );
  await tester.pumpWidget(PhoneApp(phone));
  await phone.start();
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  return phone;
}

/// The height [text]'s section or row takes, as laid out.
double _height(WidgetTester tester, String text) => tester
    .getSize(
      find.ancestor(of: find.text(text), matching: find.byType(Presence)).first,
    )
    .height;

/// Chat b, needing you or not.
Future<void> _needs(WidgetTester tester, FakeDaemon fake, bool on) async {
  final b = fake.chats.firstWhere((c) => c.id == 'b')
    ..status = ChatStatus(busy: on, waiting: on);
  fake.emit(EventsResponse(chatId: 'b', chat: b));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('“Needs you” grows in with the chat that needs you, which '
      'leaves its project; it folds once none does', (tester) async {
    final fake = FakeDaemon(_chats());
    final phone = await _app(tester, fake);
    expect(find.text('Needs you'), findsNothing);

    await _needs(tester, fake, true);
    await tester.pump(Motion.standard ~/ 2);
    expect(find.text('Needs you'), findsOneWidget);
    final full = tester.getSize(find.text('Needs you')).height;
    final mid = _height(tester, 'Needs you');
    expect(mid, greaterThan(0));
    // Leaving its project, it's there twice for a moment: the one going
    // fades.
    expect(find.text('Review the Noise channel'), findsNWidgets(2));
    await tester.pump(Motion.standard);
    await tester.pump(Motion.standard);
    expect(find.text('Review the Noise channel'), findsOneWidget);
    expect(_height(tester, 'Needs you'), greaterThan(mid));
    expect(_height(tester, 'Needs you'), greaterThan(full));

    await _needs(tester, fake, false);
    await tester.pump(Motion.exit ~/ 2);
    expect(find.text('Needs you'), findsOneWidget); // folding
    await tester.pump(Motion.exit);
    await tester.pump(Motion.standard);
    expect(find.text('Needs you'), findsNothing);
    await endPhone(tester, phone);
  });

  testWidgets('with Reduce Motion the section and its row come and go at '
      'once', (tester) async {
    final fake = FakeDaemon(_chats());
    final phone = await _app(tester, fake, still: true);
    await _needs(tester, fake, true);
    expect(find.text('Needs you'), findsOneWidget);
    expect(find.text('Review the Noise channel'), findsOneWidget);
    await _needs(tester, fake, false);
    expect(find.text('Needs you'), findsNothing);
    await endPhone(tester, phone);
  });
}
