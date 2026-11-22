import 'package:flutter/material.dart';

import 'package:nushi/agent_words.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/skills_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The installed plugins: what each brings, its switch, and Uninstall….
class PluginsGroup extends StatelessWidget {
  const new(this.list, this.plugins, {super.key});

  final SkillsList list;
  final List<Plugin> plugins;

  @override
  Widget build(BuildContext context) {
    final error = list.list.pluginsError;
    final title = agentTitle(list.agent);
    final command = agentWords(list.agent).pluginCommand;
    return SettingsGroup(
      title: 'Plugins',
      about: error.isNotEmpty
          ? '$title didn’t list them: $error'
          : command == null
          ? 'Installed plugins.'
          : 'Installed plugins. Add them with $command in $title.',
      empty: 'None',
      children: [for (final p in plugins) skillRow(_PluginRow(list, p))],
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
      '${agentTitle(list.agent)} removes it for you, with its skills, '
          'commands, agents and MCP servers, and the data it saved.',
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
    final command = agentWords(list.agent).pluginCommand;
    final withIt = command == null ? '' : ' with $command';
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
        MenuIcon.line(
          LineIcon.more,
          size: 15,
          tooltip: 'More',
          entries: [
            MenuEntry(
              conventions.reveal,
              onPick: () => native.desktop.reveal(plugin.path),
            ),
            MenuEntry(
              'Uninstall…',
              tooltip: plugin.scope == 'user'
                  ? ''
                  : 'Installed for this project: uninstall it$withIt in a '
                        'terminal there.',
              onPick: plugin.scope == 'user' ? () => _uninstall(context) : null,
            ),
          ],
        ),
      ],
    );
  }
}
