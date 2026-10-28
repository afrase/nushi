import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/alerts.dart';
import 'package:nushi/alerts_settings.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// The Swift side, faked: what it was asked, and its answer to "status".
class _Swift {
  final calls = <MethodCall>[];
  String status = 'notDetermined';

  List<Object?> posted() => [
    for (final c in calls)
      if (c.method == 'post') (c.arguments as Map)['title'],
  ];

  List<Object?> badges() => [
    for (final c in calls)
      if (c.method == 'badge') c.arguments,
  ];
}

_Swift _fake() {
  final swift = _Swift();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(alertsChannel, (c) async {
        swift.calls.add(c);
        return c.method == 'status' ? swift.status : null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alertsChannel, null),
  );
  return swift;
}

void _defaults() {
  alertNeedsYou.value = alertFinished.value = alertFailed.value = true;
  alertSound.value = false;
  dockBadge.value = true;
}

EventsResponse _status(
  String id, {
  bool running = false,
  bool waiting = false,
}) => EventsResponse(
  chatId: id,
  status: ChatStatus(
    busy: running,
    waiting: waiting,
    started: running ? Int64(1000) : Int64.ZERO,
  ),
);

EventsResponse _item(String id, ItemKind kind, String status, [String? item]) =>
    EventsResponse(
      chatId: id,
      item: ItemEvent(
        item: Item(id: item ?? '$id-$status', kind: kind, status: status),
      ),
    );

Future<(FakeDaemon, Daemon, MacAlerts)> _connect(WidgetTester tester) async {
  final fake = FakeDaemon([
    chat('a', 'claude', 'Fix the login'),
    chat('b', 'codex', 'Tidy the docs', age: 1),
  ]);
  final d = await fake.connect(tester);
  return (fake, d, MacAlerts(d));
}

