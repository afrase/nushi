// The phone's link to the Mac when its channel drops (ADR 0054): the real
// nushid and nushi-relay on localhost, the fake agent as Claude, and the
// phone's Daemon and Link on the relay transport. A drop mid-stream,
// mid-call, while hidden, and the relay restarting: the phone reconnects,
// subscribes again and fetches what shows, with no raw error left.
import 'dart:async';
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

import 'e2e_rig.dart';

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

void main() {
  late Rig rig;
  late NushiServiceClient mac;
  late RelayTransport transport;
  late Daemon daemon;
  late Link link;
  late String chat;

  setUpAll(() async {
    rig = await startRig('npl');
    mac = NushiServiceClient(
      _proto(UdsTransport(rig.socket), token: rig.token),
    );
    await mac.setRemote(SetRemoteRequest(on: true, relay: rig.relayUrl));
    await until(
      () async =>
          (await mac.getRemote(GetRemoteRequest())).remote.state == 'connected',
    );

    final qr = (await mac.startPairing(StartPairingRequest())).qr;
    final shown = Completer<String>();
    final pairing = pair(
      PairingOffer.parse(qr),
      device: await KeyPair.make(),
      name: 'Link test',
      onCode: shown.complete,
    );
    final code = await shown.future;
    await until(
      () async =>
          (await mac.getRemote(GetRemoteRequest())).remote.pairing.code == code,
    );
    await mac.confirmPairing(ConfirmPairingRequest(code: code, allow: true));
    final paired = await pairing;
    transport = paired.$2;
    daemon = Daemon(transport: _proto(transport), remote: true);
    link = Link(daemon, reset: transport.reset, live: () => transport.live)
      ..start();
    await until(() => daemon.connected);

    chat = (await mac.startChat(
      StartChatRequest(agent: 'claude', folder: rig.work),
    )).chatId;
    await mac.sendPrompt(SendPromptRequest(chatId: chat, text: 'first'));
    await until(() => daemon.chats.containsKey(chat));
    daemon.select(chat);
    await until(
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
    await rig.close();
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
    await until(() => shows('while away'));
    expect(daemon.chats[chat]!.loadError, isEmpty);
  });

  test('the channel drops mid-call: the load is tried again', () async {
    final c = daemon.chats[chat]!..unload();
    daemon.select(chat); // GetChat on its way
    await transport.reset();
    await until(() => c.loaded, within: const Duration(seconds: 20));
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
    await until(() => daemon.connected && shows('while hidden'));
    expect(identical(calls, transport), isTrue);
  });

  test('the relay restarts: the Mac and the phone come back', () async {
    final was = rig.relayPort;
    rig.relay.kill(ProcessSignal.sigkill);
    await rig.relay.exitCode;
    // Its socket is gone: the next ping fails, and the try after it says
    // the relay is down.
    await link.check();
    expect(daemon.connected, isFalse);
    await link.check(user: true);
    expect(link.why, Unreachable.relay);
    expect(link.failures, greaterThan(0));
    await rig.startRelay(port: was);
    await prompt('after the restart');
    // The Mac's daemon waits at the relay again (backing off a second or
    // two); the phone's next try finds it.
    await until(() {
      if (!link.trying) unawaited(link.check(user: true));
      return daemon.connected;
    });
    await until(() => shows('after the restart'));
    expect(link.failures, 0);
    expect(link.seen, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
