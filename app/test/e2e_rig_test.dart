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
    // Killed however the test ends; its child then goes with it.
    addTearDown(() => helper.kill(ProcessSignal.sigkill));
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

  test('the process startChild returns is the child itself', () async {
    // A test that kills a child (the relay, to restart it) and awaits its
    // exit code relies on the child being gone by then.
    final child = await startChild('/bin/sh', [
      '-c',
      r'echo $$; exec sleep 600',
    ]);
    addTearDown(() => child.kill(ProcessSignal.sigkill));
    unawaited(child.stderr.drain<void>());
    final pid = int.parse(
      await child.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first,
    );
    expect(pid, child.pid, reason: "the returned process is the child's");

    child.kill(ProcessSignal.sigkill);
    await child.exitCode;
    expect(await _alive(pid), isFalse, reason: 'gone once its exit is seen');
  });
}

/// Whether a process [pid] is there (kill -0, which signals nothing).
Future<bool> _alive(int pid) async =>
    (await Process.run('kill', ['-0', '$pid'])).exitCode == 0;
