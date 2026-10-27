// The phone's screens while the link is down or a chat is on its way, at
// iPhone sizes with their safe areas (the notch and the home indicator):
// the "Reconnecting…" bar, Try again and what it says, a chat loading, and
// a long chat scrolled up to its older pages. Nothing sits under the safe
// areas.
import 'dart:async';
import 'dart:typed_data';

import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/chat_screen.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:remote_transport/remote_transport.dart' show Unreachable;

import 'fake_daemon.dart';

final List<Chat> _chats = [
  chat('a', 'claude', 'Fix the flaky relay test'),
  chat('b', 'codex', 'Review the Noise channel', age: 5),
];

/// iPhones: the screen, and the status bar's and home indicator's insets.
const _phones = {
  '390': (Size(390, 844), 47.0, 34.0),
  '430': (Size(430, 932), 59.0, 34.0),
};

Map<String, Object?> _paired() => {
  'key': Uint8List(32)..[0] = 7,
  'name': 'iPhone',
  'relay': 'wss://nushi.aaronfrase.com',
  'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
  'daemonKey': Uint8List(32)..[0] = 9,
};

/// A long chat's item [i]: a step, a tool call, or the agent's message.
Item _item(int i) => switch (i % 3) {
  0 => Item(
    id: 'i$i',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Step $i: look at the relay again',
  ),
  1 => Item(
    id: 'i$i',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    title: 'Read relay/relay.go',
    toolKind: 'read',
    status: 'completed',
  ),
  _ => Item(
    id: 'i$i',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Message $i: the wait ends when the relay restarts.',
  ),
};

/// A long chat's items, [from] to [to].
List<Item> _items(int from, int to) => [
  for (var i = from; i < to; i++) _item(i),
];

Future<Phone> _app(
  WidgetTester tester,
  FakeDaemon fake,
  String phone,
  Brightness b, {
  PhonePlatform? platform,
}) async {
  final (size, top, bottom) = _phones[phone]!;
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = size * 2
    ..padding = FakeViewPadding(top: top * 2, bottom: bottom * 2)
    ..viewPadding = FakeViewPadding(top: top * 2, bottom: bottom * 2);
  tester.platformDispatcher
    ..platformBrightnessTestValue = b
    ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final p = Phone(
    platform ?? (PhonePlatform()..saved = _paired()),
    connectTo: (_) => Daemon(transport: fake, remote: true),
  );
  await tester.pumpWidget(PhoneApp(p));
  await p.start();
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  return p;
}

Future<void> _end(WidgetTester tester, Phone phone) async {
  await phone.close();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 40));
}

/// Lets a fling end while a spinner turns.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Nothing of [f] under the status bar or the home indicator.
void _inside(WidgetTester tester, Finder f, String phone) {
  final (size, top, bottom) = _phones[phone]!;
  final r = tester.getRect(f);
  expect(r.top, greaterThanOrEqualTo(top), reason: 'under the status bar');
  expect(
    r.bottom,
    lessThanOrEqualTo(size.height - bottom),
    reason: 'under the home indicator',
  );
}

