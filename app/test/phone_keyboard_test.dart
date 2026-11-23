// The phone's on-screen keyboard (iOS shrinks the visual viewport, not the
// app's box): its height comes in as the bottom view inset, and the
// composer, the transcript and every text field keep clear of it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/keyboard.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/platform.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final Chat _chat = chat('a', 'claude', 'Fix the flaky relay test');

GetChatResponse _items() => GetChatResponse(
  chat: _chat,
  items: [
    for (var i = 0; i < 12; i++) ...[
      Item(
        id: 'u$i',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text: 'Question $i',
      ),
      Item(
        id: 'm$i',
        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
        text: 'Answer $i, long enough to take a couple of lines on a phone.',
      ),
    ],
  ],
);

/// The phone app, paired, on a [size] screen, showing the chats.
Future<(Phone, PhonePlatform)> _app(
  WidgetTester tester,
  Size size, {
  bool paired = true,
}) async {
  viewport(tester, size, ratio: 3);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final platform = PhonePlatform()..saved = !paired ? null : pairedRecord();
  // Chats in more folders: New chat's folder field comes low on the screen.
  final fake = FakeDaemon([
    _chat,
    for (var i = 0; i < 8; i++)
      chat('f$i', 'claude', 'Elsewhere $i', folder: '/Users/me/p$i', age: i),
  ])..answer = (input) => input is GetChatRequest ? _items() : null;
  final phone = await startPhone(tester, fake, platform: platform);
  return (phone, platform);
}

/// The visual viewport shrinking to [visible] over a [height] tall app, as
/// keyboard_web.dart reports it.
void _visualViewport(PhonePlatform p, double height, double visible) =>
    p.keyboard.value = keyboardInset(
      appBottom: height,
      viewportTop: 0,
      viewportHeight: visible,
    );

/// The Mac's platform, standing in for a phone's browser (see `typing`).
final TargetPlatformVariant _browser = onMac;

