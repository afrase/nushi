import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/remote_reset.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'settings_harness.dart';

const _aside = 'remote-key.json.unreadable-2026-11-22T10-00-00.000000';
const _toast = 'Remote access was reset. Pair your phones again.';

/// Remote access as the daemon says it after a reset, [on] or off.
Remote _reset({bool on = true}) => Remote(
  on: on,
  relay: 'wss://relay.example.com',
  state: on ? 'connected' : 'off',
  key: List.filled(32, 9),
  wasReset: RemoteReset(
    at: Int64(fixtureNow.millisecondsSinceEpoch),
    files: [_aside],
  ),
);

void main() {
  setUpAll(loadFonts);

  test('the reset says which files, Pair your phones again, and the old '
      "files' names", () {
    expect(
      resetWords(RemoteReset(files: [_aside])),
      "Remote access was reset because its key file couldn't be read. "
      'Pair your phones again. The old file is kept in the data folder as:',
    );
    expect(
      resetWords(
        RemoteReset(
          files: ['devices.json.unreadable-1', 'vapid.json.unreadable-1'],
        ),
      ),
      'Remote access was reset because its list of paired phones and its '
      "notifications' key file couldn't be read. Pair your phones again. "
      'The old files are kept in the data folder as:',
    );
  });

  // Settings › Remote access without the reset, then with it: the line in
  // the failure's color at the top, said once as a toast while remote
  // access is on, and gone once a phone is paired.
  for (final width in [1700.0, 720.0]) {
    testWidgets('Settings › Remote access says it was reset ($width)', (
      tester,
    ) async {
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.remote,
        size: Size(width, 900),
      );
      expect(find.byType(RemoteResetLine), findsNothing);
      await render(
        tester,
        find.byType(MaterialApp),
        'remote_reset_before_$width',
      );

      remoteState.value = _reset();
      await tester.pumpAndSettle();
      final line = find.textContaining('Remote access was reset because');
      expect(line, findsOne);
      expect(find.textContaining(_aside), findsOne);
      expect(find.text(_toast), findsOne);
      expect(remoteResetToasted.value, fixtureNow.millisecondsSinceEpoch);
      // The line comes before the switch's row, and keeps inside.
      expect(
        tester.getRect(line).bottom,
        lessThan(tester.getRect(find.text('Remote access').last).top),
      );
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(MaterialApp),
        'remote_reset_toast_$width',
      );
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text(_toast), findsNothing);
      await render(
        tester,
        find.byType(MaterialApp),
        'remote_reset_after_$width',
      );

      // Said again by the daemon (a reconnect): no second toast.
      remoteState.value = _reset()..state = 'connecting';
      await tester.pumpAndSettle();
      expect(find.text(_toast), findsNothing);

      // A phone paired: the daemon sends no reset, and the line goes.
      remoteState.value = Remote(on: true, state: 'connected');
      await tester.pumpAndSettle();
      expect(find.byType(RemoteResetLine), findsNothing);
      await closeView(tester, d);
    }, variant: onMac);
  }

  testWidgets('with remote access off, the reset is no toast, only the line', (
    tester,
  ) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.remote,
    );
    remoteState.value = _reset(on: false);
    await tester.pumpAndSettle();
    expect(find.byType(RemoteResetLine), findsOne);
    expect(find.text(_toast), findsNothing);
    expect(remoteResetToasted.value, 0);
    await closeView(tester, d);
  }, variant: onMac);
}
