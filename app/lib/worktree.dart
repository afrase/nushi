import 'package:flutter/material.dart';

import 'changes_span.dart';
import 'chat.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'settings.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The icon that marks a worktree.
const IconData worktreeIcon = Icons.account_tree_outlined;

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
  final theme = NushiTheme.of(context), t = theme.t;
  final wt = chat.worktree;
  final code = theme.code(t.text, size: 12);
  final offer = !chat.archived;
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
                  ? (on) => _switch(context, chat, daemon, on)
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

/// Moves a chat without messages into a new worktree ([on]) or back to its
/// repository, and once it has moved remembers the choice for the
/// repository.
void _switch(BuildContext context, ChatState chat, Daemon daemon, bool on) =>
    tryOrShow(context, () async {
      if (!await daemon.moveChat(chat, chat.home, worktree: on)) return;
      final repos = {...worktreeRepos.value};
      on ? repos.add(chat.home) : repos.remove(chat.home);
      worktreeRepos.value = repos;
    });

/// Under the composer of a chat without messages, as in Claude Code: its
/// folder and, in a git repository, the "New worktree" switch as a chip.
class NewChatBar extends StatefulWidget {
  const NewChatBar({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<NewChatBar> createState() => _NewChatBarState();
}

class _NewChatBarState extends State<NewChatBar> with FollowsChanges {
  @override
  ChatState get chat => widget.chat;
  @override
  Daemon get daemon => widget.daemon;
  bool _git = false;

  @override
  Future<void> reload() async {
    try {
      final s = await daemon.client.getFolderStatus(
        GetFolderStatusRequest(folder: chat.folder),
      );
      if (mounted) setState(() => _git = s.git);
    } on Object {
      // No chip, as outside git.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final on = chat.worktree != null;
    final color = on ? t.accent : t.textSecondary;
    return Row(
      children: [
        Flexible(
          child: FolderButton(chat: chat, daemon: daemon, path: false),
        ),
        if (_git)
          DecoratedBox(
            decoration: box(
              on ? t.accent : t.borderStrong,
              fill: on ? t.accentSoft : null,
              radius: 10,
            ),
            child: Tap(
              onTap: chat.busy || chat.waiting
                  ? null
                  : () => _switch(context, chat, daemon, !on),
              radius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              child: Row(
                spacing: 4,
                children: [
                  Icon(worktreeIcon, size: 12, color: color),
                  Text('New worktree', style: theme.ui(color, size: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Asks before moving a chat with messages to a new worktree, then moves it.
Future<void> _confirmMove(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  final name = chat.home.split('/').last;
  final move = await confirm(
    context,
    'Move to a new worktree?',
    'It goes on in a new worktree of $name, on a new branch from the last '
        'commit. Uncommitted changes stay in $name: the worktree starts '
        'without them.',
    'Move',
  );
  if (move && context.mounted) {
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

  final WorktreePlan plan;
  final bool remove, branch;
  final void Function({required bool remove, required bool branch}) onChanged;

  /// The choices that start on for [plan]: (remove, branch).
  static (bool, bool) defaults(WorktreePlan plan) {
    final st = plan.state;
    final remove = st.error.isEmpty && st.changed == 0 && st.ignored == 0;
    return (remove, remove && st.commits == 0 && !st.branchGone);
  }

  /// These choices for the request.
  static WorktreeChoice choice(
    WorktreePlan plan, {
    required bool remove,
    required bool branch,
  }) => WorktreeChoice(
    path: plan.worktree.path,
    removeWorktree: remove,
    forceWorktree: remove && (plan.state.changed > 0 || plan.state.ignored > 0),
    deleteBranch: remove && branch,
    forceBranch: remove && branch && plan.state.commits > 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final wt = plan.worktree;
    final st = plan.state;
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
      String what, {
      required bool value,
      required ValueChanged<bool>? onChanged,
    }) => Row(
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
    final ignored = st.ignored == 1
        ? '1 ignored file or folder'
        : '${st.ignored} ignored files or folders';
    final commits = st.commits == 1 ? '1 commit' : '${st.commits} commits';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        choice(
          'Remove the worktree',
          '.worktrees/${wt.path.split('/').last}',
          value: remove,
          onChanged: (v) => onChanged(remove: v, branch: branch),
        ),
        if (st.gone)
          note('Its folder was already removed outside Nushi.')
        else ...[
          if (st.changed > 0)
            note(
              '$changes with uncommitted or untracked changes would be lost.',
              warn: true,
            ),
          if (st.ignored > 0)
            note('$ignored (.env, build output…) would be lost.', warn: true),
        ],
        if (st.branchGone)
          note('Its branch ${wt.branch} was already deleted.')
        else ...[
          choice(
            'Delete the branch',
            wt.branch,
            value: remove && branch,
            onChanged: remove
                ? (v) => onChanged(remove: remove, branch: v)
                : null,
          ),
          if (!remove)
            note(
              'Only with the worktree: git won’t delete a checked-out branch.',
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
