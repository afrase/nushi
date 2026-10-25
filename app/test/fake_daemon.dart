import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The five agents, as the daemon lists them: installed, ready.
List<Agent> readyAgents() => [
  for (final (name, title) in [
    ('claude', 'Claude'),
    ('codex', 'Codex'),
    ('ante', 'Ante'),
    ('omp', 'oh-my-pi'),
    ('pig', 'PiG'),
  ])
    Agent(name: name, title: title, path: '/bin/$name', ready: true),
];

/// A daemon with [chats] and [agents] for widget tests; it records the
/// chats asked for in [started], and fails them with [startError] if set.
class FakeDaemon implements Transport {
  new(this.chats);

  final List<Chat> chats;

  /// What ListAgents answers; the agents set up and removed.
  List<Agent> agents = readyAgents();
  final setUp = <String>[];
  final removed = <String>[];
  final started = <StartChatRequest>[];

  /// What GetSettings answers, and each SetSettings.
  Settings settings = Settings(sleepAfterMinutes: 30);
  final setSettings = <Settings>[];
  String? startError;

  /// What ListAgentSessions answers (nothing listed when unset), and the
  /// requests: listed and opened.
  ListAgentSessionsResponse Function(ListAgentSessionsRequest)? sessions;
  final listed = <ListAgentSessionsRequest>[];
  final opened = <OpenAgentSessionRequest>[];
  // The fake's stream, which lives as long as the test.
  // ignore: close_sinks
  final _events = StreamController<EventsResponse>()..add(EventsResponse());

  /// A [Daemon] on this fake, its chats and agents listed.
  Future<Daemon> connect(WidgetTester tester) async {
    final d = Daemon(transport: this);
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
    if (input is ListAgentSessionsRequest) listed.add(input);
    if (input is OpenAgentSessionRequest) opened.add(input);
    if (input is SetUpAgentRequest) setUp.add(input.agent);
    if (input is RemoveAgentRequest) removed.add(input.agent);
    if (input is SetSettingsRequest) setSettings.add(settings = input.settings);
    if (input is StartChatRequest) {
      started.add(input);
      if (startError case final e?) throw ConnectException(Code.unknown, e);
    }
    final out = switch (input) {
      PingRequest() => PingResponse(apiVersion: apiVersion),
      ListChatsRequest() => ListChatsResponse(chats: chats),
      ListAgentsRequest() => ListAgentsResponse(agents: agents),
      GetSettingsRequest() => GetSettingsResponse(settings: settings),
      // A chat it has, so the app can show it.
      StartChatRequest() => StartChatResponse(chatId: chats.first.id),
      ListAgentSessionsRequest() =>
        sessions?.call(input) ?? ListAgentSessionsResponse(canList: true),
      OpenAgentSessionRequest() => OpenAgentSessionResponse(
        chatId: chats.first.id,
      ),
      _ => spec.outputFactory(),
    };
    return UnaryResponse(spec, Headers(), out as O, Headers());
  }

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) async =>
      StreamResponse(spec, Headers(), _events.stream as Stream<O>, Headers());
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
