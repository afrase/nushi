import 'package:flutter/material.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How many rows show without a click: each one shown costs git processes
/// when it refreshes, so the rest wait behind their line.
const _shown = 5;

/// The panel's Worktrees widget: the chat's related worktrees (ADR 0081).
/// Those still there are its list; those gone are folded under one line
/// ([goneLine]), closed, so none reads as still there. A click on a row
/// opens the Changes tab on it, through [onChanges]. Null (no widget) when
/// the chat has none.
PanelWidget? worktreesWidget(
  ChatState chat, {
  required VoidCallback onChanges,
}) {
  final list = chat.related.ordered;
  if (list.isEmpty) return null;
  final subs = {for (final s in subagentsOf(chat.items)) s.call.id: s};
  Widget row(RelatedWorktree w) => _WorktreeRow(
    chat,
    w,
    subs[w.callId],
    onChanges,
    key: ValueKey(
      chat.related.keyOf(w)!,
    ), // of the list; a path can have several
  );
  final there = [
    for (final w in list)
      if (w.state == 'present') row(w),
  ];
  final gone = list.where((w) => w.state != 'present').toList();
  return PanelWidget(
    title: 'Worktrees',
    summary: Builder(
      builder: (context) {
        final theme = NushiTheme.of(context);
        return Text(
          [
            if (there.isNotEmpty) '${there.length}',
            if (gone.isNotEmpty) '${gone.length} removed',
          ].join(', '),
          style: theme.ui(theme.t.textMuted, size: 12),
        );
      },
    ),
    rows: [
      for (final r in there.take(_shown)) (null, r),
      if (there.length > _shown)
        (
          null,
          MoreRows(
            '${there.length - _shown} more',
            there.skip(_shown).toList(),
            open: false,
            key: const ValueKey('more'),
          ),
        ),
      if (gone.isNotEmpty)
        (
          null,
          MoreRows(
            goneLine(gone),
            [for (final w in gone) row(w)],
            open: false,
            key: const ValueKey('gone'),
          ),
        ),
    ],
  );
}

/// The line the gone worktrees fold under: how many, and how many of them
/// were merged ("2 removed", "3 removed, 2 merged", "2 removed, both
/// merged").
String goneLine(List<RelatedWorktree> gone) {
  final n = gone.length;
  final merged = gone.where((w) => w.merged || w.pullMerged).length;
  return switch (merged) {
    0 => '$n removed',
    _ when merged < n => '$n removed, $merged merged',
    _ when n == 1 => '1 removed, merged',
    _ when n == 2 => '2 removed, both merged',
    _ => '$n removed, all merged',
  };
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
  // Its record's key: the row is keyed by it, so it stays the row's.
  late final String _key = widget.chat.related.keyOf(widget.worktree)!;

  @override
  void initState() {
    super.initState();
    widget.chat.related.want(_key);
  }

  @override
  void dispose() {
    widget.chat.related.unwant(_key);
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
        widget.chat.related.pick(_key);
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
                  // Gone, it's inked as an archived chat is: no longer
                  // live (its end says so in words).
                  style: theme.code(
                    w.state == 'present' ? t.text : t.textMuted,
                    size: 11.5,
                  ),
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
                  builder: (context, _) => _Work(
                    widget.chat.related.stats(_key),
                    gone: w.state != 'present',
                  ),
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

/// "+12 −3, 4 files, 2 ahead", or that its commits are gone; a line of
/// its own height before the stats are in. A [gone] worktree's is all in
/// muted ink, its counts too: nothing on its row reads as live work.
class _Work extends StatelessWidget {
  const new(this.stats, {required this.gone});

  final RelatedWorktreeStats? stats;
  final bool gone;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 11.5);
    final s = stats;
    if (s == null) return Text('…', style: muted);
    if (s.commitsGone) return Text('Commits gone', style: muted);
    final t = theme.t;
    final code = theme.code(gone ? t.textMuted : t.done, size: 11);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '+${s.added}', style: code),
          TextSpan(
            text: ' −${s.removed}',
            style: code.copyWith(color: gone ? t.textMuted : t.crashed),
          ),
          TextSpan(
            text: [
              '',
              '${s.files} file${s.files == 1 ? '' : 's'}',
              if (s.ahead > 0) '${s.ahead} ahead',
            ].join(', '),
            style: muted,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
