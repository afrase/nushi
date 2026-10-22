import 'package:flutter/material.dart';

import 'theme/theme.dart';

/// A completion offered while typing: a slash command or a file.
typedef Choice = ({String label, String detail, String insert});

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
