import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Where a reopened chat's history comes from changes (ADR 0047): above
/// it, Nushi's copy alone. A compaction's ("compacted": the agent kept
/// only a summary of what came before, which a click shows), or a divider
/// where the agent's history differs from the copy ("history_differs").
class HistoryMark extends StatefulWidget {
  const new(this.item, {required this.agent, super.key});

  final Item item;

  /// The agent's name, as people read it.
  final String agent;

  @override
  State<HistoryMark> createState() => _HistoryMarkState();
}

class _HistoryMarkState extends State<HistoryMark> {
  bool _open = false; // the summary shows

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final item = widget.item;
    final compacted = item.status == 'compacted';
    final summary = compacted && item.text.isNotEmpty;
    final label = compacted ? item.title : item.text;
    final rule = Expanded(child: Container(height: 1, color: t.borderSubtle));
    final style = theme.ui(t.textMuted, size: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            rule,
            Tap(
              onTap: summary ? () => setState(() => _open = !_open) : null,
              tooltip: compacted
                  ? 'Above: Nushi’s copy. ${widget.agent} kept only a '
                        'summary of it.'
                  : 'Above: Nushi’s copy. From here: ${widget.agent}’s '
                        'history.',
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 5,
                children: [
                  Icon(
                    compacted ? Icons.compress : Icons.call_split,
                    size: 13,
                    color: t.textMuted,
                  ),
                  Text(label, style: style),
                  if (summary)
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: t.textMuted,
                    ),
                ],
              ),
            ),
            rule,
          ],
        ),
        if (_open)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: box(t.borderSubtle, fill: t.base),
            child: AgentMarkdown(item.text),
          ),
      ],
    );
  }
}
