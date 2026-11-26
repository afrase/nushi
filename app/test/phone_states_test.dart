// The phone's screens while the link is down or a chat is on its way, at
// iPhone sizes with their safe areas (the notch and the home indicator):
// the "Reconnecting…" bar, Try again and what it says, a chat loading, and
// a long chat scrolled up to its older pages. Nothing sits under the safe
// areas.
import 'dart:async';

import 'package:connectrpc/connect.dart' as connect;
import 'package:daemon_transport/remote_transport.dart' show Unreachable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/chat_screen.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/spinner.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final List<Chat> _chats = [
  chat('a', 'claude', 'Fix the flaky relay test'),
  chat('b', 'codex', 'Review the Noise channel', age: 5),
];

/// iPhones: the screen, and the status bar's and home indicator's insets.
const _phones = {
  '390': (Size(390, 844), 47.0, 34.0),
  '430': (Size(430, 932), 59.0, 34.0),
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
  final p = await startPhone(tester, fake, platform: platform);
  return p;
}

/// [endPhone] after links that failed: a retry waits up to 30 s.
Future<void> _end(WidgetTester tester, Phone phone) =>
    endPhone(tester, phone, wait: const Duration(seconds: 40));

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
    for (final b in renderThemes) {
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
        await render(tester, find.byType(PhoneApp), 'phone_reconnecting_$name');

        await p.link!.check();
        // Today at 10:42 (the render's time; another day adds the date).
        p.link!.seen = DateTime(
          fixtureNow.year,
          fixtureNow.month,
          fixtureNow.day,
          10,
          42,
        );
        await tester.pump();
        expect(find.text("Can't reach your Mac"), findsOneWidget);

        // Try again: a spinner while it tries, then what came of it.
        held = Completer();
        final tried = p.link!.check(user: true);
        await tester.pump();
        expect(find.text('Try again'), findsNothing);
        expect(find.byType(Spinner), findsOneWidget);
        held.complete();
        held = null;
        await tried;
        await tester.pump();
        expect(find.text("Still can't reach your Mac"), findsOneWidget);
        // The reason has commas of its own, so when it was last seen is a
        // line of its own, never joined on with another comma (issue 119).
        expect(
          find.text("It's asleep or offline, or its remote access is off"),
          findsOneWidget,
        );
        expect(find.text('Last seen 10:42'), findsOneWidget);
        _inside(tester, find.byType(ConnectionBar), phone);
        await render(tester, find.byType(PhoneApp), 'phone_cant_reach_$name');

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
        await render(tester, find.byType(PhoneApp), 'phone_pair_scan_$name');
        await _end(tester, p);
      });

      testWidgets('storage that throws offers Reload, never pairing '
          '($name)', (tester) async {
        final platform = PhonePlatform()
          ..saved = pairedRecord()
          ..loadFails = StateError('IndexedDB: the open failed');
        final p = await _app(
          tester,
          FakeDaemon(_chats),
          phone,
          b,
          platform: platform,
        );
        expect(find.text('Scan QR code'), findsNothing);
        expect(find.text('Couldn’t open this app’s storage'), findsOneWidget);
        _inside(tester, find.text('Reload'), phone);
        await render(tester, find.byType(PhoneApp), 'phone_storage_$name');
        await tester.tap(find.text('Reload'));
        expect(platform.reloads, 1);
        // Nothing was written over the pairing it couldn't read.
        expect(platform.saved, pairedRecord());
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
            ..openedWith = 'https://relay.example.com/#pair?r=x',
        );
        expect(find.text('Open Nushi from your Home Screen'), findsOneWidget);
        expect(find.text('Copy link'), findsOneWidget);
        expect(find.text('Scan QR code'), findsNothing);
        await render(tester, find.byType(PhoneApp), 'phone_pair_safari_$name');
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
        await frames(tester, 10, const Duration(milliseconds: 50));
        expect(find.byType(TranscriptSkeleton), findsOneWidget);
        expect(find.text('Loading the chat…'), findsOneWidget);
        expect(
          asked.single.recent,
          Daemon.recentItems,
          reason: 'the recent part first',
        );
        _inside(tester, find.byType(TextField).last, phone);
        await render(tester, find.byType(PhoneApp), 'phone_chat_loading_$name');
        await _end(tester, p);
      });

      testWidgets('the chats on their way: a spinner, never "No chats" '
          'until the list has come ($name)', (tester) async {
        final list = Completer<ListChatsResponse>();
        final fake = FakeDaemon(_chats)
          ..answer = (input) => input is ListChatsRequest ? list.future : null;
        final p = await _app(tester, fake, phone, b);
        expect(p.daemon!.connected, isTrue);
        expect(p.daemon!.chatsListed, isFalse);
        expect(find.text('No chats'), findsNothing);
        expect(find.byType(PhoneSpinner), findsOneWidget);
        await render(
          tester,
          find.byType(PhoneApp),
          'phone_chats_loading_$name',
        );
        // None after all: now it says so.
        list.complete(ListChatsResponse());
        await frames(tester, 8, const Duration(milliseconds: 50));
        expect(find.text('No chats'), findsOneWidget);
        expect(find.byType(PhoneSpinner), findsNothing);
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
        await frames(tester, 10, const Duration(milliseconds: 50));
        expect(
          find.text('Message 239: the wait ends when the relay restarts.'),
          findsOneWidget,
        );
        expect(find.text('160 earlier items'), findsOneWidget);
        // Scrolled up near the top: the next page is asked for; when it
        // comes, what shows stays where it was.
        final scroll = find.byType(Scrollable).first;
        await tester.fling(scroll, const Offset(0, 6000), 6000);
        await tester.pumpAndSettle(); // the fling, and the page it asks for
        expect(pages, ['i160']);
        final seen = find.text('Step 162: look at the relay again');
        final before = tester.getTopLeft(seen);
        page.complete(GetChatItemsResponse(items: _items(80, 160), older: 80));
        await frames(tester, 4);
        expect(tester.getTopLeft(seen).dy, closeTo(before.dy, 1));
        // Further up: the page before that is on its way.
        await tester.fling(scroll, const Offset(0, 8000), 8000);
        await tester.pumpAndSettle();
        expect(find.byType(Earlier), findsOneWidget);
        expect(
          find.text('Step 81: look at the relay again').hitTestable(),
          findsOneWidget,
        );
        _inside(tester, find.byType(TextField).last, phone);
        await render(tester, find.byType(PhoneApp), 'phone_chat_older_$name');
        await _end(tester, p);
      });
    }
  }

  testWidgets('back from the background: it reconnects quietly', (
    tester,
  ) async {
    var down = false;
    Completer<void>? held;
    final fake = FakeDaemon(_chats)
      ..answer = (input) async {
        if (input is! PingRequest) return null;
        await held?.future;
        if (down) {
          throw connect.ConnectException(connect.Code.unavailable, 'gone');
        }
        return null;
      };
    final p = await _app(tester, fake, '390', Brightness.dark);
    final link = p.link!..visible(shown: false);
    // While hidden the network was gone: tries failed (a timer that fired
    // before iOS froze the page, or a check).
    down = true;
    await link.check();
    await link.check();
    await tester.pump();
    expect(link.failures, 2);
    // Back to the front, the network back: at most "Reconnecting…" while
    // it dials, never "Can't reach", and then nothing.
    down = false;
    held = Completer();
    link.visible(shown: true);
    await tester.pump();
    expect(find.text("Can't reach your Mac"), findsNothing);
    expect(find.text('Reconnecting…'), findsOneWidget);
    held.complete();
    held = null;
    await frames(tester, 5);
    expect(p.daemon!.connected, isTrue);
    expect(find.byType(ConnectionBar), findsOneWidget);
    expect(find.text('Reconnecting…'), findsNothing);
    // Restored from the back-forward cache while the link is down: the
    // same quiet try.
    down = true;
    await link.check();
    down = false;
    link.resume();
    await frames(tester, 5);
    expect(p.daemon!.connected, isTrue);
    expect(link.failures, 0);
    await _end(tester, p);
  });

  testWidgets('the network back, or the page restored, redials at once', (
    tester,
  ) async {
    var down = false;
    final fake = FakeDaemon(_chats)
      ..answer = (input) {
        if (input is PingRequest && down) {
          throw connect.ConnectException(connect.Code.unavailable, 'gone');
        }
        return null;
      };
    final platform = PhonePlatform()..saved = pairedRecord();
    final p = await _app(
      tester,
      fake,
      '390',
      Brightness.dark,
      platform: platform,
    );
    final link = p.link!;
    // What Phone.start gave the browser's online and pageshow events.
    for (final back in [platform.networkBack!, platform.pageRestored!]) {
      down = true;
      await link.check();
      await tester.pump();
      expect(p.daemon!.connected, isFalse);
      expect(link.failures, greaterThan(0));
      down = false;
      back();
      await frames(tester, 5);
      expect(p.daemon!.connected, isTrue);
      expect(link.failures, 0);
    }
    await _end(tester, p);
  });
}
