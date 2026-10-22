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

  /// The open side chats, by id: not stored, not listed.
  final sides = <String, ChatState>{};
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
            if (sides[e.chatId] case final side?) {
              side.apply(e);
            } else if (e.hasChat()) {
              _chat(e.chat);
              notifyListeners();
            } else if (e.removed) {
              chats.remove(e.chatId);
              if (selectedId == e.chatId) selectedId = null;
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

  ChatState _chat(Chat c) {
    final chat = chats[c.id] ??= ChatState(c.id, c.folder);
    if (chat.archived && !c.archived) {
      // Unarchived: the daemon replays it from scratch.
      chat.unload();
      if (chat.id == selectedId) unawaited(_load(chat));
    }
    return chat
      ..title = c.title
      ..archived = c.archived
      ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt())
      ..status(c.status);
  }

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

  Future<void> renameChat(String chatId, String title) =>
      client.renameChat(RenameChatRequest(chatId: chatId, title: title));

  Future<void> archiveChat(String chatId, {required bool archived}) => client
      .archiveChat(ArchiveChatRequest(chatId: chatId, archived: archived));

  Future<void> removeChat(String chatId) =>
      client.removeChat(RemoveChatRequest(chatId: chatId));

  Future<void> sendPrompt(String chatId, String text, List<String> files) =>
      client.sendPrompt(
        SendPromptRequest(chatId: chatId, text: text, files: files),
      );

  Future<List<String>> listFiles(String folder) async =>
      (await client.listFiles(ListFilesRequest(folder: folder))).paths;

  /// Opens a side chat of [chat] (see ForkChat).
  Future<ChatState> forkChat(ChatState chat) async {
    final resp = await client.forkChat(ForkChatRequest(chatId: chat.id));
    final side = sides[resp.chatId] = ChatState(resp.chatId, chat.folder);
    unawaited(_load(side));
    return side;
  }

  Future<void> closeSide(ChatState side) async {
    sides.remove(side.id);
    await client.closeSideChat(CloseSideChatRequest(chatId: side.id));
  }

  Future<void> cancelTurn(String chatId) =>
      client.cancelTurn(CancelTurnRequest(chatId: chatId));

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
