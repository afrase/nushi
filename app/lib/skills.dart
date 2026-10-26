import 'dart:async';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/skills_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The Skills view, beside the MCP servers view and in its style (ADR
/// 0051): a folder picker and a search box, then Claude's skills by where
/// they come from (yours, the project's, each plugin's, built in), each
/// with its description, cost and switch, and the installed plugins. What
/// changed in a terminal shows when the view opens or on Refresh.
class SkillsView extends StatefulWidget {
  const new({required this.daemon, required this.folder, super.key});

  final Daemon daemon;
  final String folder;

  @override
  State<SkillsView> createState() => _SkillsViewState();
}

class _SkillsViewState extends State<SkillsView> {
  final _search = TextEditingController();

  SkillsList get list => SkillsList.of(widget.daemon, widget.folder);

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
                  final a? when knownAgents.length > 1 => '${a.title}’s skills',
                  _ => 'Skills',
                }, style: theme.ui(t.text, weight: FontWeight.w600)),
                const SizedBox(width: 12),
                MenuField(
                  compact: true,
                  entries: folderEntries(
                    daemon,
                    checked: widget.folder,
                    onPick: (f) => f == null ? _pick() : daemon.showSkills(f),
                  ),
                  label: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: name, style: theme.ui(t.text, size: 12)),
                        TextSpan(
                          text: '  $dir',
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 200,
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
                ),
                const SizedBox(width: 8),
                Button(
                  label: 'New skill…',
                  icon: Icons.add,
                  onPressed: () => newSkill(context, daemon, widget.folder),
                ),
                const SizedBox(width: 8),
                if (list.loading)
                  Text('Reading…', style: theme.ui(t.textMuted, size: 12)),
                Button(
                  label: 'Refresh',
                  onPressed: list.loading ? null : list.refresh,
                ),
                const SizedBox(width: 4),
                IconTap(
                  Icons.close,
                  tooltip: 'Close',
                  onTap: () => daemon.showSkills(null),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final side = max(20.0, (box.maxWidth - 900) / 2);
                return ListView(
                  padding: EdgeInsets.fromLTRB(side, 12, side, 20),
                  children: _sections(
                    context,
                    _search.text.trim().toLowerCase(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context, String query) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final r = list.list;
    final plugins = {for (final p in r.plugins) p.id: p};
    final groups = list.groups(r.skills.where((s) => skillMatches(s, query)));
    final shownPlugins = r.plugins.where((p) => pluginMatches(p, query));
    final builtIn = skillMatches(
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
      if (list.loaded && !any)
        Text('No skills or plugins match.', style: muted),
      if (list.loaded)
        for (final MapEntry(key: from, value: skills) in groups.entries)
          if (skills.isNotEmpty || (query.isEmpty && from != 'user'))
            SkillGroup(
              list: list,
              title: switch (from) {
                'user' => 'Yours',
                'project' => 'This project',
                _ => plugins[from]?.name ?? from,
              },
              about: switch (from) {
                'user' => 'In every folder: skills in your Claude folder.',
                'project' =>
                  'In this folder: .claude/skills here and in the folders '
                      'above it.',
                _ =>
                  'From the plugin $from: on and off with it, under '
                      'Plugins.',
              },
              skills: skills,
            ),
      if (list.loaded && builtIn) BuiltInGroup(list),
      if (list.loaded && (shownPlugins.isNotEmpty || query.isEmpty))
        PluginsGroup(list, shownPlugins.toList()),
    ];
  }
}

/// New skill…: a new Claude chat in [folder] with a message asking Claude
/// to write the skill in its box, to read, change and send (Claude's own
/// skill-creator can take it from there). Nothing is sent here.
Future<void> newSkill(
  BuildContext context,
  Daemon daemon,
  String folder,
) async {
  final before = daemon.selectedId;
  await tryOrShow(context, () => daemon.startChat(folder, 'claude'));
  final chat = daemon.selected; // the new chat, unless you went elsewhere
  if (chat == null || chat.id == before || !chat.fresh) return;
  chat.draft.text.text =
      'Help me write a new Claude Code skill. First ask me what it should '
      'do and whether it is for this project (.claude/skills) or for me '
      'everywhere (~/.claude/skills), then write its SKILL.md. Use the '
      'skill-creator skill if you have it.';
}
