import 'dart:math';

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
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The MCP servers view: a folder picker, then the servers by scope, each
/// with its state, transport and command or URL (secrets masked).
class McpView extends StatelessWidget {
  const new({required this.daemon, required this.folder, super.key});

  final Daemon daemon;
  final String folder;

  Future<void> _pick() async {
    final f = await getDirectoryPath(confirmButtonText: 'Show');
    if (f != null) daemon.showMcp(f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final list = McpServers.of(daemon, folder);
    final (name, dir) = folderParts(
      folder,
      scratch: daemon.chats.values.any((c) => c.scratch && c.folder == folder),
    );
    return ListenableBuilder(
      listenable: list,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.only(left: 20, right: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.borderSubtle)),
            ),
            child: Row(
              children: [
                Text(switch (mcpAgent) {
                  final a? when knownAgents.length > 1 =>
                    '${a.title}’s MCP servers',
                  _ => 'MCP servers',
                }, style: theme.ui(t.text, weight: FontWeight.w600)),
                const SizedBox(width: 12),
                Menu(
                  entries: folderEntries(
                    daemon,
                    checked: folder,
                    onPick: (f) => f == null ? _pick() : daemon.showMcp(f),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: name, style: theme.ui(t.text, size: 12)),
                        TextSpan(
                          text: '  $dir ▾',
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Button(
                  label: 'Add server',
                  icon: Icons.add,
                  kind: ButtonKind.ghost,
                  height: 24,
                  onPressed: () => mcpForm(context, list),
                ),
                const SizedBox(width: 8),
                if (list.checking)
                  Text('Checking…', style: theme.ui(t.textMuted, size: 12)),
                IconTap(
                  Icons.refresh,
                  tooltip: 'Check again',
                  onTap: list.checking ? null : list.refresh,
                ),
                IconTap(
                  Icons.close,
                  tooltip: 'Close',
                  onTap: () => daemon.showMcp(null),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                // At most 900 wide, in the middle.
                final side = max(20.0, (box.maxWidth - 900) / 2);
                return ListView(
                  padding: EdgeInsets.fromLTRB(side, 12, side, 20),
                  children: [
                    if (list.error.isNotEmpty)
                      Text(list.error, style: theme.ui(t.crashed, size: 12)),
                    for (final MapEntry(key: scope, value: (title, about))
                        in scopes.entries)
                      if (scope != 'other' ||
                          list.servers.any((s) => s.scope == scope))
                        _Group(list, scope, title, about),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One scope's servers, under its heading.
class _Group extends StatelessWidget {
  const new(this.list, this.scope, this.title, this.about);

  final McpServers list;
  final String scope, title, about;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final servers = list.servers.where((s) => s.scope == scope).toList();
    final muted = theme.ui(t.textMuted, size: 12);
    // Plugins' servers and connectors come with the check.
    final later = scope == 'plugin' || scope == 'claudeai' || !list.loaded;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
          ),
          Text(about, style: muted),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: box(t.borderSubtle),
            child: Column(
              children: [
                if (servers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        later && list.checking ? 'Checking…' : 'None',
                        style: muted,
                      ),
                    ),
                  ),
                for (final (i, s) in servers.indexed)
                  _Row(list, s, first: i == 0, shadowedBy: _winner(s)),
              ],
            ),
          ),
        ],
      ),
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
  const new(this.list, this.server, {required this.first, this.shadowedBy});

  final McpServers list;
  final McpServer server;
  final bool first;
  final String? shadowedBy;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final c = config(server);
    final hidden = secrets(c);
    final dim = shadowedBy != null;
    final failed = server.state == 'failed' && server.detail.isNotEmpty;
    final (word, color) = stateOf(server, t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Opacity(
        opacity: dim ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!dim) McpDot(server) else const SizedBox(width: 11),
                const SizedBox(width: 8),
                Text(
                  server.name,
                  style: theme.ui(t.text, weight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Text(transport(c), style: theme.code(t.textMuted, size: 11)),
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
                if (!dim) ...[
                  const SizedBox(width: 12),
                  Text(word, style: theme.ui(color, size: 12)),
                ],
                const SizedBox(width: 6),
                McpActions(list, server),
              ],
            ),
            if (hidden.isNotEmpty || dim || failed)
              Padding(
                padding: const EdgeInsets.only(left: 19, top: 3),
                child: Text(
                  [
                    if (dim) 'Not used: the $shadowedBy one has the same name',
                    if (failed) server.detail,
                    if (hidden.isNotEmpty) hidden,
                  ].join('  ·  '),
                  style: failed
                      ? theme.ui(t.crashed, size: 11.5)
                      : theme.code(t.textMuted, size: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
