import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nushi/agent_words.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart' show errorText;

/// The MCP servers an agent's config gives a folder, from the daemon (API
/// 32; Ante's from API 80): read from the config at once, then checked
/// (the agent connects to each, a few seconds), which fills in their
/// states. One per agent and folder, shared by the view and the panel widget
/// while the app runs; asked for again once it is a few minutes old, since
/// servers connect, sign in and change outside Nushi too, and once the
/// daemon is back after it was lost during a refresh (a restart into an
/// update cuts a check short).
class McpServers extends ChangeNotifier {
  factory of(Daemon daemon, String folder, {required String agent}) {
    final list = _byFolder[(agent, folder)] ??= McpServers._(
      daemon,
      folder,
      agent,
    );
    final at = list._at;
    final old = at != null && DateTime.now().difference(at) > fresh;
    if (!list.checking && (list._stale || old)) {
      list._stale = false;
      unawaited(Future.microtask(list.refresh)); // not while a build asks
    }
    return list;
  }
  new _(this.daemon, this.folder, this.agent) {
    agentList.addListener(notifyListeners); // userOnly is the agent's to say
    unawaited(refresh());
  }

  static final Map<(String, String), McpServers> _byFolder = runMap(
    onForget: (l) => l._forget(),
  );

  /// Stops hearing the agents and the daemon's return: the list is no
  /// longer the folder's (tests start afresh).
  void _forget() {
    agentList.removeListener(notifyListeners);
    _back.cancel();
  }

  /// How long a list is taken as current.
  static const fresh = Duration(minutes: 5);

  final Daemon daemon;
  final String folder;

  /// Whose servers: an agent's name, as ListAgents gives it.
  final String agent;

  /// What the agent's MCP config has (its scopes, an off switch and where
  /// it reaches, approval, SSE, the scopes only the check fills), as the
  /// daemon says of it (API 157); from an older daemon, mcpUserOnly says
  /// it: Ante's yours only, else Claude's. An agent gone from the list
  /// (removed in Settings › Agents while its form is open) keeps the last
  /// shape seen, and one never seen has the narrowest: never Claude's
  /// whole model, which would offer what it hasn't.
  McpShape get shape => _seen = switch (knownAgents[agent]) {
    final a? when a.hasMcpShape() => a.mcpShape,
    final a? when a.mcpUserOnly => _yoursOnly,
    _? => _claudes,
    null => _seen ?? _yoursOnly,
  };
  McpShape? _seen; // the shape last given, for an agent gone from the list

  static final _yoursOnly = McpShape(scopes: ['user']);
  static final _claudes = McpShape(
    scopes: ['user', 'project', 'local'],
    offSwitch: true,
    approval: true,
    sse: true,
    userSwitch: McpUserSwitch.MCP_USER_SWITCH_PROJECT,
    checkedScopes: ['plugin', 'claudeai'],
  );

  /// Its servers are only yours: one scope, the user's.
  bool get userOnly =>
      shape.scopes.length == 1 && shape.scopes.single == 'user';

  /// What the Project group says under it in a folder the agent doesn't
  /// trust ([folderTrusted]), once: the agent loads its servers only once the
  /// folder is trusted in it, which only the agent itself does (Nushi has
  /// no trust card for it, ADR 0078), in its own program's words.
  static String untrustedNote(String agent) =>
      switch (agentWords(agent).command) {
        final command? =>
          'Folder not trusted: run $command here in a terminal and trust '
              'it, then Check again.',
        null =>
          'Folder not trusted: trust it in ${agentTitle(agent)}, then Check '
              'again.',
      };

  List<McpServer> servers = [];

  /// Whether the agent trusts the folder, so loads its project's servers,
  /// as the daemon says (ListMcpServersResponse.folder_trusted, API 157);
  /// null for an agent with no folder trust of its own (Claude's, Ante's)
  /// and until the daemon has said.
  bool? folderTrusted;
  bool loaded = false;
  bool checking = false;
  String error = ''; // why the list or the check failed

  bool _again = false; // refresh once the running one is done
  bool _stale = false; // refresh when next asked for: another folder's changed
  DateTime? _at; // when the last refresh ended
  late final _back = LoadAgain(daemon, () => unawaited(refresh()));

  Future<void> refresh() async {
    if (checking) {
      _again = true;
      return;
    }
    checking = true;
    _back.cancel();
    notifyListeners();
    do {
      _again = false;
      try {
        _take(await _list(false));
        _take(await _list(true), checked: true);
      } on Object catch (e) {
        _unchecked();
        error = errorText(e);
        if (!_again) _back.failed(e);
      }
    } while (_again);
    checking = false;
    _at = DateTime.now();
    notifyListeners();
  }

  /// After a change here: the agent's other folders' lists may be out of
  /// date too. One shown, or being read, is asked for again now; the rest
  /// when next asked for (of). They stay the folders' lists, each only
  /// ever made once: one dropped would stay on agentList's listeners for
  /// good, and a view still holding it would never hear of a change.
  void changed() {
    // A copy: a refresh tells its listeners at once, which may ask for
    // another folder's list.
    for (final MapEntry(key: (a, _), value: l) in _byFolder.entries.toList()) {
      if (l == this || a != agent) continue;
      if (l.checking || l.hasListeners) {
        unawaited(l.refresh());
      } else {
        l._stale = true;
      }
    }
    unawaited(refresh());
  }

