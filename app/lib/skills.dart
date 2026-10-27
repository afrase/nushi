import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/skills_new.dart';
import 'package:nushi/skills_rows.dart';
import 'package:nushi/skills_shared.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings › Skills, beside MCP servers and in its style (ADRs 0051,
/// 0052): an agent picker (Claude unless another was picked), a
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

  SkillsList get list =>
      SkillsList.of(widget.daemon, widget.folder, widget.daemon.skillsAgent);

  void _pickAgent(String agent) {
    setState(() => widget.daemon.skillsAgent = agent);
    unawaited(list.refresh());
  }

  @override
  void initState() {
    super.initState();
    unawaited(list.refresh());
    _search.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(SkillsView old) {
    super.didUpdateWidget(old);
    if (old.folder != widget.folder) unawaited(list.refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await getDirectoryPath(confirmButtonText: 'Show');
    if (f != null) widget.daemon.showSkills(f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final daemon = widget.daemon;
    final (name, dir) = folderParts(
      widget.folder,
      scratch: daemon.chats.values.any(
        (c) => c.scratch && c.folder == widget.folder,
      ),
    );
    final small = theme.ui(t.textSecondary, size: 12);
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
                          checked: a.name == daemon.skillsAgent,
                          onPick: () => _pickAgent(a.name),
                        ),
                    ],
                    label: Text(
                      agentTitle(daemon.skillsAgent),
                      style: theme.ui(t.text, size: 12),
                    ),
                  ),
                  Text('  in ', style: small),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MenuField(
                        compact: true,
                        entries: folderEntries(
                          daemon,
                          checked: widget.folder,
                          onPick: (f) =>
                              f == null ? _pick() : daemon.showSkills(f),
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
          const SizedBox(height: 4),
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
    final claude = agent == 'claude';
    final plugins = {for (final p in r.plugins) p.id: p};
    final groups = list.groups(r.skills.where((s) => skillMatches(s, query)));
    final shownPlugins = r.plugins.where((p) => pluginMatches(p, query));
    final builtIn =
        claude &&
        skillMatches(
          Skill(name: 'built-in', description: 'Claude Code’s own skills'),
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
          Text('No skills or plugins match.', style: muted),
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
        if (list.loaded && claude && (shownPlugins.isNotEmpty || query.isEmpty))
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
  ('pig', 'user') => 'In every folder: skills in PiG’s agent folder.',
  ('pig', 'project') =>
    'In this folder only: .pig/skills, once PiG trusts the folder.',
  (_, 'user') => 'In every folder.',
  (_, 'project') => 'In this folder.',
  (_, 'system') => 'The agent’s own.',
  (_, final from) =>
    'From the plugin $from: on and off with it, under Plugins.',
};
