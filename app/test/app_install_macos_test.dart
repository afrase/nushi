import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_install_macos.dart';
import 'package:nushi/daemon.dart';

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

  test('outside a bundle there is no daemon, build or version, and the '
      'data folder is in Application Support', () {
    final mac = MacAppInstall();
    expect((mac.daemon, mac.daemonBuild, mac.version), (null, null, ''));
    expect(
      mac.dataFolder,
      '${Platform.environment['HOME']}/Library/Application Support/Nushi',
    );
  });

  // Arch has no lsof by default: a restart there must say the daemon
  // didn't stop, not throw from here before it tried.
  test('without lsof, a stop stops nothing rather than throwing', () {
    final dir = Directory.systemTemp.createTempSync('nushi-stop-');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(
      () => stopByLsof(dir.path, lsof: '${dir.path}/no-lsof'),
      returnsNormally,
    );
  });

  // Launch Services can refuse the helper (damaged, quarantined): the
  // daemon never ran, so app.log is where that shows.
  test(
    'an open that fails is logged with its exit and stderr, not thrown',
    () async {
      final app = Directory.systemTemp.createTempSync('nushi-app-');
      addTearDown(() => app.deleteSync(recursive: true));
      Directory(helperIn(app.path)).createSync(recursive: true);
      final opened = <List<String>>[];
      final mac = MacAppInstall(
        executable: '${app.path}/Contents/MacOS/Nushi',
        run: (program, args) async {
          opened.add([program, ...args]);
          return ProcessResult(
            1,
            1,
            '',
            'LSOpenURLsWithRole() failed: -10810\n',
          );
        },
      );
      await mac.launch('/tmp/nd');
      expect(opened.single.first, '/usr/bin/open');
      final log = File('$dataDir/app.log').readAsStringSync();
      expect(log, contains("the bundled daemon didn't start"));
      expect(log, contains('exit=1'));
      expect(log, contains('-10810'));

      await expectLater(
        MacAppInstall(
          executable: '${app.path}/Contents/MacOS/Nushi',
          run: (_, _) =>
              throw const ProcessException('/usr/bin/open', [], 'no open'),
        ).launch('/tmp/nd'),
        completes,
      );
      expect(File('$dataDir/app.log').readAsStringSync(), contains('no open'));
    },
  );
}
