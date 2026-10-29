import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/update_toast.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _macOS = TargetPlatformVariant.only(TargetPlatform.macOS);
const _url = 'https://github.com/afrase/nushi/releases/tag/v0.1.17';

UpdateCheck _newer(String v) => UpdateCheck(
  version: v,
  url: _url,
  latest: v,
  checkedMs: Int64(fixtureNow.millisecondsSinceEpoch),
);

/// A daemon (0.1.16) whose check found [found]; Check for updates finds
/// [checks] (else what it found).
FakeDaemon _daemon(UpdateCheck Function() found, {UpdateCheck? checks}) =>
    FakeDaemon([chat('c', 'claude', 'Fix the login redirect')])
      ..settings = Settings(sleepAfterMinutes: 30, checkUpdates: true)
      ..answer = (input) => switch (input) {
        PingRequest() => PingResponse(
          apiVersion: apiVersion,
          version: '0.1.16',
          update: found(),
        ),
        CheckForUpdatesRequest() => CheckForUpdatesResponse(
          update: checks ?? found(),
        ),
        _ => null,
      };

Future<Daemon> _open(
  WidgetTester tester,
  FakeDaemon fake, {
  double width = 1700,
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, Size(width, 700), brightness: brightness);
  final d = await fake.connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  d.select('c');
  await tester.pumpAndSettle();
  return d;
}

final Finder _toast = find.byKey(const ValueKey('update-toast'));

