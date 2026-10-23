import 'package:flutter/material.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'settings.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The icon that marks a worktree.
const worktreeIcon = Icons.account_tree_outlined;

/// The Environment card's worktree rows for a chat in a git repository:
/// for a worktree chat its branch (with the worktree icon) and base; for a
/// chat without messages a "New worktree" switch, which moves it into a new
/// worktree or back and is remembered for the repository; otherwise "Move to
/// new worktree". [branch] is the branch checked out in the chat's folder.
List<(String?, Widget)> worktreeRows(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
  String branch,
) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final wt = chat.worktree;
  final code = theme.code(t.text, size: 12);
  final offer = daemon.canWorktrees && !chat.archived;
  final can = offer && !chat.busy && !chat.waiting;
  return [
    (
      'Branch',
      Tooltip(
        message: wt == null ? '' : 'A worktree at ${tildePath(wt.path)}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (wt != null) ...[
              Icon(worktreeIcon, size: 13, color: t.textSecondary),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(branch, style: code, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    ),
    if (wt != null)
      ('Base', Text(wt.base, style: code, overflow: TextOverflow.ellipsis)),
    if (offer && chat.fresh)
      (
        'New worktree',
        SizedBox(
          height: 20,
          child: FittedBox(
            child: Switch(
              value: wt != null,
              onChanged: can
                  ? (on) {
                      final repos = {...worktreeRepos.value};
                      on ? repos.add(chat.home) : repos.remove(chat.home);
                      worktreeRepos.value = repos;
                      tryOrShow(
                        context,
                        () => daemon.moveChat(chat, chat.home, worktree: on),
                      );
                    }
                  : null,
            ),
          ),
        ),
      )
    else if (offer && wt == null)
      (
        null,
        Align(
          alignment: Alignment.centerLeft,
          child: Button(
            label: 'Move to new worktree',
            icon: worktreeIcon,
            kind: ButtonKind.ghost,
            height: 24,
            onPressed: can ? () => _confirmMove(context, chat, daemon) : null,
          ),
        ),
      ),
  ];
}

/// Asks before moving a chat with messages to a new worktree, then moves it.
Future<void> _confirmMove(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final name = chat.home.split('/').last;
  final move = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: t.raised,
      title: Text(
        'Move to a new worktree?',
        style: theme.ui(t.text, size: 15, weight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 440,
        child: Text(
          'The chat goes on in a new worktree of $name, in its .worktrees '
          'folder, on a new branch nushi/… that starts from the last commit.'
          '\n\nUncommitted changes stay where they are: they stay in $name, '
          'and the worktree starts without them.',
          style: theme.ui(t.textSecondary),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: theme.ui(t.text)),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, true),
          child: Text('Move', style: theme.ui(t.accent)),
        ),
      ],
    ),
  );
  if (move == true && context.mounted) {
    await tryOrShow(
      context,
      () => daemon.moveChat(chat, chat.home, worktree: true),
    );
  }
}
