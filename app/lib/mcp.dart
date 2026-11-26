import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agent_words.dart';
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

/// Settings › MCP servers: a folder picker, then the servers of each agent
/// the daemon says Nushi reads them for (Agent.mcp), in the groups its
/// McpShape offers (Claude's user, project and local; Ante's yours only;
/// PiG's yours and the folder's own), each with its state, transport and
/// command or URL (secrets masked). "Reading…" until the daemon has
/// listed its agents.
class McpView extends StatelessWidget {
  const new({required this.daemon, required this.folder, super.key});

  final Daemon daemon;
  final String folder;

  /// What the group of an agent with yours only says: it also has no off
  /// switch.
  static String userOnlyAbout(String title) =>
      'Yours, in every folder: $title reads no project’s MCP servers. It has '
      'no off switch (remove a server instead), and a change applies to new '
      '$title sessions.';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: agentList,
    builder: (context, known, _) {
      final theme = NushiTheme.of(context);
      final muted = theme.ui(theme.t.textMuted, size: 12);
      final agents = [for (final a in mcpAgents) a.name];
      if (agents.isEmpty) {
        return SettingsPage(
          title: 'MCP servers',
          children: [
            Text(
              known.isEmpty
                  ? 'Reading…'
                  : 'No agent’s MCP servers are shown here',
              style: muted,
            ),
          ],
        );
      }
      return _Lists(daemon, folder, [
        for (final a in agents) McpServers.of(daemon, folder, agent: a),
      ]);
    },
  );
}

/// The page of [lists], one per agent with MCP.
class _Lists extends StatelessWidget {
  const new(this.daemon, this.folder, this.lists);

  final Daemon daemon;
  final String folder;
  final List<McpServers> lists;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
                  child: FolderMenuField(
                    daemon,
                    folder,
                    onShow: daemon.showMcp,
                  ),
                ),
              ],
            ),
            // The groups' own space is under them.
            const SizedBox(height: 20),
            // Each agent's heading, even one alone: whose servers these are.
            for (final list in lists) ...[
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
              if (list.userOnly)
                _Group(
                  list,
                  'user',
                  'User',
                  McpView.userOnlyAbout(agentTitle(list.agent)),
                )
              else
                for (final scope in scopes.keys)
                  if (_shows(list, scope))
                    switch (scopeOf(list.agent, scope)) {
                      (final title, final about) => _Group(
                        list,
                        scope,
                        title,
                        switch (scope) {
                          'plugin' => _withPluginCommand(about, list.agent),
                          _ => about,
                        },
                      ),
                    },
            ],
          ],
        );
      },
    );
  }
}

/// Whether [list]'s page has a group for [scope]: each scope its agent's
/// shape offers, one it lists servers in, and one only the check fills
/// (McpShape.checked_scopes: Claude's plugins' servers and claude.ai
/// connectors), which keeps its place while empty, not to move the page
/// when the check ends.
bool _shows(McpServers list, String scope) =>
    list.shape.scopes.contains(scope) ||
    list.servers.any((s) => s.scope == scope) ||
    list.shape.checkedScopes.contains(scope);

/// [about] with how [agent]'s plugins are added, in its own command's
/// words ([agentWords]), as the Skills view's Plugins group says it.
String _withPluginCommand(String about, String agent) => switch (agentWords(
  agent,
).pluginCommand) {
  final command? => '$about Add them with $command in ${agentTitle(agent)}.',
  null => about,
};

/// One scope's servers, under its heading.
class _Group extends StatelessWidget {
  const new(this.list, this.scope, this.title, this.about);

  final McpServers list;
  final String scope;
  final String title;
  final String about;

  @override
  Widget build(BuildContext context) {
    // A scope only the check fills (plugins' servers, connectors) is
    // "Checking…" while it runs.
    final later = list.shape.checkedScopes.contains(scope) || !list.loaded;
    final theme = NushiTheme.of(context);
    // Once for the project's group, not on each row (each keeps only its
    // pill), by the daemon's word: also before the folder has a server.
    final untrusted = scope == 'project' && list.folderTrusted == false;
    return SettingsGroup(
      title: title,
      about: about,
      footer: untrusted
          ? Text(
              McpServers.untrustedNote(list.agent),
              style: theme.ui(theme.t.textSecondary, size: 12),
            )
          : null,
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
            .map((u) => scopeOf(list.agent, u.scope).$1)
            .firstOrNull;
}

/// A server: its state, name, transport and command or URL, why it
/// failed, and its masked env vars and headers.
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
    final untrusted = server.untrusted;
    final off = !untrusted && (server.off || server.state == 'disabled');
    final failed = server.state == 'failed' && server.detail.isNotEmpty;
    final (word, _) = stateOf(server, t);
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
                        child: tooltip(
                          context,
                          server.source,
                          Text(
                            target(c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.code(t.textSecondary, size: 11.5),
                          ),
                        ),
                      ),
                      if (!shadowed) ...[
                        const SizedBox(width: 12),
                        NotePill(word, tone: toneOf(server)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              McpActions(list, server),
            ],
          ),
          // Each on its own line: why it isn't used, why its switch can't
          // act here (the daemon's words), why it failed (its own words,
          // which can run to several lines), its masked env vars and
          // headers.
          for (final line in [
            if (shadowed)
              Text(
                'Not used: the $shadowedBy one has the same name',
                style: theme.ui(t.textMuted, size: 11.5),
              ),
            if (server.held.isNotEmpty)
              Text(server.held, style: theme.ui(t.textMuted, size: 11.5)),
            if (failed)
              Text(server.detail, style: theme.ui(t.crashed, size: 11.5)),
            if (hidden.isNotEmpty)
              Text(hidden, style: theme.code(t.textMuted, size: 11)),
          ])
            Opacity(
              opacity: shadowed || off ? 0.5 : 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 19, top: 3),
                child: line,
              ),
            ),
        ],
      ),
    );
  }
}
