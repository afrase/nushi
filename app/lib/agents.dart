import 'chat.dart';
import 'gen/nushi/v1/nushi.pb.dart';

/// The agents the daemon runs (ListAgents), by name, the default first.
var knownAgents = <String, Agent>{};

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
