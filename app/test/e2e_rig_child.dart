// A process for e2e_rig_test.dart to kill: it starts a long-lived child
// (a shell that becomes `sleep`) through the rig's startChild, prints the
// child's pid, which the child itself says, and waits.
//
// dart:io only, run by `dart` from app/, so it imports the rig by its
// relative path.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'e2e_rig.dart';

Future<void> main() async {
  final child = await startChild('/bin/sh', ['-c', r'echo $$; exec sleep 600']);
  final pid = Completer<String>();
  child.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    line,
  ) {
    if (!pid.isCompleted) pid.complete(line);
  });
  stdout.writeln(await pid.future);
  await child.exitCode;
}
