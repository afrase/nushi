import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/widgets.dart';

/// New skill…: a new chat with the list's agent in its folder, with a
/// message asking it to write the skill in its box, to read, change and
/// send. Nothing is sent here, and Nushi writes nothing (ADR 0052). The
/// skill goes in the shared .agents/skills, in the standard front matter,
/// when the agent reads it; for Claude, which doesn't yet, it asks first:
/// .claude/skills, or .agents/skills and a link from the Skills view.
Future<void> newSkill(BuildContext context, SkillsList list) async {
  final daemon = list.daemon;
  final title = agentTitle(list.agent);
  var shared = true;
  if (!list.list.readsShared) {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => nushiDialog(
        'New skill for $title',
        Text(
          '$title doesn’t read .agents/skills yet: put it in .claude/skills '
          'instead, or link it there. A skill in .agents/skills is read by '
          'Codex, PiG, oh-my-pi and Ante too; once it’s written, “Link for '
          '$title…” in its menu gives it to $title.',
        ),
        [
          Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
          Button(
            label: 'In .agents/skills',
            onPressed: () => Navigator.pop(context, true),
          ),
          Button(
            label: 'In .claude/skills',
            kind: ButtonKind.primary,
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (choice == null) return;
    shared = choice;
  }
  if (!context.mounted) return;
  final before = daemon.selectedId;
  await tryOrShow(context, () => daemon.startChat(list.folder, list.agent));
  final chat = daemon.selected; // the new chat, unless you went elsewhere
  if (chat == null || chat.id == before || !chat.fresh) return;
  chat.draft.text.text = shared
      ? 'Help me write a new skill shared by every agent that reads '
            '.agents/skills. First ask me what it should do, then write '
            '.agents/skills/<name>/SKILL.md in this folder: a short '
            'lowercase name with hyphens, the folder named the same, and '
            'the file starting with front matter that has `name` and '
            '`description` (what it does and when to use it), so Codex, '
            'Claude, PiG, oh-my-pi and Ante can all use it. Use the '
            'skill-creator skill if you have it.'
      : 'Help me write a new Claude Code skill. First ask me what it '
            'should do and whether it is for this project (.claude/skills) '
            'or for me everywhere (~/.claude/skills), then write its '
            'SKILL.md. Use the skill-creator skill if you have it.';
}
