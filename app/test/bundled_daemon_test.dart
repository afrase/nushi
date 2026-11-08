import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/bundled_daemon.dart';

void main() {
  test('the daemon is opened as the helper app, through the login shell', () {
    final helper = helperIn('/Applications/Nushi.app');
    expect(helper, '/Applications/Nushi.app/Contents/Helpers/Nushi Daemon.app');
    expect(openHelper(helper, null), ['-n', '-g', helper, '--args', '-login']);
    expect(openHelper(helper, '/tmp/dev'), [
      '-n',
      '-g',
      '--env',
      'NUSHI_DATA=/tmp/dev',
      helper,
      '--args',
      '-login',
    ]);
  });

  // Arch has no lsof by default: a restart there must say the daemon
  // didn't stop, not throw from here before it tried.
  test('without lsof, a stop stops nothing rather than throwing', () {
    final dir = Directory.systemTemp.createTempSync('nushi-stop-');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(
      () => stopDaemon(dir.path, lsof: '${dir.path}/no-lsof'),
      returnsNormally,
    );
  });
}
