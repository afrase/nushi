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

/// The five agents, as the daemon lists them: installed, ready.
List<Agent> readyAgents() => [
  for (final (name, title) in [
    ('claude', 'Claude'),
    ('codex', 'Codex'),
    ('ante', 'Ante'),
    ('omp', 'oh-my-pi'),
    ('pi', 'Pi'),
    ('pig', 'PiG'),
  ])
    Agent(
      name: name,
      title: title,
      path: '/bin/$name',
      ready: true,
      mcpUserOnly: name == 'ante',
    ),
];

/// A daemon with [chats] and [agents] for widget tests; it records the
/// chats asked for in [started], and fails them with [startError] if set.
class FakeDaemon implements Transport {
  new(this.chats);

  final List<Chat> chats;

  /// What ListAgents answers; the agents set up and removed.
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

  /// Answers calls the fake doesn't know (Jira's, git's): an answer (or a
  /// Future of one, to answer later), or null for the empty one; a thrown
  /// error fails the call. Every such call is in [calls].
  Object? Function(Object input)? answer;
  final calls = <Object>[];

  /// While set the daemon is gone: every call fails as the transport says
  /// when none answers, pings too.
  bool down = false;

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
  // The fake's stream, which lives as long as the test.
  final _events = StreamController<EventsResponse>()..add(EventsResponse());

  /// Sends [e] down the events stream.
  void emit(EventsResponse e) => _events.add(e);

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
    if (down) {
      throw ConnectException(
        Code.unavailable,
        'daemon unavailable: dial failed',
      );
    }
    if (input is ListAgentSessionsRequest) listed.add(input);
    if (input is OpenAgentSessionRequest) opened.add(input);
    if (input is SetUpAgentRequest) setUp.add(input.agent);
    if (input is RemoveAgentRequest) removed.add(input.agent);
    if (input is SetSettingsRequest) setSettings.add(settings = input.settings);
    if (input is PinChatsRequest) _pin(input.chatIds);
    if (input is SetChatColorRequest) _color(input.chatId, input.color);
    if (input is PinMessageRequest) _pinMessage(input);
    if (input is ForkAsChatRequest) _fork(input.chatId, 'fork');
    if (input is KeepSideChatRequest) _fork(chats.first.id, 'kept');
    if (input is StartChatRequest) {
      started.add(input);
      if (startError case final e?) {
        throw ConnectException(
          Code.failedPrecondition,
          e,
          metadata: Headers()..add('nushi-reason', 'agent_start'),
        );
      }
    }
    if (input is WriteChatFileRequest && files.containsKey(input.path)) {
      calls.add(input);
      return UnaryResponse(spec, Headers(), _write(input) as O, Headers());
    }
    var other = answer?.call(input);
    if (other is Future) other = await other;
    calls.add(input);
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
              agents: agents,
              environment: refreshEnvironment || reloadEnvironment
                  ? environment
                  : null,
            ),
          GetSettingsRequest() => GetSettingsResponse(settings: settings),
          // A chat it has, so the app can show it.
          StartChatRequest() => StartChatResponse(chatId: chats.first.id),
          ListAgentSessionsRequest() =>
            sessions?.call(input) ?? ListAgentSessionsResponse(canList: true),
          OpenAgentSessionRequest() => OpenAgentSessionResponse(
            chatId: chats.first.id,
          ),
          ForkAsChatRequest() => ForkAsChatResponse(chatId: 'fork'),
          KeepSideChatRequest() => KeepSideChatResponse(chatId: 'kept'),
          _ => spec.outputFactory(),
        };
    return UnaryResponse(spec, Headers(), out as O, Headers());
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
    emit(EventsResponse(chatId: id, chat: fork));
  }

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
      if (c.pin != pin) emit(EventsResponse(chatId: c.id, chat: c..pin = pin));
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
      emit(EventsResponse(chatId: id, chat: c..color = color));
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
    emit(
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
      editable: true,
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
  /// events' stream. Every such request is in [calls].
  Stream<Object>? Function(Object input)? streams;

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) async {
    if (streams != null || files.isNotEmpty) {
      final request = await input.first;
      if (streams?.call(request) case final s?) {
        calls.add(request);
        return StreamResponse(spec, Headers(), s.cast<O>(), Headers());
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
          watch.stream.cast<O>(),
          Headers(),
        );
      }
    }
    return StreamResponse(
      spec,
      Headers(),
      _events.stream as Stream<O>,
      Headers(),
    );
  }
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
