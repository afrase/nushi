import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_link.dart' show rowItem;

import 'agent_facts_fixture.dart';

/// The agents as the daemon lists them, installed and ready: each one's
/// facts (its title, sign-in, what deletes its sessions, its adapter…)
/// from internal/e2e/testdata/agents.json, which a Go test checks against
/// the daemon's own list; none in the browser, which can't read it.
List<Agent> readyAgents() => [
  for (final a in agentFacts())
    Agent(
      name: a['name']! as String,
      title: a['title']! as String,
      path: '/bin/${a['name']}',
      ready: true,
      mcpUserOnly: a['mcpUserOnly']! as bool,
      goAgentSwitch: a['goAgentSwitch']! as bool,
      signIn: a['signIn']! as String,
      expires: a['expires']! as String,
      adapter: switch (a['adapter']! as String) {
        '' => null,
        final package => Adapter(package: package),
      },
    ),
];

/// A daemon with [chats] and [agents] for widget tests; it records the
/// chats asked for in [started], and fails them with [startError] if set.
class FakeDaemon implements Transport {
  new(List<Chat> chats) : chats = [for (final c in chats) c.deepCopy()];

  /// The daemon's chats: copies of its own, so one it adds (a fork, a new
  /// chat) or drops, or a chat it changes (a pin, a color), isn't in a
  /// list or a chat its test shares with the next.
  final List<Chat> chats;

  /// What ListAgents answers (one with a Go agent switch without its
  /// adapter while [settings] run it through the Go agent, as the daemon
  /// does); the agents set up and removed.
  List<Agent> agents = readyAgents();

  /// How reading the shell's environment went, as ListAgents tells it
  /// when asked to read it (Settings › Agents).
  ShellEnvironment? environment;
  final setUp = <String>[];
  final removed = <String>[];
  final started = <StartChatRequest>[];

  /// What GetSettings answers, and each SetSettings.
  Settings settings = Settings(sleepAfterMinutes: 30);
  final setSettings = <Settings>[];
  String? startError;

  /// The plain why a [startError] carries (AgentStartError, API 144); null
  /// as from an older daemon.
  String? startWhy;

  /// The ways to sign in a [startError] carries, as a start the agent
  /// refused for want of a sign-in does (API 139).
  AgentSignIn? startSignIn;

  /// Each SignInAgent asked for. One waits for [signInGate] when set, and
  /// fails with the message it completes with (null: signed in), or as
  /// Canceled once its call is cancelled.
  final signIns = <SignInAgentRequest>[];
  Completer<String?>? signInGate;

  /// Answers calls the fake doesn't know (Jira's, git's): an answer (or a
  /// Future of one, to answer later), or null for the empty one; a thrown
  /// error fails the call. Every such call is in [calls]. GetGitHubItems
  /// it leaves unanswered are its GetGitHubPull answers' rows.
  Object? Function(Object input)? answer;
  final calls = <Object>[];

  /// Puts [fn] in front of [answer]: what it answers wins, and a call it
  /// answers null goes on to the answer before it (the fake's own when
  /// none). So it can't force the empty answer over an earlier one, and a
  /// Future it returns wins even if it ends in null.
  void on(Object? Function(Object input) fn) {
    final before = answer;
    answer = (input) => fn(input) ?? before?.call(input);
  }

  /// What GetChat answers for a chat by its id, with the chat itself:
  /// its transcript's items. A chat not in it answers the empty response.
  /// [answer] goes first.
  final chatItems = <String, List<Item>>{};

  /// What GetDiff with a path (a file preview's question, API 121) answers,
  /// by the file's absolute path (folder and path joined): its one change,
  /// or an exception to throw. A file not in it answers no change, as a
  /// tracked, unchanged one does. [answer] goes first.
  final fileDiffs = <String, Object>{};

