// The end-to-end tests' rig (remote_e2e_test, phone_link_test and the web
// test's web/mac_side.dart): the real nushid and nushi-relay built into a
// folder of their own in /tmp, the fake agent as Claude, the relay and the
// daemon started there. Each test makes its own client steps on it.
//
// dart:io only: web/mac_side.dart runs in a hybrid isolate, which resolves
// no packages, and imports this file by its relative path.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The version the fake `claude` CLI says it is.
const claudeVersion = '2.1.310';

/// The version of Claude's adapter, as installed in the data folder.
const adapterVersion = '0.94.0';

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
  /// /tmp whose name starts with [name], and sets Claude up there: its CLI
  /// on the daemon's PATH, its adapter in the data folder, run by a "node"
  /// that runs the fake agent instead.
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
      ('fakeagent', './internal/acptest/fakeagent'),
    ]) {
      final r = await Process.run('go', [
        'build',
        '-o',
        '$path/bin/$out',
        pkg,
      ], workingDirectory: root);
      if (r.exitCode != 0) throw StateError('building $pkg: ${r.stderr}');
    }
    for (final (name, body) in [
      ('node', 'exec $path/bin/fakeagent'),
      ('claude', 'echo $claudeVersion'),
    ]) {
      final f = File('$path/bin/$name');
      await f.writeAsString('#!/bin/sh\n$body\n');
      await Process.run('chmod', ['+x', f.path]);
    }
    final adapter = Directory(
      '$path/data/agents/claude/node_modules/@agentclientprotocol/claude-agent-acp',
    );
    await adapter.create(recursive: true);
    await File('${adapter.path}/package.json').writeAsString(
      '{"version": "$adapterVersion", "bin": {"claude-agent-acp": "dist/index.js"}}',
    );
  }

  /// Starts a relay on [port] (0: any free one) with [args], once it
  /// listens; it becomes [relay].
  Future<void> startRelay({int port = 0, List<String> args = const []}) async {
    relay = await Process.start('$path/bin/nushi-relay', [
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
    final daemon = await Process.start(
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

/// A rig with its relay (started with [relayArgs]) and daemon running.
Future<Rig> startRig(String name, {List<String> relayArgs = const []}) async {
  final rig = await Rig.build(name);
  try {
    await rig.startRelay(args: relayArgs);
    await rig.startDaemon();
  } on Object {
    await rig.close();
    rethrow;
  }
  return rig;
}
