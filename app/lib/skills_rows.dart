import 'package:flutter/material.dart';

import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A group's heading, the line under it and its rows in a box, as the MCP
/// view's scopes.
class SkillsBox extends StatelessWidget {
  const new(this.title, this.about, this.rows, {super.key});

  final String title;
  final String about;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
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
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('None', style: muted),
                    ),
                  ),
                for (final (i, r) in rows.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(top: BorderSide(color: t.borderSubtle)),
                    ),
                    child: r,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A switch for where it acts ([where]: "everywhere", "in this project"),
/// disabled with [why] when it can't act; [onChanged] runs the change.
class SkillSwitch extends StatefulWidget {
  const new({
    required this.on,
    required this.where,
    required this.onChanged,
    this.why = '',
    super.key,
  });

  final bool on;
  final String where;
  final String why;
  final Future<void> Function({required bool on}) onChanged;

  @override
  State<SkillSwitch> createState() => _SkillSwitchState();
}

class _SkillSwitchState extends State<SkillSwitch> {
  bool _working = false;

  Future<void> _set(bool on) async {
    setState(() => _working = true);
    await tryOrShow(context, () => widget.onChanged(on: on));
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Tooltip(
      message: widget.why.isNotEmpty
          ? widget.why
          : '${widget.on ? 'On' : 'Off'} ${widget.where}. Chats pick up a '
                'change when they restart.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 2),
            child: Text(
              widget.where,
              style: theme.ui(theme.t.textMuted, size: 11),
            ),
          ),
          SizedBox(
            height: 20,
            child: FittedBox(
              child: Switch(
                value: widget.on,
                onChanged: _working || widget.why.isNotEmpty ? null : _set,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row's name and, under it, its author's text, plain (never Markdown or
/// links), dimmed when [off].
Widget skillNamed(
  BuildContext context,
  String name,
  String text, {
  required bool off,
  List<Widget> after = const [],
}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  return Opacity(
    opacity: off ? 0.5 : 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text, weight: FontWeight.w500),
              ),
            ),
            ...after,
          ],
        ),
        if (text.isNotEmpty)
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.textSecondary, size: 12),
          ),
      ],
    ),
  );
}

/// A skill's state in words, when it isn't plainly on or off.
String? _stateWord(String state) => switch (state) {
  'name-only' => 'Name only',
  'user-invocable-only' => 'Only by /name',
  'off' => 'Off',
  _ => null,
};

/// One source's skills: yours, the project's or a plugin's.
class SkillGroup extends StatelessWidget {
  const new({
    required this.list,
    required this.title,
    required this.about,
    required this.skills,
    super.key,
  });

  final SkillsList list;
  final String title;
  final String about;
  final List<Skill> skills;

  @override
  Widget build(BuildContext context) =>
      SkillsBox(title, about, [for (final s in skills) _SkillRow(list, s)]);
}

class _SkillRow extends StatelessWidget {
  const new(this.list, this.skill);

