// The phone's web app as it runs, in a real browser: paired (its record in
// IndexedDB), its chats listed, one opened. The widget tests run the
// phone on the VM, where kIsWeb is false and dart:io works, so they take
// the desktop side of every guard; this one takes the phone's, where a
// file read or an unset native edge throws.
// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/findings_card.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';

import '../fake_daemon.dart';

/// A review's findings as an agent writes them: one inside the chat's
/// folder, written absolute, which the phone must place without looking
/// the folder up on disk.
final String _review = [
  'Two things to fix:',
  '```json',
  jsonEncode([
    {
      'file': '/Users/me/nushi/calc/calc.go',
      'line': 6,
      'summary': 'Average skips the first element.',
    },
    {'file': '/etc/hosts', 'line': 1, 'summary': 'Outside the folder.'},
  ]),
  '```',
].join('\n');

void main() {
  testWidgets('paired, it lists the chats, opens one and places a '
      'finding’s path without reading a file', (tester) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(390, 844) * 2;
    addTearDown(tester.view.reset);
    addTearDown(() => phoneHost = macConventions);
    final c = chat('c', 'claude', 'Review the calculator');
    final fake = FakeDaemon([c, chat('d', 'codex', 'Fix the cart', age: 5)])
      ..chatItems['c'] = [
        userSays('u', 'Review calc.go.'),
        agentSays('a', _review),
      ];
    final platform = PhonePlatform();
    await tester.runAsync(
      () => platform.save({
        'key': Uint8List(32)..[0] = 7,
        'name': 'iPhone',
        'relay': 'wss://relay.example.com',
        'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
        'daemonKey': Uint8List(32)..[0] = 9,
      }),
    );
    late final Phone phone;
    phone = Phone(
      platform,
      connectTo: (_) =>
          Daemon(transport: fake, remote: true, drafts: phone.drafts),
    );
    await tester.pumpWidget(PhoneApp(phone));
    await tester.runAsync(phone.start);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(phone.paired, isNotNull);
    expect(find.text('Review the calculator'), findsOneWidget);
    expect(find.text('Fix the cart'), findsOneWidget);

    await tester.tap(find.text('Review the calculator'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(FindingsCard), findsOneWidget);
    // The one in the folder opens there; the other is outside it.
    expect(find.byTooltip('/Users/me/nushi/calc/calc.go:6'), findsOneWidget);
    expect(
      find.byTooltip('/etc/hosts:1: outside the chat’s folder'),
      findsOneWidget,
    );
    expect(fake.calls.whereType<WatchChatFileRequest>(), isEmpty);

    await tester.runAsync(phone.close);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(platform.clear);
  });
}
