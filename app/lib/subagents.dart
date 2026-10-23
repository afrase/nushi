import 'dart:async';

import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'status.dart';
import 'theme/theme.dart';
import 'tool_calls.dart';

/// A tool call that started a subagent, and what the subagent did.
typedef SubagentRun = ({Item call, List<Item> items});

/// The subagents in [items], each with the items it made, in order.
List<SubagentRun> subagentsOf(List<Item> items) {
  final under = <String, List<Item>>{};
  for (final it in items) {
    if (it.parent.isNotEmpty) (under[it.parent] ??= []).add(it);
  }
  return [
    for (final it in items)
      if (it.agent.isNotEmpty) (call: it, items: under[it.id] ?? const []),
  ];
}

/// Whether the subagent works, as the daemon says.
bool subagentRunning(SubagentRun s) => s.call.subagent.state == 'running';

/// The subagent's own steps, without its report (that shows as its result).
List<Item> _steps(SubagentRun s) => [
  for (final it in s.items)
    if (!it.report) it,
];

DateTime? _time(int ms) =>
    ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);

/// A subagent's state in a few words: "Reading notes.md · 6 tool calls ·
/// 40s" while it works, "done · 6 tool calls · 1m 02s" once done, "failed".
/// The count shows only when its steps are known (a background subagent's
/// aren't after the chat reopened), the time only when the daemon saw it
/// start.
String subagentState(SubagentRun s) {
  final sa = s.call.subagent;
  final calls = _steps(s)
      .where((it) => it.kind == ItemKind.ITEM_KIND_TOOL_CALL)
      .length;
  final running = subagentRunning(s);
  final since = _time(sa.started.toInt());
  final end = running ? DateTime.now() : _time(sa.ended.toInt());
  return [
    if (running) doing(s.items) else sa.state,
    if (calls > 0) '$calls tool call${calls == 1 ? '' : 's'}',
    if (since != null && end != null) elapsed(end.difference(since)),
  ].join(' · ');
}

/// A subagent as one card: its type and task ("Explore: find the scroll
/// handling") and its state, live; opened, its own steps ([nested] builds
/// them) and its result. [still]: the agent waits on the user.
class SubagentCard extends StatefulWidget {
  const SubagentCard(
    this.subagent, {
    super.key,
    required this.nested,
    this.still = false,
  });

  final SubagentRun subagent;
  final Widget Function(List<Item> items) nested;
  final bool still;

  @override
  State<SubagentCard> createState() => _SubagentCardState();
}

class _SubagentCardState extends State<SubagentCard> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (subagentRunning(widget.subagent)) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final s = widget.subagent;
    final call = s.call;
    final running = subagentRunning(s);
    final failed = call.subagent.state == 'failed';
    return Collapsible(
      failed: failed,
      header: Row(
        spacing: 6,
        children: [
          Icon(Icons.smart_toy_outlined, size: 14, color: t.textSecondary),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${call.agent}: ',
                    style: theme.ui(t.text, weight: FontWeight.w600),
                  ),
                  TextSpan(text: call.title, style: theme.ui(t.text)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              subagentState(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(failed ? t.crashed : t.textMuted, size: 12),
            ),
          ),
          if (running && !widget.still)
            const SizedBox.square(
              dimension: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else if (!running && !failed)
            Icon(Icons.check, size: 13, color: t.done),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.nested(_steps(s)),
            if (call.subagent.result case final result
                when !running && result.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Result',
                style: theme.ui(
                  t.textSecondary,
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
              AgentMarkdown(result),
            ],
          ],
        ),
      ),
    );
  }
}