  /// The folders GetDiff's names (the Files tree's dots, API 123) answers
  /// for: each [fileDiffs] change under one, unskipped and not deleted,
  /// by its path in the folder, whatever the base. Any other folder
  /// isn't a git repository. [answer] goes first.
  final repositories = <String>{};

  /// The chats' images GetChatImage answers, by hash (ADR 0099); another
  /// hash is NotFound.
  final chatImages = <String, ImageData>{};

  /// The projects' icons GetProjectIcon answers, by folder (ADR 0112);
  /// another folder has none.
  final projectIcons = <String, List<int>>{};

  /// What GetUsage answers (ADR 0136), whatever the range: nothing used
  /// until a test sets it.
  GetUsageResponse usage = GetUsageResponse();

  /// While set the daemon is gone: every call fails as the transport says
  /// when none answers, pings too, and setting it drops every stream it
  /// serves with that error (events subscriptions, watches, the [streams]
  /// hook's), as a daemon that stops ends them all.
  bool get down => _down;
  set down(bool gone) {
    _down = gone;
    if (!gone) return;
    for (final s in subscriptions.where((s) => s.live)) {
      s._out
        ..addError(_unavailable())
        ..close().ignore();
    }
    for (final drop in [..._served]) {
      drop();
    }
    _served.clear();
  }

  /// How to drop each open stream the fake serves besides Events.
  final _served = <void Function()>{};

