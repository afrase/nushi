import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter/foundation.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mac_view.dart';
import 'package:nushi/place.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/trust_ask.dart';
import 'package:uds_transport/uds_transport.dart';

export 'package:nushi/place.dart';

final support = '${Platform.environment['HOME']}/Library/Application Support';

/// The daemon's data folder; `NUSHI_DATA` picks another one (development).
/// Tests get a new one in the temporary folder, never the user's, even
/// with `NUSHI_DATA` exported (a restart there would stop its daemon):
/// one per test process, as test files run side by side and a shared
/// app.json would let one file's settings overwrite another's; new, so a
/// reused pid starts from no one's prefs. flutter_test_config deletes it.
final String dataDir = Platform.environment.containsKey('FLUTTER_TEST')
    ? Directory.systemTemp.createTempSync('nushi-test-').path
    : Platform.environment['NUSHI_DATA'] ?? '$support/Nushi';

/// The API version this app was built with (`internal/api.Version`).
const apiVersion = 91;

/// The API from which the daemon keeps which chats are pinned, in order
/// (Chat.pin, PinChats).
const pinApi = 90;

/// The API from which the daemon re-runs a pull request's failed jobs
/// (RerunGitHubChecks).
const rerunApi = 88;

/// The API from which the daemon checks for a newer release of Nushi
/// (Ping's update, CheckForUpdates, Settings.check_updates).
const updatesApi = 86;

/// The API from which a daemon restarts itself once nothing runs, when
/// asked (RestartWhenIdle).
const restartWhenIdleApi = 77;

/// A pull request or an issue the GitHub view shows the details of: which
/// it is goes with it, so the pane stays one whatever the inbox holds.
typedef GitHubPick = ({GitHubRef ref, bool pull});

