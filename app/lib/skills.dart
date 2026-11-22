import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/skills_new.dart';
import 'package:nushi/skills_plugins.dart';
import 'package:nushi/skills_rows.dart';
import 'package:nushi/skills_shared.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings › Skills, beside MCP servers and in its style (ADRs 0051,
/// 0052): an agent picker (until one is picked, the agent a new chat would
/// start with, else the first the daemon lists; "Reading…" until it has), a
/// folder picker and a search box, then the agent's skills by where they
/// come from (yours, the project's, the shared .agents/skills with the
/// agents that load each, the agent's own, Claude's plugins' and built-in
/// ones), each with its description, cost and switch, and Claude's
/// plugins. What changed in a terminal shows when the view opens or on
/// Refresh.
class SkillsView extends StatefulWidget {
  const new({required this.daemon, required this.folder, super.key});

  final Daemon daemon;
  final String folder;

  @override
  State<SkillsView> createState() => _SkillsViewState();
}

class _SkillsViewState extends State<SkillsView> {
  final _search = TextEditingController();

  /// The agent the view opened on when none was picked, kept once known:
  /// [defaultAgent] moves with the newest chat and the agents' state, and
  /// the list shown has to be the one asked for.
  String? _opened;

  /// Whose skills show: the one picked, else the agent a new chat would
  /// start with when the view opened ([defaultAgent], the first listed
  /// when none was used); null while the daemon hasn't listed its agents.
  /// Never an empty name, which the daemon would read as its own default.
  String? get _agent {
    final d = widget.daemon;
    if (d.skillsAgent case final picked?) return picked;
    if (_opened == null) {
      final first = defaultAgent(d, knownAgents.keys.toList());
      if (first.isNotEmpty) _opened = first;
    }
    return _opened;
  }

  /// The list shown; only asked for once [_agent] is known.
  SkillsList get list => SkillsList.of(widget.daemon, widget.folder, _agent!);

  void _pickAgent(String agent) {
    setState(() => widget.daemon.skillsAgent = agent);
    unawaited(list.refresh());
  }

  /// The agents listed after the view opened: their list is read now.
  void _agentsCame() {
    if (_agent == null) return;
    agentList.removeListener(_agentsCame);
    if (mounted) setState(() => unawaited(list.refresh()));
  }

