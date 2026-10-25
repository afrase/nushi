import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/inline_edit.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The New chat dialog's lines for a Jira issue: without one, "Jira
/// issue…" (I) to pick one; with one, the issue (a click picks another, ×
/// or ⌫ clears it) and, in a folder, whether the chat gets a worktree on
/// the issue's branch (W), the branch editable in place (a click, or B).
class IssueLines extends StatelessWidget {
  const new({
    required this.issue,
    required this.inFolder,
    required this.editingBranch,
    required this.onPick,
    required this.onClear,
    required this.onWorktree,
    required this.onEditBranch,
    required this.onBranch,
    super.key,
  });

  final IssueChat? issue;

  /// Whether the chat has a folder of its own (a worktree needs one).
  final bool inFolder;
  final bool editingBranch;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onWorktree;
  final VoidCallback onEditBranch;

  /// The branch typed, or null when the edit was cancelled.
  final ValueChanged<String?> onBranch;

  static const _pad = EdgeInsets.symmetric(horizontal: 8, vertical: 6);

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final small = theme.ui(t.textSecondary, size: 12.5);
    final issue = this.issue;
    if (issue == null) {
      return Tap(
        onTap: onPick,
        padding: _pad,
        child: Row(
          children: [
            Icon(Icons.task_alt, size: 16, color: t.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text('Jira issue…', style: small)),
            keyHint(context, 'I'),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap(
          onTap: onPick,
          tooltip: 'Pick another issue',
          padding: const EdgeInsets.fromLTRB(8, 2, 2, 2),
          child: Row(
            children: [
              Icon(Icons.task_alt, size: 16, color: t.textSecondary),
              const SizedBox(width: 12),
              Text(issue.key, style: theme.code(t.text, size: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issue.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
              ),
              IconTap(
                Icons.close,
                size: 14,
                tooltip: 'No issue (⌫)',
                onTap: onClear,
              ),
            ],
          ),
        ),
        if (inFolder)
          Tap(
            onTap: onWorktree,
            padding: _pad,
            child: Row(
              children: [
                Icon(
                  issue.worktree
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 16,
                  color: t.textSecondary,
                ),
                const SizedBox(width: 12),
                Text('In a new worktree on ', style: small),
                Expanded(
                  child: editingBranch
                      ? SizedBox(
                          height: 22,
                          child: InlineEdit(
                            text: issue.branch,
                            onDone: onBranch,
                            style: theme.code(t.text, size: 12),
                          ),
                        )
                      : Tap(
                          onTap: onEditBranch,
                          tooltip: 'Change the branch (B)',
                          child: Text(
                            issue.branch,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.code(t.text, size: 12),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                keyHint(context, 'W'),
              ],
            ),
          ),
      ],
    );
  }
}
