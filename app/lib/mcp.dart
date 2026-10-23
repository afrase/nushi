import 'dart:math';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'menu.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The MCP servers the agent's config gives a folder, from the daemon (API
/// 32): read from the config at once, then checked (the agent connects to
/// each, a few seconds), which fills in their states. One per folder,
/// shared by the view and the panel card while the app runs.
class McpServers extends ChangeNotifier {
  McpServers._(this.daemon, this.folder) {
    refresh();
  }

  static final _byFolder = <String, McpServers>{};

  factory McpServers.of(Daemon daemon, String folder) =>
      _byFolder[folder] ??= McpServers._(daemon, folder);

  final Daemon daemon;
  final String folder;
  List<McpServer> servers = [];
  bool loaded = false;
  bool checking = false;
  String error = ''; // why the list or the check failed

  Future<void> refresh() async {
    if (checking) return;
    checking = true;
    notifyListeners();
    try {
      _take(await _list(false));
      _take(await _list(true));
    } on Object catch (e) {
      error = '$e';
    }
    checking = false;
    notifyListeners();
  }

  Future<ListMcpServersResponse> _list(bool check) =>
      daemon.client.listMcpServers(
        ListMcpServersRequest(folder: folder, checkHealth: check),
      );

  void _take(ListMcpServersResponse r) {
    servers = r.servers;
    error = r.checkError;
    loaded = true;
    notifyListeners();
  }

  /// The servers the agent uses: none hidden by one of the same name.
  Iterable<McpServer> get used => servers.where((s) => !s.shadowed);
}

/// The scopes in the order the view shows them: its heading and what it
/// means.
const scopes = {
  'user': ('User', 'Yours, in every folder.'),
  'project': (
    'Project',
    'The repository’s .mcp.json, shared with everyone on the repo.',
  ),
  'local': ('Local', 'Yours, in this project only.'),
  'plugin': (
    'Plugins',
    'From installed plugins: add or remove them with /plugin in Claude Code.',
  ),
  'claudeai': (
    'claude.ai',
    'Connectors from your claude.ai account: change them at '
        'claude.ai/customize/connectors.',
  ),
  'other': ('Other', 'From settings Nushi doesn’t read, such as managed ones.'),
};

/// A server's config, decoded.
Map<String, dynamic> config(McpServer s) =>
    (jsonDecode(s.configJson) as Map).cast<String, dynamic>();

/// "stdio", "http", "sse", ...
String transport(Map<String, dynamic> c) =>
    c['type'] as String? ?? (c['url'] == null ? 'stdio' : 'http');

/// Its command line, or its URL.
String target(Map<String, dynamic> c) =>
    c['url'] as String? ?? [c['command'], ...?(c['args'] as List?)].join(' ');

/// Its env vars and headers, values masked as the daemon sends them.
String secrets(Map<String, dynamic> c) => [
  for (final k in (c['env'] as Map? ?? {}).keys) '$k=••••',
  for (final k in (c['headers'] as Map? ?? {}).keys) '$k: ••••',
].join('  ');

/// A server's state in words, and its color.
(String, Color) stateOf(McpServer s, Tokens t) => switch (s.state) {
  'connected' => ('Connected', t.done),
  'failed' => ('Failed to connect', t.crashed),
  'needs_auth' => ('Needs login', t.needs),
  'pending' => ('Waiting for approval', t.needs),
  'disabled' => ('Off', t.idle),
  '' => ('Checking…', t.textMuted),
  _ => (s.detail, t.textMuted),
};

/// A server's state as a dot: filled once known, a ring until then or
/// while it is off.
class McpDot extends StatelessWidget {
  const McpDot(this.server, {super.key});

  final McpServer server;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final (word, color) = stateOf(server, t);
    final ring = server.state == '' || server.state == 'disabled';
    return Tooltip(
      message: server.detail.isEmpty ? word : '$word: ${server.detail}',
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ring ? null : color,
          border: ring ? Border.all(color: color, width: 1.5) : null,
        ),
      ),
    );
  }
}

/// The MCP servers view: a folder picker, then the servers by scope, each
/// with its state, transport and command or URL (secrets masked).
class McpView extends StatelessWidget {
  const McpView({super.key, required this.daemon, required this.folder});

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
    final (name, parent) = folderParts(folder);
    final dir = tildePath(parent);
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
                Text(
                  'MCP servers',
                  style: theme.ui(t.text, weight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Menu(
                  tooltip: 'The folder whose servers show',
                  entries: [
                    for (final f in daemon.recentFolders.take(8))
                      MenuEntry(
                        folderParts(f).$1,
                        detail: folderParts(f).$2,
                        checked: f == folder,
                        onPick: () => daemon.showMcp(f),
                      ),
                    MenuEntry.divider,
                    MenuEntry('Choose folder…', onPick: _pick),
                  ],
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
  const _Group(this.list, this.scope, this.title, this.about);

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
          Container(
            decoration: box(t.borderSubtle, radius: NushiTheme.card),
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
                  _Row(s, first: i == 0, shadowedBy: _winner(s)),
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
  const _Row(this.server, {required this.first, this.shadowedBy});

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
                  style: theme.ui(t.text, size: 13, weight: FontWeight.w500),
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
