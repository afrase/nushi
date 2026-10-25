import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agent_mark.dart';
import 'agents.dart';
import 'gen/nushi/v1/nushi.connect.client.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// Settings › Agents: each agent as found on this Mac (its version and
/// path, or "Not installed" with where to get it), and for one that runs
/// through an adapter, Set up, Update and Remove (ADR 0037).
class AgentsPage extends StatefulWidget {
  const new(this.client, {super.key});

  final NushiServiceClient client;

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  final _removing = <String>{};

  @override
  void initState() {
    super.initState();
    listAgents(widget.client).ignore(); // as they are now
  }

  /// Removes [a]'s adapter once asked; its row says so meanwhile (its
  /// awake chats sleep first, which takes a few seconds).
  Future<void> _remove(Agent a) async {
    if (!await _confirmRemove(context, widget.client, a) || !mounted) return;
    setState(() => _removing.add(a.name));
    await tryOrShow(context, () async {
      await widget.client.removeAgent(RemoveAgentRequest(agent: a.name));
      await listAgents(widget.client);
    });
    if (mounted) setState(() => _removing.remove(a.name));
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: agentList,
    builder: (context, agents, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in agents.values)
          AgentRow(
            a,
            client: widget.client,
            onRemove: _removing.contains(a.name) ? null : () => _remove(a),
          ),
      ],
    ),
  );
}

/// [path] with the home folder as ~.
String tilde(String path) {
  final home = Platform.environment['HOME'] ?? '';
  return home.isNotEmpty && path.startsWith('$home/')
      ? '~${path.substring(home.length)}'
      : path;
}

String _mb(int bytes) => '${(bytes / 1e6).round()} MB';

/// One agent: its mark and name, what was found, and what can be done.
class AgentRow extends StatelessWidget {
  const new(
    this.agent, {
    super.key,
    required this.client,
    required this.onRemove,
  });

  final Agent agent;
  final NushiServiceClient client;
  final VoidCallback? onRemove; // null while it's being removed

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final a = agent, ad = a.hasAdapter() ? a.adapter : null;
    final installed = a.path.isNotEmpty;
    final muted = theme.ui(t.textMuted, size: 12);
    final found = [
      if (a.version.isNotEmpty) a.version,
      tilde(a.path),
    ].join(' · ');
    final problem = switch (a.problem) {
      'Not installed' => '',
      final p => p,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AgentMark(a.name, size: 20, color: t.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: theme.ui(t.text, weight: FontWeight.w600)),
                Text(
                  installed ? found : 'Not installed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                if (problem.isNotEmpty)
                  Text(problem, style: theme.ui(t.needs, size: 12)),
                if (a.signedIn == 'no' && problem.isEmpty)
                  Text('Not signed in', style: theme.ui(t.needs, size: 12)),
                if (ad != null && ad.installed.isNotEmpty)
                  Text('Adapter ${ad.installed}', style: muted),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ..._actions(context, theme, t, ad, installed),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    NushiTheme theme,
    Tokens t,
    Adapter? ad,
    bool installed,
  ) {
    if (!installed) {
      return [
        Button(
          label: 'Get it',
          icon: Icons.open_in_new,
          kind: ButtonKind.ghost,
          onPressed: () => launchUrl(Uri.parse(agent.page)),
        ),
      ];
    }
    if (ad == null) {
      return [
        if (agent.ready)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Ready', style: theme.ui(t.textSecondary, size: 12)),
          ),
      ];
    }
    final setUp = ad.installed.isEmpty,
        update = !setUp && ad.installed != ad.pinned;
    return [
      if (!setUp)
        Button(
          label: onRemove == null ? 'Removing…' : 'Remove',
          kind: ButtonKind.ghost,
          onPressed: onRemove,
        ),
      if (setUp || update) ...[
        const SizedBox(width: 6),
        Button(
          label: setUp ? 'Set up' : 'Update to ${ad.pinned}',
          kind: ButtonKind.primary,
          onPressed: agent.problem.isEmpty
              ? () => setUpAdapter(context, client, agent)
              : null,
        ),
      ],
    ];
  }
}

/// " Its 2 awake chats sleep." for an agent with chats awake.
String _sleeps(Agent a) => switch (a.awake) {
  0 => '',
  1 => ' Its awake chat sleeps.',
  final n => ' Its $n awake chats sleep.',
};

/// The Set up sheet: what it downloads, how big, and where, then one press
/// installs it.
Future<void> setUpAdapter(
  BuildContext context,
  NushiServiceClient client,
  Agent agent,
) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SetUp(client, agent),
);

class _SetUp extends StatefulWidget {
  const new(this.client, this.agent);

  final NushiServiceClient client;
  final Agent agent;

  @override
  State<_SetUp> createState() => _SetUpState();
}

class _SetUpState extends State<_SetUp> {
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Its awake chats as they are now.
    unawaited(
      listAgents(widget.client)
          .then((_) => mounted ? setState(() {}) : null, onError: (_) {}),
    );
  }

  Future<void> _run() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.client.setUpAgent(
        SetUpAgentRequest(agent: widget.agent.name),
      );
      await listAgents(widget.client);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final a = knownAgents[widget.agent.name] ?? widget.agent, ad = a.adapter;
    final update = ad.installed.isNotEmpty;
    return PopScope(
      canPop: !_working,
      child: nushiDialog(
        '${update ? 'Update' : 'Set up'} ${a.title}',
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloads ${ad.package} ${ad.pinned} and the '
              '${ad.packages - 1} packages it needs from npm, about '
              '${_mb(ad.downloadBytes.toInt())} '
              '(${_mb(ad.diskBytes.toInt())} on disk), into '
              '${tilde(ad.folder)}.${_sleeps(a)}',
              style: theme.ui(t.text),
            ),
            if (_error case final e?) ...[
              const SizedBox(height: 10),
              Text(
                e,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: theme.code(t.crashed, size: 11.5),
              ),
            ],
          ],
        ),
        [
          Button(
            label: 'Cancel',
            kind: ButtonKind.ghost,
            onPressed: _working ? null : () => Navigator.pop(context),
          ),
          Button(
            label: _working
                ? (update ? 'Updating…' : 'Setting up…')
                : (update ? 'Update' : 'Set up'),
            kind: ButtonKind.primary,
            autofocus: true,
            onPressed: _working ? null : _run,
          ),
        ],
      ),
    );
  }
}

/// Asks before removing [agent]'s adapter, with its awake chats as they
/// are now.
Future<bool> _confirmRemove(
  BuildContext context,
  NushiServiceClient client,
  Agent agent,
) async {
  await listAgents(client).catchError((_) {});
  if (!context.mounted) return false;
  final a = knownAgents[agent.name] ?? agent, ad = a.adapter;
  return await confirm(
    context,
    "Remove ${a.title}'s adapter?",
    'Removes ${tilde(ad.folder)} (${_mb(ad.diskBytes.toInt())}). ${a.title} '
        "chats start again once it's set up.${_sleeps(a)}",
    'Remove',
  );
}
