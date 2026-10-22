import 'dart:async';

import 'package:flutter/material.dart';

import 'chat.dart';
import 'theme/theme.dart';

enum ButtonKind {
  /// The one main action: accent fill.
  primary,

  /// Outlined.
  secondary,

  /// A quiet toolbar action: no chrome.
  ghost,

  /// Stop: outlined in red.
  danger,
}

/// A compact button with an optional leading [icon] and a shortcut [hint]
/// after the label.
class Button extends StatelessWidget {
  const Button({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = ButtonKind.secondary,
    this.icon,
    this.hint,
    this.height = 26,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final IconData? icon;
  final String? hint;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final enabled = onPressed != null;
    final (Color? bg, Color fg, Color? border) = switch (kind) {
      ButtonKind.primary => (t.accent, t.onAccent, null),
      ButtonKind.secondary => (null, t.text, t.borderStrong),
      ButtonKind.ghost => (null, t.textSecondary, null),
      ButtonKind.danger => (null, t.crashed, t.crashed),
    };
    final color = enabled ? fg : t.textMuted;
    final style = theme.ui(
      color,
      weight: kind == ButtonKind.primary ? FontWeight.w500 : null,
    );
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, height)),
        fixedSize: WidgetStatePropertyAll(Size.fromHeight(height)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStatePropertyAll(
          enabled ? bg : (bg == null ? null : t.selected),
        ),
        foregroundColor: WidgetStatePropertyAll(color),
        overlayColor: WidgetStatePropertyAll(t.text.withValues(alpha: 0.06)),
        shape: WidgetStateProperty.resolveWith(
          (states) => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NushiTheme.control),
            side: states.contains(WidgetState.focused)
                ? BorderSide(color: t.focus, width: 2)
                : border == null
                ? BorderSide.none
                : BorderSide(color: enabled ? border : t.borderSubtle),
          ),
        ),
        textStyle: WidgetStatePropertyAll(style),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(width: 6),
            KeyHint(
              hint!,
              color: enabled && kind == ButtonKind.primary
                  ? t.onAccent
                  : t.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

/// A shortcut in small monospace (`⏎`).
class KeyHint extends StatelessWidget {
  const KeyHint(this.keys, {super.key, this.color});

  final String keys;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Text(keys, style: theme.code(color ?? theme.t.textMuted, size: 11));
  }
}

/// A chat's status dot: amber with a soft ring while it waits on the user,
/// filled while the agent works, a ring when idle.
class ChatDot extends StatelessWidget {
  const ChatDot({super.key, required this.chat, this.size = 7});

  final ChatState chat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return DecoratedBox(
      decoration: chat.waiting
          ? BoxDecoration(
              color: t.needs,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: t.needsSoft, spreadRadius: 2)],
            )
          : chat.busy
          ? BoxDecoration(color: t.running, shape: BoxShape.circle)
          : BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.idle, width: 1.5),
            ),
      child: SizedBox.square(dimension: size),
    );
  }
}

/// What a chat is doing, in a word: "needs you", "working · 12s" (ticking)
/// or "idle".
class ChatStatusWord extends StatefulWidget {
  const ChatStatusWord(this.chat, {super.key, this.style});

  final ChatState chat;
  final TextStyle? style;

  @override
  State<ChatStatusWord> createState() => _ChatStatusWordState();
}

class _ChatStatusWordState extends State<ChatStatusWord> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.chat.started != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final started = chat.started;
    final (word, color) = chat.waiting
        ? ('needs you', t.needs)
        : started != null
        ? (
            'working · ${_elapsed(DateTime.now().difference(started))}',
            t.running,
          )
        : chat.busy
        ? ('working', t.running)
        : ('idle', t.idle);
    return Text(
      word,
      style: (widget.style ?? theme.ui(t.text, size: 12)).copyWith(
        color: color,
      ),
    );
  }

  static String _elapsed(Duration d) => d.inMinutes == 0
      ? '${d.inSeconds}s'
      : '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
}

/// The agent's monogram: its letter on its color.
class AgentMonogram extends StatelessWidget {
  const AgentMonogram({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.claude,
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: Text(
        'C',
        style: TextStyle(
          fontFamily: NushiTheme.uiFont,
          fontSize: size * 0.64,
          height: 1,
          fontWeight: FontWeight.w600,
          color: t.monogramText,
        ),
      ),
    );
  }
}

/// One choice of a few (`Chat | Changes`).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.base,
        border: Border.all(color: t.borderSubtle),
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, text) in segments)
            TextButton(
              onPressed: () => onChanged(v),
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 20)),
                fixedSize: const WidgetStatePropertyAll(Size.fromHeight(20)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: WidgetStatePropertyAll(
                  v == value ? t.selected : null,
                ),
                shape: const WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(NushiTheme.control),
                    ),
                  ),
                ),
              ),
              child: Text(
                text,
                style: theme.ui(
                  v == value ? t.text : t.textSecondary,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
