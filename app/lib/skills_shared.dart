import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/skills_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The shared skills (ADR 0052): the project's .agents/skills (here and in
/// the folders above it) and yours in ~/.agents/skills, which several
/// agents read. Each row names the agents that load it; its switch is the
/// picked agent's, by that agent's own means.
class SharedGroup extends StatelessWidget {
  const new(this.list, this.skills, {super.key});

  final SkillsList list;
  final List<Skill> skills;

  @override
  Widget build(BuildContext context) {
    final title = agentTitle(list.agent);
    final link = list.list.readsShared
        ? ''
        : ' $title doesn’t read .agents/skills yet: link a skill to give it '
              'to $title.';
    return SkillsBox(
      'Shared',
      'In .agents/skills, which several agents read: the project’s, and '
          'yours in ~/.agents/skills.$link',
      [for (final s in skills) _SharedRow(list, s)],
    );
  }
}

/// "Codex, PiG and Claude": [names] as a sentence's list.
String listed(List<String> names) => switch (names.length) {
  0 => '',
  1 => names.single,
  _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
};

class _SharedRow extends StatelessWidget {
  const new(this.list, this.skill);

  final SkillsList list;
  final Skill skill;

  SkillAgent? get _mine =>
      skill.agents.where((a) => a.agent == list.agent).firstOrNull;

  Future<void> _delete(BuildContext context) async {
    final losing = listed([for (final a in skill.agents) agentTitle(a.agent)]);
    final links = [
      for (final a in skill.agents)
        if (a.via.isNotEmpty)
          '${agentTitle(a.agent)}’s link ${tildePath(a.via)}',
    ];
    final ok = await confirm(
      context,
      'Delete ${skill.name}?',
      'Its folder goes to the Trash:\n${tildePath(skill.path)}\n\n'
          '${losing.isEmpty ? 'No agent loads it here.' : '$losing lose it.'}'
          '${links.isEmpty ? '' : '\n${listed(links)} go too.'}',
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

  Future<void> _link(BuildContext context) async {
    final title = agentTitle(list.agent);
    final at = skill.everywhere
        ? 'your skills folder'
        : '.claude/skills beside the .agents holding it';
    final ok = await confirm(
      context,
      'Link ${skill.name} for $title?',
      '$title doesn’t read .agents/skills yet. Nushi makes a link to the '
          'skill in $at, so $title loads it too; the skill stays where it is.',
      'Link',
    );
    if (!ok || !context.mounted) return;
    await tryOrShow(context, () async {
      await list.daemon.client.linkSkill(
        LinkSkillRequest(
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
    final mine = _mine;
    final title = agentTitle(list.agent);
    final notes = [
      for (final a in skill.agents)
        if (a.state == 'off')
          'Off for ${agentTitle(a.agent)}'
        else if (a.state == 'untrusted')
          '${agentTitle(a.agent)} loads it once the folder is trusted',
    ];
    final names = [
      for (final a in skill.agents)
        agentTitle(a.agent) + (a.via.isEmpty ? '' : ' (linked)'),
    ];
    final canLink = mine == null && list.agent == 'claude';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              skillNamed(
                context,
                skill.name,
                skill.description,
                off: mine == null || mine.state != 'on',
                after: [
                  const SizedBox(width: 8),
                  if (skill.everywhere) Text('~/.agents/skills', style: muted),
                  if (skill.linked.isNotEmpty)
                    Tooltip(
                      message: 'A link to ${skill.linked}',
                      child: Text(' linked', style: muted),
                    ),
                ],
              ),
              Text(
                [
                  if (names.isEmpty)
                    'No agent loads it here'
                  else
                    names.join(', '),
                  ...notes,
                ].join('  ·  '),
                style: muted,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'About what listing it costs every chat’s context',
          child: Text('≈ ${skill.tokens} tokens', style: muted),
        ),
        if (mine == null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              canLink ? 'Not read by $title' : 'Not read by $title here',
              style: muted,
            ),
          )
        else if (mine.state == 'untrusted')
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Tooltip(
              message:
                  '$title loads a folder’s skills only once you trust the '
                  'folder in $title.',
              child: Text('Loads once the folder is trusted', style: muted),
            ),
          )
        else
          SkillSwitch(
            on: mine.state != 'off',
            where: 'for $title',
            why: switchWhy(list, mine.setIn),
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
            if (canLink)
              MenuEntry('Link for $title…', onPick: () => _link(context)),
            MenuEntry('Delete…', onPick: () => _delete(context)),
          ],
        ),
      ],
    );
  }
}
