// End to end through the relay (ADR 0034): the real nushid and
// nushi-relay on localhost, the fake agent as Claude, and the app's
// generated client on the phone's transport. A phone pairs, lists chats,
// starts one, prompts it, answers its permission card, gets the streamed
// events, and is revoked.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:remote_transport/remote_transport.dart';
import 'package:uds_transport/uds_transport.dart';

NushiServiceClient _client(Http2ClientTransport t, {String? token}) => NushiServiceClient(
  protocol.Transport(
    baseUrl: 'http://nushid',
    codec: const ProtoCodec(),
    httpClient: createHttpClient(transport: t),
    interceptors: [
      if (token != null)
        <I extends Object, O extends Object>(connect.AnyFn<I, O> next) => (req) {
          req.headers['authorization'] = 'Bearer $token';
          return next(req);
        },
    ],
  ),
);

Future<void> _until(Future<bool> Function() ok) async {
  for (var i = 0; i < 300; i++) {
    if (await ok()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('waited too long');
}

void main() {
  late Directory tmp;
  final procs = <Process>[];

  setUpAll(() async {
    // A short path: the socket's path has a length limit.
    tmp = await Directory('/tmp').createTemp('nre');
    for (final d in ['bin', 'data', 'home', 'work']) {
      await Directory('${tmp.path}/$d').create();
    }
    for (final (out, pkg) in [('nushid', './cmd/nushid'), ('nushi-relay', './cmd/nushi-relay'), ('fakeagent', './acp/acptest/fakeagent')]) {
      final r = await Process.run('go', ['build', '-o', '${tmp.path}/bin/$out', pkg], workingDirectory: '..');
      if (r.exitCode != 0) throw StateError('building $pkg: ${r.stderr}');
    }
    // Agents start through npx, which says where the program is.
    final npx = File('${tmp.path}/bin/npx');
    await npx.writeAsString('#!/bin/sh\necho ${tmp.path}/bin/fakeagent\n');
    await Process.run('chmod', ['+x', npx.path]);
  });

  tearDownAll(() async {
    for (final p in procs) {
      p.kill();
      await p.exitCode;
    }
    await tmp.delete(recursive: true);
  });

  test('a phone through the relay', () async {
    final relay = await Process.start('${tmp.path}/bin/nushi-relay', ['-addr', '127.0.0.1:0']);
    procs.add(relay);
    final started = await relay.stderr.transform(utf8.decoder).transform(const LineSplitter()).first;
    final relayUrl = 'ws://${started.split(' ').last}';
    final daemon = await Process.start('${tmp.path}/bin/nushid', [], environment: {
      'PATH': '${tmp.path}/bin:/usr/bin:/bin',
      'HOME': '${tmp.path}/home',
      'NUSHI_DATA': '${tmp.path}/data',
    }, includeParentEnvironment: false);
    procs.add(daemon);
    daemon.stdout.drain<void>();
    daemon.stderr.drain<void>();
    await _until(() async => File('${tmp.path}/data/nushid.sock').exists());
    final token = (await File('${tmp.path}/data/token').readAsString()).trim();
    final mac = _client(UdsTransport('${tmp.path}/data/nushid.sock'), token: token);

    await mac.setRemote(SetRemoteRequest(on: true, relay: relayUrl));
    await _until(() async => (await mac.getRemote(GetRemoteRequest())).remote.state == 'connected');

    // Pairing: the QR code, the code on both screens, Allow on the Mac.
    final qr = (await mac.startPairing(StartPairingRequest())).qr;
    final shown = Completer<String>();
    final device = await KeyPair.make();
    final pairing = pair(PairingOffer.parse(qr), device: device, name: 'Test phone', onCode: shown.complete);
    final code = await shown.future;
    await _until(() async => (await mac.getRemote(GetRemoteRequest())).remote.pairing.code == code);
    expect((await mac.getRemote(GetRemoteRequest())).remote.pairing.name, 'Test phone');
    await mac.confirmPairing(ConfirmPairingRequest(code: code, allow: true));
    final (paired, transport) = await pairing;
    final phone = _client(transport);

    // The phone is a full client, with the same generated client.
    expect((await phone.ping(PingRequest())).apiVersion, greaterThanOrEqualTo(47));
    expect((await phone.listChats(ListChatsRequest())).chats, isEmpty);
    final events = StreamIterator(phone.events(EventsRequest()));
    expect(await events.moveNext(), isTrue); // live
    final chat = (await phone.startChat(StartChatRequest(agent: 'claude', folder: '${tmp.path}/work'))).chatId;
    await phone.sendPrompt(SendPromptRequest(chatId: chat, text: 'hello from the phone'));
    Future<EventsResponse> next(bool Function(EventsResponse) ok) async {
      while (await events.moveNext()) {
        if (events.current.chatId == chat && ok(events.current)) return events.current;
      }
      throw StateError('events ended');
    }

    await next((e) => e.hasItem() && e.item.item.text.contains('hello from the phone') && e.item.item.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE);
    await phone.sendPrompt(SendPromptRequest(chatId: chat, text: 'permission please'));
    final card = await next((e) => e.hasItem() && e.item.item.kind == ItemKind.ITEM_KIND_PERMISSION && e.item.item.status == 'pending');
    await phone.answerPermission(AnswerPermissionRequest(chatId: chat, itemId: card.item.item.id, optionId: 'allow'));
    await next((e) => e.hasItem() && e.item.item.text.contains('Permission: selected allow'));
    expect((await mac.listChats(ListChatsRequest())).chats.map((c) => c.id), contains(chat));

    // A new channel, as after the app comes back: IK on the daemon's id.
    await transport.close();
    final again = _client(RelayTransport(paired, device));
    expect((await again.listChats(ListChatsRequest())).chats.map((c) => c.id), contains(chat));
    final devices = (await mac.getRemote(GetRemoteRequest())).remote.devices;
    expect(devices.single.name, 'Test phone');
    await _until(() async => (await mac.getRemote(GetRemoteRequest())).remote.devices.single.connected);

    // Revoked, the phone is out at once, and stays out.
    await mac.revokeDevice(RevokeDeviceRequest(id: devices.single.id));
    await expectLater(again.listChats(ListChatsRequest()), throwsA(isA<connect.ConnectException>()));
    await expectLater(_client(RelayTransport(paired, device)).listChats(ListChatsRequest()), throwsA(isA<connect.ConnectException>()));

    await mac.setRemote(SetRemoteRequest(on: false, relay: relayUrl));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
