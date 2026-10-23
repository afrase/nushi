import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// Stops the chat's running turn.
Future<void> stopTurn(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  if (chat.started != null) {
    await tryOrShow(
      context,
      () => daemon.client.cancelTurn(CancelTurnRequest(chatId: chat.id)),
    );
  }
}

/// A completion offered while typing: a slash command or a file.
typedef Choice = ({String label, String detail, String insert});

/// The names holding [q], those whose last part starts with it first,
/// then the shortest.
List<String> rankChoices(Iterable<String> names, String q) {
  q = q.toLowerCase();
  final hits = [
    for (final n in names)
      if (n.toLowerCase().contains(q)) n,
  ];
  int score(String n) =>
      (n.split(RegExp('[/:]')).last.toLowerCase().startsWith(q) ? 0 : 1000) +
      n.length;
  hits.sort((a, b) => score(a) - score(b));
  return hits.take(8).toList();
}

/// A small round icon button inside the prompt box.
Widget boxButton(String tooltip, VoidCallback onPressed, Widget child) => Tap(
  tooltip: tooltip,
  onTap: onPressed,
  radius: 14,
  child: SizedBox.square(dimension: 28, child: Center(child: child)),
);

/// Stop: a filled square in a circle, like a media player's.
Widget stopIcon(Color color) => Container(
  width: 16,
  height: 16,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: color, width: 1.5),
  ),
  child: Container(width: 6, height: 6, color: color),
);

/// The completions over the prompt box, the picked one highlighted.
class ChoiceList extends StatelessWidget {
  const ChoiceList(
    this.choices,
    this.picked, {
    super.key,
    required this.onPick,
  });

  final List<Choice> choices;
  final int picked;
  final void Function(Choice) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: box(t.borderStrong, fill: t.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in choices.indexed)
            Tap(
              onTap: () => onPick(c),
              selected: i == picked,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: c.label,
                      style: theme.code(t.text, size: 12.5),
                    ),
                    if (c.detail.isNotEmpty)
                      TextSpan(
                        text: '   ${c.detail}',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
