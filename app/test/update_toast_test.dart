import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/update_toast.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'update_fixtures.dart';

void main() {
  setUpAll(loadFonts);
  setUp(() {
    dismissedUpdate.value = null;
    brewCask = null;
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
        homebrewCask(exe, '/Users/me', folders.contains) == 'nushi';
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
    // The cask that follows beta versions.
    expect(
      homebrewCask(
        '/Applications/Nushi.app/Contents/MacOS/Nushi',
        '/Users/me',
        {'/opt/homebrew/Caskroom/nushi@beta'}.contains,
      ),
      'nushi@beta',
    );
  });

  for (final kind in ['zip', ...toastStates.keys]) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      for (final width in [1700.0, 720.0]) {
        testWidgets('the toast ($kind), ${width.toInt()} wide ($name): in '
            'the bottom right corner', (tester) async {
          final (found, buttons) =
              toastStates[kind] ?? (newerUpdate('0.1.17'), ['Download']);
          brewCask = kind == 'zip' ? null : 'nushi';
          final d = await openWithUpdate(
            tester,
            updateDaemon(() => found),
            width: width,
            brightness: brightness,
          );
          expect(toastButtons(tester), buttons);
          final box = tester.getRect(updateToast);
          expect(box.right, width - UpdateToast.inset);
          // Over the main pane's corner; the agents' counts are in the
          // sidebar, not under it.
          final window = tester.getRect(find.byType(NushiApp));
          expect(box.bottom, window.bottom - UpdateToast.inset);
          expect(
            tester.getRect(find.byType(StatusBar)).right,
            lessThan(box.left),
          );
          final last = tester.getRect(find.text(buttons.last));
          expect(last.right, lessThan(box.right - 10)); // not clipped
          if (find
              .byKey(const ValueKey('update-error'))
              .evaluate()
              .isNotEmpty) {
            // The whole sentence, inside the card.
            final error = tester.getRect(
              find.byKey(const ValueKey('update-error')),
            );
            expect(error.right, lessThan(box.right - 10));
            expect(error.height, lessThan(40));
          }
          if (width == 1700) {
            // Over the details panel's empty bottom, its text's width.
            final text = tester.getRect(find.text('Environment')).left;
            expect(box.left, text);
          }
          await render(
            tester,
            find.byType(MaterialApp),
            'update_toast_${kind}_${width.toInt()}_$name',
          );
          d.dispose();
        }, variant: macOSOnly);
      }
    }
  }

  testWidgets('Dismiss remembers the version: not again until a newer one', (
    tester,
  ) async {
    var found = newerUpdate('0.1.17');
    final d = await openWithUpdate(tester, updateDaemon(() => found));
    expect(updateToast, findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss: not again until a newer one'));
    await tester.pump();
    // It fades where it is, taking no clicks, then it's gone.
    expect(updateToast, findsOneWidget);
    expect(
      tester
          .widgetList<IgnorePointer>(
            find.ancestor(
              of: updateToast,
              matching: find.byType(IgnorePointer),
            ),
          )
          .any((w) => w.ignoring),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(updateToast, findsNothing);
    expect(dismissedUpdate.value, '0.1.17');
    await tester.pump(const Duration(seconds: 4)); // pings say it again
    expect(updateToast, findsNothing);
    found = newerUpdate('0.1.18');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Nushi 0.1.18 is available.'), findsOneWidget);
    d.dispose();
  }, variant: macOSOnly);

  testWidgets('a release arrives as an event; nothing found, no toast', (
    tester,
  ) async {
    var found = UpdateCheck();
    final fake = updateDaemon(() => found);
    final d = await openWithUpdate(tester, fake);
    expect(updateToast, findsNothing);
    found = newerUpdate('0.1.17');
    fake.emit(EventsResponse(update: found));
    await tester.pump();
    await tester.pump();
    expect(updateToast, findsOneWidget);
    // It rises up to 8 px as it fades in.
    await tester.pump(Motion.enter ~/ 4);
    final rising = tester.getRect(updateToast).bottom;
    await tester.pumpAndSettle();
    final rest = tester.getRect(updateToast).bottom;
    expect(rising - rest, inExclusiveRange(0, 8));
    d.dispose();
  }, variant: macOSOnly);

  testWidgets('Settings › General: the switch turns the checks off, and the '
      'toast goes when the daemon forgets the release', (tester) async {
    var found = newerUpdate('0.1.17');
    final fake = updateDaemon(() => found);
    final d = await openWithUpdate(tester, fake);
    expect(updateToast, findsOneWidget);
    d.openSettings(section: SettingsSection.general);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Check for updates'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.textContaining('Last checked just now'), findsOneWidget);
    final checks = find.descendant(
      of: find.widgetWithText(SettingsRow, 'Check for updates'),
      matching: find.byType(SettingsSwitch),
    );
    await tester.ensureVisible(checks);
    await tester.pumpAndSettle();
    await tester.tap(checks);
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.checkUpdates, false);
    found = UpdateCheck(latest: '0.1.17', checkedMs: found.checkedMs);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(); // it fades out
    expect(updateToast, findsNothing);
    d.dispose();
  }, variant: macOSOnly);

  testWidgets('the palette checks now: a newer one dismissed before shows '
      'again; none, a note says so', (tester) async {
    dismissedUpdate.value = '0.1.17';
    var checks = newerUpdate('0.1.17');
    final fake = updateDaemon(() => UpdateCheck(latest: '0.1.16'))
      ..answer = (input) => switch (input) {
        PingRequest() => PingResponse(
          apiVersion: apiVersion,
          version: '0.1.16',
        ),
        CheckForUpdatesRequest() => CheckForUpdatesResponse(update: checks),
        _ => null,
      };
    final d = await openWithUpdate(tester, fake);
    expect(updateToast, findsNothing);
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
    expect(updateToast, findsOneWidget);
    expect(dismissedUpdate.value, isNull);
    await tester.tap(find.byTooltip('Dismiss: not again until a newer one'));
    checks = UpdateCheck(latest: '0.1.16', checkedMs: checks.checkedMs);
    await check();
    expect(updateToast, findsNothing);
    expect(find.text('Nushi is up to date (0.1.16).'), findsOneWidget);
    final note = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Material),
    );
    expect(tester.getSize(note.first).width, 420);
    await render(tester, find.byType(MaterialApp), 'up_to_date_dark');
    d.dispose();
  }, variant: macOSOnly);

  testWidgets('a failed check says why', (tester) async {
    final fake = updateDaemon(UpdateCheck.new)
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
    final d = await openWithUpdate(tester, fake);
    final context = tester.element(find.byType(StatusBar));
    await checkForUpdates(context, d);
    await tester.pump();
    expect(find.textContaining("can't reach GitHub"), findsOneWidget);
    d.dispose();
  }, variant: macOSOnly);
}