  @override
  void initState() {
    super.initState();
    if (_agent == null) {
      agentList.addListener(_agentsCame);
    } else {
      unawaited(list.refresh());
    }
    _search.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(SkillsView old) {
    super.didUpdateWidget(old);
    if (old.folder != widget.folder && _agent != null) {
      unawaited(list.refresh());
    }
  }

  @override
  void dispose() {
    agentList.removeListener(_agentsCame);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final daemon = widget.daemon;
    final small = theme.ui(t.textSecondary, size: 12);
    final agent = _agent;
    if (agent == null) {
      return SettingsPage(
        title: 'Skills',
        children: [Text('Reading…', style: theme.ui(t.textMuted, size: 12))],
      );
    }
    return ListenableBuilder(
      listenable: list,
      builder: (context, _) => SettingsPage(
        title: 'Skills',
        actions: [
          if (list.loading)
            Text('Reading…', style: theme.ui(t.textMuted, size: 12)),
          Button(
            label: 'Refresh',
            onPressed: list.loading ? null : list.refresh,
          ),
          Button(
            label: 'New skill…',
            icon: Icons.add,
            onPressed: () => newSkill(context, list),
          ),
        ],
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final pickers = Row(
                children: [
                  Text('For ', style: small),
                  MenuField(
                    compact: true,
                    tooltip: 'Whose skills',
                    entries: [
                      for (final a in knownAgents.values)
                        MenuEntry(
                          a.title,
                          checked: a.name == agent,
                          onPick: () => _pickAgent(a.name),
                        ),
                    ],
                    label: Text(
                      agentTitle(agent),
                      style: theme.ui(t.text, size: 12),
                    ),
                  ),
                  Text('  in ', style: small),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FolderMenuField(
                        daemon,
                        widget.folder,
                        onShow: daemon.showSkills,
                      ),
                    ),
                  ),
                ],
              );
              final search = SizedBox(
                height: 26,
                child: TextField(
                  controller: _search,
                  style: theme.ui(t.text, size: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search skills and plugins',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 14,
                      color: t.textMuted,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 26),
                  ),
                ),
              );
              // Narrow, the search goes under the pickers.
              return box.maxWidth < 600
                  ? Column(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [pickers, search],
                    )
                  : Row(
                      children: [
                        Expanded(child: pickers),
                        const SizedBox(width: 12),
                        SizedBox(width: 240, child: search),
                      ],
                    );
            },
          ),
          // The groups' own space is under them.
          const SizedBox(height: 16),
          ..._sections(context, _search.text.trim().toLowerCase()),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context, String query) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final r = list.list;
    final agent = list.agent;
    final plugins = {for (final p in r.plugins) p.id: p};
    final groups = list.groups(r.skills.where((s) => skillMatches(s, query)));
    final shownPlugins = r.plugins.where((p) => pluginMatches(p, query));
    final builtIn =
        list.hasBuiltIn &&
        skillMatches(
          Skill(
            name: 'built-in',
            description: '${agentTitle(agent)}’s own skills',
          ),
          query,
        );
    final any =
        groups.values.any((g) => g.isNotEmpty) ||
        shownPlugins.isNotEmpty ||
        builtIn;
    return [
      if (list.error.isNotEmpty)
        Text(list.error, style: theme.ui(t.crashed, size: 12)),
      if (!list.loaded && list.loading) Text('Reading…', style: muted),
      if (list.loaded && r.noSkills.isNotEmpty)
        Text(r.noSkills, style: muted)
      else ...[
        if (list.loaded && !any)
          Text('No skills or plugins match', style: muted),
        if (list.loaded)
          for (final MapEntry(key: from, value: skills) in groups.entries)
            if (from == 'shared')
              if (skills.isNotEmpty || query.isEmpty)
                SharedGroup(list, skills)
              else
                const SizedBox()
            else if (skills.isNotEmpty || (query.isEmpty && from == 'project'))
              SkillGroup(
                list: list,
                title: switch (from) {
                  'user' => 'Yours',
                  'project' => 'This project',
                  'system' => '${agentTitle(agent)}’s own',
                  _ => plugins[from]?.name ?? from,
                },
                about: _about(agent, from),
                skills: skills,
              ),
        if (list.loaded && builtIn) BuiltInGroup(list),
        if (list.loaded &&
            list.hasPlugins &&
            (shownPlugins.isNotEmpty || query.isEmpty))
          PluginsGroup(list, shownPlugins.toList()),
      ],
    ];
  }
}

/// The line under a group's title: where the agent reads those skills.
String _about(String agent, String from) => switch ((agent, from)) {
  ('claude', 'user') => 'In every folder: skills in your Claude folder.',
  ('claude', 'project') =>
    'In this folder: .claude/skills here and in the folders above it.',
  ('codex', 'user') => 'In every folder: skills in your Codex folder.',
  ('codex', 'project') =>
    'In this folder: .codex/skills here and in the folders above it, up to '
        'the repository’s root.',
  ('codex', 'system') => 'Installed with Codex, which puts them back.',
  ('ante', 'user') =>
    'In every folder: ~/.ante/skills, and Claude’s ~/.claude/skills.',
  ('ante', 'project') =>
    'In this folder only: .ante/skills and Claude’s .claude/skills.',
  ('ante', 'system') => 'Bundled with Ante, which rewrites them on updates.',
  ('omp', 'user') =>
    'In every folder: ~/.omp/agent/skills and ~/.agent/skills.',
  ('omp', 'project') =>
    'In this folder: .omp/skills, Claude’s .claude/skills and .agent/skills '
        'here and above it, up to the repository’s root; the nearest '
        '.codex/skills; .github/skills.',
  ('pi', 'user') => 'In every folder: skills in Pi’s agent folder.',
  ('pi', 'project') =>
    'In this folder only: .pi/skills, once Pi trusts the folder.',
  ('pig', 'user') => 'In every folder: skills in PiG’s agent folder.',
  ('pig', 'project') =>
    'In this folder only: .pig/skills, once PiG trusts the folder.',
  ('opencode', 'user') =>
    'In every folder: skills in your OpenCode config folder, and Claude’s '
        '~/.claude/skills.',
  ('opencode', 'project') =>
    'In this folder: .opencode/skills, .opencode/skill and Claude’s '
        '.claude/skills, here and in every folder above it.',
  (_, 'user') => 'In every folder.',
  (_, 'project') => 'In this folder.',
  (_, 'system') => 'The agent’s own.',
  (_, final from) =>
    'From the plugin $from: on and off with it, under Plugins.',
};
