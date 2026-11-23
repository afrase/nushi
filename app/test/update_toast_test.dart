import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/beside.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/toast.dart';
import 'package:nushi/top_notices.dart';
import 'package:nushi/update_toast.dart';

import 'fake_app_install.dart';
import 'fake_daemon.dart';
import 'harness.dart';
import 'update_fixtures.dart';

void main() {
  setUpAll(loadFonts);
  setUp(() {
    brewCask = null;
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
        testWidgets('the toast ($kind), ${width.toInt()} wide ($name): at '
            'the bottom right, above the composer', (tester) async {
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
          // At the window's bottom right (ADR 0128, amended 2026-11-19):
          // over the details rail where it shows, else above the composer
          // and so clear of its buttons.
          final area = tester.getRect(find.byType(Beside));
          final transcript = tester.getRect(find.byType(ChatView));
          expect(box.right, area.right - TopNotices.cardInset);
          expect(
            box.bottom,
            width == 1700
                ? area.bottom - TopNotices.cardInset
                : composerFoot(tester).top - TopNotices.cardInset,
          );
          expect(box.top, greaterThan(transcript.center.dy)); // not the top
          expect(
            tester.getRect(find.byType(StatusBar)).right,
            lessThan(box.left),
          );
          final last = tester.getRect(find.text(buttons.last));
          expect(last.right, lessThan(box.right - 10)); // not clipped
          expect(
            find.byKey(const ValueKey('update-error')),
            kind == 'failed' ? findsOne : findsNothing,
          );
          if (kind == 'failed') {
            // The whole sentence, inside the card.
            final error = tester.getRect(
              find.byKey(const ValueKey('update-error')),
            );
            expect(error.right, lessThan(box.right - 10));
            expect(error.height, lessThan(40));
          }
          if (width == 1700) {
            // The rail shows, and the card is over it.
            final rail = tester.getRect(find.byType(DetailsPanel));
            expect(rail.intersect(box), box);
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

  testWidgets('an app already at or past the release found (just upgraded '
      'by brew, its daemon not restarted yet) shows no toast', (tester) async {
    final d = await openWithUpdate(
      tester,
      updateDaemon(() => newerUpdate('0.1.17')),
    );
    expect(updateToast, findsOneWidget); // this app is older (unset)
    for (final mine in ['0.1.17', '0.1.17+52', '0.1.18-beta.1', '0.2.0']) {
      fakeInstall.version = mine;
      d.listChanged();
      await tester.pumpAndSettle();
      expect(updateToast, findsNothing, reason: mine);
    }
    // A beta before the release still hears of it.
    fakeInstall.version = '0.1.17-beta.3';
    d.listChanged();
    await tester.pumpAndSettle();
    expect(updateToast, findsOneWidget);
    d.dispose();
  }, variant: macOSOnly);

  for (final width in [720.0, 900.0]) {
    testWidgets('Files lying over the transcript, ${width.toInt()} wide: the '
        "card is the window's, over the pane at its corner", (tester) async {
      final d = await openWithUpdate(
        tester,
        updateDaemon(() => newerUpdate('0.1.17')),
        width: width,
      );
      filesChats.value = {'c'};
      await tester.pumpAndSettle();
      // The pane has the window's corner: the card is over it, drawn
      // and clicked there, not lifted (Files has no bar at its foot) nor
      // hidden.
      final card = tester.getRect(updateToast);
      final pane = tester.getRect(find.byType(FilesPane));
      expect(pane.intersect(card), card);
      final area = tester.getRect(find.byType(Beside));
      expect(card.right, area.right - TopNotices.cardInset);
      expect(card.bottom, area.bottom - TopNotices.cardInset);
      final hit = tester.hitTestOnBinding(card.center);
      bool reached(Finder f) => hit.path.any(
        (e) => f.evaluate().any((el) => el.renderObject == e.target),
      );
      expect(reached(updateToast), isTrue);
      expect(find.text('Download').hitTestable(), findsOneWidget);
      await render(
        tester,
        find.byType(MaterialApp),
        'update_toast_files_${width.toInt()}',
      );
      // Closed, the card is back above the composer, at the same right.
      filesChats.value = {};
      await tester.pumpAndSettle();
      expect(find.text('Download').hitTestable(), findsOneWidget);
      expect(tester.getRect(updateToast).right, card.right);
      d.dispose();
    }, variant: macOSOnly);
  }

  testWidgets('the card stands above the composer as it grows, and stays '
      'put as a toast shows', (tester) async {
    final d = await openWithUpdate(
      tester,
      updateDaemon(() => newerUpdate('0.1.17')),
      width: 720,
    );
    final before = tester.getRect(updateToast);
    showToast(
      Toasts.maybeOf(tester.element(find.byType(Scaffold))),
      'Committed 3f2a9c1',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(updateToast), before);
    await tester.enterText(
      find.byType(TextField).first,
      'one\ntwo\nthree\nfour\nfive',
    );
    await tester.pumpAndSettle();
    final grown = tester.getRect(updateToast);
    expect(grown.bottom, composerFoot(tester).top - TopNotices.cardInset);
    expect(grown.bottom, lessThan(before.bottom));
    // Its buttons are where it's drawn.
    expect(find.text('Download').hitTestable(), findsOneWidget);
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
    final note = find.ancestor(
      of: find.byType(ToastLine),
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
          Code.failedPrecondition,
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

/// The foot of the chat's transcript: its turn status and composer.
Rect composerFoot(WidgetTester tester) => tester.getRect(
  find.ancestor(of: find.byType(Composer), matching: find.byType(Column)).first,
);
