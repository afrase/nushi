import 'dart:convert';

import 'package:flutter/material.dart';

import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';

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

  bool _again = false; // refresh once the running one is done

  Future<void> refresh() async {
    if (checking) {
      _again = true;
      return;
    }
    checking = true;
    notifyListeners();
    do {
      _again = false;
      try {
        _take(await _list(false));
        _take(await _list(true));
      } on Object catch (e) {
        error = '$e';
      }
    } while (_again);
    checking = false;
    notifyListeners();
  }

  /// After a change here: other folders' lists may be out of date too.
  void changed() {
    _byFolder.removeWhere((_, l) => l != this);
    refresh();
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
  'pending' when s.approved => ('Approved · folder not trusted', t.needs),
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