  /// [source] as the daemon serves it: until the app lets it go, or until
  /// [down] ends it with the transport's error.
  Stream<Object> _droppable(Stream<Object> source) {
    StreamSubscription<Object>? sub;
    late final StreamController<Object> out;
    void drop() {
      if (out.isClosed) return;
      sub?.cancel().ignore();
      sub = null;
      out
        ..addError(_unavailable())
        ..close().ignore();
    }

    // Synchronous: each message reaches the app when the source's does,
    // as if the source were served itself.
    out = StreamController<Object>(
      sync: true,
      onListen: () => sub = source.listen(
        out.add,
        onError: out.addError,
        onDone: () {
          _served.remove(drop);
          sub = null;
          out.close().ignore();
        },
      ),
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        _served.remove(drop);
        final s = sub;
        sub = null;
        return s?.cancel();
      },
    );
    _served.add(drop);
    return out.stream;
  }

  bool _down = false;

  /// The transport's error when no daemon answers.
  ConnectException _unavailable() =>
      ConnectException(Code.unavailable, 'daemon unavailable: dial failed');

  /// The daemon gone for a ping, then back, as across a restart.
  Future<void> restart(WidgetTester tester) async {
    down = true;
    await tester.pump(const Duration(seconds: 2));
    down = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  /// What ListAgentSessions answers (nothing listed when unset), and the
  /// requests: listed and opened.
  ListAgentSessionsResponse Function(ListAgentSessionsRequest)? sessions;
  final listed = <ListAgentSessionsRequest>[];
  final opened = <OpenAgentSessionRequest>[];

  /// What SearchAgentSessions answers (a Future of it, to answer later; a
  /// thrown error fails it; nothing found when unset), the searches, and
  /// the texts of those the app cancelled.
  FutureOr<SearchAgentSessionsResponse> Function(SearchAgentSessionsRequest)?
  searches;
  final searched = <SearchAgentSessionsRequest>[];
  final cancelledSearches = <String>[];

  /// The requests whose caller cancelled them, as each was.
  final cancelled = <Object>[];

  /// Each Events subscription the app made, first to last, as the daemon
  /// gives each its own stream: a second one is a reconnect.
  final subscriptions = <EventsSubscription>[];

  /// Sends [e] down every live events subscription. With none live it
  /// throws, as an event the daemon sends then reaches nobody: a test
  /// that emits before the app subscribes has a gap, not an event.
  void emit(EventsResponse e) {
    if (!subscriptions.any((s) => s.live)) {
      throw StateError('FakeDaemon.emit with no live events subscription');
    }
    _send(e);
  }

  /// Sends [e] to whoever is subscribed, as the daemon's own changes (a
  /// fork, a pin) go out whether or not anyone listens.
  void _send(EventsResponse e) {
    for (final s in subscriptions.where((s) => s.live)) {
      s._out.add(e);
    }
  }

  /// A new events subscription for [request]: its first message, empty,
  /// says it's live (internal/api/api.go's Events).
  EventsSubscription _subscribe(EventsRequest request) {
    final s = EventsSubscription._(request);
    s._out.add(EventsResponse());
    subscriptions.add(s);
    return s;
  }

  /// A [Daemon] on this fake, its chats and agents listed; it keeps
  /// drafts in [drafts], if given.
  Future<Daemon> connect(WidgetTester tester, {Drafts? drafts}) async {
    final d = Daemon(transport: this, drafts: drafts);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    return d;
  }

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) async {
    if (down) throw _unavailable();
    if (options?.signal case final signal?) {
      unawaited(signal.future.then((_) => cancelled.add(input)));
    }
    if (input is ListAgentSessionsRequest) listed.add(input);
    if (input is OpenAgentSessionRequest) opened.add(input);
    if (input is SearchAgentSessionsRequest) {
      searched.add(input);
      unawaited(
        options?.signal?.future.then((_) => cancelledSearches.add(input.text)),
      );
      final r =
          await searches?.call(input) ??
          SearchAgentSessionsResponse(canSearch: true);
      return UnaryResponse(spec, Headers(), r as O, Headers());
    }
    if (input is SetUpAgentRequest) setUp.add(input.agent);
    if (input is RemoveAgentRequest) removed.add(input.agent);
    if (input is SetSettingsRequest) setSettings.add(settings = input.settings);
    if (input is PinChatsRequest) _pin(input.chatIds);
    if (input is SetChatColorRequest) _color(input.chatId, input.color);
    if (input is PinMessageRequest) _pinMessage(input);
    if (input is ForkAsChatRequest) _fork(input.chatId, _nextFork());
    if (input is KeepSideChatRequest) _fork(chats.first.id, 'kept');
    if (input is StartChatRequest) {
      started.add(input);
      if (startError case final e?) {
        throw ConnectException(
          Code.failedPrecondition,
          e,
          metadata: Headers()..add('nushi-reason', 'agent_start'),
          details: [
            if (startSignIn case final s?)
              ErrorDetail(s.info_.qualifiedMessageName, s.writeToBuffer()),
            if (startWhy case final w?)
              ErrorDetail(
                AgentStartError().info_.qualifiedMessageName,
                AgentStartError(why: w).writeToBuffer(),
              ),
          ],
        );
      }
    }
    if (input is SignInAgentRequest) {
      signIns.add(input);
      final waits = <Future<Object?>>[
        if (signInGate case final g?) g.future,
        if (options?.signal case final s?) s.future,
      ];
      final out = waits.isEmpty ? null : await Future.any(waits);
      switch (out) {
        case ConnectException():
          throw ConnectException(Code.canceled, 'operation canceled');
        case final String why:
          throw ConnectException(Code.failedPrecondition, why);
      }
      return UnaryResponse(
        spec,
        Headers(),
        SignInAgentResponse() as O,
        Headers(),
      );
    }
    if (input is WriteChatFileRequest && files.containsKey(input.path)) {
      calls.add(input);
      return UnaryResponse(spec, Headers(), _write(input) as O, Headers());
    }
    var other = answer?.call(input);
    if (other is Future) other = await other;
    if (other == null && input is GetGitHubItemsRequest) {
      other = await _itemsFromWhole(input);
    }
    calls.add(input);
    if (input is DeleteChatRequest) _delete(input.chatId);
    final out =
        other ??
        switch (input) {
          PingRequest() => PingResponse(apiVersion: apiVersion),
          ListChatsRequest() => ListChatsResponse(chats: chats),
          ListAgentsRequest(
            :final refreshEnvironment,
            :final reloadEnvironment,
          ) =>
            ListAgentsResponse(
              agents: [for (final a in agents) _asRun(a)],
              environment: refreshEnvironment || reloadEnvironment
                  ? environment
                  : null,
            ),
          GetSettingsRequest() => GetSettingsResponse(settings: settings),
          GetChatRequest(:final chatId) when chatItems.containsKey(chatId) =>
            GetChatResponse(
              chat: chats.where((c) => c.id == chatId).firstOrNull,
              items: chatItems[chatId],
            ),
          GetDiffRequest(:final folder, names: true) =>
            repositories.contains(folder)
                ? GetDiffResponse(
                    files: [
                      for (final MapEntry(:key, :value) in fileDiffs.entries)
                        if (value is FileChange &&
                            value.skipped.isEmpty &&
                            value.status != 'deleted' &&
                            key.startsWith('$folder/'))
                          FileChange(
                            path: key.substring(folder.length + 1),
                            status: value.status,
                          ),
                    ],
                  )
                : throw ConnectException(
                    Code.failedPrecondition,
                    '$folder is not in a git repository',
                  ),
          GetDiffRequest(:final folder, :final path) when path.isNotEmpty =>
            switch (fileDiffs['$folder/$path']) {
              final FileChange f => GetDiffResponse(files: [f]),
              final Exception e => throw e,
              _ => GetDiffResponse(),
            },
          // A chat it has, so the app can show it.
          StartChatRequest() => StartChatResponse(chatId: chats.first.id),
          ListAgentSessionsRequest() =>
            sessions?.call(input) ?? ListAgentSessionsResponse(canList: true),
          OpenAgentSessionRequest() => OpenAgentSessionResponse(
            chatId: chats.first.id,
          ),
          ForkAsChatRequest() => ForkAsChatResponse(chatId: chats.last.id),
          KeepSideChatRequest() => KeepSideChatResponse(chatId: 'kept'),
          GetChatImageRequest(:final sha256) => switch (chatImages[sha256]) {
            final i? => GetChatImageResponse(data: i.data),
            null => throw ConnectException(Code.notFound, 'no such image'),
          },
          GetProjectIconRequest(:final folder) =>
            switch (projectIcons[folder]) {
              final data? => GetProjectIconResponse(data: data),
              null => GetProjectIconResponse(),
            },
          GetUsageRequest() => usage,
          // Saved: the pull request is read again for what it says now.
          EditGitHubPullRequest() => EditGitHubPullResponse(),
          _ => spec.outputFactory(),
        };
    return UnaryResponse(spec, Headers(), out as O, Headers());
  }

  /// The next fork's id: fork, then fork2, fork3…
  String _nextFork() {
    final n = chats.where((c) => c.id.startsWith('fork')).length;
    return n == 0 ? 'fork' : 'fork${n + 1}';
  }

  /// Deletes chat [id] as the daemon does once [answer] lets it: gone from
  /// the list, announced as removed.
  void _delete(String id) {
    if (chats.any((c) => c.id == id)) {
      chats.removeWhere((c) => c.id == id);
      _send(EventsResponse(chatId: id, removed: true));
    }
  }

  /// A fork of chat [of] as the daemon makes one (ForkAsChat, and a kept
  /// side chat's): chat [id], titled as a fork, listed and announced.
  void _fork(String of, String id) {
    final c = chats.firstWhere((c) => c.id == of);
    final fork = Chat(
      id: id,
      agent: c.agent,
      title: '${c.title} (fork)',
      folder: c.folder,
      createdUnixMs: c.createdUnixMs,
      status: ChatStatus(asleep: id == 'kept'),
      color: c.color,
    );
    chats.add(fork);
    _send(EventsResponse(chatId: id, chat: fork));
  }

  /// GetGitHubItems answered as the daemon would from what [answer] says
  /// of each pull request whole (its row, `rowItem`), for a test that
  /// answers only GetGitHubPull; null when it says none.
  Future<GetGitHubItemsResponse?> _itemsFromWhole(
    GetGitHubItemsRequest input,
  ) async {
    final items = <GitHubItem>[];
    for (final ref in input.refs) {
      Object? whole;
      try {
        whole = answer?.call(GetGitHubPullRequest(ref: ref));
        if (whole is Future) whole = await whole;
      } on Object {
        continue; // the whole one fails: the row isn't known
      }
      if (whole is GetGitHubPullResponse &&
          whole.pull.item.ref.number == ref.number) {
        items.add(rowItem(whole.pull));
      }
    }
    return items.isEmpty ? null : GetGitHubItemsResponse(items: items);
  }

  /// [a] as the daemon lists it now: an agent through its Go agent
  /// (Settings.go_agents) needs no adapter, so it's ready once found.
  Agent _asRun(Agent a) =>
      a.goAgentSwitch && (settings.goAgents[a.name] ?? false)
      ? (a.deepCopy()
          ..clearAdapter()
          ..ready = a.path.isNotEmpty && a.problem.isEmpty)
      : a;

  /// Pins [ids] as the daemon does: each at its place, every other chat
  /// unpinned, an archived one never; a chat whose pin changed comes as
  /// an event.
  void _pin(List<String> ids) {
    final live = [
      for (final id in ids)
        if (chats.any((c) => c.id == id && !c.archived)) id,
    ];
    for (final c in chats) {
      final pin = live.indexOf(c.id) + 1;
      if (c.pin != pin) _send(EventsResponse(chatId: c.id, chat: c..pin = pin));
    }
  }

  /// Colors chat [id] as the daemon does: a name that isn't one of the
  /// eight is refused; a changed color comes as an event.
  void _color(String id, String color) {
    if (color.isNotEmpty && ChatColor.named(color) == null) {
      throw ConnectException(Code.invalidArgument, 'not a chat color');
    }
    final c = chats.firstWhere((c) => c.id == id);
    if (c.color != color) {
      _send(EventsResponse(chatId: id, chat: c..color = color));
    }
  }

  /// Pins or unpins a message as the daemon does: one pinned again keeps its
  /// place, titled "Pinned" and its id; a changed chat comes as an event.
  void _pinMessage(PinMessageRequest r) {
    final c = chats.firstWhere((c) => c.id == r.chatId);
    final ids = c.pinnedMessages;
    if (ids.contains(r.itemId) == r.pinned) return;
    r.pinned ? ids.add(r.itemId) : ids.remove(r.itemId);
    c.messagePins.removeWhere((p) => p.itemId == r.itemId);
    if (r.pinned) {
      c.messagePins.add(
        MessagePin(itemId: r.itemId, title: 'Pinned ${r.itemId}'),
      );
    }
    _send(
      EventsResponse(
        chatId: r.chatId,
        chat: chats.firstWhere((c) => c.id == r.chatId),
      ),
    );
  }

  /// The chats' files WatchChatFile and WriteChatFile read and write
  /// (ADR 0096), by the path asked for; null for one that isn't there.
  /// Each write is in [writes]; [putFile] changes one as an agent would.
  final files = <String, List<int>?>{};

  /// The [files] whose permissions don't let them be written: they show
  /// read-only.
  final readOnlyFiles = <String>{};
  final writes = <WriteChatFileRequest>[];
  final _watches = <String, List<StreamController<WatchChatFileResponse>>>{};

  /// [path] as its watch sends it now.
  WatchChatFileResponse fileNow(String path) => switch (files[path]) {
    null => WatchChatFileResponse(path: '/Users/me/nushi/$path', missing: true),
    final data => WatchChatFileResponse(
      path: '/Users/me/nushi/$path',
      data: data,
      size: Int64(data.length),
      sha256: sha256.convert(data).toString(),
      editable: !readOnlyFiles.contains(path),
      readOnly: readOnlyFiles.contains(path),
    ),
  };

  /// Changes [path] on disk ([data] null: deletes it), and its watches
  /// send it, as the daemon's would a second later.
  void putFile(String path, List<int>? data) {
    files[path] = data;
    for (final w
        in _watches[path] ??
            const <StreamController<WatchChatFileResponse>>[]) {
      w.add(fileNow(path));
    }
  }

  /// Sends [path]'s watches [message] as it is: one from before a save,
  /// arriving late.
  void sendWatch(String path, WatchChatFileResponse message) {
    for (final w
        in _watches[path] ??
            const <StreamController<WatchChatFileResponse>>[]) {
      w.add(message);
    }
  }

  WriteChatFileResponse _write(WriteChatFileRequest w) {
    writes.add(w);
    final now = files[w.path];
    final sum = now == null ? '' : sha256.convert(now).toString();
    if (now != null && listEquals(now, w.data)) {
      return WriteChatFileResponse(
        saved: WriteChatFileResponse_Saved(sha256: sum),
      );
    }
    if (now == null ? !w.mustNotExist : w.mustNotExist || sum != w.baseSha256) {
      return WriteChatFileResponse(
        stale: WriteChatFileResponse_Stale(
          sha256: sum,
          data: now,
          missing: now == null,
        ),
      );
    }
    files[w.path] = w.data;
    return WriteChatFileResponse(
      saved: WriteChatFileResponse_Saved(
        sha256: sha256.convert(w.data).toString(),
      ),
    );
  }

  /// Answers a stream call (its request): its messages, or null for the
  /// fake's own answer (Events: a new [subscriptions] entry). Every
  /// request it answers is in [calls]; [down] ends its streams too.
  Stream<Object>? Function(Object input)? streams;

  /// The dev servers' output WatchServerLog sends (ADR 0100), by
  /// DevServer.log_id: what [serverLog]'s controller is given, to each
  /// watch from then on. A server with none, or whose controller the test
  /// closed, is refused as one whose output the daemon no longer keeps.
  final _serverLogs = <String, StreamController<WatchServerLogResponse>>{};

  /// The output of the server [logId], for the test to send.
  StreamController<WatchServerLogResponse> serverLog(String logId) =>
      _serverLogs[logId] ??= () {
        final log = StreamController<WatchServerLogResponse>.broadcast();
        // Not waited on: its done waits on watches the app may have let go.
        addTearDown(() => unawaited(log.close()));
        return log;
      }();

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) async {
    if (down) throw _unavailable();
    final request = await input.first;
    if (streams?.call(request) case final s?) {
      calls.add(request);
      return StreamResponse(
        spec,
        Headers(),
        _droppable(s).cast<O>(),
        Headers(),
      );
    }
    if (request is EventsRequest) {
      final s = _subscribe(request);
      return StreamResponse(
        spec,
        Headers(),
        s._out.stream.cast<O>(),
        Headers(),
      );
    }
    // A folder the test doesn't list is empty, and stays watched while the
    // test runs, or until [down] (the Files pane's tree, open with every
    // file, ADR 0123).
    if (request case WatchChatFolderRequest(:final path)) {
      calls.add(request);
      final watch = StreamController<WatchChatFolderResponse>()
        ..add(WatchChatFolderResponse(folders: [FolderListing(path: path)]));
      addTearDown(watch.close);
      return StreamResponse(
        spec,
        Headers(),
        _droppable(watch.stream).cast<O>(),
        Headers(),
      );
    }
    {
      if (request case WatchServerLogRequest(:final serverId)) {
        calls.add(request);
        // One the test closed is gone, as the daemon's output of a server
        // five others ended after. Closed by the test, or as it ends.
        // ignore: close_sinks
        final log = _serverLogs[serverId];
        final live = log != null && !log.isClosed ? log.stream : null;
        return StreamResponse(
          spec,
          Headers(),
          _droppable(
            live ??
                Stream<WatchServerLogResponse>.error(
                  ConnectException(
                    Code.notFound,
                    'no such server’s output is kept in this chat’s folder',
                  ),
                ),
          ).cast<O>(),
          Headers(),
        );
      }
      if (request case WatchChatFileRequest(:final path)
          when files.containsKey(path)) {
        calls.add(request);
        final watch = StreamController<WatchChatFileResponse>();
        (_watches[path] ??= []).add(watch);
        addTearDown(watch.close);
        watch.add(fileNow(path));
        return StreamResponse(
          spec,
          Headers(),
          _droppable(watch.stream).cast<O>(),
          Headers(),
        );
      }
    }
    throw ConnectException(
      Code.unimplemented,
      'FakeDaemon has no stream for ${request.runtimeType}',
    );
  }
}

