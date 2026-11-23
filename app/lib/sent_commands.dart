import 'package:flutter/material.dart';
import 'package:nushi/run_text.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A command a user message carried ([splitCommands]), in its bubble: a
/// chevron, `! cmd` in code type and its exit (a failed one a red pill),
/// its output folded under it until the row is clicked. Claude Code's own
/// two messages of a `!` show as two: the command alone, then "Output"
/// with its own.
class SentCommandCard extends StatefulWidget {
  const new(this.command, {super.key});

  final SentCommand command;

  @override
  State<SentCommandCard> createState() => _SentCommandCardState();
}

class _SentCommandCardState extends State<SentCommandCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = widget.command;
    final output = c.output;
    // design: off the type scale, to move to a step
    final code = theme.code(t.userBandText, size: 12.5);
    // design: off the type scale, to move to a step
    final muted = theme.code(t.userBandMuted, size: 12.5);
    final lines = c.command.split('\n');
    final head = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        if (output != null)
          Icon(
            _open ? Icons.expand_more : Icons.chevron_right,
            size: 15,
            color: t.userBandMuted,
          ),
        if (c.command.isEmpty)
          // design: off the type scale, to move to a step
          Text('Output', style: theme.ui(t.userBandMuted, size: 12.5))
        else
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '! ', style: muted),
                  TextSpan(text: _open ? c.command : lines.first),
                  if (!_open && lines.length > 1)
                    TextSpan(text: ' …', style: muted),
                ],
              ),
              maxLines: _open ? null : 1,
              softWrap: _open,
              overflow: _open ? null : TextOverflow.ellipsis,
              style: code,
            ),
          ),
        if (c.exit == 0)
          Text('exit 0', style: theme.ui(t.userBandMuted, size: 12))
        else if (c.exit case final exit?)
          NotePill('exit $exit', tone: NoteTone.crashed),
      ],
    );
    return DecoratedBox(
      key: const ValueKey('sent-command'),
      decoration: BoxDecoration(
        color: t.userBandCodeBlock,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (output == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: head,
            )
          else
            Tap(
              tooltip: _open ? 'Hide its output' : 'Show its output',
              onTap: () => setState(() => _open = !_open),
              padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
              child: head,
            ),
          if (_open && output != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 0, 10, 8),
              child: Text(
                output.isEmpty ? 'No output' : output,
                style: output.isEmpty ? muted : code,
              ),
            ),
        ],
      ),
    );
  }
}
