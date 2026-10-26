import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter/foundation.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_panel.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/trust_card.dart';
import 'package:uds_transport/uds_transport.dart';

final support = '${Platform.environment['HOME']}/Library/Application Support';

/// The daemon's data folder; `NUSHI_DATA` picks another one (development),
/// and tests get one in the temporary folder, never the user's.
final String dataDir =
    Platform.environment['NUSHI_DATA'] ??
    (Platform.environment.containsKey('FLUTTER_TEST')
        // One per test process: test files run side by side, and a shared
        // app.json would let one file's settings overwrite another's.
        ? '${Directory.systemTemp.path}/nushi-test-$pid'
        : '$support/Nushi');

/// The API version this app was built with (`internal/api.Version`).
const apiVersion = 63;

/// The app's link to nushid. [connected] follows a ping every few seconds;
/// while connected, daemon events keep [chats] current. When no daemon
/// answers, the bundled one is started; a running daemon is only ever
/// stopped by [restartDaemon].
class Daemon extends ChangeNotifier {
  /// A test passes a [transport] of its own.
  new({connect.Transport? transport}) {
    client = NushiServiceClient(
      transport ??
          protocol.Transport(
            baseUrl: 'http://nushid',
            codec: const ProtoCodec(),
            httpClient: createHttpClient(transport: _transport),
            interceptors: [_auth],
          ),
    );
    appLog.client = client;
    appLog.reachable = () => connected && hasLog(daemonApi);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _ping());
    unawaited(
      _ping().then(
        (_) => appLog.info('app started', {
          'version': appVersion,
          'api': '$apiVersion',
          'pid': '$pid',
          'daemon': connected ? 'answers' : 'not answering',
        }),
      ),
    );
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

  /// The chats the daemon removed because their agent no longer had their
  /// sessions, until [dismissRemoved].
  List<RemovedChat> removedChats = [];