/// One events subscription on a [FakeDaemon]: what the app asked for, and
/// whether its stream is still open (the app hasn't let it go and the
/// daemon hasn't dropped it).
class EventsSubscription {
  new _(this.request);

  /// The request the app subscribed with.
  final EventsRequest request;

  /// Whether the stream still delivers: the app hasn't cancelled it and
  /// the daemon hasn't dropped it.
  bool get live => !_out.isClosed;

  // Closed when the app cancels, as the daemon's handler ends then.
  late final StreamController<EventsResponse> _out = StreamController(
    onCancel: () => _out.close(),
  );
}

/// A chat for [FakeDaemon], [age] minutes old.
Chat chat(
  String id,
  String agent,
  String title, {
  String folder = '/Users/me/nushi',
  int age = 0,
  ChatStatus? status,
}) => Chat(
  id: id,
  agent: agent,
  title: title,
  folder: folder,
  createdUnixMs: Int64(
    DateTime(2026, 10, 25, 12).millisecondsSinceEpoch - age * 60000,
  ),
  status: status ?? ChatStatus(),
);

/// The agent's message [text], item [id] of a transcript.
Item agentSays(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

/// The user's message [text], item [id] of a transcript.
Item userSays(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: text);

/// A Write the agent ran on [path], item [id] of a transcript.
Item wrote(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

/// An MCP tool call, item [id] of a transcript: [server]'s [tool] with
/// [args], titled and its input written as Claude sends one
/// (`mcp__server__tool`, the arguments as indented JSON) or, with
/// [codex], as Codex does (`mcp.server.tool`, the arguments inside its
/// server and tool). An [old] one is from a daemon before it named the
/// server and tool, Codex's then an execute call.
Item mcpCall(
  String id,
  String server,
  String tool,
  Map<String, Object> args, {
  bool codex = false,
  bool old = false,
  String status = 'completed',
  String text = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: codex && old ? 'execute' : 'other',
  title: codex ? 'mcp.$server.$tool' : 'mcp__${server}__$tool',
  mcpServer: old ? null : server,
  mcpTool: old ? null : tool,
  status: status,
  text: text,
  input: const JsonEncoder.withIndent(
    '  ',
  ).convert(codex ? {'server': server, 'tool': tool, 'arguments': args} : args),
);

/// Loads the app's fonts (the bundled ones and Material's icons), so
/// goldens show text rather than boxes.
Future<void> loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// [child] laid out at [size] and drawn [scale] times as large, so a
/// golden (taken at one pixel a point) shows a small mark's pixels.
Widget enlarged(Size size, double scale, Widget child) => RepaintBoundary(
  child: SizedBox(
    width: size.width * scale,
    height: size.height * scale,
    child: FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: size, child: child),
    ),
  ),
);

/// The daemon's refusal of an edit of a pull request whose text GitHub
/// changed since the edit began (API 128, reason changed_since).
ConnectException changedSinceRefusal() => ConnectException(
  Code.failedPrecondition,
  'it changed on GitHub since you opened it, so nothing was saved',
  metadata: Headers()..add('nushi-reason', 'changed_since'),
);
