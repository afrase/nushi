import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'mcp_servers.dart';
import 'panel_cards.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The details panel's MCP card: the servers the agent uses in the chat's
/// folder, each with its state; "Manage…" opens the MCP servers view.
PanelCard mcpCard(ChatState chat, Daemon daemon) {
  final list = McpServers.of(daemon, chat.folder);
  return PanelCard(
    title: 'MCP',
    summary: ListenableBuilder(
      listenable: list,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final s in list.used.take(12)) McpDot(s)],
      ),
    ),
    rows: [(null, _Servers(list, daemon))],
  );
}

class _Servers extends StatelessWidget {
  const _Servers(this.list, this.daemon);

  final McpServers list;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
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
          if (list.error.isNotEmpty && !list.checking)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${list.error} '),
                  WidgetSpan(
                    child: Tap(
                      onTap: list.refresh,
                      child: Text(
                        'Try again',
                        style: theme.ui(t.link, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
              style: theme.ui(t.crashed, size: 12),
            ),
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
                ],
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              onTap: () => daemon.showMcp(list.folder),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('Manage…', style: theme.ui(t.link, size: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
