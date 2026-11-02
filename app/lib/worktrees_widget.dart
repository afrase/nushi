import 'package:flutter/material.dart';

import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_people.dart' show plainName;
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How many rows show without a click: each one shown costs git processes
/// when it refreshes, so the rest wait behind their line.
const _shown = 5;

/// The panel's Worktrees widget: the chat's related worktrees (ADR 0081), the
/// ones still there first. A click on a row opens the Changes tab on it,
/// through [onChanges]. Null (no widget) when the chat has none.
PanelWidget? worktreesWidget(
  ChatState chat, {
  required VoidCallback onChanges,
}) {
  final list = chat.related.ordered;
  if (list.isEmpty) return null;
  final subs = {for (final s in subagentsOf(chat.items)) s.call.id: s};
  final rows = [
    for (final w in list)
      _WorktreeRow(chat, w, subs[w.callId], onChanges, key: ValueKey(w.path)),
  ];
  return PanelWidget(
    title: 'Worktrees',
    summary: Builder(
      builder: (context) {
        final theme = NushiTheme.of(context);
        final out = list.where((w) => w.state != 'present').length;
        return Text(
          ['${list.length}', if (out > 0) '$out removed'].join(' · '),
          style: theme.ui(theme.t.textMuted, size: 12),
        );
      },
    ),
    rows: [
      for (final r in rows.take(_shown)) (null, r),
      if (rows.length > _shown)
        (
          null,
          MoreRows(
            '${rows.length - _shown} more',
            rows.skip(_shown).toList(),
            open: false,
          ),
        ),
    ],
  );
}

/// A related worktree: its branch and its subagent's mark, then its work and
/// how it ended. Its stats are asked for by its being built: a collapsed
/// widget, or a row folded away, asks for nothing.
class _WorktreeRow extends StatefulWidget {
  const new(this.chat, this.worktree, this.run, this.onChanges, {super.key});

  final ChatState chat;
  final RelatedWorktree worktree;
  final SubagentRun? run;
  final VoidCallback onChanges;

  @override
  State<_WorktreeRow> createState() => _WorktreeRowState();
}

class _WorktreeRowState extends State<_WorktreeRow> {
  @override
  void initState() {
    super.initState();
    widget.chat.related.want(widget.worktree.path);
  }

  @override
  void dispose() {
    widget.chat.related.unwant(widget.worktree.path);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final w = widget.worktree;
    final run = widget.run;
    final end = worktreeEnd(w);
    return Tap(
      onTap: () {
        widget.chat.related.pick(w.path);
        widget.onChanges();
      },
      tooltip: plainName(w.path),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 6,
            children: [
              Expanded(
                child: Text(
                  worktreeName(w),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.code(t.text, size: 11.5),
                ),
              ),
              if (run != null) subagentMark(run),
            ],
          ),
          Row(
            spacing: 6,
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.chat.related,
                  builder: (context, _) =>
                      _Work(widget.chat.related.stats(w.path)),
                ),
              ),
              if (end.isNotEmpty)
                Text(end, style: theme.ui(t.textMuted, size: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

/// "+12 −3 · 4 files · 2 ahead", or that its commits are gone; a line of
/// its own height before the stats are in.
class _Work extends StatelessWidget {
  const new(this.stats);

  final RelatedWorktreeStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 11.5);
    final s = stats;
    if (s == null) return Text('…', style: muted);
    if (s.commitsGone) return Text('commits gone', style: muted);
    final code = theme.code(theme.t.done, size: 11);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '+${s.added}', style: code),
          TextSpan(
            text: ' −${s.removed}',
            style: code.copyWith(color: theme.t.crashed),
          ),
          TextSpan(
            text: [
              '',
              '${s.files} file${s.files == 1 ? '' : 's'}',
              if (s.ahead > 0) '${s.ahead} ahead',
            ].join(' · '),
            style: muted,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
