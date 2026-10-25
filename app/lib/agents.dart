import 'package:flutter/foundation.dart';

import 'chat.dart';
import 'gen/nushi/v1/nushi.connect.client.dart';
import 'gen/nushi/v1/nushi.pb.dart';

/// The agents the daemon runs (ListAgents), by name, the default first,
/// as last found on this Mac.
final agentList = ValueNotifier<Map<String, Agent>>({});

Map<String, Agent> get knownAgents => agentList.value;

/// Has the daemon find the agents again.
Future<void> listAgents(NushiServiceClient client) async {
  final list = (await client.listAgents(ListAgentsRequest())).agents;
  agentList.value = {for (final a in list) a.name: a};
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
