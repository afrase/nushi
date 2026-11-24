import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/pull_check_lines.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_merge.dart';
import 'package:nushi/pull_merge_state.dart';
import 'package:nushi/pull_segment_lists.dart';
import 'package:nushi/pull_segments.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/theme/theme.dart';

/// What the merge status card says first: its heading, one line under it,
/// its mood and icon.
typedef MergeHead = ({String heading, String line, Mood mood, IconData icon});

/// What the card says of [p]: merged or closed, else [mergeView]'s
/// heading and sentence (in the queue; auto-merge on; ready; still being
/// worked out; or blocked, and by what).
MergeHead mergeHead(GitHubPull p) {
  MergeHead say(String h, String l, Mood m, IconData i) =>
      (heading: h, line: l, mood: m, icon: i);
  final it = p.item;
  if (it.state == 'merged') {
    return say('Merged', 'Into ${p.base}.', Mood.ok, Icons.merge_type);
  }
  if (it.state == 'closed') {
    return say('Closed', 'Without merging.', Mood.quiet, closedIcon);
  }
  final view = mergeView(p);
  if (view == null) {
    return say('Checking whether it can merge', '', Mood.quiet, Icons.schedule);
  }
  return say(view.heading, view.why, view.mood, view.icon);
}

/// The merge status card, first on the Overview: its state's icon,
/// heading and line; at its right, when something blocks that the agent
/// can act on, Send N to agent ([items], each a reply card), and the
/// merge button with its method menu ([MergeButtons]). Under it, for an
/// open pull request, the Checks, Comments and Approvals segments; a
/// click opens one's list under them, one at a time.
class MergeCard extends StatefulWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.items,
    required this.onChanged,
    required this.onThread,
    required this.onReview,
    super.key,
    this.stale = false,
  });

  final Daemon daemon;
  final GitHubPull pull;

  /// What blocks it that can go to the agent ([todo]).
  final List<TodoItem> items;
  final Future<void> Function() onChanged;
  final ValueChanged<GitHubThread> onThread;
  final ValueChanged<String> onReview;

  /// It shows what was kept from before: no merge button.
  final bool stale;

  @override
  State<MergeCard> createState() => MergeCardState();
}

/// [MergeCard]'s state; [reveal] opens the first segment that holds the
/// merge back (the bar's Merge status).
class MergeCardState extends State<MergeCard> {
  Segment? _open;

  /// Opens the first segment not met, unless one is open.
  void reveal() {
    if (_open != null) return;
    final first = _segments().where((s) => s.mood != Mood.ok).firstOrNull;
    if (first != null) setState(() => _open = first.segment);
  }

  List<SegmentState> _segments() => segmentsOf(
    widget.pull,
    findings: widget.items.whereType<FindingTodo>().length,
  );

  Future<void> _send() {
    final p = widget.pull;
    final items = widget.items;
    return toAgent(
      context,
      widget.daemon,
      p.item,
      what: items.length == 1 ? items.single.what : '',
      replies: () => Future.wait([
        for (final i in items) i.reply(widget.daemon, p.item.ref),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _build(context, narrow: box.maxWidth < 640),
  );

  Widget _build(BuildContext context, {required bool narrow}) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = widget.pull;
    final head = mergeHead(p);
    final open = p.item.state == 'open';
    final items = open ? widget.items : const <TodoItem>[];
    final line = Divider(height: 1, thickness: 1, color: t.line);
    final words = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: moodSoft(t, head.mood),
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          child: Icon(head.icon, size: 18, color: moodColor(t, head.mood)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                head.heading,
                key: const ValueKey('merge-heading'),
                style: theme.ui(t.text, size: 14, weight: FontWeight.w600),
              ),
              if (head.line.isNotEmpty)
                Text(
                  head.line,
                  key: const ValueKey('merge-line'),
                  style: theme.ui(t.textMuted, size: 12),
                ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (items.isNotEmpty)
          quietSend(
            context,
            label: items.length == 1
                ? 'Send to agent'
                : 'Send ${items.length} to agent',
            onPressed: _send,
          ),
        MergeButtons(
          daemon: widget.daemon,
          pull: p,
          stale: widget.stale,
          onChanged: widget.onChanged,
        ),
      ],
    );
    final segments = _segments();
    return Container(
      key: const ValueKey('merge-card'),
      clipBehavior: Clip.antiAlias,
      decoration: cardBox(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [words, actions],
                  )
                : Row(
                    children: [
                      Expanded(child: words),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  ),
          ),
          if (open) ...[
            line,
            SegmentRow(
              segments: segments,
              open: _open,
              narrow: narrow,
              onOpen: (s) => setState(() => _open = s),
            ),
            if (_open case final s?) ...[
              line,
              switch (s) {
                Segment.checks => ChecksList(
                  daemon: widget.daemon,
                  pull: p,
                  narrow: narrow,
                  onChanged: widget.onChanged,
                ),
                Segment.comments => CommentsList(
                  daemon: widget.daemon,
                  pull: p,
                  narrow: narrow,
                  findings: [
                    for (final i in widget.items.whereType<FindingTodo>())
                      i.finding,
                  ],
                  onThread: widget.onThread,
                  onReview: widget.onReview,
                ),
                Segment.approvals => ApprovalsList(pull: p),
              },
            ],
          ],
        ],
      ),
    );
  }
}
