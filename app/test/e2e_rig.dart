// The end-to-end tests' rig (remote_e2e_test, phone_link_test and the web
// test's web/mac_side.dart): the real nushid and nushi-relay built into a
// folder of their own in /tmp, the fake agent as oh-my-pi (built as the
// `omp` on the daemon's PATH: omp is a plain program Nushi starts as it
// is, with no adapter to set up and no version it needs), the relay and
// the daemon started there, each through startChild, so they end with the
// test's process however it ends. Each test makes its own client steps on
// it.
//
// dart:io only: web/mac_side.dart runs in a hybrid isolate, which resolves
// no packages, and imports this file by its relative path.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The agent the rig's chats run: the fake agent, as oh-my-pi.
const rigAgent = 'omp';

/// Waits until [ok] says yes, asking every 50 ms; a [TimeoutException]
/// after [within].
Future<void> until(
  FutureOr<bool> Function() ok, {
  Duration within = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(within);
  while (!await ok()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('waited too long');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Starts [executable] with [arguments] as the rig's child that ends with
/// the test, however the test's process ends: on macOS and Linux it runs
/// under a small shell that holds a pipe from this process (its stdin) and
/// stops the child (SIGTERM) when that pipe closes, as it does when this
/// process is killed, even by SIGKILL, which no handler here would see.
/// The shell passes on a SIGTERM to the child and ends with it, with its
/// exit code; the child's output is the shell's, so it reads as the
/// child's own. On Windows, where the rig doesn't run, the child is
/// started as it is.
Future<Process> startChild(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
}) {
  if (Platform.isWindows) {
    return Process.start(
      executable,
      arguments,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
    );
  }
  return Process.start(
    '/bin/sh',
    ['-c', _supervised, 'sh', executable, ...arguments],
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );
}

/// The shell [startChild] runs a child under: the child with no stdin, a
/// watcher that reads the pipe from the test's process until it closes
/// and then stops the child, a SIGTERM passed on, and the child's exit
/// code its own once the child has ended (the wait again after a SIGTERM
/// cut it short).
const _supervised = r"""
exec 3<&0
"$@" 0</dev/null 3<&- &
child=$!
(while read -r _ <&3; do :; done; kill -TERM "$child" 2>/dev/null) \
  0</dev/null 1>/dev/null 2>&1 &
watch=$!
exec 3<&-
trap 'kill -TERM "$child" 2>/dev/null' TERM
wait "$child"
code=$?
while kill -0 "$child" 2>/dev/null; do
  wait "$child"
  code=$?
done
kill "$watch" 2>/dev/null
exit "$code"
""";

/// The binaries built and set up in [path] (bin, data, home, work): the
/// relay and the daemon once started, and what a client needs of them.
class Rig {
  new _(this.path);

  /// The rig's folder: short, as the socket's path has a length limit.
  final String path;
  final _procs = <Process>[];

  /// The relay running now (see [startRelay]).
  late Process relay;

  /// The relay's address, host:port.
  late String relayAddress;

  /// The daemon's token, for the socket's calls.
  late String token;

  String get relayUrl => 'ws://$relayAddress';
  int get relayPort => int.parse(relayAddress.split(':').last);
  String get socket => '$path/data/nushid.sock';
  String get work => '$path/work';

  /// Builds nushid, nushi-relay and the fake agent into a new folder in
  /// /tmp whose name starts with [name], the fake agent as the `omp` on
  /// the daemon's PATH.
  static Future<Rig> build(String name) async {
    final rig = Rig._((await Directory('/tmp').createTemp(name)).path);
    try {
      await rig._setUp();
    } on Object {
      await rig.close();
      rethrow;
    }
    return rig;
  }

  Future<void> _setUp() async {
    final root = Directory.current.parent.path; // tests run in app/
    for (final d in ['bin', 'data', 'home', 'work']) {
      await Directory('$path/$d').create();
    }
    for (final (out, pkg) in [
      ('nushid', './cmd/nushid'),
      ('nushi-relay', './cmd/nushi-relay'),
      ('omp', './internal/acptest/fakeagent'),
    ]) {
      final r = await Process.run('go', [
        'build',
        '-o',
        '$path/bin/$out',
        pkg,
      ], workingDirectory: root);
      if (r.exitCode != 0) throw StateError('building $pkg: ${r.stderr}');
    }
  }

  /// Starts a relay on [port] (0: any free one) with [args], once it
  /// listens; it becomes [relay].
  Future<void> startRelay({int port = 0, List<String> args = const []}) async {
    relay = await startChild('$path/bin/nushi-relay', [
      '-addr',
      '127.0.0.1:$port',
      ...args,
    ]);
    _procs.add(relay);
    // Its first line names its address; the rest is read and dropped.
    final started = Completer<String>();
    relay.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!started.isCompleted) started.complete(line);
          },
          onDone: () {
            if (!started.isCompleted) {
              started.completeError(StateError('the relay ended'));
            }
          },
        );
    relayAddress = (await started.future).split(' ').last;
  }

  /// Starts nushid on the rig's data folder, its agents on the rig's PATH
  /// (not the login shell's), once its socket is there.
  Future<void> startDaemon() async {
    final daemon = await startChild(
      '$path/bin/nushid',
      [],
      environment: {
        'PATH': '$path/bin:/usr/bin:/bin',
        'HOME': '$path/home',
        'NUSHI_DATA': '$path/data',
        'NUSHI_SHELL_ENV': 'off',
      },
      includeParentEnvironment: false,
    );
    _procs.add(daemon);
    unawaited(daemon.stdout.drain<void>());
    unawaited(daemon.stderr.drain<void>());
    await until(() => File(socket).existsSync());
    token = (await File('$path/data/token').readAsString()).trim();
  }

  /// Stops what it started and deletes its folder.
  Future<void> close() async {
    for (final p in _procs) {
      p.kill();
      await p.exitCode;
    }
    await Directory(path).delete(recursive: true);
  }
}

/// A rig with its relay and daemon running.
Future<Rig> startRig(String name) async {
  final rig = await Rig.build(name);
  try {
    await rig.startRelay();
    await rig.startDaemon();
  } on Object {
    await rig.close();
    rethrow;
  }
  return rig;
}
