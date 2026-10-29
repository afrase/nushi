import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/mcp_actions.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The details panel's MCP card: the servers the agent uses in the chat's
/// folder, each with its state and its switch for the project (a change
/// reaches the chat when it restarts, which the card then offers);
/// "Manage…" opens the MCP servers view. Claude's and Ante's (no switch:
/// Ante can't turn one off); an agent whose MCP config Nushi doesn't read
/// gets a note.
PanelCard mcpCard(ChatState chat, Daemon daemon) {
  if (knownAgents[chat.agent]?.mcp == false) {
    return PanelCard(
      title: 'MCP',
      rows: const [],
      note: "In ${chat.agentName}'s own config",
    );
  }
  final list = McpServers.of(
    daemon,
    chat.folder,
    agent: chat.agent.isEmpty ? 'claude' : chat.agent,
  );
  return PanelCard(
    title: 'MCP',
    summary: ListenableBuilder(
      listenable: list,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final s in list.used.take(12)) McpDot(s)],
      ),
    ),
    rows: [(null, _Servers(list, daemon, chat))],
  );
}

class _Servers extends StatelessWidget {
  const new(this.list, this.daemon, this.chat);

  final McpServers list;
  final Daemon daemon;
  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    return ListenableBuilder(
      listenable: list,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!list.loaded && list.checking)
            Text('…', style: muted)
          else if (list.loaded && list.used.isEmpty)
            Text('No MCP servers.', style: muted),
          if (list.error.isNotEmpty && !list.checking) ...[
            Text(list.error, style: theme.ui(t.crashed, size: 12)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Button(label: 'Try again', onPressed: list.refresh),
              ),
            ),
          ],
          for (final s in list.used)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  McpDot(s),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.text, size: 12),
                    ),
                  ),
                  Text(stateOf(s, t).$1, style: muted),
                  const SizedBox(width: 4),
                  McpSwitch(list, s, label: false),
                ],
              ),
            ),
          if (chat.mcpChanged && !chat.archived)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Applies when the chat restarts', style: muted),
                  ),
                  ReloadButton(chat, daemon),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Button(
              label: 'Manage…',
              onPressed: () => daemon.showMcp(list.folder),
            ),
          ),
        ],
      ),
    );
  }
}
