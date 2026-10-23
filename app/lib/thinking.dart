import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The agent's thinking: a dim "Thinking" line that opens to the thoughts,
/// with a spinner while they stream ([live]).
class ThoughtView extends StatefulWidget {
  const ThoughtView(this.item, {super.key, required this.live});

  final Item item;
  final bool live;

  @override
  State<ThoughtView> createState() => _ThoughtViewState();
}

class _ThoughtViewState extends State<ThoughtView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final style = theme
        .ui(theme.t.textMuted, size: 12.5)
        .copyWith(fontStyle: FontStyle.italic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(
                _open ? Icons.expand_more : Icons.chevron_right,
                size: 14,
                color: theme.t.textMuted,
              ),
              Text(widget.live ? 'Thinking…' : 'Thought', style: style),
              if (widget.live)
                const SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
            ],
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(left: 6, top: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.t.borderStrong, width: 2),
              ),
            ),
            child: Text(widget.item.text, style: style),
          ),
      ],
    );
  }
}

/// The agent's plan as a checklist, ticked off as the agent works.
class PlanView extends StatelessWidget {
  const PlanView(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final done = item.plan.where((e) => e.status == 'completed').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: box(t.borderSubtle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            'Plan · $done of ${item.plan.length} done',
            style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
          ),
          for (final e in item.plan)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: switch (e.status) {
                    'completed' => Icon(
                      Icons.check_circle,
                      size: 14,
                      color: t.done,
                    ),
                    'in_progress' => Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: t.running,
                    ),
                    _ => Icon(
                      Icons.radio_button_unchecked,
                      size: 14,
                      color: t.textMuted,
                    ),
                  },
                ),
                Expanded(
                  child: Text(
                    e.content,
                    style: switch (e.status) {
                      'completed' => theme.ui(t.textMuted),
                      'in_progress' => theme.ui(
                        t.text,
                        weight: FontWeight.w600,
                      ),
                      _ => theme.ui(t.text),
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The current step of the turn's plan, one line above the composer while
/// the agent works, as the plan itself may have scrolled away.
class PlanStatus extends StatelessWidget {
  const PlanStatus(this.plan, {super.key});

  final Item plan;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final entries = plan.plan;
    final done = entries.where((e) => e.status == 'completed').length;
    final now = entries.where((e) => e.status == 'in_progress').firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.checklist, size: 14, color: t.textSecondary),
          Text(
            '$done/${entries.length}',
            style: theme.ui(t.textSecondary, size: 12),
          ),
          if (now != null)
            Expanded(
              child: Text(
                now.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// The plan of the current turn (since the last prompt), if any.
Item? turnPlan(List<Item> items) {
  for (final it in items.reversed) {
    if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE) return null;
    if (it.kind == ItemKind.ITEM_KIND_PLAN) return it;
  }
  return null;
}
