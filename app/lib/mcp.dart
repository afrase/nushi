import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp_actions.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings › MCP servers: a folder picker, then each agent's servers
/// (Claude's by scope, Ante's yours only), each with its state, transport
/// and command or URL (secrets masked).
class McpView extends StatelessWidget {
  const new({required this.daemon, required this.folder, super.key});

  final Daemon daemon;
  final String folder;

  /// What Ante's group says: it has yours only, and no off switch.
  static const anteAbout =
      'Yours, in every folder: Ante reads no project’s MCP servers. It has '
      'no off switch (remove a server instead), and a change applies to new '
      'Ante sessions.';

  Future<void> _pick() async {
    final f = await getDirectoryPath(confirmButtonText: 'Show');
    if (f != null) daemon.showMcp(f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final agents = [for (final a in mcpAgents) a.name];
    final lists = [
      for (final a in agents.isEmpty ? ['claude'] : agents)
        McpServers.of(daemon, folder, agent: a),
    ];
    final (name, dir) = folderParts(
      folder,
      scratch: daemon.chats.values.any((c) => c.scratch && c.folder == folder),
    );
    return ListenableBuilder(
      listenable: Listenable.merge(lists),
      builder: (context, _) {
        final checking = lists.any((l) => l.checking);
        return SettingsPage(
          title: 'MCP servers',
          actions: [
            if (checking)
              Text('Checking…', style: theme.ui(t.textMuted, size: 12)),
            Button(
              label: 'Check again',
              onPressed: checking
                  ? null
                  : () {
                      for (final l in lists) {
                        unawaited(l.refresh());
                      }
                    },
            ),
            if (lists.length == 1)
              Button(
                label: 'Add server',
                icon: Icons.add,
                onPressed: () => mcpForm(context, lists.single),
              )
            else
              MenuButton(
                label: 'Add server',
                icon: Icons.add,
                entries: [
                  for (final l in lists)
                    MenuEntry(
                      'For ${agentTitle(l.agent)}…',
                      onPick: () => mcpForm(context, l),
                    ),
                ],
              ),
          ],
          children: [
            Row(
              children: [
                Text('In ', style: theme.ui(t.textSecondary, size: 12)),
                Flexible(
                  child: MenuField(
                    compact: true,
                    entries: folderEntries(
                      daemon,
                      checked: folder,
                      onPick: (f) => f == null ? _pick() : daemon.showMcp(f),
                    ),
                    label: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: name,
                            style: theme.ui(t.text, size: 12),
                          ),
                          TextSpan(
                            text: '  $dir',
                            style: theme.ui(t.textMuted, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // The groups' own space is under them.
            const SizedBox(height: 20),
            for (final list in lists) ...[
              if (lists.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    agentTitle(list.agent),
                    style: theme.ui(t.text, size: 14, weight: FontWeight.w600),
                  ),
                ),
              if (list.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(list.error, style: theme.ui(t.crashed, size: 12)),
                ),
              if (list.ante)
                _Group(list, 'user', 'User', anteAbout)
              else
                for (final MapEntry(key: scope, value: (title, about))
                    in scopes.entries)
                  if (scope != 'other' ||
                      list.servers.any((s) => s.scope == scope))
                    _Group(list, scope, title, about),
            ],
          ],
        );
      },
    );
  }
}

/// One scope's servers, under its heading.
class _Group extends StatelessWidget {
  const new(this.list, this.scope, this.title, this.about);

  final McpServers list;
  final String scope;
  final String title;
  final String about;

  @override
  Widget build(BuildContext context) {
    // Plugins' servers and connectors come with the check.
    final later = scope == 'plugin' || scope == 'claudeai' || !list.loaded;
    return SettingsGroup(
      title: title,
      about: about,
      empty: later && list.checking ? 'Checking…' : 'None',
      children: [
        for (final s in list.servers)
          if (s.scope == scope) _Row(list, s, shadowedBy: _winner(s)),
      ],
    );
  }

  /// The scope of the server that hides [s], if one does.
  String? _winner(McpServer s) => !s.shadowed
      ? null
      : list.used
            .where((u) => u.name == s.name)
            .map((u) => scopes[u.scope]?.$1)
            .firstOrNull;
}

/// A server: its state, name, transport and command or URL, its masked
/// env vars and headers, and why it failed.
class _Row extends StatelessWidget {
  const new(this.list, this.server, {this.shadowedBy});

  final McpServers list;
  final McpServer server;
  final String? shadowedBy;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = config(server);
    final hidden = secrets(c);
    final shadowed = shadowedBy != null;
    final off = server.off || server.state == 'disabled';
    final failed = server.state == 'failed' && server.detail.isNotEmpty;
    final (word, color) = stateOf(server, t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: shadowed || off ? 0.5 : 1,
                  child: Row(
                    children: [
                      if (!shadowed)
                        McpDot(server)
                      else
                        const SizedBox(width: 11),
                      const SizedBox(width: 8),
                      Text(
                        server.name,
                        style: theme.ui(t.text, weight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        transport(c),
                        style: theme.code(t.textMuted, size: 11),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Tooltip(
                          message: server.source,
                          child: Text(
                            target(c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.code(t.textSecondary, size: 11.5),
                          ),
                        ),
                      ),
                      if (!shadowed) ...[
                        const SizedBox(width: 12),
                        Text(word, style: theme.ui(color, size: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              McpActions(list, server),
            ],
          ),
          if (hidden.isNotEmpty || shadowed || failed)
            Opacity(
              opacity: shadowed || off ? 0.5 : 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 19, top: 3),
                child: Text(
                  [
                    if (shadowed)
                      'Not used: the $shadowedBy one has the same name',
                    if (failed) server.detail,
                    if (hidden.isNotEmpty) hidden,
                  ].join('  ·  '),
                  style: failed
                      ? theme.ui(t.crashed, size: 11.5)
                      : theme.code(t.textMuted, size: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