  /// Says the app has shown [removedChats]: the daemon forgets them.
  void dismissRemoved() {
    final ids = [for (final r in removedChats) r.id];
    removedChats = [];
    notifyListeners();
    unawaited(
      client
          .dismissRemovedChats(DismissRemovedChatsRequest(ids: ids))
          .then((_) {}, onError: (Object _) {}),
    );
  }

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
    return await next(req);
  };

  /// The folder whose MCP servers show in place of the chat, if they do.
  String? mcpFolder;

  void showMcp(String? folder) {
    trustAsk?.decide(start: false);
    mcpFolder = folder;
    jiraOpen = githubOpen = false;
    notifyListeners();
  }

  /// Whether Jira shows in place of the chat.
  bool jiraOpen = false;

  void showJira({required bool open}) {
    trustAsk?.decide(start: false);
    jiraOpen = open;
    if (open) {
      mcpFolder = null;
      githubOpen = false;
    }
    notifyListeners();
  }

  /// Whether GitHub shows in place of the chat.
  bool githubOpen = false;

  /// What the GitHub view is to show when it opens next (a chat's pull
  /// request or issue), taken by the view.
  GitHubRef? githubShow;

  void showGitHub({required bool open, GitHubRef? item}) {
    trustAsk?.decide(start: false);
    githubOpen = open;
    githubShow = item;
    if (open) {
      mcpFolder = null;
      jiraOpen = false;
    }
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
      trustAsk?.decide(start: false);
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
      final was = connected;
      connected = ok;
      if (ok) {
        daemonApi = api; // kept while away: the app stays as it was
        _build = build;
      }
      notifyListeners();
      if (!ok) {
        appLog.warn('lost the daemon');
      } else if (outdated) {
        appLog.warn('the daemon is older than the app', {
          'daemon_api': '$api',
          'app_api': '$apiVersion',
        });
      } else if (!was) {
        appLog.info('connected to the daemon', {'api': '$api', 'build': build});
      }
    }
  }

  /// Stops the running daemon (it stops its agents) and starts the bundled
  /// one; chats reopen through session/load as they are opened.
  Future<void> restartDaemon() async {
    await appLog.write(
      'info',
      'restarting the daemon',
      attrs: {'build': _build, 'bundled': ?bundledBuild},
    );
    final before = _build;
    stopDaemon(dataDir);
    // The first ping that fails starts the bundled daemon.
    _launcher.launched = DateTime(0);
    for (var i = 0; i < 50 && connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _ping();
    }
    if (connected && _build == before) {
      appLog.warn('the daemon did not stop', {'build': before});
      throw StateError(
        "The running daemon didn't stop: quit nushid in Activity Monitor, "
        'then reopen Nushi',
      );
    }
    // Then wait for the new one: callers reload from it, and a reload
    // while none answers fails quietly and leaves what asked for the
    // restart on screen.
    for (var i = 0; i < 100 && !connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _ping();
    }
    if (!connected) {
      throw StateError("The daemon didn't come back: Settings › Show logs");
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
              unawaited(
                client
                    .getRemote(GetRemoteRequest())
                    .then((r) => remoteState.value = r.remote, onError: (_) {}),
              );
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
    if (e.hasRemote()) {
      remoteState.value = e.remote;
    } else if (e.hasRemovedChats()) {
      removedChats = e.removedChats.chats;
      notifyListeners();
    } else if (e.hasTerminals()) {
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
    } else if (chats[e.chatId] case final chat?) {
      final failed = chat.reopenFailed;
      chat.apply(e);
      // Its agent became ready (not a reopen starting): shown, it reopens.
      if (failed && !chat.reopenFailed && !chat.busy && chat.id == selectedId) {
        shown();
      }
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
      final resp = await client.listChats(ListChatsRequest());
      removedChats = resp.removed;
      final listed = resp.chats..forEach(_chat);
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
      await listAgents(client);
      notifyListeners();
    } on Object {
      // As they were: the next subscription asks again.
    }
  }

  /// Fetches a chat's snapshot; its events have been held since `loading`.
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
      ..jiraSite = c.jiraSite
      ..jiraKey = c.jiraKey
      ..github = c.hasGithub() ? c.github : null
      ..title = c.title
      ..archived = c.archived
      ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt())
      // Only the list carries a status; a chat event would clear it.
      ..status(c.hasStatus() ? c.status : null);
  }

  void select(String chatId) {
    trustAsk?.decide(start: false);
    selectedId = chatId;
    mcpFolder = null;
    jiraOpen = githubOpen = false;
    final chat = chats[chatId];
    if (chat != null) unawaited(_load(chat));
    shown();
    notifyListeners();
  }

  /// The selected chat is shown: picked, or the app came to the front. A
  /// chat whose agent should run but doesn't reopens, and one whose reopen
  /// failed tries again, once a show (the daemon's ReopenChat). A sleeping
  /// one stays asleep.
  void shown() {
    if (selected case final chat? when !chat.archived) reopen(chat);
  }

  /// ReopenChat for [chat] (Try again); how it goes shows in the chat.
  void reopen(ChatState chat) => unawaited(
    client
        .reopenChat(ReopenChatRequest(chatId: chat.id))
        .then((_) {}, onError: (Object _) {}),
  );

  /// The folder a chat is starting in ('' for none), while one is.
  String? starting;

  /// Why each agent whose last start failed in this run didn't start, as
  /// the daemon said ("couldn't start Ante: …"); a start that works clears
  /// it.
  final cantStart = <String, String>{};

  /// Starts a chat with [agent] in [folder], or in a scratch folder of its
  /// own (''); in a new worktree of its repository if that's the choice
  /// remembered for it. A chat on a Jira [issue] remembers it and takes
  /// its worktree choice; its box stays empty (the agent's tools say which
  /// issue it is).
  Future<void> startChat(
    String folder,
    String agent, {
    IssueChat? issue,
  }) async {
    starting = folder;
    notifyListeners();
    try {
      if (!await _mayRun(folder, 'Start a chat', agent)) return;
      final before = (selectedId, mcpFolder);
      final StartChatResponse resp;
      try {
        resp = await client.startChat(
          StartChatRequest(
            agent: agent,
            folder: folder,
            worktree: issue?.worktree ?? wantsWorktree(folder),
            jiraSite: issue?.github == null ? issue?.site : null,
            jiraKey: issue?.github == null ? issue?.key : null,
            github: issue?.github,
            branch:
                issue != null &&
                    issue.worktree &&
                    folder.isNotEmpty &&
                    issue.github?.pull != true
                ? issue.branch
                : null,
          ),
        );
      } on connect.ConnectException catch (e) {
        if (e.message.startsWith("couldn't start ")) {
          cantStart[agent] = e.message;
        }
        rethrow;
      }
      cantStart.remove(agent);
      chats[resp.chatId] ??= ChatState(resp.chatId, folder);
      // Not if the user went elsewhere meanwhile: a trust card or another
      // chat they're on stays.
      if ((selectedId, mcpFolder) == before && trustAsk == null) {
        select(resp.chatId);
      }
    } finally {
      starting = null;
      notifyListeners();
    }
  }

  /// Opens [session], one of [agent]'s sessions that isn't a chat, as a
  /// chat in [asked] (its own folder for ''), and shows it.
  Future<void> openSession(
    String asked,
    String agent,
    FoundSession session,
  ) async {
    final folder = asked.isEmpty ? session.folder : asked;
    starting = folder;
    notifyListeners();
    try {
      if (!await _mayRun(folder, 'Open the session', agent)) return;
      final before = (selectedId, mcpFolder);
      final resp = await client.openAgentSession(
        OpenAgentSessionRequest(
          agent: agent,
          folder: folder,
          sessionId: session.sessionId,
          title: session.title,
        ),
      );
      chats[resp.chatId] ??= ChatState(resp.chatId, folder);
      if ((selectedId, mcpFolder) == before && trustAsk == null) {
        select(resp.chatId);
      }
    } finally {
      starting = null;
      notifyListeners();
    }
  }

  /// Whether new chats in [folder] get a worktree, as last chosen there.
  bool wantsWorktree(String folder) => worktreeRepos.value.contains(folder);

  /// Moves a chat to [folder], or to a new worktree of its repository, and
  /// says whether it did (not when the user cancelled). A chat without
  /// messages follows the choice remembered for [folder].
  Future<bool> moveChat(ChatState chat, String folder, {bool? worktree}) async {
    if (!await _mayRun(folder, 'Move the chat', chat.agent)) return false;
    await client.moveChat(
      MoveChatRequest(
        chatId: chat.id,
        folder: folder,
        worktree: worktree ?? (chat.fresh && wantsWorktree(folder)),
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

/// A chat to start on a Jira issue: its site, key and summary, and a
/// worktree on [branch] if [worktree] (on when the issue is picked).
class IssueChat {
  new({
    required this.site,
    required this.key,
    required this.summary,
    required this.branch,
    this.worktree = true,
    this.github,
  });

  /// A GitHub pull request or issue: its worktree starts on a pull
  /// request's head (the daemon fetches it), an issue's on a branch named
  /// from it.
  new github(GitHubItem it)
    : this(
        site: '',
        key: '${it.ref.repo}#${it.ref.number}',
        summary: it.title,
        branch: it.pull ? '' : githubBranch(it.ref.number, it.title),
        github: GitHubLink(
          host: it.ref.host,
          id: it.id,
          repo: it.ref.repo,
          number: it.ref.number,
          pull: it.pull,
        ),
      );

  /// An issue FindJiraIssues found.
  new found(FoundJiraIssue f)
    : this(
        site: f.site,
        key: f.issue.key,
        summary: f.issue.summary,
        branch: f.branch,
      );

  final String site;
  final String key;
  final String summary;
  String branch;
  bool worktree;

  /// The GitHub item it is, if it isn't a Jira issue.
  final GitHubLink? github;
}

/// The branch for a chat on GitHub issue [n] (the daemon's IssueBranch):
/// its number, then its title's letters and digits, lowercase, words
/// joined by "-", 40 characters of title at most, cut between words.
String githubBranch(int n, String title) {
  final words = title
      .toLowerCase()
      .split(RegExp('[^a-z0-9]+'))
      .where((w) => w.isNotEmpty);
  var out = '';
  for (final w in words) {
    if (out.length + w.length + 1 > 40 && out.isNotEmpty) break;
    out = out.isEmpty ? w : '$out-$w';
  }
  if (out.length > 40) out = out.substring(0, 40);
  return out.isEmpty ? '$n' : '$n-$out';
}
