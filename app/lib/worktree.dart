import 'package:flutter/material.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
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

/// The Delete dialog's choices for a chat's worktree and branch, each on by
/// default only when nothing would be lost; forcing follows from the
/// warning shown. The branch goes only with the worktree (git keeps a
/// branch a worktree has checked out).
class WorktreeChoices extends StatelessWidget {
  const WorktreeChoices({
    super.key,
    required this.plan,
    required this.remove,
    required this.branch,
    required this.onChanged,
  });

  final PlanDeleteChatResponse plan;
  final bool remove, branch;
  final void Function(bool remove, bool branch) onChanged;

  /// The choices that start on for [plan]: (remove, branch).
  static (bool, bool) defaults(PlanDeleteChatResponse plan) {
    final st = plan.worktreeState;
    final remove = st.error.isEmpty && st.changed == 0;
    return (remove, remove && st.commits == 0 && !st.branchGone);
  }

  /// [req] with these choices.
  static DeleteChatRequest request(
    DeleteChatRequest req,
    PlanDeleteChatResponse plan, {
    required bool remove,
    required bool branch,
  }) {
    final st = plan.worktreeState;
    return req
      ..removeWorktree = remove
      ..forceWorktree = remove && st.changed > 0
      ..deleteBranch = remove && branch
      ..forceBranch = remove && branch && st.commits > 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final wt = plan.worktree;
    final st = plan.worktreeState;
    final base = wt.base;
    Widget note(String text, {bool warn = false}) => Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 2),
      child: Text(
        text,
        style: theme.ui(warn ? t.crashed : t.textMuted, size: 12),
      ),
    );
    Widget choice(
      String label,
      String what,
      bool value,
      ValueChanged<bool>? onChanged,
    ) => Row(
      children: [
        Checkbox(
          value: value,
          visualDensity: VisualDensity.compact,
          onChanged: onChanged == null ? null : (v) => onChanged(v!),
        ),
        Text(label, style: theme.ui(onChanged == null ? t.textMuted : t.text)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            what,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.textMuted, size: 11.5),
          ),
        ),
      ],
    );
    if (st.error.isNotEmpty) {
      return Text(
        'Its worktree ${tildePath(wt.path)} and branch ${wt.branch} stay: '
        'Nushi can’t tell what’s in them (${st.error}).',
        style: theme.ui(t.textSecondary),
      );
    }
    final changes = st.changed == 1 ? '1 file' : '${st.changed} files';
    final commits = st.commits == 1 ? '1 commit' : '${st.commits} commits';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        choice(
          'Remove the worktree',
          '.worktrees/${wt.path.split('/').last}',
          remove,
          (v) => onChanged(v, branch),
        ),
        if (st.gone)
          note('Its folder was already removed outside Nushi.')
        else if (st.changed > 0)
          note(
            '$changes with uncommitted or untracked changes would be lost.',
            warn: true,
          ),
        if (st.branchGone)
          note('Its branch ${wt.branch} was already deleted.')
        else ...[
          choice(
            'Delete the branch',
            wt.branch,
            remove && branch,
            remove ? (v) => onChanged(remove, v) : null,
          ),
          if (!remove)
            note(
              'Only with the worktree: git won’t delete a branch a worktree '
              'has checked out.',
            )
          else if (st.commits > 0)
            note('$commits that $base doesn’t have would be lost.', warn: true)
          else
            note('$base has all of its commits.'),
        ],
      ],
    );
  }
}
