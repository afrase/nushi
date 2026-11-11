import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// What the update card's tests share (update_toast_test.dart, the check
// and where the card sits; update_install_test.dart, its Update button):
// a daemon that found a newer version, the app open on it, the card.

final macOSOnly = TargetPlatformVariant.only(TargetPlatform.macOS);
const _url = 'https://github.com/afrase/nushi/releases/tag/v0.1.17';

/// The daemon found [v]; its install of it is running ([installing]),
/// failed with [error], or brought [installed].
UpdateCheck newerUpdate(
  String v, {
  bool installing = false,
  String error = '',
  String installed = '',
}) => UpdateCheck(
  version: v,
  url: _url,
  latest: v,
  checkedMs: Int64(fixtureNow.millisecondsSinceEpoch),
  installing: installing,
  installError: error,
  installed: installed,
);

/// A daemon (0.1.16, of API [api]) whose check found [found]; Check for
/// updates finds [checks] (else what it found).
FakeDaemon updateDaemon(
  UpdateCheck Function() found, {
  UpdateCheck? checks,
  int api = apiVersion,
}) => FakeDaemon([chat('c', 'claude', 'Fix the login redirect')])
  ..settings = Settings(sleepAfterMinutes: 30, checkUpdates: true)
  ..answer = (input) => switch (input) {
    PingRequest() => PingResponse(
      apiVersion: api,
      version: '0.1.16',
      update: found(),
    ),
    CheckForUpdatesRequest() => CheckForUpdatesResponse(
      update: checks ?? found(),
    ),
    _ => null,
  };

/// The card's states with Homebrew's cask: what the daemon says in each,
/// and the buttons it then has, in order.
const notYet = "Homebrew doesn't have 0.1.17 yet. Try again in a few minutes.";
final toastStates = <String, (UpdateCheck, List<String>)>{
  'update': (newerUpdate('0.1.17'), ['Update', 'Release notes']),
  'updating': (
    newerUpdate('0.1.17', installing: true),
    ['Updating…', 'Release notes'],
  ),
  'failed': (
    newerUpdate('0.1.17', error: notYet),
    ['Copy', 'Retry', 'Release notes'],
  ),
  'installed': (newerUpdate('0.1.17', installed: '0.1.17'), ['Release notes']),
};

/// The card's buttons' labels, left to right.
List<String> toastButtons(WidgetTester tester) => [
  for (final b in tester.widgetList<Button>(
    find.descendant(of: updateToast, matching: find.byType(Button)),
  ))
    b.label,
];

Future<Daemon> openWithUpdate(
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

final Finder updateToast = find.byKey(const ValueKey('update-toast'));
