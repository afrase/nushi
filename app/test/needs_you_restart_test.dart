import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/alerts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

void main() {
  setUpAll(loadFonts);

  // The owner: a chat needed you, the daemon restarted with an update, and
  // its amber dot never cleared. The new daemon lists it as not waiting:
  // the dot, the Dock badge and the notification follow.
  for (final shown in [true, false]) {
    testWidgets("a chat that needed you doesn't after the daemon's restart: "
        'its dot, the badge and its notification go '
        '(${shown ? 'on screen' : 'in the list'})', (tester) async {
      dockBadge.value = alertNeedsYou.value = true;
      final swift = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        alertsChannel,
        (c) async {
          swift.add(c);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          alertsChannel,
          null,
        ),
      );
      // Each subscription is a daemon's events: the first message says it's
      // live, and closing it is that daemon stopping.
      late StreamController<EventsResponse> events;
      final chats = [
        chat(
          'a',
          'claude',
          'Fix the login redirect',
          status: ChatStatus(busy: true, waiting: true),
        ),
      ];
      final fake = FakeDaemon(chats)
        ..streams = ((input) => input is EventsRequest
            ? (events = StreamController()..add(EventsResponse())).stream
            : null)
        // Its snapshot, as the daemon has it.
        ..answer = ((input) => input is GetChatRequest
            ? GetChatResponse(chat: chats[0], status: chats[0].status)
            : null);
      final d = await fake.connect(tester);
      if (shown) d.select('a');
      final alerts = MacAlerts(d)..focused = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SizedBox(width: 260, child: Sidebar(daemon: d)),
            ),
          ),
        ),
      );
      events.add(
        EventsResponse(
          chatId: 'a',
          item: ItemEvent(
            item: Item(
              id: 'p',
              kind: ItemKind.ITEM_KIND_PERMISSION,
              status: 'pending',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('needs you'), findsOneWidget);
      expect(swift.where((c) => c.method == 'post'), hasLength(1));
      expect(swift.lastWhere((c) => c.method == 'badge').arguments, '1');

      // The daemon restarts: its agents stopped, the prompt was cancelled,
      // and the new one lists the chat asleep.
      chats[0] = chat(
        'a',
        'claude',
        'Fix the login redirect',
        status: ChatStatus(asleep: true),
      );
      await events.close();
      await tester.pump(const Duration(seconds: 2)); // the next ping
      await tester.pump();
      await tester.pump();

      expect(d.chats['a']!.waiting, isFalse);
      expect(find.byTooltip('needs you'), findsNothing);
      expect(find.byTooltip('asleep'), findsOneWidget);
      expect(swift.lastWhere((c) => c.method == 'badge').arguments, '');
      final withdrawn = swift.lastWhere((c) => c.method == 'withdraw');
      expect(withdrawn.arguments, ['a/permission', 'a/question']);
      alerts.dispose();
      d.dispose();
    });
  }
}
