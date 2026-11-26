import 'package:flutter/material.dart';

import 'package:nushi/agent_words.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/skills_shared.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// [row] inset in its group's box, as the MCP view's servers.
Widget skillRow(Widget row) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  child: row,
);

/// What listing [skill] costs every chat's context, in a row's [muted]
/// words.
Widget skillTokens(BuildContext context, Skill skill, TextStyle muted) =>
    tooltip(
      context,
      'About what listing it costs every chat’s context',
      Text('≈ ${skill.tokens} tokens', style: muted),
    );

/// A skill row's ⋯: open its file, show it, then [more].
Widget skillMenu(Skill skill, List<MenuEntry> more) => MenuIcon.line(
  LineIcon.more,
  size: 15,
  tooltip: 'More',
  entries: [
    MenuEntry(openSkillLabel(skill), onPick: () => openSkillFile(skill)),
    MenuEntry(
      conventions.reveal,
      onPick: () => native.desktop.reveal(skill.path),
    ),
    ...more,
  ],
);

/// A switch for where it acts ([where]: "everywhere", "in this project"),
/// disabled with [why] when it can't act; [onChanged] runs the change.
class SkillSwitch extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return tooltip(
      context,
      why.isNotEmpty
          ? why
          : '${on ? 'On' : 'Off'} $where. Chats pick up a '
                'change when they restart.',
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 8),
            child: Text(where, style: theme.ui(theme.t.textMuted, size: 11)),
          ),
          SettingsSwitch(value: on, run: why.isNotEmpty ? null : onChanged),
        ],
      ),
    );
  }
}

/// A row's name and, under it, its author's text, plain (never Markdown or
/// links), then [note], Nushi's own words, in a muted line of its own (a
/// plugin's counts), so a long description never pushes it out or passes
/// it off as the author's; dimmed when [off].
Widget skillNamed(
  BuildContext context,
  String name,
  String text, {
  required bool off,
  List<Widget> after = const [],
  String note = '',
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
        if (note.isNotEmpty) Text(note, style: theme.ui(t.textMuted, size: 11)),
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
  Widget build(BuildContext context) => SettingsGroup(
    title: title,
    about: about,
    empty: 'None',
    children: [for (final s in skills) skillRow(_SkillRow(list, s))],
  );
}

class _SkillRow extends StatelessWidget {
  const new(this.list, this.skill);

  final SkillsList list;
  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 11);
    final plugin = skill.source == 'plugin';
    // The daemon says what its Trash would refuse (a file, one in a
    // group, another agent's, the agent's own built-in ones).
    final deletable = !plugin && skill.source != 'system' && !skill.noTrash;
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
                tooltip(
                  context,
                  'A link to ${skill.linked}',
                  Text('linked', style: muted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        skillTokens(context, skill, muted),
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
        skillMenu(skill, [
          if (deletable)
            MenuEntry(
              'Delete…',
              onPick: () => deleteSkill(context, list, skill),
            ),
        ]),
      ],
    );
  }
}

/// The agent's built-in skills, on and off together, everywhere.
class BuiltInGroup extends StatelessWidget {
  const new(this.list, {super.key});

  final SkillsList list;

  @override
  Widget build(BuildContext context) {
    final r = list.list;
    final setting = agentWords(list.agent).builtInSetting;
    return SettingsGroup(
      title: 'Built in',
      about:
          '${agentTitle(list.agent)}’s own skills, which it doesn’t list for '
          'Nushi.',
      empty: 'None',
      children: [
        skillRow(
          Row(
            children: [
              Expanded(
                child: skillNamed(
                  context,
                  'Built-in skills',
                  'All of them together'
                      '${setting == null ? '' : ' ($setting)'}; built-in '
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
        ),
      ],
    );
  }
}
