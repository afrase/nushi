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
/// while connected, daemon events keep [chats] current.
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

  /// Every stored chat, by id.
  final chats = <String, ChatState>{};
  String? selectedId;
  ChatState? get selected => chats[selectedId];

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
    var live = false;
    _events = client
        .events(EventsRequest())
        .listen(
          (e) {
            if (!live) {
              // The first message says the subscription is live: now the
              // list can't miss a chat.
              live = true;
              unawaited(_listChats());
              return;
            }
            if (e.hasChat()) {
              _chat(e.chat);
              notifyListeners();
            } else {
              chats[e.chatId]?.apply(e);
            }
          },
          onError: (_) => _events = null,
          onDone: () => _events = null,
        );
  }

  Future<void> _listChats() async {
    for (final c in chats.values) {
      c.unload(); // events may have been missed while disconnected
    }
    for (final c in (await client.listChats(ListChatsRequest())).chats) {
      _chat(c);
    }
    if (selected != null) unawaited(_load(selected!));
    notifyListeners();
  }

  /// Fetches a chat's snapshot; its events have been held since [loading].
  Future<void> _load(ChatState chat) async {
    if (chat.loaded || chat.loading) return;
    chat.loading = true;
    try {
      chat.load(await client.getChat(GetChatRequest(chatId: chat.id)));
    } on Object catch (e) {
      chat
        ..unload()
        ..error = '$e';
      notifyListeners();
    }
  }

  ChatState _chat(Chat c) => (chats[c.id] ??= ChatState(c.id, c.folder))
    ..title = c.title
    ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt());

  void select(String chatId) {
    selectedId = chatId;
    final chat = chats[chatId];
    if (chat != null) unawaited(_load(chat));
    notifyListeners();
  }

  Future<void> startChat(String folder) async {
    final resp = await client.startChat(StartChatRequest(folder: folder));
    chats[resp.chatId] ??= ChatState(resp.chatId, folder);
    select(resp.chatId);
  }

  Future<void> sendPrompt(String chatId, String text) =>
      client.sendPrompt(SendPromptRequest(chatId: chatId, text: text));

  Future<void> answerPermission(
    String chatId,
    String itemId,
    String optionId,
  ) => client.answerPermission(
    AnswerPermissionRequest(chatId: chatId, itemId: itemId, optionId: optionId),
  );

  Future<void> setConfigOption(String chatId, String configId, String value) =>
      client.setConfigOption(
        SetConfigOptionRequest(
          chatId: chatId,
          configId: configId,
          value: value,
        ),
      );

  /// Answers a question with values by field id, or declines it (null).
  Future<void> answerQuestion(
    String chatId,
    String itemId,
    Map<String, List<String>>? answer,
  ) => client.answerQuestion(
    AnswerQuestionRequest(
      chatId: chatId,
      itemId: itemId,
      decline: answer == null,
      answers: [
        for (final MapEntry(:key, :value) in (answer ?? {}).entries)
          FieldAnswer(fieldId: key, values: value),
      ],
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
