// The phone's link to the Mac when its channel drops (ADR 0054): the real
// nushid and nushi-relay on localhost, the fake agent as Claude, and the
// phone's Daemon and Link on the relay transport. A drop mid-stream,
// mid-call, while hidden, and the relay restarting: the phone reconnects,
// subscribes again and fetches what shows, with no raw error left.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/link.dart';
import 'package:remote_transport/remote_transport.dart';
import 'package:uds_transport/uds_transport.dart';

connect.Transport _proto(Http2ClientTransport t, {String? token}) =>
    protocol.Transport(
      baseUrl: 'http://nushid',
      codec: const ProtoCodec(),
      httpClient: createHttpClient(transport: t),
      acceptCompressions: const [Gzip()],
      interceptors: [
        if (token != null)
          <I extends Object, O extends Object>(connect.AnyFn<I, O> next) =>
              (req) {
                req.headers['authorization'] = 'Bearer $token';
                return next(req);
              },
      ],
    );

Future<void> _until(
  bool Function() ok, {
  Duration within = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(within);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('waited too long');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory tmp;
  late Process relay;
  late int port;
  late NushiServiceClient mac;
  late RelayTransport transport;
  late Daemon daemon;
  late Link link;
  late String chat;
  final procs = <Process>[];

  Future<void> startRelay([int at = 0]) async {
    relay = await Process.start('${tmp.path}/bin/nushi-relay', [
      '-addr',
      '127.0.0.1:$at',
    ]);
    procs.add(relay);
    final started = await relay.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    port = int.parse(started.split(':').last);
  }

  setUpAll(() async {
    tmp = await Directory('/tmp').createTemp('npl');
    for (final d in ['bin', 'data', 'home', 'work']) {
      await Directory('${tmp.path}/$d').create();
    }
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
      ], workingDirectory: '..');
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
    await startRelay();
    final nushid = await Process.start(
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
    procs.add(nushid);
    unawaited(nushid.stdout.drain<void>());
    unawaited(nushid.stderr.drain<void>());
    await _until(() => File('${tmp.path}/data/nushid.sock').existsSync());
    final token = (await File('${tmp.path}/data/token').readAsString()).trim();
    mac = NushiServiceClient(
      _proto(UdsTransport('${tmp.path}/data/nushid.sock'), token: token),
    );
    await mac.setRemote(
      SetRemoteRequest(on: true, relay: 'ws://127.0.0.1:$port'),
    );
    var state = '';
    await _until(() {
      unawaited(
        mac.getRemote(GetRemoteRequest()).then((r) => state = r.remote.state),
      );
      return state == 'connected';
    });

    final qr = (await mac.startPairing(StartPairingRequest())).qr;
    final shown = Completer<String>();
    final pairing = pair(
      PairingOffer.parse(qr),
      device: await KeyPair.make(),
      name: 'Link test',
      onCode: shown.complete,
    );
    final code = await shown.future;
    var asked = '';
    await _until(() {
      unawaited(
        mac
            .getRemote(GetRemoteRequest())
            .then((r) => asked = r.remote.pairing.code),
      );
      return asked == code;
    });
    await mac.confirmPairing(ConfirmPairingRequest(code: code, allow: true));
    final paired = await pairing;
    transport = paired.$2;
    daemon = Daemon(transport: _proto(transport), remote: true);
    link = Link(daemon, reset: transport.reset, live: () => transport.live)
      ..start();
    await _until(() => daemon.connected);

    chat = (await mac.startChat(
      StartChatRequest(agent: 'claude', folder: '${tmp.path}/work'),
    )).chatId;
    await mac.sendPrompt(SendPromptRequest(chatId: chat, text: 'first'));
    await _until(() => daemon.chats.containsKey(chat));
    daemon.select(chat);
    await _until(
      () =>
          daemon.chats[chat]!.loaded &&
          daemon.chats[chat]!.items.any((i) => i.text.contains('first')),
    );
  });

  tearDownAll(() async {
    // The channel first: the daemon's event stream ends with it, as it
    // does when a page goes.
    link.dispose();
    await transport.close();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    daemon.dispose();
    for (final p in procs) {
      p.kill();
      await p.exitCode;
    }
    await tmp.delete(recursive: true);
  });

  bool shows(String text) =>
      daemon.chats[chat]!.items.any((i) => i.text.contains(text));

  Future<void> prompt(String text) async {
    for (;;) {
      try {
        await mac.sendPrompt(SendPromptRequest(chatId: chat, text: text));
        return;
      } on connect.ConnectException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  test('the channel drops mid-stream: what came meanwhile shows', () async {
    await transport.reset(); // the events stream ends with the channel
    await prompt('while away');
    await link.check();
    expect(daemon.connected, isTrue);
    await _until(() => shows('while away'));
    expect(daemon.chats[chat]!.loadError, isEmpty);
  });

  test('the channel drops mid-call: the load is tried again', () async {
    final c = daemon.chats[chat]!..unload();
    daemon.select(chat); // GetChat on its way
    await transport.reset();
    await _until(() => c.loaded, within: const Duration(seconds: 20));
    expect(c.loadError, isEmpty);
    expect(shows('first'), isTrue);
  });

  test('hidden a while: back, it dials again at once', () async {
    Link.away = Duration.zero;
    addTearDown(() => Link.away = const Duration(seconds: 30));
    link.visible(shown: false);
    await prompt('while hidden');
    final calls = transport;
    link.visible(shown: true);
    await _until(() => daemon.connected && shows('while hidden'));
    expect(identical(calls, transport), isTrue);
  });

  test('the relay restarts: the Mac and the phone come back', () async {
    final was = port;
    relay.kill(ProcessSignal.sigkill);
    await relay.exitCode;
    // Its socket is gone: the next ping fails, and the try after it says
    // the relay is down.
    await link.check();
    expect(daemon.connected, isFalse);
    await link.check(user: true);
    expect(link.why, Unreachable.relay);
    expect(link.failures, greaterThan(0));
    await startRelay(was);
    await prompt('after the restart');
    // The Mac's daemon waits at the relay again (backing off a second or
    // two); the phone's next try finds it.
    await _until(() {
      if (!link.trying) unawaited(link.check(user: true));
      return daemon.connected;
    });
    await _until(() => shows('after the restart'));
    expect(link.failures, 0);
    expect(link.seen, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
