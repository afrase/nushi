// End to end through the relay (ADR 0034): the real nushid and
// nushi-relay on localhost, the fake agent as Claude, and the app's
// generated client on the phone's transport. A phone pairs, lists chats,
// starts one, prompts it, answers its permission card, gets the streamed
// events, and is revoked.
import 'dart:async';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:remote_transport/remote_transport.dart';
import 'package:uds_transport/uds_transport.dart';

import 'e2e_rig.dart';

NushiServiceClient _client(Http2ClientTransport t, {String? token}) =>
    NushiServiceClient(
      protocol.Transport(
        baseUrl: 'http://nushid',
        codec: const ProtoCodec(),
        httpClient: createHttpClient(transport: t),
        interceptors: [
          if (token != null)
            <I extends Object, O extends Object>(connect.AnyFn<I, O> next) =>
                (req) {
                  req.headers['authorization'] = 'Bearer $token';
                  return next(req);
                },
        ],
      ),
    );

void main() {
  late Rig rig;

  setUpAll(() async => rig = await Rig.build('nre'));
  tearDownAll(() => rig.close());

  test('a phone through the relay', () async {
    // A dialer waits 2 s for the Mac, not 10: a revoked phone dials an id
    // nobody listens on any more, and is refused after that wait.
    await rig.startRelay(args: ['-dial-wait', '2s']);
    await rig.startDaemon();
    final relayUrl = rig.relayUrl;
    final mac = _client(UdsTransport(rig.socket), token: rig.token);

    await mac.setRemote(SetRemoteRequest(on: true, relay: relayUrl));
    await until(
      () async =>
          (await mac.getRemote(GetRemoteRequest())).remote.state == 'connected',
    );

    // Pairing: the QR code, the code on both screens, Allow on the Mac.
    final qr = (await mac.startPairing(StartPairingRequest())).qr;
    final shown = Completer<String>();
    final device = await KeyPair.make();
    final pairing = pair(
      PairingOffer.parse(qr),
      device: device,
      name: 'Test phone',
      onCode: shown.complete,
    );
    final code = await shown.future;
    await until(
      () async =>
          (await mac.getRemote(GetRemoteRequest())).remote.pairing.code == code,
    );
    expect(
      (await mac.getRemote(GetRemoteRequest())).remote.pairing.name,
      'Test phone',
    );
    await mac.confirmPairing(ConfirmPairingRequest(code: code, allow: true));
    final (paired, transport) = await pairing;
    final phone = _client(transport);

    // The phone is a full client, with the same generated client. The
    // daemon's API is the app's: one bumped without the other shows here.
    expect((await phone.ping(PingRequest())).apiVersion, apiVersion);
    expect((await phone.listChats(ListChatsRequest())).chats, isEmpty);
    final events = StreamIterator(phone.events(EventsRequest()));
    expect(await events.moveNext(), isTrue); // live
    final chat = (await phone.startChat(
      StartChatRequest(agent: 'claude', folder: rig.work),
    )).chatId;
    await phone.sendPrompt(
      SendPromptRequest(chatId: chat, text: 'hello from the phone'),
    );
    Future<EventsResponse> next(bool Function(EventsResponse) ok) async {
      while (await events.moveNext()) {
        if (events.current.chatId == chat && ok(events.current)) {
          return events.current;
        }
      }
      throw StateError('events ended');
    }

    await next(
      (e) =>
          e.hasItem() &&
          e.item.item.text.contains('hello from the phone') &&
          e.item.item.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE,
    );
    await phone.sendPrompt(
      SendPromptRequest(chatId: chat, text: 'permission please'),
    );
    final card = await next(
      (e) =>
          e.hasItem() &&
          e.item.item.kind == ItemKind.ITEM_KIND_PERMISSION &&
          e.item.item.status == 'pending',
    );
    await phone.answerPermission(
      AnswerPermissionRequest(
        chatId: chat,
        itemId: card.item.item.id,
        optionId: 'allow',
      ),
    );
    await next(
      (e) =>
          e.hasItem() &&
          e.item.item.text.contains('Permission: selected allow'),
    );
    expect(
      (await mac.listChats(ListChatsRequest())).chats.map((c) => c.id),
      contains(chat),
    );

    // A new channel, as after the app comes back: IK on the daemon's id.
    await transport.close();
    final again = _client(RelayTransport(paired, device));
    expect(
      (await again.listChats(ListChatsRequest())).chats.map((c) => c.id),
      contains(chat),
    );
    final devices = (await mac.getRemote(GetRemoteRequest())).remote.devices;
    expect(devices.single.name, 'Test phone');
    await until(
      () async =>
          (await mac.getRemote(GetRemoteRequest()))
              .remote
              .devices
              .single
              .connected,
    );

    // Revoked, the phone is out at once, and stays out.
    await mac.revokeDevice(RevokeDeviceRequest(id: devices.single.id));
    await expectLater(
      again.listChats(ListChatsRequest()),
      throwsA(isA<connect.ConnectException>()),
    );
    await expectLater(
      _client(RelayTransport(paired, device)).listChats(ListChatsRequest()),
      throwsA(isA<connect.ConnectException>()),
    );

    await mac.setRemote(SetRemoteRequest(on: false, relay: relayUrl));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
