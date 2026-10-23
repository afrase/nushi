import 'dart:async';

import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'status.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// A tool call that started a subagent, and what the subagent did.
/// [busy]: the chat's turn runs.
typedef Subagent = ({Item call, List<Item> items, bool busy});

/// The subagents in [items], each with the items it made, in order.
List<Subagent> subagentsOf(List<Item> items, {required bool busy}) {
  final under = <String, List<Item>>{};
  for (final it in items) {
    if (it.parent.isNotEmpty) (under[it.parent] ??= []).add(it);
  }
  return [
    for (final it in items)
      if (it.agent.isNotEmpty)
        (call: it, items: under[it.id] ?? const [], busy: busy),
  ];
}

/// The tool call that ends a subagent and carries its report (Claude's
/// SubagentHandback), if it has come.
Item? _handback(Subagent s) =>
    s.items.where((it) => it.tool == 'SubagentHandback').lastOrNull;

/// Whether the subagent works: its call runs, or it was started in the
/// background (Claude then completes the call at once, saying so) and
/// hasn't handed back yet, while the turn runs or it has made steps. (A
/// chat reopened with session/load gets no steps of a background subagent:
/// it reads as done.)
bool _running(Subagent s) =>
    s.call.status == 'pending' ||
    s.call.status == 'in_progress' ||
    s.call.status == 'completed' &&
        s.call.text.startsWith('Async agent launched') &&
        _handback(s) == null &&
        (s.busy || s.items.isNotEmpty);

/// What the subagent found: its handback's report, else (a subagent in the
/// foreground) its call's output, once it has ended.
String _result(Subagent s) =>
    _handback(s)?.text ??
    (s.call.text.startsWith('Async agent launched') ? '' : s.call.text);

/// The subagent's own steps, without the handback (its report shows as the
/// result).
List<Item> _steps(Subagent s) => [
  for (final it in s.items)
    if (it.tool != 'SubagentHandback') it,
];

/// When each running subagent was first seen, by its call's id: the app
/// gets no start times, so the time counts from then.
final _seen = <String, DateTime>{};

/// A subagent's state in a few words: "Reading notes.md · 6 tool calls ·
/// 40s" while it works, "6 tool calls" once done, "failed".
String subagentState(Subagent s) {
  final calls = _steps(s)
      .where((it) => it.kind == ItemKind.ITEM_KIND_TOOL_CALL)
      .length;
  final count = '$calls tool call${calls == 1 ? '' : 's'}';
  if (s.call.status == 'failed') return 'failed · $count';
  if (!_running(s)) return count;
  final since = _seen.putIfAbsent(s.call.id, DateTime.now);
  return '${doing(s.items)} · $count · '
      '${elapsed(DateTime.now().difference(since))}';
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

  final Subagent subagent;
  final Widget Function(List<Item> items) nested;
  final bool still;

  @override
  State<SubagentCard> createState() => _SubagentCardState();
}

class _SubagentCardState extends State<SubagentCard> {
  bool _open = false;
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_running(widget.subagent)) setState(() {});
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
    final running = _running(s);
    final failed = call.status == 'failed';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: box(failed ? t.crashed : t.borderSubtle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: failed ? t.crashedSoft : t.raised,
            child: Tap(
              onTap: () => setState(() => _open = !_open),
              radius: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                spacing: 6,
                children: [
                  Icon(
                    _open ? Icons.expand_more : Icons.chevron_right,
                    size: 14,
                    color: t.textSecondary,
                  ),
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 14,
                    color: t.textSecondary,
                  ),
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
                      style: theme.ui(
                        failed ? t.crashed : t.textMuted,
                        size: 12,
                      ),
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
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.nested(_steps(s)),
                  if (_result(s) case final result
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
        ],
      ),
    );
  }
}
