import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter/foundation.dart';
import 'package:uds_transport/uds_transport.dart';

import 'chat.dart';
import 'gen/nushi/v1/nushi.connect.client.dart';
import 'gen/nushi/v1/nushi.pb.dart';

final dataDir =
    '${Platform.environment['HOME']}/Library/Application Support/Nushi Next';

/// The app's link to nushid. [connected] follows a ping every few seconds;
/// while connected, daemon events update [chat].
class Daemon extends ChangeNotifier {
  Daemon() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _ping());
    _ping();
  }

  final _transport = UdsTransport('$dataDir/nushid.sock');
  late final NushiServiceClient client = NushiServiceClient(
    protocol.Transport(
      baseUrl: 'http://nushid',
      codec: const ProtoCodec(),
      httpClient: createHttpClient(transport: _transport),
      interceptors: [_auth],
    ),
  );
  late final Timer _timer;
  bool connected = false;
  StreamSubscription<EventsResponse>? _events;
  Chat? chat;

  connect.AnyFn<I, O> _auth<I extends Object, O extends Object>(
    connect.AnyFn<I, O> next,
  ) => (req) async {
    // Read at every call: the daemon writes it on its first start.
    final token = await File('$dataDir/token').readAsString();
    req.headers['authorization'] = 'Bearer ${token.trim()}';
    return next(req);
  };

  Future<void> _ping() async {
    bool ok;
    try {
      await client.ping(PingRequest());
      ok = true;
    } on Object {
      ok = false;
    }
    if (ok && _events == null) _subscribe();
    if (ok != connected) {
      connected = ok;
      notifyListeners();
    }
  }

  void _subscribe() {
    _events = client
        .events(EventsRequest())
        .listen(
          (e) {
            if (e.chatId == chat?.id) chat!.apply(e);
          },
          onError: (_) => _events = null,
          onDone: () => _events = null,
        );
  }

  Future<void> startChat(String folder) async {
    final resp = await client.startChat(StartChatRequest(folder: folder));
    chat = Chat(resp.chatId, folder);
    notifyListeners();
  }

  Future<void> sendPrompt(String text) =>
      client.sendPrompt(SendPromptRequest(chatId: chat!.id, text: text));

  Future<void> answerPermission(String itemId, String optionId) =>
      client.answerPermission(
        AnswerPermissionRequest(
          chatId: chat!.id,
          itemId: itemId,
          optionId: optionId,
        ),
      );

  @override
  void dispose() {
    _timer.cancel();
    unawaited(_events?.cancel());
    unawaited(_transport.close());
    super.dispose();
  }
}
