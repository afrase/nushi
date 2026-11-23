// The e2e rig's children (the daemon and the relay) end with the test's
// process, however it ends: an interrupted or timed-out run once left them
// running from their /tmp folders.
@TestOn('mac-os || linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'e2e_rig.dart';

void main() {
  test('a child of the rig ends when its process is killed', () async {
    final helper = await Process.start('dart', ['test/e2e_rig_child.dart']);
    unawaited(helper.stderr.drain<void>());
    final pid = int.parse(
      await helper.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => int.tryParse(line) != null), // past any notice
    );
    addTearDown(() => Process.killPid(pid, ProcessSignal.sigkill));
    expect(await _alive(pid), isTrue, reason: 'the child runs');

    helper.kill(ProcessSignal.sigkill);
    await helper.exitCode;
    await until(() async => !await _alive(pid));
  });
}

/// Whether a process [pid] is there (kill -0, which signals nothing).
Future<bool> _alive(int pid) async =>
    (await Process.run('kill', ['-0', '$pid'])).exitCode == 0;
