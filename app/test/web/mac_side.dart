// The Mac's side of web_e2e_test.dart, in the VM (a hybrid isolate): the
// real nushid and nushi-relay (serving a web app, so it takes the test
// page's origin), the fake agent as Claude, and the Mac's calls on the
// daemon's socket.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// The channel is used untyped: see below.
// ignore_for_file: avoid_dynamic_calls

// A hybrid isolate under flutter test resolves no packages: dart:io only,
// the channel untyped, and the Mac's calls as Connect's JSON through curl
// (the socket speaks HTTP/2 only).

/// The Mac's side, for the test at [origin]; channel is a StreamChannel.
Future<void> hybridMain(dynamic channel, Object? origin) async {
  final tmp = await Directory('/tmp').createTemp('nwe');
  final procs = <Process>[];
  Future<void> cleanUp() async {
    for (final p in procs) {
      p.kill();
      await p.exitCode;
    }
    await tmp.delete(recursive: true);
  }

  try {
    final root = Directory.current.parent.path; // tests run in app/
    for (final d in ['bin', 'data', 'home', 'work', 'web']) {
      await Directory('${tmp.path}/$d').create();
    }
    await File('${tmp.path}/web/index.html').writeAsString('<!doctype html>');
    for (final (out, pkg) in [
      ('nushid', './cmd/nushid'),
      ('nushi-relay', './cmd/nushi-relay'),
      ('fakeagent', './internal/acptest/fakeagent'),
    ]) {
      final r = await Process.run('go', [
        'build',
        '-o',
        '${tmp.path}/bin/$out',
        pkg,
      ], workingDirectory: root);
      if (r.exitCode != 0) throw StateError('building $pkg: ${r.stderr}');
    }
    for (final (name, body) in [
      ('node', 'exec ${tmp.path}/bin/fakeagent'),
      ('claude', 'echo 2.1.310'),
    ]) {
      final f = File('${tmp.path}/bin/$name');
      await f.writeAsString('#!/bin/sh\n$body\n');
      await Process.run('chmod', ['+x', f.path]);
    }
    final adapter = Directory(
      '${tmp.path}/data/agents/claude/node_modules/@agentclientprotocol/claude-agent-acp',
    );
    await adapter.create(recursive: true);
    await File('${adapter.path}/package.json').writeAsString(
      '{"version": "0.94.0", "bin": {"claude-agent-acp": "dist/index.js"}}',
    );

    final relay = await Process.start('${tmp.path}/bin/nushi-relay', [
      '-addr',
      '127.0.0.1:0',
      '-web',
      '${tmp.path}/web',
      '-origin',
      origin! as String,
    ]);
    procs.add(relay);
    final started = await relay.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final relayUrl = 'ws://${started.split(' ').last}';
    final daemon = await Process.start(
      '${tmp.path}/bin/nushid',
      [],
      environment: {
        'PATH': '${tmp.path}/bin:/usr/bin:/bin',
        'HOME': '${tmp.path}/home',
        'NUSHI_DATA': '${tmp.path}/data',
        'NUSHI_SHELL_ENV': 'off',
      },
      includeParentEnvironment: false,
    );
    procs.add(daemon);
    unawaited(daemon.stdout.drain<void>());
    unawaited(daemon.stderr.drain<void>());
    final sock = File('${tmp.path}/data/nushid.sock');
    for (var i = 0; i < 200 && !sock.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final token = (await File('${tmp.path}/data/token').readAsString()).trim();
    Future<Map<String, Object?>> mac(String method, [Object? body]) async {
      final r = await Process.run('curl', [
        '-sS',
        '--unix-socket',
        sock.path,
        '--http2-prior-knowledge',
        '-H',
        'Authorization: Bearer $token',
        '-H',
        'Content-Type: application/json',
        '-d',
        jsonEncode(body ?? {}),
        'http://nushid/nushi.v1.NushiService/$method',
      ]);
      final out = (jsonDecode(r.stdout as String) as Map)
          .cast<String, Object?>();
      if (out['code'] != null) throw StateError('$method: ${out['message']}');
      return out;
    }

    Future<Map<String, Object?>> remote() async =>
        ((await mac('GetRemote'))['remote']! as Map).cast<String, Object?>();

    await mac('SetRemote', {'on': true, 'relay': relayUrl});
    for (var i = 0; i < 200; i++) {
      if ((await remote())['state'] == 'connected') {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // The link the Mac's Copy link gives: the QR code's text, in the
    // fragment of the relay's own address.
    final qr = (await mac('StartPairing'))['qr']! as String;
    final http = relayUrl.replaceFirst('ws://', 'http://');
    channel.sink.add({
      'link': '$http/#${qr.substring('nushi://'.length)}',
      'folder': '${tmp.path}/work',
    });

    await for (final Object? m in channel.stream as Stream<Object?>) {
      final ask = (m! as Map).cast<String, Object?>();
      switch (ask['do']) {
        case 'confirm':
          // Allow only the phone whose code the Mac shows.
          var code = '';
          for (var i = 0; i < 200 && code.isEmpty; i++) {
            final p = (await remote())['pairing'] as Map? ?? {};
            code = p['code'] as String? ?? '';
            if (code.isEmpty) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
          }
          final allow = code == ask['code'];
          await mac('ConfirmPairing', {'code': code, 'allow': allow});
          channel.sink.add({'allowed': allow});
        case 'devices':
          channel.sink.add({
            'file': await File('${tmp.path}/data/devices.json').readAsString(),
            'remote': jsonEncode(await remote()),
          });
        case 'done':
          await cleanUp();
          channel.sink.add({'done': true});
          return;
      }
    }
  } on Object catch (e) {
    channel.sink.add({'error': '$e'});
    await cleanUp();
  }
}
