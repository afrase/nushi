import 'package:flutter/foundation.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The agents the daemon runs (ListAgents), by name, the default first,
/// as last found on this Mac.
final agentList = ValueNotifier<Map<String, Agent>>({});

Map<String, Agent> get knownAgents => agentList.value;

/// How the daemon last read the login shell's environment, which agents
/// start with (ADR 0048); null until Settings › Agents asked.
final shellEnvironment = ValueNotifier<ShellEnvironment?>(null);

/// Has the daemon find the agents again; with [refreshEnvironment], read
/// the shell's environment first if it was read over a minute ago, with
/// [reloadEnvironment] whatever its age.
Future<void> listAgents(
  NushiServiceClient client, {
  bool refreshEnvironment = false,
  bool reloadEnvironment = false,
}) async {
  final resp = await client.listAgents(
    ListAgentsRequest(
      refreshEnvironment: refreshEnvironment,
      reloadEnvironment: reloadEnvironment,
    ),
  );
  agentList.value = {for (final a in resp.agents) a.name: a};
  if (resp.hasEnvironment()) shellEnvironment.value = resp.environment;
}

/// [agent]'s name to show: "Claude".
String agentTitle(String agent) => switch (agent) {
  _ when knownAgents[agent] != null => knownAgents[agent]!.title,
  '' => 'The agent',
  _ => agent[0].toUpperCase() + agent.substring(1),
};

/// The agent whose MCP servers Nushi shows and changes, if one is known.
Agent? get mcpAgent => knownAgents.values.where((a) => a.mcp).firstOrNull;

/// The agent new chats start with: the newest of [chats]'s, else the
/// default.
String lastAgent(Iterable<ChatState> chats) {
  ChatState? newest;
  for (final c in chats) {
    if (knownAgents.containsKey(c.agent) &&
        (newest == null || c.created.isAfter(newest.created))) {
      newest = c;
    }
  }
  return newest?.agent ?? knownAgents.keys.firstOrNull ?? '';
}