void main() {
  setUpAll(loadFonts);

  for (final phone in _phones.keys) {
    for (final b in Brightness.values) {
      final name = '${phone}_${b.name}';

      testWidgets('the link down, then Try again ($name)', (tester) async {
        var down = false;
        Completer<void>? held; // a ping that takes a while
        final fake = FakeDaemon(_chats)
          ..answer = (input) async {
            if (input is! PingRequest || !down) return null;
            await held?.future;
            throw connect.ConnectException(
              connect.Code.unavailable,
              'daemon unavailable: no Mac at the relay',
              cause: Unreachable.mac,
            );
          };
        final p = await _app(tester, fake, phone, b);
        expect(find.byType(ConnectionBar), findsOneWidget);
        expect(find.text('Reconnecting…'), findsNothing);

        down = true;
        unawaited(p.link!.check());
        await tester.pump();
        await tester.pump();
        expect(find.text('Reconnecting…'), findsOneWidget);
        await expectLater(
          find.byType(PhoneApp),
          matchesGoldenFile('goldens/phone_reconnecting_$name.png'),
        );

        await p.link!.check();
        p.link!.seen = DateTime(2026, 10, 27, 10, 42);
        await tester.pump();
        expect(find.text("Can't reach your Mac"), findsOneWidget);

        // Try again: a spinner while it tries, then what came of it.
        held = Completer();
        final tried = p.link!.check(user: true);
        await tester.pump();
        expect(find.text('Try again'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        held.complete();
        held = null;
        await tried;
        await tester.pump();
        expect(find.text("Still can't reach your Mac"), findsOneWidget);
        expect(
          find.textContaining("it's asleep or offline, or its remote access"),
          findsOneWidget,
        );
        expect(find.textContaining('last seen'), findsOneWidget);
        _inside(tester, find.byType(ConnectionBar), phone);
        await expectLater(
          find.byType(PhoneApp),
          matchesGoldenFile('goldens/phone_cant_reach_$name.png'),
        );

        // Back: the bar goes.
        down = false;
        await p.link!.check(user: true);
        await tester.pump();
        expect(find.text("Still can't reach your Mac"), findsNothing);
        expect(find.text('Reconnecting…'), findsNothing);
        await _end(tester, p);
      });

      testWidgets('pairing: Scan, or paste the link ($name)', (tester) async {
        final p = await _app(
          tester,
          FakeDaemon(_chats),
          phone,
          b,
          platform: PhonePlatform()..iPhone = true,
        );
        expect(find.text('Scan QR code'), findsOneWidget);
        expect(find.bySemanticsLabel('Back'), findsNothing);
        _inside(tester, find.text('Pair').last, phone);
        await expectLater(
          find.byType(PhoneApp),
          matchesGoldenFile('goldens/phone_pair_scan_$name.png'),
        );
        await _end(tester, p);
      });

      testWidgets('the Mac’s QR code opened in Safari ($name)', (tester) async {
        final p = await _app(
          tester,
          FakeDaemon(_chats),
          phone,
          b,
          platform: PhonePlatform()
            ..iPhone = true
            ..installed = false
            ..openedWith = 'https://nushi.aaronfrase.com/#pair?r=x',
        );
        expect(find.text('Open Nushi from your Home Screen'), findsOneWidget);
        expect(find.text('Copy link'), findsOneWidget);
        expect(find.text('Scan QR code'), findsNothing);
        await expectLater(
          find.byType(PhoneApp),
          matchesGoldenFile('goldens/phone_pair_safari_$name.png'),
        );
        await _end(tester, p);
      });

      testWidgets('a chat loading ($name)', (tester) async {
        final never = Completer<GetChatResponse>();
        final asked = <GetChatRequest>[];
        final fake = FakeDaemon(_chats)
          ..answer = (input) => input is GetChatRequest
              ? (asked..add(input), never.future).$2
              : null;
        final p = await _app(tester, fake, phone, b);
        await tester.tap(find.text('Fix the flaky relay test'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(TranscriptSkeleton), findsOneWidget);
        expect(find.text('Loading the chat…'), findsOneWidget);
        expect(
          asked.single.recent,
          Daemon.recentItems,
          reason: 'the recent part first',
        );
        _inside(tester, find.byType(TextField).last, phone);
        await expectLater(
          find.byType(PhoneApp),
          matchesGoldenFile('goldens/phone_chat_loading_$name.png'),
        );
        await _end(tester, p);
      });

      testWidgets('a long chat scrolled up ($name)', (tester) async {
        final page = Completer<GetChatItemsResponse>();
        final pages = <String>[];
        final fake = FakeDaemon(_chats)
          ..answer = (input) => switch (input) {
            GetChatRequest() => GetChatResponse(
              chat: _chats[0],
              items: _items(160, 240),
              older: 160,
            ),
            GetChatItemsRequest(:final before) =>
              (pages..add(before)).length == 1
                  ? page.future
                  : Completer<Never>().future,
            _ => null,
          };
        final p = await _app(tester, fake, phone, b);
        await tester.tap(find.text('Fix the flaky relay test'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          find.text('Message 239: the wait ends when the relay restarts.'),
          findsOneWidget,
        );
        expect(find.text('160 earlier items'), findsOneWidget);
        // Scrolled up near the top: the next page is asked for; when it
        // comes, what shows stays where it was.
        final scroll = find.byType(Scrollable).first;
        await tester.fling(scroll, const Offset(0, 6000), 6000);
        await _settle(tester); // a spinner turns while the page comes
        expect(pages, ['i160']);
        final seen = find.text('Step 162: look at the relay again');
        final before = tester.getTopLeft(seen);
        page.complete(GetChatItemsResponse(items: _items(80, 160), older: 80));
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        expect(tester.getTopLeft(seen).dy, closeTo(before.dy, 1));
        // Further up: the page before that is on its way.
        await tester.fling(scroll, const Offset(0, 8000), 8000);
        await _settle(tester);
        expect(find.byType(Earlier), findsOneWidget);
        expect(
          find.text('Step 81: look at the relay again').hitTestable(),
          findsOneWidget,
        );
        _inside(tester, find.byType(TextField).last, phone);
        await expectLater(
          find.byType(PhoneApp),
          matchesGoldenFile('goldens/phone_chat_older_$name.png'),
        );
        await _end(tester, p);
      });
    }
  }
}
