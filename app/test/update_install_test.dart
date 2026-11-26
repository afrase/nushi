import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'update_fixtures.dart';

// The update card's Update button (ADR 0109): the daemon's install as the
// card shows it, in each state.
void main() {
  setUpAll(loadFonts);

  testWidgets('a beta version: Update and Copy upgrade the cask the '
      "daemon names; a daemon that names none (the release's cask can't "
      'bring it) gets Download', (tester) async {
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
    var found = newerUpdate('0.29.0-beta.1', cask: 'nushi@beta');
    final fake = updateDaemon(() => found);
    final d = await openWithUpdate(tester, fake);
    expect(find.text('Nushi 0.29.0-beta.1 is available.'), findsOneWidget);
    expect(
      find.byTooltip('Runs “brew update && brew upgrade --cask nushi@beta”'),
      findsOneWidget,
    );
    found = newerUpdate(
      '0.29.0-beta.1',
      cask: 'nushi@beta',
      error: 'brew upgrade: no network',
    );
    fake.emit(EventsResponse(update: found));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, 'brew update && brew upgrade --cask nushi@beta');
    await tester.pump(const Duration(seconds: 3));
    d.dispose();

    final d2 = await openWithUpdate(
      tester,
      updateDaemon(() => newerUpdate('0.29.0-beta.1')),
    );
    expect(toastButtons(tester), ['Download']);
    d2.dispose();
  }, variant: onMac);

  testWidgets('a daemon from before API 145 sends no cask: Download, '
      'with no guess of its own', (tester) async {
    viewport(tester, const Size(1700, 700));
    final fake = updateDaemon(() => newerUpdate('0.1.17'), api: 144);
    // The app bundles a newer daemon, which this one restarts into once
    // idle (ADR 0056): meanwhile the app works as usual.
    final d = (await fake.connect(tester))..bundled = '7-2000';
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(d.daemonApi, 144);
    expect(find.text('Nushi 0.1.17 is available.'), findsOneWidget);
    expect(toastButtons(tester), ['Download']);
    await closeView(tester, d);
  }, variant: onMac);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the card on its own, in each state ($name)', (tester) async {
      viewport(tester, const Size(360, 200));
      var found = UpdateCheck();
      final fake = updateDaemon(() => found);
      final d = await fake.connect(tester);
      await tester.pumpWidget(
        themed(Center(child: UpdateToast(d)), tokens: tokens),
      );
      for (final MapEntry(key: kind, value: (says, buttons))
          in toastStates.entries) {
        found = says;
        fake.emit(EventsResponse(update: found));
        await tester.pumpAndSettle();
        expect(toastButtons(tester), buttons, reason: kind);
        expect(
          find.byType(Spinner),
          kind == 'updating' ? findsOneWidget : findsNothing,
        );
        await expectLater(
          updateToast,
          matchesGoldenFile('goldens/update_toast_${kind}_$name.png'),
        );
      }
      await closeView(tester, d);
    }, variant: onMac);
  }

  testWidgets('Update has the daemon install it, once: Updating… until '
      'Homebrew is through', (tester) async {
    var found = newerUpdate('0.1.17', cask: 'nushi');
    final fake = updateDaemon(() => found);
    // The daemon answers once Homebrew has started, the event before it.
    final started = Completer<InstallUpdateResponse>();
    fake.on((input) => input is InstallUpdateRequest ? started.future : null);
    final d = await openWithUpdate(tester, fake);
    expect(
      find.byTooltip('Runs “brew update && brew upgrade --cask nushi”'),
      findsOneWidget,
    );
    await tester.tap(find.text('Update'));
    await tester.tap(find.text('Update'), warnIfMissed: false);
    await tester.pump();
    found = newerUpdate('0.1.17', cask: 'nushi', installing: true);
    fake.emit(EventsResponse(update: found));
    started.complete(InstallUpdateResponse());
    await tester.pump();
    await tester.pump();
    expect(fake.calls.whereType<InstallUpdateRequest>(), hasLength(1));
    expect(find.text('Updating to Nushi 0.1.17…'), findsOneWidget);
    expect(
      find.descendant(of: updateToast, matching: find.byType(Spinner)),
      findsOneWidget,
    );
    final busy = tester.widget<Button>(
      find.widgetWithText(Button, 'Updating…'),
    );
    expect(busy.onPressed, isNull);
    await tester.tap(find.text('Updating…'), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls.whereType<InstallUpdateRequest>(), hasLength(1));
    d.dispose();
  }, variant: onMac);

  // Update keeps its width while it reads Updating…, so Release notes
  // beside it stays put.
  testWidgets('Update keeps its width while it reads Updating…', (
    tester,
  ) async {
    var found = newerUpdate('0.1.17', cask: 'nushi');
    final fake = updateDaemon(() => found);
    final d = await openWithUpdate(tester, fake);
    Finder button(String label) => find.descendant(
      of: updateToast,
      matching: find.byWidgetPredicate((w) => w is Button && w.label == label),
    );
    final rest = tester.getRect(button('Update'));
    final notes = tester.getRect(button('Release notes'));
    await render(tester, updateToast, 'busy_update_toast_idle');
    await tester.tap(button('Update'));
    await tester.pump();
    found = newerUpdate('0.1.17', cask: 'nushi', installing: true);
    fake.emit(EventsResponse(update: found));
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(button('Updating…')), rest);
    await render(tester, updateToast, 'busy_update_toast_busy');
    expect(tester.getRect(button('Release notes')), notes);
    d.dispose();
  }, variant: onMac);

  testWidgets('a failed install says why, with Copy, Retry and Release '
      'notes; Retry installs again', (tester) async {
    var found = newerUpdate('0.1.17', cask: 'nushi', error: notYet);
    final fake = updateDaemon(() => found);
    final d = await openWithUpdate(tester, fake);
    expect(find.text('Nushi 0.1.17 is available.'), findsOneWidget);
    expect(find.text(notYet), findsOneWidget);
    expect(toastButtons(tester), ['Copy', 'Retry', 'Release notes']);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(fake.calls.whereType<InstallUpdateRequest>(), hasLength(1));
    found = newerUpdate('0.1.17', cask: 'nushi', installing: true);
    fake.emit(EventsResponse(update: found));
    await tester.pump();
    await tester.pump();
    expect(find.text(notYet), findsNothing);
    expect(toastButtons(tester), ['Updating…', 'Release notes']);
    d.dispose();
  }, variant: onMac);

  testWidgets('installed with this app still running: it says to quit and '
      'open it again', (tester) async {
    final d = await openWithUpdate(
      tester,
      updateDaemon(
        () => newerUpdate('0.1.17', cask: 'nushi', installed: '0.1.17'),
      ),
    );
    expect(find.text('Nushi 0.1.17 is installed.'), findsOneWidget);
    expect(find.text('Quit Nushi and open it again.'), findsOneWidget);
    expect(toastButtons(tester), ['Release notes']);
    d.dispose();
  }, variant: onMac);

  testWidgets('an install the daemon refuses says why', (tester) async {
    final fake = updateDaemon(() => newerUpdate('0.1.17', cask: 'nushi'))
      ..on(
        (input) => input is InstallUpdateRequest
            ? throw ConnectException(
                Code.failedPrecondition,
                "Homebrew didn't install this Nushi",
              )
            : null,
      );
    final d = await openWithUpdate(tester, fake);
    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Homebrew didn't install this Nushi"), findsOneWidget);
    expect(toastButtons(tester), ['Update', 'Release notes']);
    d.dispose();
  }, variant: onMac);

  testWidgets('after a failure, Copy puts the Homebrew command on the '
      'clipboard', (tester) async {
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
    final d = await openWithUpdate(
      tester,
      updateDaemon(() => newerUpdate('0.1.17', cask: 'nushi', error: notYet)),
    );
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, 'brew update && brew upgrade --cask nushi');
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copy'), findsOneWidget);
    d.dispose();
  }, variant: onMac);
}
