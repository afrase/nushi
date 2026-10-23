import 'dart:async';

import 'package:flutter/material.dart';

import 'chat.dart';
import 'theme/theme.dart';

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
    final theme = NushiTheme.of(context), t = theme.t;
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
