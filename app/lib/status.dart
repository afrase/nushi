import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

/// A dot of [color]; [ringing], a soft ring grows out of it and fades,
/// again every 1.6 seconds, from the shared clock.
class _Mark extends CustomPainter {
  new(this.color, {required this.ringing})
    : super(repaint: ringing ? loopClock : null);

  final Color color;
  final bool ringing;

  static const period = Duration(milliseconds: 1600);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.55;
    if (ringing) {
      final v = Curves.easeOut.transform(loopClock.phase(period));
      canvas.drawCircle(
        c,
        r * (1 + 1.6 * v),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.7 * (1 - v)),
      );
    }
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Mark old) => old.color != color || old.ringing != ringing;
}

/// A check drawn [drawn] of the way, at [opacity].
class _Check extends CustomPainter {
  new(this.color, this.drawn, this.opacity);

  final Color color;
  final double drawn;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 10;
    final path = Path()
      ..moveTo(1.5 * s, 5.2 * s)
      ..lineTo(4 * s, 7.5 * s)
      ..lineTo(8.5 * s, 2.5 * s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: opacity);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * drawn), paint);
    }
  }

  @override
  bool shouldRepaint(_Check old) =>
      old.color != color || old.drawn != drawn || old.opacity != opacity;
}

/// A chat's status dot: amber with a soft ring while it waits on the user
/// (it hops once when that starts), a ring growing out of it while the
/// agent works, a ring when idle (a check draws itself there for a moment
/// when a turn ends), solid green while a turn's end is unseen (the check
/// settles into it); a moon asleep, a quiet clock when its agent deleted
/// its session, an error mark when it couldn't start.
class ChatDot extends StatefulWidget {
  const new({required this.chat, super.key});

  static const size = 7.0;

  final ChatState chat;

  @override
  State<ChatDot> createState() => _ChatDotState();
}

class _ChatDotState extends State<ChatDot> with TickerProviderStateMixin {
  late bool _busy = widget.chat.busy;
  late bool _waiting = widget.chat.waiting;
  late bool _stopped = widget.chat.stopping; // the user stopped the turn
  late bool? _unseen = widget.chat.unseen;
  AnimationController? _hop; // once, as the chat starts waiting
  AnimationController? _check; // drawn, held, then the ring again

  static const _hopFor = Duration(milliseconds: 1200);
  static const _checkFor = Duration(milliseconds: 2700);

  // The hop: up 3 px, down, up 1.5, down, still.
  static final Animatable<double> _rise = TweenSequence([
    for (final (from, to, weight) in const [
      (0.0, 3.0, 20.0),
      (3.0, 0.0, 20.0),
      (0.0, 1.5, 15.0),
      (1.5, 0.0, 15.0),
      (0.0, 0.0, 30.0),
    ])
      TweenSequenceItem(
        tween: Tween(
          begin: from,
          end: to,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: weight,
      ),
  ]);

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChatDot old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat) return;
    old.chat.removeListener(_changed);
    widget.chat.addListener(_changed);
    _busy = widget.chat.busy;
    _waiting = widget.chat.waiting;
    _unseen = widget.chat.unseen;
    _hop?.value = 1;
    _check?.value = 1;
  }

  @override
  void dispose() {
    widget.chat.removeListener(_changed);
    _hop?.dispose();
    _check?.dispose();
    super.dispose();
  }

  AnimationController _once(Duration d) =>
      AnimationController(vsync: this, duration: d)..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) setState(() {});
      });

  void _changed() {
    final c = widget.chat;
    if (c.busy && !_busy) {
      _stopped = false;
      _check?.value = 1; // a new turn: the check goes
    }
    if (c.stopping) _stopped = true;
    if (c.waiting && !_waiting && !reduceMotion(context)) {
      (_hop ??= _once(_hopFor)).forward(from: 0).ignore();
    }
    if (_busy && !c.busy && !c.waiting && !_stopped) {
      (_check ??= _once(_checkFor)).forward(from: 0).ignore();
    }
    // Every streamed chunk notifies: only a change of state rebuilds.
    if (c.busy == _busy && c.waiting == _waiting && c.unseen == _unseen) {
      return;
    }
    _busy = c.busy;
    _waiting = c.waiting;
    _unseen = c.unseen;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const size = ChatDot.size;
    final t = NushiTheme.of(context).t;
    final chat = widget.chat;
    // An unseen end shows through sleep: the user hasn't seen it yet.
    final unseen = (chat.unseen ?? false) && !chat.archived && !chat.waiting;
    if (chat.asleep && !chat.archived && !unseen) {
      return Icon(Icons.bedtime_outlined, size: size * 1.6, color: t.idle);
    }
    if (chat.sessionGone && !chat.archived) {
      return Icon(Icons.history_toggle_off, size: size * 1.6, color: t.idle);
    }
    if (chat.reopenFailed && !chat.archived) {
      return Icon(Icons.error_outline, size: size * 1.6, color: t.crashed);
    }
    final still = reduceMotion(context);
    if (chat.busy && !chat.waiting) {
      return CustomPaint(
        size: const Size.square(size * 1.6),
        painter: _Mark(t.running, ringing: !still),
      );
    }
    final done = Padding(
      padding: const EdgeInsets.all(size * 0.3),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.done, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: size),
      ),
    );
    if (_check case final check? when check.isAnimating && !chat.waiting) {
      return AnimatedBuilder(
        animation: check,
        builder: (context, _) {
          final ms = check.value * _checkFor.inMilliseconds;
          final out = still ? 0.0 : ((ms - 2400) / 300).clamp(0.0, 1.0);
          final mark = CustomPaint(
            size: const Size.square(size * 1.6),
            painter: _Check(
              t.done,
              still ? 1 : Curves.easeOut.transform((ms / 350).clamp(0, 1)),
              1 - out,
            ),
          );
          // Unseen, the check settles into the green dot as it fades.
          if (!unseen) return mark;
          return Stack(
            children: [
              Opacity(opacity: out, child: done),
              mark,
            ],
          );
        },
      );
    }
    if (unseen) return done;
    final dot = Padding(
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
    final hop = _hop;
    if (hop == null || !chat.waiting) return dot;
    return AnimatedBuilder(
      animation: hop,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -_rise.transform(hop.value)),
        child: child,
      ),
      child: dot,
    );
  }
}

/// What a chat is doing, in a word: "needs you", "working", "asleep",
/// "expired" (its agent deleted its session), "couldn't start" (its reopen
/// failed) or "idle".
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
        : chat.sessionGone
        ? ('expired', t.idle)
        : chat.reopenFailed
        ? ("couldn't start", t.crashed)
        : ('idle', t.idle);
    return Text(word, style: style.copyWith(color: color));
  }
}

/// Under the transcript while a turn runs, as in Claude Code: a mark, what
/// the agent is doing ([doing]), shining, and for how long; "Waiting for
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
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
            painter: _Mark(waiting ? t.needs : t.accent, ringing: false),
          ),
          Flexible(
            child: Shine(
              on: !waiting,
              child: Text(
                widget.what ??
                    (waiting ? 'Waiting for you' : doing(chat.items)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(
                  waiting ? t.needs : t.textSecondary,
                  size: 12.5,
                ),
              ),
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
  if (running != null) return doingOf(running);
  return turn.firstOrNull?.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE
      ? 'Writing'
      : 'Thinking';
}
