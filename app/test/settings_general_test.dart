import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';

import 'fake_app_install.dart';
import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'spell_harness.dart' show FakeSpeller;

/// Settings at [section] on a fake daemon: sleep after 30 minutes.
Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester,
  SettingsSection section,
) async {
  final fake = FakeDaemon([])
    ..settings = Settings(
      sleepAfterMinutes: 30,
      debugLog: false,
      keepTranscripts: true,
      transcriptDays: 90,
    );
  final d = await fake.connect(tester);
  await pumpSettings(tester, d, section);
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the font, its size and the sleep time are menus that look '
      'it; Show logs is a button', (tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<MouseCursor> over(String text) async {
      await mouse.moveTo(tester.getCenter(find.text(text)));
      await tester.pump();
      return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;
    }

    for (final (section, control, label) in [
      (SettingsSection.terminal, 'JetBrains Mono', 'Font'),
      (SettingsSection.terminal, '12.5', 'Size'),
      (SettingsSection.general, 'After 30 minutes', 'Sleep idle chats'),
      (SettingsSection.logs, 'Show logs', 'Debug lines'),
    ]) {
      final (_, d) = await _open(tester, section);
      expect(await over(control), SystemMouseCursors.click, reason: control);
      expect(await over(label), SystemMouseCursors.basic, reason: label);
      d.dispose();
    }
  });

  testWidgets('a sleep time picked is set', (tester) async {
    final (fake, d) = await _open(tester, SettingsSection.general);
    await tester.tap(find.text('After 30 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hour'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.sleepAfterMinutes, 60);
    d.dispose();
  });

  // UX review, finding 15: remembered, not the View menu's state alone.
  testWidgets('the appearance is a setting, kept in app.json', (tester) async {
    final (_, d) = await _open(tester, SettingsSection.appearance);
    final mode = find.byKey(const ValueKey('appearance-mode'));
    expect(find.descendant(of: mode, matching: find.text('System')), findsOne);
    await tester.tap(find.descendant(of: mode, matching: find.text('Dark')));
    await tester.pumpAndSettle();
    expect(appearance.value, ThemeMode.dark);
    expect(readSaved()['appearance'], 'dark');
    // The segments say it.
    expect(tester.widget<Segmented<ThemeMode>>(mode).value, ThemeMode.dark);
    d.dispose();
  });

  testWidgets('General: "Enter starts a new line" is a switch, off at '
      'first, that sets the pref and keeps it in app.json', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    final row = find.widgetWithText(SettingsRow, 'Enter starts a new line');
    expect(
      find.descendant(
        of: row,
        matching: find.text('Send with ⌘⏎ or the Send button.'),
      ),
      findsOne,
    );
    final toggle = find.descendant(
      of: row,
      matching: find.byType(SettingsSwitch),
    );
    expect(tester.widget<SettingsSwitch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(enterStartsLine.value, isTrue);
    expect(tester.widget<SettingsSwitch>(toggle).value, isTrue);
    expect(readSaved()['enterStartsLine'], isTrue);
    d.dispose();
  }, variant: onMac);

  testWidgets('General: the chat rows are one group, not a group of one row '
      'each; Check now is a button that asks, and says the version', (
    tester,
  ) async {
    native.speller = FakeSpeller({});
    final fake = settingsFake();
    var asked = 0;
    fake.on((input) {
      if (input is! CheckForUpdatesRequest) return null;
      asked++;
      return CheckForUpdatesResponse(
        update: UpdateCheck(latest: '1.2.0', checkedMs: Int64(1)),
      );
    });
    final d = await pumpSettingsApp(tester, fake, SettingsSection.general);
    final chats = find.ancestor(
      of: find.text('Sleep idle chats'),
      matching: find.byType(SettingsGroup),
    );
    for (final row in [
      'Check spelling while typing',
      'Enter starts a new line',
      'Open local links in built-in browser',
    ]) {
      expect(find.descendant(of: chats, matching: find.text(row)), findsOne);
    }
    expect(find.text('Composer'), findsNothing);
    expect(find.text('Browser'), findsNothing);
    // Each description is one line.
    for (final e in find.byType(SettingsRow).evaluate()) {
      final row = e.widget as SettingsRow;
      if (row.description == null) continue;
      final text = find.descendant(
        of: find.byWidget(row),
        matching: find.text(row.description!),
      );
      expect(tester.getSize(text).height, lessThan(20), reason: row.label);
    }
    // Check now: a button on the version's row, not a link.
    final version = find.widgetWithText(SettingsRow, 'Nushi 1.2.0');
    await tester.scrollUntilVisible(
      version,
      100,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.descendant(of: version, matching: find.textContaining('up to date')),
      findsOne,
    );
    final check = find.descendant(
      of: version,
      matching: find.widgetWithText(Button, 'Check now'),
    );
    expect(check, findsOne);
    expect(find.widgetWithText(LinkText, 'Check now'), findsNothing);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(asked, 1);
    await closeView(tester, d);
  }, variant: onMac);

  /// Settings › General scrolled to the updates' row, its check held
  /// until [answer] completes.
  Future<Daemon> checkNow(
    WidgetTester tester,
    Completer<CheckForUpdatesResponse> answer, {
    Size size = const Size(1700, 1000),
    Brightness brightness = Brightness.dark,
  }) async {
    native.speller = FakeSpeller({});
    final fake = settingsFake()
      ..on((input) => input is CheckForUpdatesRequest ? answer.future : null);
    final d = await pumpSettingsApp(
      tester,
      fake,
      SettingsSection.general,
      size: size,
      brightness: brightness,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('check-now')),
      100,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    return d;
  }

  testWidgets('Check now keeps its place and width while it reads '
      'Checking…', (tester) async {
    final answer = Completer<CheckForUpdatesResponse>();
    final d = await checkNow(tester, answer);
    final button = find.byKey(const ValueKey('check-now'));
    final rest = tester.getRect(button);
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<Button>(button).label, 'Checking…');
    expect(tester.getRect(button), rest);
    answer.complete(
      CheckForUpdatesResponse(
        update: UpdateCheck(latest: '1.2.0', checkedMs: Int64(1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Button>(button).label, 'Check now');
    expect(tester.getRect(button), rest);
    await closeView(tester, d);
  }, variant: onMac);

  for (final size in const [Size(1700, 1000), Size(720, 900)]) {
    renderTest('Check now and Checking…, at ${size.width.round()} wide', (
      tester,
    ) async {
      for (final b in Brightness.values) {
        final answer = Completer<CheckForUpdatesResponse>();
        final d = await checkNow(tester, answer, size: size, brightness: b);
        final name = 'settings_check_now_${size.width.round()}_${b.name}';
        await render(tester, find.byType(MaterialApp), name);
        await tester.tap(find.byKey(const ValueKey('check-now')));
        await tester.pump();
        await render(tester, find.byType(MaterialApp), '${name}_checking');
        answer.complete(CheckForUpdatesResponse(update: UpdateCheck()));
        await tester.pumpAndSettle();
        await closeView(tester, d);
      }
    }, variant: onMac);
  }

  testWidgets(
    'Start at login heads Startup and updates, not the chats’ group',
    (tester) async {
      (native.install as FakeAppInstall).daemon = '/Applications/nushid';
      const channel = MethodChannel('nushi/login');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(channel, (_) async => 'enabled');
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final fake = FakeDaemon([])
        ..settings = Settings(sleepAfterMinutes: 30, checkUpdates: true);
      final d = await fake.connect(tester);
      await pumpSettings(tester, d, SettingsSection.general);
      Finder inGroup(String title) => find.ancestor(
        of: find.text(title),
        matching: find.byType(SettingsGroup),
      );
      final login = find.ancestor(
        of: find.text('Start at login'),
        matching: find.byType(SettingsGroup),
      );
      expect(login, findsOne);
      expect(tester.widget<SettingsGroup>(login).title, 'Startup and updates');
      expect(inGroup('Sleep idle chats'), isNot(login.evaluate().single));
      // First in it, over Check for updates.
      expect(
        tester.getRect(find.text('Start at login')).top,
        lessThan(tester.getRect(find.text('Check for updates')).top),
      );
      await closeView(tester, d);
    },
    // A dev run's own data folder shows no Start at login (it starts the
    // usual folder's daemon).
    skip: Platform.environment.containsKey('NUSHI_DATA'),
    variant: onMac,
  );
}