bool _focused(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

void main() {
  test('the inset is what the visual viewport leaves out of the app', () {
    double inset(double bottom, double top, double height) => keyboardInset(
      appBottom: bottom,
      viewportTop: top,
      viewportHeight: height,
    );
    // iOS 18.3's keyboard and form bar over a Safari tab (the simulator).
    expect(inset(663, 0, 394.65625), 268);
    expect(inset(663, 0, 663), 0, reason: 'no keyboard');
    expect(inset(663, 0, 662.5), 0, reason: 'rounding');
    expect(inset(663, 20, 400), 243, reason: 'the viewport moved down');
    expect(inset(663, 0, 700), 0, reason: 'never negative');
  });

  testWidgets('the composer sits on the keyboard, the transcript above it', (
    tester,
  ) async {
    const size = Size(390, 844);
    final (phone, platform) = await _app(tester, size);
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    expect(tester.getRect(field).bottom, greaterThan(size.height - 120));
    await tester.tap(field);
    await tester.pump();

    // The keyboard (and its form bar) take the bottom 336 points.
    _visualViewport(platform, size.height, size.height - 336);
    await tester.pumpAndSettle();
    final top = size.height - 336;
    final box = tester.getRect(field);
    expect(box.bottom, lessThanOrEqualTo(top), reason: 'above the keyboard');
    expect(box.bottom, greaterThan(top - 120), reason: 'right above it');
    expect(
      tester.getRect(find.bySemanticsLabel('Back').first).top,
      greaterThanOrEqualTo(0),
      reason: 'the bar stays',
    );
    // The transcript followed its bottom: the last answer shows, above the
    // composer.
    final last = tester.getRect(find.textContaining('Answer 11').first);
    expect(last.bottom, lessThanOrEqualTo(box.top));
    expect(last.top, greaterThan(52));

    // Taller (the emoji keyboard), then gone.
    _visualViewport(platform, size.height, size.height - 380);
    await tester.pumpAndSettle();
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(size.height - 380));
    _visualViewport(platform, size.height, size.height);
    await tester.pumpAndSettle();
    expect(tester.getRect(field).bottom, greaterThan(size.height - 120));
    await endPhone(tester, phone);
  });

  // A touch on the transcript, with the keyboard up (touch_outside.dart).
  // Under flutter_test kIsWeb is false, and a phone's platform never lets
  // go on a touch there: the Mac's platform stands in for the browser's,
  // where the framework lets go on the touch's press just as it does.
  Future<(Phone, Finder)> typing(WidgetTester tester) async {
    const size = Size(390, 844);
    final (phone, platform) = await _app(tester, size);
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    await tester.tap(field);
    await tester.pump();
    _visualViewport(platform, size.height, size.height - 336);
    await tester.pumpAndSettle();
    expect(_focused(tester, field), isTrue);
    return (phone, field);
  }

  testWidgets('a scroll of the transcript keeps the keyboard up', (
    tester,
  ) async {
    final (phone, field) = await typing(tester);
    final answer = find.textContaining('Answer 9').first;
    final before = tester.getRect(answer).top;
    await tester.dragFrom(tester.getCenter(answer), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(tester.getRect(answer).top, greaterThan(before), reason: 'scrolled');
    expect(_focused(tester, field), isTrue, reason: 'still typing');
    await endPhone(tester, phone);
  }, variant: _browser);

  testWidgets('a tap on the transcript puts the keyboard away', (tester) async {
    final (phone, field) = await typing(tester);
    final finger = await tester.startGesture(
      tester.getCenter(find.textContaining('Answer 9').first),
    );
    await tester.pump();
    expect(_focused(tester, field), isTrue, reason: 'not on the press');
    await finger.up();
    await tester.pumpAndSettle();
    expect(_focused(tester, field), isFalse, reason: 'on the lift');
    await endPhone(tester, phone);
  }, variant: _browser);

  testWidgets('cramped (landscape), the bar gives way to the field', (
    tester,
  ) async {
    const size = Size(844, 369);
    final (phone, platform) = await _app(tester, size);
    await tester.tap(find.text('Fix the flaky relay test'));
    await tester.pumpAndSettle();
    _visualViewport(platform, size.height, 150);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back'), findsNothing);
    final box = tester.getRect(find.byType(TextField).last);
    expect(box.top, greaterThanOrEqualTo(0));
    expect(box.bottom, lessThanOrEqualTo(150));
    expect(tester.takeException(), isNull);
    await endPhone(tester, phone);
  });

  testWidgets('New chat: the folder field scrolls above the keyboard', (
    tester,
  ) async {
    const size = Size(390, 844);
    final (phone, platform) = await _app(tester, size);
    await tester.tap(find.bySemanticsLabel('New chat'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    expect(tester.getRect(field).bottom, greaterThan(400), reason: 'low');
    await tester.tap(field);
    await tester.pump();
    _visualViewport(platform, size.height, 400);
    await tester.pumpAndSettle();
    final box = tester.getRect(field);
    expect(box.top, greaterThan(52), reason: 'below the bar');
    expect(box.bottom, lessThanOrEqualTo(400), reason: 'above the keyboard');
    await endPhone(tester, phone);
  });

  testWidgets('Pairing: the link field scrolls above the keyboard', (
    tester,
  ) async {
    const size = Size(390, 844);
    final (phone, platform) = await _app(tester, size, paired: false);
    final field = find.widgetWithText(TextField, 'Pairing link');
    expect(tester.getRect(field).bottom, greaterThan(330), reason: 'low');
    await tester.tap(field);
    await tester.pump();
    _visualViewport(platform, size.height, 330);
    await tester.pumpAndSettle();
    final box = tester.getRect(field);
    expect(box.top, greaterThan(52), reason: 'below the bar');
    expect(box.bottom, lessThanOrEqualTo(330), reason: 'above the keyboard');
    await endPhone(tester, phone);
  });
}
