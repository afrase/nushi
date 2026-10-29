// Replying on the phone: text selected by touch gets one menu, the
// selection's own, with Copy and Reply (iOS's menu hid Nushi's toolbar
// over the selection); Reply opens the reply box, which stays above the
// keyboard. A mouse still gets Nushi's toolbar.

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/keyboard.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/reply_cards.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final Chat _chat = chat('a', 'claude', 'Fix the flaky relay test');

const _answer =
    'The relay drops the socket when the phone sleeps, so the test waits '
    'for a reconnect that the fake clock never brings.';

/// The phone app on a [size] screen, in the chat.
Future<(Phone, PhonePlatform)> _chatOpen(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  viewport(tester, size, ratio: 3);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final platform = PhonePlatform()..saved = pairedRecord();
  final fake = FakeDaemon([_chat])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(
            chat: _chat,
            items: [
              Item(
                id: 'u1',
                kind: ItemKind.ITEM_KIND_USER_MESSAGE,
                text: 'Why is the relay test flaky?',
              ),
              Item(
                id: 'm1',
                kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                text: _answer,
              ),
            ],
          )
        : null;
  final phone = Phone(
    platform,
    connectTo: (_) => Daemon(transport: fake, remote: true),
  );
  await tester.pumpWidget(PhoneApp(phone));
  await phone.start();
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  await tester.tap(find.text('Fix the flaky relay test'));
  await tester.pumpAndSettle();
  return (phone, platform);
}

/// The middle of [word] in the agent's answer.
Offset _at(WidgetTester tester, String word) {
  final para = tester.renderObject<RenderParagraph>(
    find.textContaining('fake clock', findRichText: true).last,
  );
  final i = para.text.toPlainText().indexOf(word);
  final box = para
      .getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + word.length),
      )
      .first
      .toRect();
  return para.localToGlobal(box.center);
}

/// A long press on [word], as a finger selects it.
Future<void> _longPress(WidgetTester tester, String word) async {
  final touch = await tester.startGesture(_at(tester, word));
  await tester.pump(const Duration(milliseconds: 600));
  await touch.up();
  await tester.pumpAndSettle();
}

void main() {
  // The app's fonts: the test font's tall lines overflow a reply's card.
  setUpAll(loadFonts);

  // Each phone's screen and the keyboard's height over it (with its form
  // bar); landscape leaves a strip.
  for (final (size, keyboard) in [
    (const Size(390, 844), 336.0),
    (const Size(430, 932), 346.0),
    (const Size(844, 390), 240.0),
  ]) {
    testWidgets('${size.width.round()}x${size.height.round()}: a long press '
        'selects a word, its menu has Copy and Reply, and Reply opens the box '
        'with the word, above the keyboard', (tester) async {
      final (phone, platform) = await _chatOpen(tester, size: size);
      await _longPress(tester, 'socket');

      // One menu, the platform's, over the selection; no toolbar of Nushi's.
      expect(find.byType(CupertinoTextSelectionToolbar), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Select All'), findsNothing);
      expect(find.byType(SelectionToolbar), findsNothing);

      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTextSelectionToolbar), findsNothing);
      final box = find.byType(ReplyBox);
      expect(tester.widget<ReplyBox>(box).quote, 'socket');
      final r = tester.getRect(box);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(size.width));

      // The keyboard comes up (and its form bar): the box and its send
      // button stay above it.
      final field = find.descendant(of: box, matching: find.byType(TextField));
      await tester.tap(field);
      await tester.pump();
      final top = size.height - keyboard;
      platform.keyboard.value = keyboardInset(
        appBottom: size.height,
        viewportTop: 0,
        viewportHeight: top,
      );
      await tester.pumpAndSettle();
      final send = find.byTooltip('Add to the message (⏎)');
      expect(tester.getRect(box).bottom, lessThanOrEqualTo(top));
      expect(tester.getRect(box).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(send).bottom, lessThanOrEqualTo(top));

      await tester.enterText(field, 'Can the fake clock bring it?');
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.byType(ReplyBox), findsNothing);
      final cards = tester.widget<ReplyCards>(find.byType(ReplyCards));
      expect(cards.replies.value, [
        (quote: 'socket', text: 'Can the fake clock bring it?', from: ''),
      ]);
      expect(tester.takeException(), isNull);
      await endPhone(tester, phone);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('Copy puts the selection on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final (phone, _) = await _chatOpen(tester);
    await _longPress(tester, 'reconnect');
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'reconnect');
    expect(find.byType(ReplyBox), findsNothing);
    await endPhone(tester, phone);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: the same menu, Material', (tester) async {
    final (phone, _) = await _chatOpen(tester);
    await _longPress(tester, 'socket');
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Reply'), findsOneWidget);
    expect(find.byType(SelectionToolbar), findsNothing);
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(tester.widget<ReplyBox>(find.byType(ReplyBox)).quote, 'socket');
    await endPhone(tester, phone);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a mouse gets the toolbar where it went up, no menu', (
    tester,
  ) async {
    final (phone, _) = await _chatOpen(tester, size: const Size(900, 700));
    final drag = await tester.startGesture(
      _at(tester, 'relay'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveTo(_at(tester, 'socket'));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.byType(SelectionToolbar), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.byType(ReplyBox), findsOneWidget);
    await endPhone(tester, phone);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