void main() {
  setUp(_defaults);

  testWidgets('a permission prompt and a question are posted once, in the '
      "phone's words, the chat's title under them", (tester) async {
    final swift = _fake();
    final (fake, d, alerts) = await _connect(tester);
    fake
      ..emit(_status('a', running: true))
      ..emit(_item('a', ItemKind.ITEM_KIND_PERMISSION, 'pending', 'p1'))
      ..emit(_item('a', ItemKind.ITEM_KIND_PERMISSION, 'pending', 'p1'))
      ..emit(_item('b', ItemKind.ITEM_KIND_QUESTION, 'pending', 'q1'));
    await tester.pump();
    expect(swift.posted(), ['Claude needs you', 'Codex has a question']);
    final post = swift.calls.firstWhere((c) => c.method == 'post');
    expect(post.arguments, {
      'id': 'a/permission',
      'chat': 'a',
      'title': 'Claude needs you',
      'body': 'Fix the login',
      'sound': false,
    });
    alerts.dispose();
    d.dispose();
  });

  testWidgets("a turn's end is posted 2 s later; not when the agent goes "
      'on, nor when someone stopped it; an error makes it a failure', (
    tester,
  ) async {
    final swift = _fake();
    final (fake, d, alerts) = await _connect(tester);
    fake
      ..emit(_status('a', running: true))
      ..emit(_status('a'));
    await tester.pump(const Duration(seconds: 1));
    expect(swift.posted(), isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(swift.posted(), ['Claude finished']);

    // Went straight on: nothing.
    fake
      ..emit(_status('a', running: true))
      ..emit(_status('a'))
      ..emit(_status('a', running: true));
    await tester.pump(const Duration(seconds: 3));
    // Stopped by someone: nothing.
    fake
      ..emit(_item('a', ItemKind.ITEM_KIND_NOTICE, 'cancelled'))
      ..emit(_status('a'));
    await tester.pump(const Duration(seconds: 3));
    expect(swift.posted(), ['Claude finished']);

    fake
      ..emit(_status('b', running: true))
      ..emit(_item('b', ItemKind.ITEM_KIND_NOTICE, 'error'))
      ..emit(_status('b'));
    await tester.pump(const Duration(seconds: 3));
    expect(swift.posted(), ['Claude finished', "Codex's turn failed"]);
    alerts.dispose();
    d.dispose();
  });

  testWidgets('in front, only the chat on screen is left out; in the '
      'background every chat is posted, and showing a chat clears its', (
    tester,
  ) async {
    final swift = _fake();
    final (fake, d, alerts) = await _connect(tester);
    d.select('a');
    fake
      ..emit(_item('a', ItemKind.ITEM_KIND_PERMISSION, 'pending', 'p1'))
      ..emit(_item('b', ItemKind.ITEM_KIND_PERMISSION, 'pending', 'p2'));
    await tester.pump();
    expect(swift.posted(), ['Codex needs you']);

    alerts.focused = false;
    fake.emit(_item('a', ItemKind.ITEM_KIND_PERMISSION, 'pending', 'p3'));
    await tester.pump();
    expect(swift.posted(), ['Codex needs you', 'Claude needs you']);

    // Back in front on chat a: its notification goes.
    alerts.focused = true;
    expect(swift.calls.last.method, 'clear');
    expect(swift.calls.last.arguments, 'a');
    d.select('b');
    expect(swift.calls.last.arguments, 'b');
    alerts.dispose();
    d.dispose();
  });

  testWidgets('each kind can be off, and the sound on', (tester) async {
    final swift = _fake();
    final (fake, d, alerts) = await _connect(tester);
    alertNeedsYou.value = false;
    alertFinished.value = false;
    alertSound.value = true;
    fake
      ..emit(_item('a', ItemKind.ITEM_KIND_PERMISSION, 'pending', 'p1'))
      ..emit(_status('b', running: true))
      ..emit(_status('b'))
      ..emit(_status('a', running: true))
      ..emit(_item('a', ItemKind.ITEM_KIND_NOTICE, 'error'))
      ..emit(_status('a'));
    await tester.pump(const Duration(seconds: 3));
    expect(swift.posted(), ["Claude's turn failed"]);
    final post = swift.calls.lastWhere((c) => c.method == 'post');
    expect((post.arguments as Map)['sound'], true);
    alerts.dispose();
    d.dispose();
  });

  testWidgets('the Dock badge counts the chats that need you, and goes '
      'when turned off', (tester) async {
    final swift = _fake();
    final (fake, d, alerts) = await _connect(tester);
    fake
      ..emit(_status('a', running: true, waiting: true))
      ..emit(_status('b', running: true, waiting: true));
    await tester.pump();
    fake.emit(_status('a', running: true));
    await tester.pump();
    expect(swift.badges(), ['', '1', '2', '1']); // none at first
    dockBadge.value = false;
    expect(swift.badges().last, '');
    alerts.dispose();
    d.dispose();
  });

  testWidgets("a notification's click opens its chat", (tester) async {
    _fake();
    final (_, d, alerts) = await _connect(tester);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          alertsChannel.name,
          alertsChannel.codec.encodeMethodCall(const MethodCall('open', 'b')),
          (_) {},
        );
    expect(d.selectedId, 'b');
    alerts.dispose();
    d.dispose();
  });

  testWidgets('Settings: the switches set each kind; macOS having them off '
      'says so with a way to its settings', (tester) async {
    final swift = _fake()..status = 'denied';
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(
          body: SingleChildScrollView(child: NotificationsGroup()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('macOS has notifications off for Nushi.'), findsOne);
    await tester.tap(find.text('Open Notifications…'));
    await tester.pump();
    expect(swift.calls.last.method, 'openSettings');

    Finder switchOf(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(switchOf('Sound')).value, false);
    expect(tester.widget<Switch>(switchOf('Dock badge')).value, true);
    await tester.tap(switchOf('A turn ends'));
    await tester.tap(switchOf('Sound'));
    await tester.pump();
    expect(alertFinished.value, false);
    expect(alertSound.value, true);
  });
}
