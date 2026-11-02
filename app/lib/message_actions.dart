import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Room under a message for its actions, kept while they don't show, so
/// nothing moves as the pointer passes.
const messageActionsHeight = 28.0;

/// A message with what can be done to it in a row under it, on hover: at
/// its right under [end] (the user's), at its left otherwise.
class MessageActions extends StatelessWidget {
  const new({
    required this.child,
    required this.actions,
    super.key,
    this.end = false,
  });

  final Widget child;
  final List<Widget> Function() actions;
  final bool end;

  @override
  Widget build(BuildContext context) => Hover(
    builder: (context, {required hover}) => Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.stretch,
      children: [
        child,
        // On hover only: a find's count doesn't change as the pointer passes.
        Unmarked(
          child: SizedBox(
            height: messageActionsHeight,
            child: hover
                ? Row(
                    mainAxisAlignment: end
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    spacing: NushiTheme.iconGap,
                    children: actions(),
                  )
                : null,
          ),
        ),
      ],
    ),
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// [at] as a date and time: "Nov 1, 2026, 8:45 AM".
String fullTime(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '${_months[at.month - 1]} ${at.day}, ${at.year}, '
      '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
}

/// How long ago a message was sent ([ms], since the epoch), the date and
/// time under the pointer.
class MessageTime extends StatelessWidget {
  const new(this.ms, {super.key});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Tooltip(
      message: fullTime(DateTime.fromMillisecondsSinceEpoch(ms)),
      child: Text(
        agoAt(ms, clock()),
        style: theme.ui(theme.t.textMuted, size: 12),
      ),
    );
  }
}

/// Whether the agent has read a message: one check while it's only sent,
/// two once something of the agent's follows it.
class ReadMark extends StatelessWidget {
  const new({required this.read, required this.agent, super.key});

  final bool read;
  final String agent;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: read ? 'Read by $agent' : 'Sent',
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        read ? Icons.done_all : Icons.done,
        size: 15,
        color: NushiTheme.of(context).t.textMuted,
      ),
    ),
  );
}

/// Copy, for [text] as the message has it.
class CopyAction extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => IconTap(
    Icons.content_copy,
    size: 15,
    color: NushiTheme.of(context).t.textMuted,
    tooltip: 'Copy as Markdown',
    onTap: () => tryOrShow(context, () async {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showError(context, 'Copied');
    }),
  );
}