void main() {
  setUpAll(loadFonts);
  setUp(() {
    dismissedUpdate.value = null;
    byHomebrew = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
  });

  test('versions order as semantic versioning does', () {
    expect(compareVersions('0.1.17', '0.1.16'), 1);
    expect(compareVersions('0.1.10', '0.1.9'), 1);
    expect(compareVersions('0.1.17', '0.1.17'), 0);
    expect(compareVersions('0.1.17-beta.1', '0.1.17'), -1);
    expect(compareVersions('0.1.17-beta.2', '0.1.17-beta.10'), -1);
    expect(compareVersions('0.1.17-1', '0.1.17-alpha'), -1);
    expect(compareVersions('0.1.17+40', '0.1.17'), 0);
    expect(compareVersions('', '0.1.17'), -1);
  });

  test('Homebrew installed it: Nushi.app in an Applications folder, and '
      'its Caskroom has nushi', () {
    bool brew(String exe, Set<String> folders) =>
        installedByHomebrew(exe, '/Users/me', folders.contains);
    const caskroom = {'/opt/homebrew/Caskroom/nushi'};
    expect(
      brew('/Applications/Nushi.app/Contents/MacOS/Nushi', caskroom),
      true,
    );
    expect(
      brew('/Users/me/Applications/Nushi.app/Contents/MacOS/Nushi', {
        '/usr/local/Caskroom/nushi',
      }),
      true,
    );
    // make install's app, without the cask; a build's; elsewhere.
    expect(
      brew('/Users/me/Applications/Nushi.app/Contents/MacOS/Nushi', {}),
      false,
    );
    expect(
      brew(
        '/Users/me/nushi/app/build/Nushi.app/Contents/MacOS/Nushi',
        caskroom,
      ),
      false,
    );
    expect(brew('/Volumes/x/Nushi.app/Contents/MacOS/Nushi', caskroom), false);
  });

  for (final brew in [true, false]) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      for (final width in [1700.0, 720.0]) {
        final kind = brew ? 'brew' : 'zip';
        testWidgets('the toast ($kind), ${width.toInt()} wide ($name): in '
            'the bottom right corner', (tester) async {
          byHomebrew = brew;
          final d = await _open(
            tester,
            _daemon(() => _newer('0.1.17')),
            width: width,
            brightness: brightness,
          );
          expect(find.text('Nushi 0.1.17 is available.'), findsOneWidget);
          expect(find.text('Copy'), brew ? findsOneWidget : findsNothing);
          expect(
            find.text('Release notes'),
            brew ? findsOneWidget : findsNothing,
          );
          expect(find.text('Download'), brew ? findsNothing : findsOneWidget);
          final box = tester.getRect(_toast);
          expect(box.right, width - 12);
          final status = tester.getRect(find.byType(StatusBar));
          expect(box.bottom, status.top - 12);
          final last = tester.getRect(
            find.text(brew ? 'Release notes' : 'Download'),
          );
          expect(last.right, lessThan(box.right - 10)); // not clipped
          if (width == 1700) {
            // Over the details panel's empty bottom, its cards' width.
            final card = tester.getRect(find.text('Environment')).left;
            expect(box.left, lessThan(card));
            expect(box.left, greaterThan(card - 20));
          }
          await expectLater(
            _toast,
            matchesGoldenFile(
              'goldens/update_toast_${kind}_${width.toInt()}_$name.png',
            ),
          );
          d.dispose();
        }, variant: _macOS);
      }
    }
  }

  testWidgets('Copy puts the Homebrew command on the clipboard', (
    tester,
  ) async {
    byHomebrew = true;
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
    final d = await _open(tester, _daemon(() => _newer('0.1.17')));
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, 'brew update && brew upgrade --cask nushi');
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copy'), findsOneWidget);
    d.dispose();
  }, variant: _macOS);

  testWidgets('Dismiss remembers the version: not again until a newer one', (
    tester,
  ) async {
    var found = _newer('0.1.17');
    final d = await _open(tester, _daemon(() => found));
    expect(_toast, findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss: not again until a newer one'));
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);
    expect(dismissedUpdate.value, '0.1.17');
    await tester.pump(const Duration(seconds: 4)); // pings say it again
    expect(_toast, findsNothing);
    found = _newer('0.1.18');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Nushi 0.1.18 is available.'), findsOneWidget);
    d.dispose();
  }, variant: _macOS);

  testWidgets('a release arrives as an event; nothing found, no toast', (
    tester,
  ) async {
    var found = UpdateCheck();
    final fake = _daemon(() => found);
    final d = await _open(tester, fake);
    expect(_toast, findsNothing);
    found = _newer('0.1.17');
    fake.emit(EventsResponse(update: found));
    await tester.pump();
    await tester.pump();
    expect(_toast, findsOneWidget);
    d.dispose();
  }, variant: _macOS);

  testWidgets('Settings › General: the switch turns the checks off, and the '
      'toast goes when the daemon forgets the release', (tester) async {
    var found = _newer('0.1.17');
    final fake = _daemon(() => found);
    final d = await _open(tester, fake);
    expect(_toast, findsOneWidget);
    d.openSettings(section: SettingsSection.general);
    await tester.pumpAndSettle();
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.textContaining('Last checked just now'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(SettingsRow, 'Check for updates'),
        matching: find.byType(SettingsSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.checkUpdates, false);
    found = UpdateCheck(latest: '0.1.17', checkedMs: found.checkedMs);
    await tester.pump(const Duration(seconds: 2));
    expect(_toast, findsNothing);
    d.dispose();
  }, variant: _macOS);

  testWidgets('the palette checks now: a newer one dismissed before shows '
      'again; none, a note says so', (tester) async {
    dismissedUpdate.value = '0.1.17';
    var checks = _newer('0.1.17');
    final fake = _daemon(() => UpdateCheck(latest: '0.1.16'))
      ..answer = (input) => switch (input) {
        PingRequest() => PingResponse(
          apiVersion: apiVersion,
          version: '0.1.16',
        ),
        CheckForUpdatesRequest() => CheckForUpdatesResponse(update: checks),
        _ => null,
      };
    final d = await _open(tester, fake);
    expect(_toast, findsNothing);
    Future<void> check() async {
      unawaited(showPalette(tester.element(find.byType(StatusBar)), d));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Palette),
          matching: find.byType(TextField),
        ),
        'check for updates',
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }

    await check();
    expect(fake.calls.whereType<CheckForUpdatesRequest>(), hasLength(1));
    expect(_toast, findsOneWidget);
    expect(dismissedUpdate.value, isNull);
    await tester.tap(find.byTooltip('Dismiss: not again until a newer one'));
    checks = UpdateCheck(latest: '0.1.16', checkedMs: checks.checkedMs);
    await check();
    expect(_toast, findsNothing);
    expect(find.text('Nushi is up to date (0.1.16).'), findsOneWidget);
    d.dispose();
  }, variant: _macOS);

  testWidgets('a failed check says why', (tester) async {
    final fake = _daemon(UpdateCheck.new)
      ..answer = (input) => switch (input) {
        PingRequest() => PingResponse(
          apiVersion: apiVersion,
          version: '0.1.16',
        ),
        CheckForUpdatesRequest() => throw ConnectException(
          Code.unavailable,
          "can't reach GitHub: no route to host",
        ),
        _ => null,
      };
    final d = await _open(tester, fake);
    final context = tester.element(find.byType(StatusBar));
    await checkForUpdates(context, d);
    await tester.pump();
    expect(find.textContaining("can't reach GitHub"), findsOneWidget);
    d.dispose();
  }, variant: _macOS);
}