/// The app's link to nushid. [connected] follows a ping every few seconds;
/// while connected, daemon events keep [chats] current. When no daemon
/// answers, the bundled one is started; a running daemon is only ever
/// stopped by [restartDaemon].
class Daemon extends ChangeNotifier {
  /// A test passes a [transport] of its own. The phone passes its
  /// relay's, [remote]: then nothing of the Mac's runs (no bundled daemon,
  /// no token, no app log), and its link pings (phone/link.dart), which
  /// also keeps its relay connection alive.
  new({connect.Transport? transport, this.remote = false, this.drafts}) {
    client = NushiServiceClient(
      transport ??
          protocol.Transport(
            baseUrl: 'http://nushid',
            codec: const ProtoCodec(),
            httpClient: createHttpClient(transport: _transport),
            interceptors: [_auth],
          ),
    );
    // The phone's link pings on its own schedule (phone/link.dart).
    if (remote) return;
    addListener(macView.tick);
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(ping()),
    );
    appLog.client = client;
    appLog.reachable = () => connected && hasLog(daemonApi);
    unawaited(
      ping().then(
        (_) => appLog.info('app started', {
          'version': appVersion,
          'api': '$apiVersion',
          'pid': '$pid',
          'daemon': connected ? 'answers' : 'not answering',
        }),
      ),
    );
  }

  /// Whether this is the phone's link to a Mac's daemon through a relay.
  final bool remote;

  /// Where the chats' drafts are kept, if anywhere (not in tests).
  final Drafts? drafts;

  late final _transport = UdsTransport('$dataDir/nushid.sock');
  late final NushiServiceClient client;
  Timer? _timer;
  bool connected = false;

  /// Why the last ping failed (the phone shows it in details).
  Object? pingError;
  int daemonApi = 0; // the daemon's API version
  String _build = ''; // the running daemon's build
  String daemonVersion = ''; // its release, "" when it isn't one (API 74)

  /// The running daemon's build: its program's `<size>-<mtime in ms>`.
  String get daemonBuild => _build;

  /// Whether the daemon is older than the app: it needs a restart.
  bool get outdated => daemonApi < apiVersion;

  /// The bundled daemon's build ([bundledBuild]): none on the phone, or
  /// when the app isn't packaged. Tests set one.
  late String? bundled = remote ? null : bundledBuild;

  /// Whether the app bundles a newer build of the daemon than the one that
  /// runs (installed since it started): a restart would bring it in. Newer
  /// by its program's time, so a second, older copy of the app open at
  /// once never takes the daemon back.
  bool get replaced =>
      _build.isNotEmpty && _builtAt(bundled ?? '') > _builtAt(_build);

  static int _builtAt(String build) => int.tryParse(build.split('-').last) ?? 0;

  /// Whether the daemon is older than the bundled one and restarts into it
  /// by itself once nothing runs: the pings ask it to (an ask lapses unless
  /// repeated, so an app that quit leaves it running), and the app starts
  /// the new one when it has gone. Meanwhile the app works as usual, the
  /// daemon behind or not (its API only grew), so what runs can be seen
  /// and answered.
  bool get updatesWhenIdle =>
      !remote &&
      bundled != null &&
      daemonApi >= restartWhenIdleApi &&
      (outdated || replaced);

  /// What the daemon's restart into the bundled one waits for, as it last
  /// said (API 85): chats that run or wait, terminals running a command.
  List<RestartHold> restartHolds = const [];

  static bool _sameHolds(List<RestartHold> a, List<RestartHold> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  /// What the daemon's check for a newer release found, from its pings and
  /// events (API 86); empty until it said.
  UpdateCheck update = UpdateCheck();

  void _sawUpdate(UpdateCheck u) {
    if (u == update) return;
    update = u;
    notifyListeners();
  }

  /// Asks the daemon to check for a newer release now.
  Future<UpdateCheck> checkForUpdates() async {
    final r = await client.checkForUpdates(CheckForUpdatesRequest());
    _sawUpdate(r.update);
    return r.update;
  }

  /// Whether the daemon last answered [updatesWhenIdle]: when it's gone,
  /// it's restarting.
  bool updating = false;
  final _launcher = Launcher();

  /// Whether starting the bundled daemon keeps failing.
  bool get launchFailed => _launcher.launches >= 3 && !connected;
  StreamSubscription<EventsResponse>? _events;

  /// Every stored chat, by id.
  final chats = <String, ChatState>{};

  /// Whether [chats] has been listed once: a chat not in it is gone.
  bool chatsListed = false;

  /// The chats the daemon removed because their agent no longer had their
  /// sessions, until [dismissRemoved].
  List<RemovedChat> removedChats = [];

  /// Says the app has shown [removedChats]: the daemon forgets them.
  void dismissRemoved() {
    final ids = [for (final r in removedChats) r.id];
    removedChats = [];
    notifyListeners();
    client.dismissRemovedChats(DismissRemovedChatsRequest(ids: ids)).ignore();
  }

  /// What the Mac's window shows, told to the daemon (not the phone's).
  late final macView = MacView(this);

  /// The open side chats, by id: not stored, not listed.
  final sides = <String, ChatState>{};
  String? selectedId;
  ChatState? get selected => chats[selectedId];

  /// Whether the selected chat shows in the window: nothing (the trust
  /// card, Settings, Jira, GitHub) is in its place. What the daemon is
  /// told the Mac views, and what a chat's tabs and actions need.
  bool get chatShows =>
      selected != null && trustAsk == null && place is ChatPlace;

  connect.AnyFn<I, O> _auth<I extends Object, O extends Object>(
    connect.AnyFn<I, O> next,
  ) => (req) async {
    // Read at every call: the daemon writes it on its first start.
    final token = await File('$dataDir/token').readAsString();
    req.headers['authorization'] = 'Bearer ${token.trim()}';
    return await next(req);
  };

  /// What shows in the chat's place: the chat, Settings, Jira or GitHub.
  Place place = const ChatPlace();

  /// What Settings closes back to: the Jira or GitHub view it opened
  /// from, else the chat.
  Place _beforeSettings = const ChatPlace();

  /// The section Settings opens on: the last one shown while the app runs.
  SettingsSection lastSettings = SettingsSection.general;

  /// What the GitHub view is to show when it opens next (a chat's pull
  /// request or issue), taken by the view.
  GitHubPick? githubShow;

  /// Shows [to] in the chat's place (picking a chat goes there too), and
  /// on GitHub, [github]'s details. A trust card asking is left: that's a
  /// no.
  void go(Place to, {GitHubPick? github}) {
    _leaveTrust();
    if (to is SettingsPlace) {
      if (place is! SettingsPlace) _beforeSettings = place;
      lastSettings = to.section;
    }
    place = to;
    githubShow = github;
    notifyListeners();
  }

  /// Leaves what's in the chat's place: Settings for what showed before
  /// it, Jira and GitHub for the chat.
  void back() {
    if (place is ChatPlace) return;
    go(place is SettingsPlace ? _beforeSettings : const ChatPlace());
  }

  /// Opens [to] in the chat's place, or leaves it when it shows (the
  /// sidebar's rows, the palette's Jira and GitHub).
  void toggle(Place to) =>
      place.runtimeType == to.runtimeType ? back() : go(to);

  /// Shows Settings at [section] (the one showing, else the last one shown,
  /// when null); a [folder] for MCP servers or Skills, an [agent] for
  /// Skills (whose skills) or Agents (the row marked).
  void openSettings({SettingsSection? section, String? folder, String? agent}) {
    final s =
        section ??
        switch (place) {
          SettingsPlace(:final section) => section,
          _ => lastSettings,
        };
    if (folder != null && s == SettingsSection.mcp) mcpFolder = folder;
    if (folder != null && s == SettingsSection.skills) skillsFolder = folder;
    if (agent != null && s == SettingsSection.skills) skillsAgent = agent;
    go(SettingsPlace(s, agent: s == SettingsSection.agents ? agent : null));
  }

  /// The folder whose MCP servers Settings › MCP servers shows: the one
  /// picked there, else the open chat's, else the home folder.
  String? mcpFolder;

  void showMcp(String folder) =>
      openSettings(section: SettingsSection.mcp, folder: folder);

  /// The folder whose skills Settings › Skills shows, as [mcpFolder].
  String? skillsFolder;

  /// The agent whose skills show: Claude unless another was picked, or
  /// the view was opened from another agent's chat.
  String skillsAgent = 'claude';

  void showSkills(String folder, {String? agent}) => openSettings(
    section: SettingsSection.skills,
    folder: folder,
    agent: agent,
  );

  /// The chats' terminals.
  late final terminals = Terminals(client);

  /// A folder's code waiting for the user's word before a chat starts or
  /// moves there (see TrustCard).
  TrustAsk? trustAsk;

  /// What a bar over the app says once, until dismissed: a start the
  /// user walked away from (its trust card answered no).
  String? notice;

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  /// The user went elsewhere while a trust card asked: that's a no, and
  /// a bar says so, or the chat asked for would just not appear.
  void _leaveTrust() {
    final ask = trustAsk;
    if (ask == null || ask.answer.isCompleted) return;
    ask.decide(start: false);
    notice = ask.left;
  }

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

  /// Asks the daemon whether it's there (every few seconds, and when the
  /// phone comes back to the front).
  /// Whether it answered; a phone's link gives a longer [wait] when the
  /// call has to dial the relay first. One at a time: a ping asked while
  /// one is out gets its answer (every 2 s against a 3 s wait, a late
  /// failure would turn the link off after a newer ping turned it on).
  Future<bool> ping({Duration wait = const Duration(seconds: 3)}) =>
      _pinging ??= _ping(wait).whenComplete(() => _pinging = null);

  Future<bool>? _pinging;

  Future<bool> _ping(Duration wait) async {
    var api = 0;
    var build = '';
    var version = '';
    var found = UpdateCheck();
    try {
      // A daemon that hangs counts as gone, rather than stalling the pings.
      final r = await client.ping(PingRequest()).timeout(wait);
      (api, build, version) = (r.apiVersion, r.build, r.version);
      found = r.update;
      pingError = null;
    } on Object catch (e) {
      pingError = e;
      if (!remote && _launcher.launch() && _launcher.launches == 3) {
        notifyListeners();
      }
    }
    final ok = api > 0;
    if (ok) _launcher.launches = 0;
    if (ok && !remote) _sawUpdate(found);
    if (ok && _events == null) _subscribe();
    if (ok && (!connected || build != _build)) macView.forget();
    if (ok != connected || ok && (api != daemonApi || build != _build)) {
      final was = connected;
      connected = ok;
      if (ok) {
        daemonApi = api; // kept while away: the app stays as it was
        _build = build;
        daemonVersion = version;
        if (updatesWhenIdle && !updating) {
          appLog.info('the daemon restarts into the bundled one when idle', {
            'build': build,
            'bundled': ?bundled,
          });
        }
        updating = updatesWhenIdle;
      }
      notifyListeners();
      if (remote) {
        // The phone has no app log.
      } else if (!ok) {
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
    if (ok && !remote) macView.tick(); // said again within the lease
    if (ok && updating) {
      unawaited(
        client.restartWhenIdle(RestartWhenIdleRequest()).then((r) {
          // What it waits for, for the update bar (an older daemon says
          // nothing).
          if (!_sameHolds(r.holds, restartHolds)) {
            restartHolds = r.holds;
            notifyListeners();
          }
        }, onError: (Object _) {}),
      );
    }
    return ok;
  }

  /// The link to the daemon was dropped (the phone's, after a ping went
  /// unanswered): the events subscribe again with the next ping that
  /// answers, and what shows is fetched again.
  void relink() {
    unawaited(_events?.cancel());
    _events = null;
  }

  /// Stops the running daemon (it stops its agents) and starts the bundled
  /// one; chats reopen through session/load as they are opened. One at a
  /// time: asked again while one runs, it waits for that one (a second
  /// stop would stop the new daemon).
  Future<void> restartDaemon() {
    if (_restarting case final run?) return run;
    final run = _restarting = _restart().whenComplete(() {
      _restarting = null;
      notifyListeners();
    });
    notifyListeners();
    return run;
  }

  Future<void>? _restarting;

  /// Whether [restartDaemon] runs.
  bool get restarting => _restarting != null;

  Future<void> _restart() async {
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
      await ping();
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
      await ping();
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

  /// Sees each event before it's applied (the Mac's notifications).
  void Function(EventsResponse)? onEvent;

  void _handle(EventsResponse e) {
    onEvent?.call(e);
    if (e.hasRemote()) {
      remoteState.value = e.remote;
    } else if (e.hasUpdate()) {
      if (!remote) _sawUpdate(e.update);
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
      _forget({e.chatId});
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
      // And what's kept for chats deleted while the app was away: the
      // stores keep the chats of the app's whole life.
      final kept = {
        ...chats.keys,
        if (!remote) ...[
          ...chatsKept(),
          ...reviews.value.keys,
          ...rememberedContexts,
        ],
        ...?drafts?.ids,
      };
      _forget(kept.difference(ids).difference(sides.keys.toSet()));
      for (final side in sides.values) {
        side.loading = true; // its events wait for its snapshot
      }
      chatsListed = true;
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
      if (chat.side.value case final side?) {
        try {
          side.load(await client.getChat(GetChatRequest(chatId: side.id)));
        } on Object {
          chat.side.value = null;
          sides.remove(side.id);
        }
      }
    }
    if (selected != null) unawaited(_load(selected!));
    notifyListeners();
  }

  /// Forgets the chats [ids], gone (deleted here, or while the app was
  /// away), and everything kept for them: the prefs kept by chat (their
  /// Changes scope, terminals panel, place in their project's order, when
  /// opened, pins, pull request's comments seen and Clean up's Not now),
  /// review comments, context breakdown, terminals and draft. (A pin goes
  /// with its chat: the daemon's.)
  void _forget(Set<String> ids) {
    for (final id in ids) {
      chats.remove(id);
      drafts?.forget(id);
      if (commentsOf(id).isNotEmpty) setComments(id, []);
      if (!remote) forgetContext(id);
      terminals.forget(id);
    }
    forgetChats(ids);
    if (ids.contains(selectedId)) selectedId = null;
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
  Future<void> _load(ChatState chat, [int tries = 0]) async {
    if (chat.loaded || chat.loading) return;
    chat
      ..loading = true
      ..stale = () => _reload(chat);
    try {
      // The phone takes the recent part first, older pages on scrolling
      // up: a long chat opens fast on a slow link.
      chat.load(
        await client.getChat(
          // From API 71, whose events say where each item is.
          GetChatRequest(
            chatId: chat.id,
            recent: remote && daemonApi >= 71 ? recentItems : 0,
          ),
        ),
      );
    } on Object catch (e) {
      chat.unload();
      if (remote) {
        // The phone: no raw error, but tries again (and again once the link
        // is back); details show why.
        chat.loadError = errorText(e);
        _retryLoad(chat, tries);
      } else {
        chat.error = errorText(e);
      }
      notifyListeners();
    }
  }

  /// How many of a chat's latest items the phone takes first.
  static const recentItems = 80;

  /// Takes a fresh snapshot of [chat] (an event reached past what the phone
  /// has of it).
  void _reload(ChatState chat) {
    if (!chat.loaded) return;
    chat.unload();
    unawaited(_load(chat));
  }

  /// Takes the page of [chat]'s items before those it has, as the phone
  /// scrolls up (nothing when it has them all, or a page is on its way).
  Future<void> loadOlder(ChatState chat) async {
    if (chat.older == 0 || chat.loadingOlder || chat.items.isEmpty) return;
    chat
      ..loadingOlder = true
      ..notifyListeners();
    final before = chat.items.first.id;
    final snapshot = chat.snapshots;
    try {
      final page = await client.getChatItems(
        GetChatItemsRequest(
          chatId: chat.id,
          before: before,
          limit: recentItems,
        ),
      );
      // Only onto what it was asked for: a reload meanwhile (a reconnect,
      // a rewind) took another snapshot.
      if (chat.loaded &&
          chat.snapshots == snapshot &&
          chat.items.isNotEmpty &&
          chat.items.first.id == before) {
        chat.prepend(page.items, page.older);
      }
    } on Object {
      // Asked again on the next scroll up.
    } finally {
      chat
        ..loadingOlder = false
        ..notifyListeners();
    }
  }

  Timer? _loadRetry;

  /// Tries a failed load again while the chat shows and the daemon
  /// answers: 2 s, then twice as long each time, up to 30 s.
  void _retryLoad(ChatState chat, [int tries = 0]) {
    final wait = Duration(seconds: [2, 4, 8, 16, 30][min(tries, 4)]);
    _loadRetry?.cancel();
    _loadRetry = Timer(wait, () {
      if (chat.loaded || chat.id != selectedId || !chats.containsKey(chat.id)) {
        return;
      }
      if (!connected) return _retryLoad(chat, tries + 1); // relinking
      unawaited(_load(chat, tries + 1)); // which comes back here if it fails
    });
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
    // An archived chat's draft goes; one unarchived is followed again.
    if (c.archived) {
      drafts?.forget(c.id);
    } else {
      drafts?.attach(chat);
    }
    return chat
      ..worktree = c.hasWorktree() ? c.worktree : null
      ..agent = c.agent
      ..scratch = c.scratch
      ..jiraSite = c.jiraSite
      ..jiraKey = c.jiraKey
      ..github = c.hasGithub() ? c.github : null
      ..pull = c.hasPull()
          ? c.pull
          : c.github.pull
          ? c.github
          : null
      ..title = c.title
      ..archived = c.archived
      ..unseen = daemonApi >= unseenApi ? c.unseen : null
      ..pin = c.pin
      ..created = DateTime.fromMillisecondsSinceEpoch(c.createdUnixMs.toInt())
      // Only the list carries a status; a chat event would clear it.
      ..listed(c.hasStatus() ? c.status : null);
  }

  /// The chats' list changed here ahead of the daemon's events (pins):
  /// whatever shows it builds again.
  void listChanged() => notifyListeners();

  void select(String chatId) {
    _leaveTrust();
    selectedId = chatId;
    chatOpened.value = {
      ...chatOpened.value,
      chatId: DateTime.now().millisecondsSinceEpoch,
    };
    place = const ChatPlace();
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
  void reopen(ChatState chat) =>
      client.reopenChat(ReopenChatRequest(chatId: chat.id)).ignore();

  /// Where the user is: a start that ends elsewhere doesn't take them
  /// to its chat.
  (String?, Place) get _place => (selectedId, place);

  /// The folder a chat is starting in ('' for none), while one is.
  String? starting;

  /// Why each agent whose last start failed in this run didn't start, as
  /// the daemon said ("couldn't start Ante: …"); a start that works clears
  /// it.
  final cantStart = <String, String>{};

  /// Starts a chat with [agent] in [folder], or in a scratch folder of its
  /// own (''); never in a worktree unless asked, as nothing is remembered
  /// (the "New worktree" chip moves it). A chat on a Jira [issue] remembers
  /// it and takes its worktree choice; its box stays empty (the agent's
  /// tools say which issue it is).
  Future<void> startChat(
    String folder,
    String agent, {
    IssueChat? issue,
  }) async {
    starting = folder;
    notifyListeners();
    try {
      if (!await _mayRun(folder, 'Start a chat', agent)) return;
      final before = _place;
      final StartChatResponse resp;
      try {
        resp = await client.startChat(
          StartChatRequest(
            agent: agent,
            folder: folder,
            worktree: issue?.worktree ?? false,
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
        if (refusedFor(
          e,
          'agent_start',
          (m) => m.startsWith("couldn't start "),
        )) {
          cantStart[agent] = e.message;
        }
        rethrow;
      }
      cantStart.remove(agent);
      chats[resp.chatId] ??= ChatState(resp.chatId, folder);
      // Not if the user went elsewhere meanwhile: a trust card or another
      // chat they're on stays.
      if (_place == before && trustAsk == null) {
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
      final before = _place;
      final resp = await client.openAgentSession(
        OpenAgentSessionRequest(
          agent: agent,
          folder: folder,
          sessionId: session.sessionId,
          title: session.title,
        ),
      );
      chats[resp.chatId] ??= ChatState(resp.chatId, folder);
      if (_place == before && trustAsk == null) {
        select(resp.chatId);
      }
    } finally {
      starting = null;
      notifyListeners();
    }
  }

  /// Moves a chat to [folder], or to a new worktree of its repository
  /// ([worktree]), and says whether it did (not when the user cancelled).
  Future<bool> moveChat(
    ChatState chat,
    String folder, {
    bool worktree = false,
  }) async {
    if (!await _mayRun(folder, 'Move the chat', chat.agent)) return false;
    await client.moveChat(
      MoveChatRequest(chatId: chat.id, folder: folder, worktree: worktree),
    );
    return true;
  }

  /// Opens [chat]'s side chat (a fork of it, ForkChat; one at a time),
  /// unless it has one or one is on its way.
  Future<void> openSide(ChatState chat) async {
    if (chat.side.value != null || chat.forking.value) return;
    chat.forking.value = true;
    try {
      final resp = await client.forkChat(ForkChatRequest(chatId: chat.id));
      final side = sides[resp.chatId] = ChatState(resp.chatId, chat.folder)
        ..agent = chat.agent;
      unawaited(_load(side));
      chat.side.value = side;
    } finally {
      chat.forking.value = false;
    }
  }

  /// Ends [chat]'s side chat, if it has one.
  void closeSide(ChatState chat) {
    final side = chat.side.value;
    if (side == null) return;
    chat.side.value = null;
    sides.remove(side.id);
    client.closeSideChat(CloseSideChatRequest(chatId: side.id)).ignore();
  }

  /// A side chat the daemon ended (its chat reloaded, moved or archived,
  /// or its agent quit).
  void _sideGone(ChatState side) {
    sides.remove(side.id);
    for (final chat in chats.values) {
      if (chat.side.value == side) chat.side.value = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loadRetry?.cancel();
    unawaited(_events?.cancel());
    if (!remote) unawaited(_transport.close());
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

/// The branch for a chat on GitHub issue [n]:
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
