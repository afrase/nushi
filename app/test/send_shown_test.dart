import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A message sent to an idle chat shows at once, faint, and the daemon's
// echo takes its place without a second rise (the fluidity review's idea
// 13, a change the owner said yes to).

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

final Chat _chat = chat('a', 'claude', 'Fix the login');

final _items = [
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Why does the login loop?',
  ),
  Item(
    id: 'm1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The session cookie expires mid-upload.',
  ),
];

/// A daemon whose SendPrompt waits on [send] (a new one each time).
class _Sends {
  Completer<void> send = Completer();
  final sent = <SendPromptRequest>[];
}

(FakeDaemon, _Sends) _fake({bool busy = false}) {
  final sends = _Sends();
  final fake = FakeDaemon([_chat])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: _chat,
        items: _items,
        status: ChatStatus(busy: busy),
      ),
      SendPromptRequest() => () async {
        sends.sent.add(input);
        await sends.send.future;
        return SendPromptResponse();
      }(),
      _ => null,
    };
  return (fake, sends);
}

Future<(FakeDaemon, _Sends, Daemon)> _app(
  WidgetTester tester, {
  bool busy = false,
}) async {
  viewport(tester, const Size(1400, 900));
  showDetails.value = false;
  final (fake, sends) = _fake(busy: busy);
  final d = await fake.connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  // Not pumpAndSettle: a busy chat's turn line shines on.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return (fake, sends, d);
}

/// The daemon's echo of [text], at [seq].
EventsResponse _echo(String text, int seq) => EventsResponse(
  chatId: 'a',
  seq: Int64(seq),
  item: ItemEvent(
    item: Item(id: 'u-$seq', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: text),
  ),
);

/// The product of the opacities over [text] in the transcript, as drawn.
double _opacity(WidgetTester tester, String text) {
  var v = 1.0;
  tester.element(_inTranscript(text)).visitAncestorElements((e) {
    // Each render object once, at its own element.
    switch (e) {
      case RenderObjectElement(renderObject: final RenderOpacity o):
        v *= o.opacity;
      case RenderObjectElement(renderObject: final RenderAnimatedOpacity o):
        v *= o.opacity.value;
    }
    return e.widget is! Transcript;
  });
  return v;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

Finder _inTranscript(String text) =>
    find.descendant(of: find.byType(Transcript), matching: find.text(text));

void main() {
  testWidgets('sent, it shows at once, faint; the echo takes its place '
      'without rising again', (tester) async {
    final (fake, sends, d) = await _app(tester);
    await _type(tester, 'Add a test for it');
    expect(sends.sent.single.text, 'Add a test for it');
    await tester.pump(const Duration(milliseconds: 300)); // it rose in
    expect(_inTranscript('Add a test for it'), findsOneWidget);
    expect(_opacity(tester, 'Add a test for it'), closeTo(0.7, 0.01));
    final at = tester.getTopLeft(_inTranscript('Add a test for it'));
    final element = tester.element(_inTranscript('Add a test for it'));

    fake.emit(_echo('Add a test for it', 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // The same entry, where it was: not a second rise.
    expect(_inTranscript('Add a test for it'), findsOneWidget);
    expect(tester.getTopLeft(_inTranscript('Add a test for it')), at);
    expect(
      tester
          .element(_inTranscript('Add a test for it'))
          .findAncestorStateOfType<State>(),
      element.findAncestorStateOfType<State>(),
    );
    await tester.pump(Motion.quick);
    expect(_opacity(tester, 'Add a test for it'), 1);
    sends.send.complete();
    await tester.pumpAndSettle();
    expect(_inTranscript('Add a test for it'), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a send that fails fades out as its text goes back in the '
      'box', (tester) async {
    final (_, sends, d) = await _app(tester);
    await _type(tester, 'Add a test for it');
    await tester.pump(const Duration(milliseconds: 300));
    sends.send.completeError(ConnectException(Code.internal, 'no agent'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // Going, and the text is back in the box.
    expect(_inTranscript('Add a test for it'), findsOneWidget);
    expect(_opacity(tester, 'Add a test for it'), lessThan(0.7));
    final box = tester.widget<TextField>(find.byType(TextField).last);
    expect(box.controller!.text, 'Add a test for it');
    await tester.pump(Motion.exit);
    await tester.pumpAndSettle();
    expect(_inTranscript('Add a test for it'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('sent, the status coming without an echo takes it away', (
    tester,
  ) async {
    final (fake, sends, d) = await _app(tester);
    await _type(tester, 'Add a test for it');
    sends.send.complete();
    await tester.pumpAndSettle();
    expect(_inTranscript('Add a test for it'), findsOneWidget);
    fake.emit(
      EventsResponse(
        chatId: 'a',
        seq: Int64(1),
        status: ChatStatus(busy: true),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(_inTranscript('Add a test for it'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a busy chat's send is a queued pill, not in the transcript", (
    tester,
  ) async {
    final (_, sends, d) = await _app(tester, busy: true);
    await _type(tester, 'Then the docs');
    expect(sends.sent.single.queue, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_inTranscript('Then the docs'), findsNothing);
    sends.send.complete();
    await tester.pump();
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('with Reduce Motion it shows faint at once and goes at once', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final (_, sends, d) = await _app(tester);
    await _type(tester, 'Add a test for it');
    expect(_opacity(tester, 'Add a test for it'), closeTo(0.7, 0.01));
    sends.send.completeError(ConnectException(Code.internal, 'no agent'));
    await tester.pump();
    await tester.pump();
    expect(_inTranscript('Add a test for it'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('on the phone, too', (tester) async {
    viewport(tester, const Size(390, 844), ratio: 3);
    final platform = PhonePlatform()..saved = pairedRecord();
    final (fake, sends) = _fake();
    final phone = Phone(
      platform,
      connectTo: (_) => Daemon(transport: fake, remote: true),
    );
    await tester.pumpWidget(PhoneApp(phone));
    await phone.start();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('Fix the login'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Add a test for it');
    await tester.pump();
    await tester.tap(find.byTooltip('Send (⏎)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_inTranscript('Add a test for it'), findsOneWidget);
    expect(_opacity(tester, 'Add a test for it'), closeTo(0.7, 0.01));
    fake.emit(_echo('Add a test for it', 1));
    sends.send.complete();
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'Add a test for it'), 1);
    await endPhone(tester, phone);
  });
}
