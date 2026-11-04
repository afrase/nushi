// Each built-in theme (ADR 0086), dark and light, on the README's demo
// data: the main window mid-turn (the transcript with its diffs, a
// subagent's pane, the details panel), a narrow one with the terminal, the
// phone's chat, and Settings › General. Renders to look at
// (`make renders TEST=test/theme_renders_test.dart`); here each must draw
// without an error or text past the window's edge.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'screenshots/demo.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Object? _demo(Object input) => switch (input) {
  GetChatRequest(:final chatId) when chatId == heroChat.id => GetChatResponse(
    chat: heroChat,
    items: heroItems,
    status: heroChat.status,
  ),
  ListTerminalsRequest() => ListTerminalsResponse(
    terminals: [
      Terminal(id: 't1', chatId: heroChat.id, folder: demoTree, shell: 'zsh'),
    ],
  ),
  _ => null,
};

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The Mac app at [size] in [b], on the demo's chats, the hero's open.
Future<Daemon> _window(WidgetTester tester, Size size, Brightness b) async {
  viewport(tester, size, brightness: b);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  clock = () => demoNow;
  final open = <StreamController<Object>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final fake = FakeDaemon(demoChats())
    ..answer = _demo
    ..streams = (input) {
      if (input is! AttachTerminalRequest) return null;
      final s = StreamController<Object>()
        ..add(AttachTerminalResponse(data: utf8.encode(demoTerminal)));
      open.add(s);
      return s.stream;
    };
  final d = await fake.connect(tester)
    ..select(heroChat.id);
  await tester.pumpWidget(NushiApp(daemon: d));
  await _pump(tester);
  return d;
}

void main() {
  setUpAll(loadFonts);

  for (final theme in builtInThemes) {
    for (final b in Brightness.values) {
      final name = '${theme.id}_${b.name}';

      testWidgets('${theme.name}, ${b.name}: the window mid-turn', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        Collapsible.opened.add('e2');
        addTearDown(Collapsible.opened.clear);
        final d = await _window(tester, const Size(1700, 1000), b);
        d.chats[heroChat.id]!.pane.value = 'x';
        await _pump(tester);
        expect(tester.takeException(), isNull);
        expect(
          NushiTheme.of(tester.element(find.byType(Scaffold).first)).t,
          same(theme.of(b)),
        );
        expectTextInside(tester, 1700);
        await render(tester, find.byType(NushiApp), 'theme_${name}_1700');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: narrow, the terminal open', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        terminalChats.value = {heroChat.id};
        showDetails.value = false;
        final d = await _window(tester, const Size(720, 900), b);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, 720);
        await render(tester, find.byType(NushiApp), 'theme_${name}_720');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: Settings › General', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        final d = await _window(tester, const Size(1200, 900), b);
        d.openSettings(section: SettingsSection.general);
        await _pump(tester, 4);
        expect(tester.takeException(), isNull);
        await render(tester, find.byType(NushiApp), 'theme_${name}_settings');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: the phone’s chat', (tester) async {
        viewport(tester, const Size(390, 844), ratio: 2, brightness: b);
        clock = () => demoNow;
        final fake = FakeDaemon(demoChats())..answer = _demo;
        final phone = Phone(
          PhonePlatform()
            ..saved = pairedRecord()
            ..theme = theme.id,
          connectTo: (_) => Daemon(transport: fake, remote: true),
        );
        await tester.pumpWidget(PhoneApp(phone));
        await phone.start();
        await _pump(tester);
        await tester.tap(find.text(heroChat.title));
        await _pump(tester, 10);
        expect(tester.takeException(), isNull);
        await render(tester, find.byType(PhoneApp), 'theme_${name}_phone');
        await endPhone(tester, phone);
      });
    }
  }
}
