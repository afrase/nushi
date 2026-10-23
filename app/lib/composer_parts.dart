import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'theme/theme.dart';

/// Stops the chat's running turn.
Future<void> stopTurn(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  if (chat.started == null) return;
  try {
    await daemon.cancelTurn(chat.id);
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
class BoxButton extends StatelessWidget {
  const BoxButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 500),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox.square(dimension: 28, child: Center(child: child)),
    ),
  );
}

/// Stop: a filled square in a circle, like a media player's.
class StopIcon extends StatelessWidget {
  const StopIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.5),
    ),
    child: Container(width: 6, height: 6, color: color),
  );
}

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
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.base,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in choices.indexed)
            Material(
              color: i == picked ? t.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(NushiTheme.control),
              child: InkWell(
                onTap: () => onPick(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
              ),
            ),
        ],
      ),
    );
  }
}

/// The prompt box's "+" menu, above [button]: "file" to mention a file, or
/// "image" to attach images (unavailable unless the agent takes [images]).
Future<String?> plusMenu(BuildContext button, {required bool images}) {
  final theme = NushiTheme.of(button);
  final t = theme.t;
  final box = button.findRenderObject()! as RenderBox;
  final at = box.localToGlobal(Offset.zero);
  return showMenu<String>(
    context: button,
    position: RelativeRect.fromLTRB(at.dx, at.dy - 76, at.dx, at.dy),
    items: [
      PopupMenuItem(
        value: 'file',
        height: 30,
        child: Text('Mention a file', style: theme.ui(t.text)),
      ),
      PopupMenuItem(
        value: 'image',
        height: 30,
        enabled: images,
        child: Tooltip(
          message: images ? '' : 'Claude doesn’t take images in this chat',
          child: Text('Image…', style: theme.ui(images ? t.text : t.textMuted)),
        ),
      ),
    ],
  );
}