  final SkillsList list;
  final Skill skill;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      'Delete ${skill.name}?',
      'Its folder goes to the Trash:\n${tildePath(skill.path)}',
      'Move to Trash',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await tryOrShow(context, () async {
      await list.daemon.client.trashSkill(
        TrashSkillRequest(
          folder: list.folder,
          path: skill.path,
          agent: list.agent,
        ),
      );
      await list.changed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 11);
    final plugin = skill.source == 'plugin';
    final deletable =
        !plugin && skill.source != 'system' && ownSkill(list.agent, skill.path);
    final word = _stateWord(skill.state);
    return Row(
      children: [
        Expanded(
          child: skillNamed(
            context,
            skill.name,
            skill.description,
            off: skill.state == 'off',
            after: [
              const SizedBox(width: 8),
              if (word != null && word != 'Off') Text(word, style: muted),
              if (skill.linked.isNotEmpty)
                Tooltip(
                  message: 'A link to ${skill.linked}',
                  child: Text('linked', style: muted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'About what listing it costs every chat’s context',
          child: Text('≈ ${skill.tokens} tokens', style: muted),
        ),
        if (plugin)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('with its plugin', style: muted),
          )
        else
          SkillSwitch(
            on: skill.state != 'off',
            where: switchWhere(list.agent, skill),
            why: switchWhy(list, skill.setIn),
            onChanged: ({required on}) => setSkillOn(list, skill, on: on),
          ),
        MenuIcon(
          Icons.more_horiz,
          tooltip: 'More',
          size: 15,
          entries: [
            MenuEntry('Open SKILL.md', onPick: () => openSkillFile(skill)),
            MenuEntry(
              'Show in Finder',
              onPick: () => revealInFinder(skill.path),
            ),
            if (deletable) MenuEntry('Delete…', onPick: () => _delete(context)),
          ],
        ),
      ],
    );
  }
}

/// Claude's built-in skills, on and off together, everywhere.
class BuiltInGroup extends StatelessWidget {
  const new(this.list, {super.key});

  final SkillsList list;

  @override
  Widget build(BuildContext context) {
    final r = list.list;
    return SkillsBox(
      'Built in',
      'Claude Code’s own skills, which it doesn’t '
          'list for Nushi.',
      [
        Row(
          children: [
            Expanded(
              child: skillNamed(
                context,
                'Built-in skills',
                'All of them together (disableBundledSkills); built-in '
                    'commands stay.',
                off: r.builtInOff,
              ),
            ),
            SkillSwitch(
              on: !r.builtInOff,
              where: 'everywhere',
              why: r.builtInSetIn.isEmpty
                  ? ''
                  : 'Set in ${tildePath(r.builtInSetIn)}; change it there.',
              onChanged: ({required on}) async {
                await list.daemon.client.setSkillOn(
                  SetSkillOnRequest(
                    folder: list.folder,
                    source: 'builtin',
                    on: on,
                    agent: list.agent,
                  ),
                );
                await list.changed();
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// The installed plugins: what each brings, its switch, and Uninstall….
class PluginsGroup extends StatelessWidget {
  const new(this.list, this.plugins, {super.key});

  final SkillsList list;
  final List<Plugin> plugins;

  @override
  Widget build(BuildContext context) {
    final error = list.list.pluginsError;
    return SkillsBox(
      'Plugins',
      error.isNotEmpty
          ? 'Claude didn’t list them: $error'
          : 'Installed plugins. Add them with /plugin in Claude Code.',
      [for (final p in plugins) _PluginRow(list, p)],
    );
  }
}

/// "2 skills · 1 command · …", what a plugin brings.
String pluginCounts(Plugin p) => [
  for (final (n, word) in [
    (p.skills, 'skill'),
    (p.commands, 'command'),
    (p.agents, 'agent'),
    (p.mcpServers, 'MCP server'),
  ])
    if (n > 0) '$n $word${n == 1 ? '' : 's'}',
].join(' · ');

class _PluginRow extends StatelessWidget {
  const new(this.list, this.plugin);

  final SkillsList list;
  final Plugin plugin;

  Future<void> _uninstall(BuildContext context) async {
    final ok = await confirm(
      context,
      'Uninstall ${plugin.id}?',
      'Claude removes it for you, with its skills, commands, agents and '
          'MCP servers, and the data it saved.',
      'Uninstall',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await tryOrShow(context, () async {
      await list.daemon.client.uninstallPlugin(
        UninstallPluginRequest(
          folder: list.folder,
          id: plugin.id,
          agent: list.agent,
        ),
      );
      await list.changed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 11);
    final counts = pluginCounts(plugin);
    return Row(
      children: [
        Expanded(
          child: skillNamed(
            context,
            plugin.id,
            [
              plugin.description,
              if (counts.isNotEmpty) counts,
            ].where((s) => s.isNotEmpty).join('  ·  '),
            off: !plugin.enabled,
            after: [
              const SizedBox(width: 8),
              if (plugin.version.isNotEmpty) Text(plugin.version, style: muted),
              if (plugin.scope != 'user') ...[
                const SizedBox(width: 8),
                Text('installed for this project', style: muted),
              ],
            ],
          ),
        ),
        SkillSwitch(
          on: plugin.enabled,
          where: plugin.switchScope == 'user'
              ? 'everywhere'
              : 'in this project',
          onChanged: ({required on}) async {
            await list.daemon.client.setPluginOn(
              SetPluginOnRequest(
                folder: list.folder,
                id: plugin.id,
                on: on,
                agent: list.agent,
              ),
            );
            await list.changed();
          },
        ),
        MenuIcon(
          Icons.more_horiz,
          tooltip: 'More',
          size: 15,
          entries: [
            MenuEntry(
              'Show in Finder',
              onPick: () => revealInFinder(plugin.path),
            ),
            MenuEntry(
              'Uninstall…',
              tooltip: plugin.scope == 'user'
                  ? ''
                  : 'Installed for this project: uninstall it with /plugin '
                        'in a terminal there.',
              onPick: plugin.scope == 'user' ? () => _uninstall(context) : null,
            ),
          ],
        ),
      ],
    );
  }
}
