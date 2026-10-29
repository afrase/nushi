import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show item, pull;

GitHubLink _link(int n) => GitHubLink(
  host: 'github.com',
  repo: 'afrase/nushi-gh-test',
  number: n,
  id: 'PR_$n',
  pull: true,
);

/// Chats on pull requests 1 (failing), 2 (running) and 3 (passed), and
/// one without.
List<Chat> _chats() => [
  chat('a', 'claude', 'Add Sub')..pull = _link(1),
  chat('b', 'claude', 'Add Neg', age: 5)..pull = _link(2),
  chat('c', 'codex', 'Docs', age: 10)..pull = _link(3),
  chat('d', 'claude', 'No pull request', age: 15),
];

Object? _states(Object input) => switch (input) {
  GetGitHubStatesRequest() => GetGitHubStatesResponse(
    items: [
      item(1, 'Add Sub', checks: 'failure'),
      item(2, 'Add Neg', checks: 'pending', draft: true),
      item(3, 'Docs', checks: 'success', state: 'merged'),
    ],
  ),
  _ => null,
};

void main() {
  setUpAll(loadFonts);

  testWidgets("the sidebar's rows: a dot for a pull request's checks, red "
      'failing, amber running, none passed', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 700);
    addTearDown(tester.view.reset);
    final fake = FakeDaemon(_chats())..answer = _states;
    final d = await fake.connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final asked = fake.calls.whereType<GetGitHubStatesRequest>();
    expect(asked, hasLength(1), reason: 'one call for every chat');
    expect(asked.single.items.map((l) => l.number), [1, 2, 3]);
    expect(find.byTooltip('#1: checks failing'), findsOneWidget);
    expect(find.byTooltip('#2: checks running'), findsOneWidget);
    expect(find.byType(PullDot), findsNWidgets(3));
    expect(find.byTooltip('#3: checks passed'), findsNothing);
    // Each minute, quietly.
    await tester.pump(const Duration(minutes: 1));
    expect(fake.calls.whereType<GetGitHubStatesRequest>().last.quiet, isTrue);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final size in const [Size(390, 844), Size(430, 932), Size(844, 390)]) {
    testWidgets("the phone: the pull request in the chat's bar, a tap opens "
        'it (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = size * 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final fake = FakeDaemon(_chats())
        ..answer = (input) => switch (input) {
          GetChatRequest() => GetChatResponse(chat: _chats().first),
          _ => _states(input),
        };
      final platform = PhonePlatform()
        ..saved = {
          'key': Uint8List(32)..[0] = 7,
          'name': 'iPhone',
          'relay': 'wss://nushi.aaronfrase.com',
          'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
          'daemonKey': Uint8List(32)..[0] = 9,
        };
      final phone = Phone(
        platform,
        connectTo: (_) => Daemon(transport: fake, remote: true),
      );
      await tester.pumpWidget(PhoneApp(phone));
      await phone.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('Add Sub'));
      await tester.pumpAndSettle();
      final chip = find.byType(PullChip);
      expect(chip, findsOneWidget);
      expect(
        find.bySemanticsLabel('Pull request #1, Open, checks failing'),
        findsOneWidget,
      );
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
      expect(
        tester.getTopRight(chip).dx,
        lessThanOrEqualTo(size.width),
        reason: 'inside the bar',
      );
      await phone.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets("the phone's bar: the PR widget's one-line summary, $name", (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(390, 844) * 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final fake = FakeDaemon(_chats())
        ..answer = (input) => switch (input) {
          GetChatRequest() => GetChatResponse(chat: _chats().first),
          GetGitHubPullRequest() => GetGitHubPullResponse(
            pull: pull()..item.id = 'PR_1',
          ),
          _ => _states(input),
        };
      final platform = PhonePlatform()
        ..saved = {
          'key': Uint8List(32)..[0] = 7,
          'name': 'iPhone',
          'relay': 'wss://nushi.aaronfrase.com',
          'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
          'daemonKey': Uint8List(32)..[0] = 9,
        };
      final phone = Phone(
        platform,
        connectTo: (_) => Daemon(transport: fake, remote: true),
      );
      await tester.pumpWidget(PhoneApp(phone));
      await phone.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('Add Sub'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          'Pull request #1, Open, checks failing, 2 open threads',
        ),
        findsOneWidget,
      );
      final chip = find.byType(PullChip);
      expect(tester.getTopRight(chip).dx, lessThanOrEqualTo(390));
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/pull_phone_bar_$name.png'),
      );
      await phone.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets("the chip opens the pull request's page", (tester) async {
    final fake = FakeDaemon(_chats())..answer = _states;
    final d = await fake.connect(tester);
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: PullChip(d, d.chats['a']!, onOpen: opened.add)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PullChip));
    expect(opened, ['https://github.com/afrase/nushi-gh-test/pull/1']);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });
}
