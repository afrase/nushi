import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

/// One clock for every moving mark: a phase from 0 to 1 and back, every
/// 1.6 seconds. It ticks only while a mark listens, and the marks paint
/// from it without rebuilding anything.
class _Pulse extends ChangeNotifier {
  Ticker? _ticker;
  double value = 0;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _ticker ??= Ticker((t) {
      value = (1 - cos(t.inMilliseconds / 1600 * 2 * pi)) / 2;
      notifyListeners();
    })..start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _ticker?.dispose();
      _ticker = null;
    }
  }
}

final _pulse = _Pulse();

/// Whether macOS asks for reduced motion.
bool _still(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

/// A dot of [color]; with [pulse] it breathes, a soft ring growing out of
/// it.
class _Mark extends CustomPainter {
  new(this.color, {required this.pulse})
    : super(repaint: pulse ? _pulse : null);

  final Color color;
  final bool pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final v = pulse ? _pulse.value : 0.0;
    if (pulse) {
      canvas.drawCircle(
        c,
        r * (0.55 + 0.45 * v),
        Paint()..color = color.withValues(alpha: 0.35 * (1 - v)),
      );
    }
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()..color = color.withValues(alpha: 1 - 0.35 * v),
    );
  }

  @override
  bool shouldRepaint(_Mark old) => old.color != color || old.pulse != pulse;
}

/// A chat's status dot: amber with a soft ring while it waits on the user,
/// breathing while the agent works, a ring when idle.
class ChatDot extends StatelessWidget {
  const new({required this.chat, super.key});

  static const size = 7.0;

  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    if (chat.asleep && !chat.archived) {
      return Icon(Icons.bedtime_outlined, size: size * 1.6, color: t.idle);
    }
    if (chat.busy && !chat.waiting) {
      return CustomPaint(
        size: const Size.square(size * 1.6),
        painter: _Mark(t.running, pulse: !_still(context)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(size * 0.3),
      child: DecoratedBox(
        decoration: chat.waiting
            ? BoxDecoration(
                color: t.needs,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: t.needsSoft, spreadRadius: 2)],
              )
            : BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.idle, width: 1.5),
              ),
        child: const SizedBox.square(dimension: size),
      ),
    );
  }
}

/// What a chat is doing, in a word: "needs you", "working", "asleep" or
/// "idle".
class ChatStatusWord extends StatelessWidget {
  const new(this.chat, {required this.style, super.key});

  final ChatState chat;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final (word, color) = chat.waiting
        ? ('needs you', t.needs)
        : chat.busy
        ? ('working', t.running)
        : chat.asleep
        ? ('asleep', t.idle)
        : ('idle', t.idle);
    return Text(word, style: style.copyWith(color: color));
  }
}

/// Under the transcript while a turn runs, as in Claude Code: a breathing
/// mark, what the agent is doing ([doing]), and for how long; "Waiting for
/// you" while a permission prompt or question waits. [what] overrides it.
class TurnStatus extends StatefulWidget {
  const new(this.chat, {super.key, this.what});

  final ChatState chat;
  final String? what;

  @override
  State<TurnStatus> createState() => _TurnStatusState();
}

class _TurnStatusState extends State<TurnStatus> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.chat.started != null) setState(() {});
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
    final chat = widget.chat;
    final waiting = chat.waiting && widget.what == null;
    final started = chat.started;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 20, 2),
      child: Row(
        spacing: 8,
        children: [
          CustomPaint(
            size: const Size.square(12),
            painter: _Mark(
              waiting ? t.needs : t.accent,
              pulse: !waiting && !_still(context),
            ),
          ),
          Flexible(
            child: Text(
              widget.what ?? (waiting ? 'Waiting for you' : doing(chat.items)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(waiting ? t.needs : t.textSecondary, size: 12.5),
            ),
          ),
          if (started != null && !waiting)
            Text(
              elapsed(DateTime.now().difference(started)),
              style: theme.ui(t.textMuted, size: 12),
            ),
        ],
      ),
    );
  }
}

/// "12s", "1m 04s".
String elapsed(Duration d) => d.inMinutes == 0
    ? '${d.inSeconds}s'
    : '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';

/// What the agent is doing now, from what it reported last in the turn: a
/// running tool call ("Reading notes.md", "Running make test"), else
/// "Writing" while its message is the last thing, else "Thinking".
String doing(List<Item> items) {
  final turn = items.reversed.takeWhile(
    (it) => it.kind != ItemKind.ITEM_KIND_USER_MESSAGE,
  );
  final running = turn
      .where(
        (it) =>
            it.kind == ItemKind.ITEM_KIND_TOOL_CALL &&
            (it.status == 'pending' || it.status == 'in_progress'),
      )
      .firstOrNull;
  if (running != null) {
    final path = running.paths.firstOrNull ?? running.diffs.firstOrNull?.path;
    final verb = kindOf(running).doing;
    return switch ((verb, path)) {
      _ when running.toolKind == 'execute' => 'Running ${running.title}',
      (final v?, final p?) => '$v $p',
      (final v?, null) => v,
      _ => running.title,
    };
  }
  return turn.firstOrNull?.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE
      ? 'Writing'
      : 'Thinking';
}
