import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter/foundation.dart';
import 'package:uds_transport/uds_transport.dart';

import 'agents.dart';
import 'bundled_daemon.dart';
import 'chat.dart';
import 'gen/nushi/v1/nushi.connect.client.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'review.dart';
import 'settings.dart';
import 'side_panel.dart';
import 'terminals.dart';
import 'trust_card.dart';

final support = '${Platform.environment['HOME']}/Library/Application Support';

/// The daemon's data folder; `NUSHI_DATA` picks another one (development),
/// and tests get one in the temporary folder, never the user's.
final dataDir =
    Platform.environment['NUSHI_DATA'] ??
    (Platform.environment.containsKey('FLUTTER_TEST')
        ? '${Directory.systemTemp.path}/nushi-test'
        : '$support/Nushi');

/// The API version this app was built with (`internal/api.Version`).
const apiVersion = 46;

/// The app's link to nushid. [connected] follows a ping every few seconds;
/// while connected, daemon events keep [chats] current. When no daemon
/// answers, the bundled one is started; a running daemon is only ever
/// stopped by [restartDaemon].
class Daemon extends ChangeNotifier {
  /// A test passes a [transport] of its own.
  Daemon({connect.Transport? transport}) {
    client = NushiServiceClient(
      transport ??
          protocol.Transport(
            baseUrl: 'http://nushid',
            codec: const ProtoCodec(),
            httpClient: createHttpClient(transport: _transport),
            interceptors: [_auth],
          ),
    );
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _ping());
    _ping();
  }

  final _transport = UdsTransport('$dataDir/nushid.sock');
  late final NushiServiceClient client;
  late final Timer _timer;
  bool connected = false;
  int daemonApi = 0; // the daemon's API version
  String _build = ''; // the running daemon's build

  /// Whether the daemon is older than the app: it needs a restart.
  bool get outdated => daemonApi < apiVersion;

  /// Whether the app bundles another build of the daemon than the one that
  /// runs (installed since it started): a restart would bring it in.
  bool get replaced =>
      bundledBuild != null && _build.isNotEmpty && _build != bundledBuild;
  final _launcher = Launcher();

  /// Whether starting the bundled daemon keeps failing.
  bool get launchFailed => _launcher.launches >= 3 && !connected;
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

  /// The folder whose MCP servers show in place of the chat, if they do.
  String? mcpFolder;

  void showMcp(String? folder) {
    trustAsk?.decide(false);
    mcpFolder = folder;
    notifyListeners();
  }

  /// The chats' terminals.
  late final terminals = Terminals(client);

  /// A folder's code waiting for the user's word before a chat starts or
  /// moves there (see TrustCard).
  TrustAsk? trustAsk;

  /// Whether a chat with [agent] may start or move into [folder] (doing
  /// [action]): when the folder brings code for it to run that nobody trusted,
  /// [trustAsk] shows it and this waits for "Start anyway", which the
  /// daemon remembers, or Cancel.
  Future<bool> _mayRun(String folder, String action, String agent) async {
    if (folder.isEmpty) return true;
    while (true) {
      final check = await client.checkFolder(
        CheckFolderRequest(folder: folder, agent: agent),
      );
      if (check.runs.isEmpty) return true;
      trustAsk?.decide(false);
      final ask = trustAsk = TrustAsk(folder, action, check.runs, agent);
      notifyListeners();
      final start = await ask.answer.future;
      if (trustAsk == ask) {
        trustAsk = null;
        notifyListeners();
      }
      // A folder without a key is for this start only.
      if (!start || check.key.isEmpty) return start;
      try {
        await client.trustFolder(
          TrustFolderRequest(folder: folder, agent: agent, key: check.key),
        );
        return true;
      } on connect.ConnectException catch (e) {
        if (e.code != connect.Code.aborted) rethrow; // changed: look again
      }
    }
  }

  Future<void> _ping() async {
    var api = 0;
    var build = '';
    try {
      // A daemon that hangs counts as gone, rather than stalling the pings.
      final r = await client
          .ping(PingRequest())
          .timeout(const Duration(seconds: 3));
      (api, build) = (r.apiVersion, r.build);
    } on Object {
      if (_launcher.launch() && _launcher.launches == 3) notifyListeners();
    }
    final ok = api > 0;
    if (ok) _launcher.launches = 0;
    if (ok && _events == null) _subscribe();
    if (ok != connected || ok && (api != daemonApi || build != _build)) {
      connected = ok;
      if (ok) {
        daemonApi = api; // kept while away: the app stays as it was
        _build = build;
      }
      notifyListeners();
    }
  }

  /// Stops the running daemon (it stops its agents) and starts the bundled
  /// one; chats reopen through session/load as they are opened.
  Future<void> restartDaemon() async {
    stopDaemon(dataDir);
    // The first ping that fails starts the bundled daemon.
    _launcher.launched = DateTime(0);
    for (var i = 0; i < 50 && connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _ping();
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
              unawaited(_listAgents());
              return;
            }
            if (_held case final held?) {
              held.add(e); // applied after the list, which may be older
            } else {
              _handle(e);
            }
          },
          onError: (_) => _events = null,
          onDone: () => _events = null,
        );
  }

  /// Events that came while the chat list was on its way.
  List<EventsResponse>? _held;

  void _handle(EventsResponse e) {
    if (e.hasTerminals()) {
      terminals.apply(e.chatId, e.terminals.terminals);
    } else if (sides[e.chatId] case final side?) {
      e.removed ? _sideGone(side) : side.apply(e);
    } else if (e.hasChat()) {
      _chat(e.chat);
      notifyListeners();
    } else if (e.removed) {
      chats.remove(e.chatId);
      if (changeScopes.value.containsKey(e.chatId)) {
        changeScopes.value = {...changeScopes.value}..remove(e.chatId);
      }
      if (commentsOf(e.chatId).isNotEmpty) setComments(e.chatId, []);
      if (terminalChats.value.contains(e.chatId)) {
        terminalChats.value = {...terminalChats.value}..remove(e.chatId);
      }
      if (selectedId == e.chatId) selectedId = null;
      notifyListeners();
    } else {
      chats[e.chatId]?.apply(e);
    }
  }

  /// Lists the chats, then applies the events held meanwhile, in order: the
  /// list was read at some point while they came, so they bring it up to
  /// date (a chat started meanwhile included). When listing fails, the
  /// subscription starts again, and with it the list.
  Future<void> _listChats() async {
    _held = [];
    for (final c in [...chats.values, ...sides.values]) {
      c.unload(); // events may have been missed while disconnected
    }
    terminals.stale();
    try {
      final listed = (await client.listChats(ListChatsRequest())).chats;
      for (final c in listed) {
        _chat(c);
      }
      // Chats deleted meanwhile go; side chats the daemon lost (it
      // restarted) end, the others catch up.
      final ids = {for (final c in listed) c.id};
      chats.removeWhere((id, _) => !ids.contains(id));
      for (final side in sides.values) {
        side.loading = true; // its events wait for its snapshot
      }
    } on Object {
      unawaited(_events?.cancel());
      _events = null; // the next ping subscribes again
      return;
    } finally {
      final held = _held ?? [];
      _held = null;
      held.forEach(_handle);
    }
    if (!chats.containsKey(selectedId)) selectedId = null;
    for (final chat in [...chats.values]) {
      if (chat.side case final side?) {
        try {
          side.load(await client.getChat(GetChatRequest(chatId: side.id)));
        } on Object {
          chat.side = null;
          sides.remove(side.id);
        }
      }
    }
    if (selected != null) unawaited(_load(selected!));
    notifyListeners();
  }

  Future<void> _listAgents() async {
    try {
      final list = (await client.listAgents(ListAgentsRequest())).agents;
      knownAgents = {for (final a in list) a.name: a};
      notifyListeners();
    } on Object {
      // As they were: the next subscription asks again.
    }
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
    if (chat.folder != c.folder) {
      chat.moved(c.folder);
      closeSide(chat); // it ran on the old agent
    }
    return chat
      ..worktree = c.hasWorktree() ? c.worktree : null
      ..agent = c.agent
      ..scratch = c.scratch
      ..title = c.title
      ..archived = c.archived
      ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt())
      // Only the list carries a status; a chat event would clear it.
      ..status(c.hasStatus() ? c.status : null);
  }

  void select(String chatId) {
    trustAsk?.decide(false);
    selectedId = chatId;
    mcpFolder = null;
    final chat = chats[chatId];
    if (chat != null) unawaited(_load(chat));
    notifyListeners();
  }

  /// Starts a chat with [agent] (else the last one used) in [folder], or
  /// in a scratch folder of its own (''); in a new worktree of its
  /// repository if that's the choice remembered for it.
  Future<void> startChat(String folder, {String? agent}) async {
    agent ??= lastAgent(chats.values);
    if (!await _mayRun(folder, 'Start a chat', agent)) return;
    final before = (selectedId, mcpFolder);
    final resp = await client.startChat(
      StartChatRequest(
        agent: agent,
        folder: folder,
        worktree: _worktree(folder),
      ),
    );
    chats[resp.chatId] ??= ChatState(resp.chatId, folder);
    // Not if the user went elsewhere meanwhile: a trust card or another
    // chat they're on stays.
    if ((selectedId, mcpFolder) == before && trustAsk == null) {
      select(resp.chatId);
    } else {
      notifyListeners();
    }
  }

  bool _worktree(String folder) => worktreeRepos.value.contains(folder);

  /// Moves a chat to [folder], or to a new worktree of its repository, and
  /// says whether it did (not when the user cancelled). A chat without
  /// messages follows the choice remembered for [folder].
  Future<bool> moveChat(ChatState chat, String folder, {bool? worktree}) async {
    if (!await _mayRun(folder, 'Move the chat', chat.agent)) return false;
    await client.moveChat(
      MoveChatRequest(
        chatId: chat.id,
        folder: folder,
        worktree: worktree ?? (chat.fresh && _worktree(folder)),
      ),
    );
    return true;
  }

  /// Opens a side chat of [chat] (see ForkChat).
  Future<ChatState> forkChat(ChatState chat) async {
    final resp = await client.forkChat(ForkChatRequest(chatId: chat.id));
    final side = sides[resp.chatId] = ChatState(resp.chatId, chat.folder)
      ..agent = chat.agent;
    unawaited(_load(side));
    return side;
  }

  /// A side chat the daemon ended (its chat reloaded, moved or archived,
  /// or its agent quit).
  void _sideGone(ChatState side) {
    sides.remove(side.id);
    for (final chat in chats.values) {
      if (chat.side == side) chat.side = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer.cancel();
    unawaited(_events?.cancel());
    unawaited(_transport.close());
    super.dispose();
  }
}
