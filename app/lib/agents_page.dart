import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/daemon_settings.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/shell_env_line.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings › Agents: each agent as found on this Mac (its version and
/// path, or "Not installed"), and for one that runs
/// through an adapter (Codex), Set up, Update and Remove (ADR 0037); Claude
/// runs through Nushi's Go agent, with nothing to set up (ADR 0066). Under
/// each agent the daemon says has one (Codex), the setting that runs it
/// through Nushi's Go agent instead of its adapter (ADR 0142), once
/// [settings] came. The [marked] agent's row stands out: a chat that
/// couldn't start it sent you here.
class AgentsPage extends StatefulWidget {
  const new(this.client, {required this.settings, super.key, this.marked});

  final NushiServiceClient client;
  final String? marked;

  /// The daemon's settings, which hold the switch to Nushi's Go agent.
  final DaemonSettings settings;

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  final _removing = <String>{};

  @override
  void initState() {
    super.initState();
    // As they are now, the shell's environment read again if it's old.
    listAgents(widget.client, refreshEnvironment: true).ignore();
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

  /// [a]'s switch between its adapter and Nushi's Go agent, set in line
  /// with the agent's name; the agents are found again once it's set, as
  /// the agent's needs changed. Null while the daemon's settings aren't
  /// known, or when it is too old to keep the setting by agent (API 142).
  Widget? _goAgent(Agent a) {
    final set = widget.settings.value;
    if (set == null || !set.goAgents.containsKey(a.name)) return null;
    return Padding(
      padding: const EdgeInsets.only(left: agentTextIndent),
      child: SettingsRow(
        goAgentLabel(a),
        description: goAgentDescription(a),
        control: SettingsSwitch(
          value: set.goAgents[a.name]!,
          run: ({required on}) async {
            await widget.settings.change((s) => s.goAgents[a.name] = on);
            await listAgents(widget.client);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([agentList, widget.settings]),
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (agentList.value case final agents when agents.isNotEmpty)
          SettingsGroup(
            children: [
              for (final a in agents.values) ...[
                AgentRow(
                  a,
                  client: widget.client,
                  marked: a.name == widget.marked,
                  onRemove: _removing.contains(a.name)
                      ? null
                      : () => _remove(a),
                ),
                if (a.goAgentSwitch) ?_goAgent(a),
              ],
            ],
          ),
        ShellEnvLine(widget.client),
      ],
    ),
  );
}

/// The switch for [a]'s Go agent: "Run Codex without Node".
String goAgentLabel(Agent a) => 'Run ${a.title} without Node';

/// What [a]'s Go agent switch says under it. "Its adapter", not the
/// adapter's name: the daemon lists the agent with none while the switch
/// is on, and the words don't change with the switch or with what this
/// run happened to list.
String goAgentDescription(Agent a) =>
    "New: Nushi's built-in agent instead of its adapter. "
    'Chats use it from their next start.';

String _mb(int bytes) => '${(bytes / 1e6).round()} MB';

/// How far an agent's name sits from its row's padding: past its mark
/// and the gap after it.
const agentTextIndent = 32.0;

/// One agent: its mark and name, what was found, and what can be done.
class AgentRow extends StatelessWidget {
  const new(
    this.agent, {
    required this.client,
    required this.onRemove,
    super.key,
    this.marked = false,
  });

  final Agent agent;
  final NushiServiceClient client;
  final VoidCallback? onRemove; // null while it's being removed
  final bool marked; // a chat that couldn't start it sent you here

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final a = agent;
    final ad = a.hasAdapter() ? a.adapter : null;
    final installed = a.path.isNotEmpty;
    final muted = theme.ui(t.textMuted, size: 12);
    final found = [
      if (a.version.isNotEmpty) a.version,
      tildePath(a.path),
    ].join(', ');
    // An agent that isn't installed says so on its own line, not again as
    // its problem.
    final problem = installed ? a.problem : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      color: marked ? t.accentSoft : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AgentMark(a.name, size: 20, ink: t.text),
          ),
          const SizedBox(width: agentTextIndent - 20),
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
    if (!installed) return [];
    if (ad == null) {
      return [
        if (agent.ready)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: NotePill('Ready', tone: NoteTone.done),
          ),
      ];
    }
    final setUp = ad.installed.isEmpty;
    final update = !setUp && ad.installed != ad.pinned;
    return [
      if (!setUp)
        Button(
          label: onRemove == null ? 'Removing…' : 'Remove',
          roomFor: const ['Removing…'],
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
  // Esc and a click outside cancel it, but not while it works: its
  // PopScope holds it then.
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
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final a = knownAgents[widget.agent.name] ?? widget.agent;
    final ad = a.adapter;
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
              '${tildePath(ad.folder)}.${_sleeps(a)}',
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
  final a = knownAgents[agent.name] ?? agent;
  final ad = a.adapter;
  return await confirm(
    context,
    "Remove ${a.title}'s adapter?",
    'Removes ${tildePath(ad.folder)} (${_mb(ad.diskBytes.toInt())}). '
        "${a.title} chats start again once it's set up.${_sleeps(a)}",
    'Remove',
    destructive: true,
  );
}
