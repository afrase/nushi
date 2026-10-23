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
import 'review.dart';
import 'settings.dart';

final _support = '${Platform.environment['HOME']}/Library/Application Support';

/// The daemon's data folder; `NUSHI_DATA` picks another one (development).
final dataDir = Platform.environment['NUSHI_DATA'] ?? '$_support/Nushi';

/// The data folder from when the app was "Nushi Next". The daemon moves it
/// to [dataDir] when it starts, once its own daemon has stopped.
final String? _oldDataDir =
    Platform.environment['NUSHI_DATA'] == null &&
        !Directory(dataDir).existsSync() &&
        Directory('$_support/Nushi Next').existsSync()
    ? '$_support/Nushi Next'
    : null;

/// The API version this app was built with (`internal/api.Version`).
const apiVersion = 32;

/// Whether [folder] is a chat's scratch folder: the chat has no folder yet.
bool isScratch(String folder) => folder.startsWith('$dataDir/scratch/');

/// The daemon in the app's bundle (`make package`), if the app runs from one.
final String? bundledDaemon = () {
  final path = '${File(Platform.resolvedExecutable).parent.path}/nushid';
  return File(path).existsSync() ? path : null;
}();

/// The app's link to nushid. [connected] follows a ping every few seconds;
/// while connected, daemon events keep [chats] current. When no daemon
/// answers, the bundled one is started; a running daemon is only ever
/// stopped by [restartDaemon].
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
  int daemonApi = 0; // the daemon's API version
  DateTime _launched = DateTime(0); // when the bundled daemon was last started
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

  /// Whether the daemon has rename, archive and remove (API 14).
  bool get canManageChats => daemonApi >= 14;
  bool get canDeleteChats => daemonApi >= 19;

  /// Whether the daemon starts chats without a folder and moves them (API 16).
  bool get canMove => daemonApi >= 16;

  /// Whether the daemon runs chats in worktrees (API 20).
  bool get canWorktrees => daemonApi >= 20;

  /// Whether the daemon lists commits and finds the default branch, for
  /// the Changes view's Branch and Commits (API 27).
  bool get canCommits => daemonApi >= 27;

  /// Whether the daemon queues messages sent while the agent works (API 28).
  bool get canQueue => daemonApi >= 28;

  /// Whether the daemon rewinds chats (API 29), and takes back a stopped
  /// message (API 30).
  bool get canRewind => daemonApi >= 29;
  bool get canTakeBack => daemonApi >= 30;

  /// Whether the daemon lists MCP servers (API 32).
  bool get canMcp => daemonApi >= 32;

  /// The folder whose MCP servers show in place of the chat, if they do.
  String? mcpFolder;

  void showMcp(String? folder) {
    mcpFolder = folder;
    notifyListeners();
  }

  /// Whether the daemon sums up a folder's changes (API 17).
  bool get canFolderStatus => daemonApi >= 17;

  Future<void> _ping() async {
    var api = 0;
    try {
      api = (await client.ping(PingRequest())).apiVersion;
    } on Object {
      _launch();
    }
    final ok = api > 0;
    if (ok && _events == null) _subscribe();
    if (ok != connected || api != daemonApi) {
      connected = ok;
      daemonApi = api;
      notifyListeners();
    }
  }

  /// Starts the bundled daemon, at most every ten seconds. It runs through
  /// the user's login shell, so it and its agents get the user's PATH, and
  /// detached, so it outlives the app.
  void _launch() {
    final bin = bundledDaemon;
    if (bin == null ||
        bin.contains("'") ||
        DateTime.now().difference(_launched).inSeconds < 10) {
      return;
    }
    _launched = DateTime.now();
    // Moving from Nushi Next: its daemon stops, and the new one starts in
    // the old folder, which it then moves (its log and folder move along).
    var dir = dataDir;
    if (_oldDataDir case final old? when !Directory(dataDir).existsSync()) {
      _stopDaemon(old);
      dir = old;
    }
    Directory(dir).createSync(recursive: true);
    Process.start(
      Platform.environment['SHELL'] ?? '/bin/zsh',
      ['-l', '-c', "exec '$bin' >>'$dir/nushid.log' 2>&1"],
      workingDirectory: dir,
      mode: ProcessStartMode.detached,
    ).ignore();
  }

  /// Stops the running daemon (it stops its agents) and starts the bundled
  /// one; chats reopen through session/load as they are opened.
  Future<void> restartDaemon() async {
    _stopDaemon(dataDir);
    // The first ping that fails starts the bundled daemon.
    _launched = DateTime(0);
    for (var i = 0; i < 50 && connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _ping();
    }
  }

  /// Stops the daemon listening in [dir], if one is.
  void _stopDaemon(String dir) {
    final lsof = Process.runSync('lsof', [
      '-a',
      '-c',
      'nushid',
      '-t',
      '$dir/nushid.sock',
    ]);
    for (final pid in '${lsof.stdout}'.split('\n')) {
      if (int.tryParse(pid) case final pid?) Process.killPid(pid);
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
              if (changeScopes.value.containsKey(e.chatId)) {
                changeScopes.value = {...changeScopes.value}..remove(e.chatId);
              }
              if (commentsOf(e.chatId).isNotEmpty) setComments(e.chatId, []);
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
    if (chat.folder != c.folder) chat.moved(c.folder);
    return chat
      ..worktree = c.hasWorktree() ? c.worktree : null
      ..sessionId = c.sessionId.isEmpty ? c.id : c.sessionId
      ..title = c.title
      ..archived = c.archived
      ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt())
      // Only the list carries a status; a chat event would clear it.
      ..status(c.hasStatus() ? c.status : null);
  }

  void select(String chatId) {
    selectedId = chatId;
    mcpFolder = null;
    final chat = chats[chatId];
    if (chat != null) unawaited(_load(chat));
    notifyListeners();
  }

  /// Starts a chat in [folder], or in a scratch folder of its own (''); in a
  /// new worktree of its repository if that's the choice remembered for it.
  Future<void> startChat(String folder) async {
    final resp = await client.startChat(
      StartChatRequest(folder: folder, worktree: _worktree(folder)),
    );
    chats[resp.chatId] ??= ChatState(resp.chatId, folder);
    select(resp.chatId);
  }

  bool _worktree(String folder) =>
      canWorktrees && worktreeRepos.value.contains(folder);

  /// Moves a chat to [folder], or to a new worktree of its repository. A
  /// chat without messages follows the choice remembered for [folder].
  Future<void> moveChat(ChatState chat, String folder, {bool? worktree}) =>
      client.moveChat(
        MoveChatRequest(
          chatId: chat.id,
          folder: folder,
          worktree: worktree ?? (chat.fresh && _worktree(folder)),
        ),
      );

  /// The chats' folders (in a worktree, its repository's), the newest
  /// chat's first, scratch folders left out.
  List<String> get recentFolders {
    final byNewest = chats.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    return {
      for (final c in byNewest)
        if (!isScratch(c.folder)) c.home,
    }.toList();
  }

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

  @override
  void dispose() {
    _timer.cancel();
    unawaited(_events?.cancel());
    unawaited(_transport.close());
    super.dispose();
  }
}