  Future<ListMcpServersResponse> _list(bool check) =>
      daemon.client.listMcpServers(
        ListMcpServersRequest(folder: folder, checkHealth: check, agent: agent),
      );

  /// Takes [r]'s servers. After a check ([checked]) one it left without a
  /// state wasn't checked: PiG's list leaves out a project's servers it
  /// doesn't load, and one in a folder trusted only by its
  /// defaultProjectTrust "always" (docs/facts/pig.md).
  void _take(ListMcpServersResponse r, {bool checked = false}) {
    servers = r.servers;
    folderTrusted = r.hasFolderTrusted() ? r.folderTrusted : null;
    if (checked || r.checkError.isNotEmpty) _unchecked();
    error = r.checkError;
    loaded = true;
    notifyListeners();
  }

  /// A check that failed, or a call cut short, leaves the servers
  /// unchecked, not "Checking…".
  void _unchecked() => servers = [
    for (final s in servers)
      if (s.state.isEmpty) s.deepCopy()..state = 'unknown' else s,
  ];

  /// The servers the agent uses: none hidden by one of the same name.
  Iterable<McpServer> get used => servers.where((s) => !s.shadowed);
}

/// The scopes in the order the view shows them: its heading and what it
/// means.
const scopes = {
  'user': ('User', 'Yours, in every folder.'),
  'project': (
    'Project',
    'The repository’s .mcp.json, shared with everyone on it.',
  ),
  'local': ('Local', 'Yours, in this project only.'),
  'plugin': (
    'Plugins',
    'From installed plugins: turn them on and off in Skills.',
  ),
  'claudeai': (
    'claude.ai',
    'Connectors from your claude.ai account: change them at '
        'claude.ai/customize/connectors.',
  ),
  'other': ('Other', 'From settings Nushi doesn’t read, such as managed ones.'),
};

/// [scope]'s heading and what it means for [agent]: [scopes]', but a
/// project's file where the agent keeps it elsewhere ([agentWords]'
/// mcpProjectFile: PiG's own folder's file).
(String, String) scopeOf(String agent, String scope) =>
    switch ((scope, agentWords(agent).mcpProjectFile)) {
      ('project', final file?) => (
        'Project',
        '${file[0].toUpperCase()}${file.substring(1)}, shared with everyone '
            'on it.',
      ),
      _ => scopes[scope] ?? (scope, ''),
    };

/// A server's config, decoded; empty when it isn't a JSON object. A
/// repository's .mcp.json is anyone's, and the daemon passes its values
/// through as written, so the readers below check each one's type.
Map<String, dynamic> config(McpServer s) {
  try {
    return switch (jsonDecode(s.configJson)) {
      final Map<String, dynamic> m => m,
      _ => {},
    };
  } on FormatException {
    return {};
  }
}

/// "stdio", "http", "sse", ...: its "type", else stdio for a command and
/// http for a URL. The daemon sends every agent's in this shape.
String transport(Map<String, dynamic> c) => switch (c['type']) {
  final String t => t,
  _ => c['url'] == null ? 'stdio' : 'http',
};

/// Its command line, or its URL, as text whatever their types.
String target(Map<String, dynamic> c) => switch ((c['url'], c['args'])) {
  (final Object url, _) => '$url',
  (_, final List<Object?> args) => [c['command'], ...args].join(' '),
  (_, final Object args) => '${c['command']} $args',
  _ => '${c['command']}',
};

/// Its env vars and headers, values masked as the daemon sends them.
String secrets(Map<String, dynamic> c) => [
  if (c['env'] case final Map<Object?, Object?> env)
    for (final k in env.keys) '$k=••••',
  if (c['headers'] case final Map<Object?, Object?> headers)
    for (final k in headers.keys) '$k: ••••',
].join('  ');

/// A server's state in words, and its color.
(String, Color) stateOf(McpServer s, Tokens t) => switch (s.state) {
  _ when s.untrusted => ('Folder not trusted', t.needs),
  _ when s.off => ('Off', t.idle),
  'connected' => ('Connected', t.done),
  'failed' => ('Failed to connect', t.crashed),
  'needs_auth' => ('Needs login', t.needs),
  'pending' when s.approved => ('Approved, folder not trusted', t.needs),
  'pending' => ('Waiting for approval', t.needs),
  'disabled' => ('Off', t.idle),
  '' => ('Checking…', t.textMuted),
  'unknown' => ('Not checked', t.textMuted),
  _ => (s.detail, t.textMuted),
};

/// A server's state as a pill's tone, as Settings shows a state (Jira's
/// and GitHub's accounts alike): working, failed, waiting on you, or
/// quiet for off and not known yet.
NoteTone toneOf(McpServer s) => switch (s.state) {
  _ when s.untrusted => NoteTone.needs,
  _ when s.off => NoteTone.quiet,
  'connected' => NoteTone.done,
  'failed' => NoteTone.crashed,
  'needs_auth' || 'pending' => NoteTone.needs,
  _ => NoteTone.quiet,
};

/// A server's state as a dot: filled once known, a ring until then or
/// while it is off.
class McpDot extends StatelessWidget {
  const new(this.server, {super.key});

  final McpServer server;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final (word, color) = stateOf(server, t);
    // Untrusted, it isn't used: a ring, as an off one's.
    final ring =
        server.untrusted ||
        server.off ||
        ['', 'disabled', 'unknown'].contains(server.state);
    return tooltip(
      context,
      server.detail.isEmpty || server.untrusted
          ? word
          : '$word: ${server.detail}',
      Container(
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
