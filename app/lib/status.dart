import 'package:flutter/material.dart';
import 'package:nushi/background_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/usage.dart';

/// A dot of [color]; [ringing], a soft ring grows out of it and fades,
/// again every 1.6 seconds, from the shared clock. Given [halo], the dot
/// sits in a soft disc of it, half the dot wider all round (a plan's
/// running step). A ring repaints with what its widget's
/// [loopRepaintOf] gives.
class StatusMark extends CustomPainter {
  new(this.color, {this.ringing = false, this.halo, Listenable? repaint})
    : super(repaint: ringing ? repaint : null);

  final Color color;
  final bool ringing;
  final Color? halo;

  // design: a loop's beat, on pulseClock
  static const period = Duration(milliseconds: 1600);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.55;
    if (halo case final halo?) {
      canvas.drawCircle(c, r * 1.9, Paint()..color = halo);
    }
    if (ringing && loopMoving) {
      final v = Curves.easeOut.transform(loopPhase(period));
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
  bool shouldRepaint(StatusMark old) =>
      old.color != color || old.ringing != ringing || old.halo != halo;
}

/// What a running row with no state words has where [TaskMark] is (a phase
/// on a workflow's card, an agent in its pane, a Worktrees row whose
/// subagent or run runs, there as [TaskMark.dot]): the running dot,
/// [TaskMark.size] square. A
/// subagent's row in the transcript has none: its words shine instead.
class RunningDot extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(TaskMark.size),
    painter: StatusMark(NushiTheme.of(context).t.running),
  );
}

/// A chat's status dot: amber, a size up, with a soft ring while it waits
/// on the user (it hops once when that starts), a ring growing out of it
/// while the agent works, a ring when idle (a check draws itself there for
/// a moment when a turn is done), solid green while a turn's end is unseen
/// (the check settles into it); two dots side by side that now and then
/// spin as droplets, merge and split ([BackgroundMark]) while subagents
/// or commands run in the background after the turn; nothing
/// asleep (an empty slot of the same size, so titles stay in line: a
/// sleeping chat recedes, its title muted where it's listed, rather than
/// wear a mark that reads like the idle ring), a quiet clock when its
/// agent deleted its session, an error mark when it couldn't start.
/// With [sparks], a turn you watched end (after [Sparks.after] or more,
/// Nushi in front) sends sparks out of its check.
class ChatDot extends StatefulWidget {
  const new({required this.chat, super.key, this.sparks = false});

  static const size = 7.0;

  final ChatState chat;
  final bool sparks;

  @override
  State<ChatDot> createState() => _ChatDotState();
}

class _ChatDotState extends State<ChatDot> with TickerProviderStateMixin {
  late bool _busy = widget.chat.busy;
  late bool _waiting = widget.chat.needsYou;
  late ChatPhase _phase = widget.chat.phase;
  AnimationController? _hop; // once, as the chat starts waiting
  AnimationController? _check; // drawn, held, then the ring again
  bool _sparks = false; // the check's sparks fly

  // design: how long a state shows, not motion
  static const _checkFor = Duration(milliseconds: 2700);

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
    _waiting = widget.chat.needsYou;
    _phase = widget.chat.phase;
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
    if (c.busy && !_busy) _check?.value = 1; // a new turn: the check goes
    if (c.needsYou && !_waiting && !reduceMotion(context)) {
      (_hop ??= _once(hopFor)).forward(from: 0).ignore();
    }
    // A done turn's check only, as the daemon judged it: a check reads as
    // success, wrong for a failure (its alert and notice say so) and a
    // stop.
    if (_busy && !c.busy && c.ended == .TURN_END_DONE && !c.needsYou) {
      _sparks = widget.sparks && sparksFor(c.lastTurn ?? Duration.zero);
      (_check ??= _once(_checkFor)).forward(from: 0).ignore();
    }
    // Usage, config and items notify too: only a change of state rebuilds.
    if (c.busy == _busy && c.needsYou == _waiting && c.phase == _phase) {
      return;
    }
    _busy = c.busy;
    _waiting = c.needsYou;
    _phase = c.phase;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const size = ChatDot.size;
    final t = NushiTheme.of(context).t;
    final chat = widget.chat;
    final phase = chat.phase;
    // An unseen end shows through sleep: the user hasn't seen it yet.
    final isDone = phase == .done;
    final still = reduceMotion(context);
    switch (phase) {
      case .asleep:
        return const SizedBox.square(dimension: size * 1.6);
      case .expired:
        return Icon(Icons.history_toggle_off, size: size * 1.6, color: t.idle);
      case .failed:
        return Icon(Icons.error_outline, size: size * 1.6, color: t.crashed);
      case .working:
        final mark = _mark(
          StatusMark(
            t.running,
            ringing: !still,
            repaint: loopRepaintOf(context),
          ),
        );
        // A turn needs no words; work the user didn't start does.
        return chat.busy ? mark : tooltip(context, workingWords(chat), mark);
      case .background:
        return tooltip(
          context,
          backgroundWords(chat.background),
          _mark(
            BackgroundMark(
              t.running,
              t: still ? 0 : null,
              repaint: still ? null : BackgroundMark.repaintOf(context),
            ),
          ),
        );
      case .archived || .waiting || .done || .fresh || .idle:
        break;
    }
    final doneDot = _dot(fill: t.done);
    if (_check case final check? when check.isAnimating && !chat.needsYou) {
      return AnimatedBuilder(
        animation: check,
        builder: (context, _) {
          final ms = check.value * _checkFor.inMilliseconds;
          final out = still ? 0.0 : ((ms - 2400) / 300).clamp(0.0, 1.0);
          final mark = _mark(
            CheckPainter(
              t.done,
              still ? 1 : Curves.easeOut.transform((ms / 350).clamp(0, 1)),
              1 - out,
              sparks: _sparks && !still
                  ? Sparks(
                      ms,
                      color: t.done,
                      band: t.shineBand,
                      seed: chat.id.hashCode,
                    )
                  : null,
            ),
          );
          // Unseen, the check settles into the green dot as it fades.
          if (!isDone) return mark;
          return Stack(
            children: [
              Opacity(opacity: out, child: doneDot),
              mark,
            ],
          );
        },
      );
    }
    if (isDone) return doneDot;
    final dot = chat.needsYou ? _waitingDot(t) : _dot(ring: t.idle);
    final hop = _hop;
    if (hop == null || !chat.needsYou) return dot;
    return AnimatedBuilder(
      animation: hop,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -hopHeight(hop.value)),
        child: child,
      ),
      child: dot,
    );
  }
}

/// Whether [chat]'s title recedes where it's listed: asleep, with no
/// unseen end to show ([ChatDot] draws nothing for it).
bool recedes(ChatState chat) => chat.phase == .asleep;

/// What a receding row's title and agent mark are drawn in: muted, and
/// half as strong again, so a sleeping chat can't be taken for an idle
/// one (the owner, 2026-11-19: muted alone, "I can't tell the
/// difference"). Its title is italic too ([recededTitle]).
Color recededColor(Tokens t) => t.textMuted.withValues(alpha: 0.5);

/// [style] as a receding row's title wears it: [recededColor], italic.
TextStyle recededTitle(TextStyle style, Tokens t) =>
    style.copyWith(color: recededColor(t), fontStyle: FontStyle.italic);

/// The moon beside "Asleep" in words (the chat's header), [ChatDot]'s
/// size: a list's sleeping row has no mark, only a muted title.
class SleepMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Icon(
    Icons.bedtime_outlined,
    size: ChatDot.size * 1.6,
    color: NushiTheme.of(context).t.idle,
  );
}

/// "Working in the background: 2 background tasks" (subagents, commands
/// and stalled workflows).
String backgroundWords(int n) =>
    'Working in the background: $n background '
    '${n == 1 ? 'task' : 'tasks'}';

/// Why a chat with no turn of the user's running counts as working: a
/// workflow runs (ADR 0127), or the agent works on its own.
String workingWords(ChatState chat) => chat.workflows > 0
    ? chat.workflows == 1
          ? 'Running a workflow'
          : 'Running ${chat.workflows} workflows'
    : 'Working on its own, after a background task';

/// [painter]'s mark in a chat's dot's room.
Widget _mark(CustomPainter painter) =>
    CustomPaint(size: const Size.square(ChatDot.size * 1.6), painter: painter);

/// A chat's dot in its room: of [fill], or a ring of [ring].
Widget _dot({Color? fill, Color? ring}) => Padding(
  padding: const EdgeInsets.all(ChatDot.size * 0.3),
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: ring == null ? null : Border.all(color: ring, width: 1.5),
    ),
    child: const SizedBox.square(dimension: ChatDot.size),
  ),
);

/// The dot of a chat that needs the user: a size up from the others, in a
/// wider soft ring, in the same room.
Widget _waitingDot(Tokens t) => Padding(
  padding: const EdgeInsets.all(ChatDot.size * 0.3 - 0.5),
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: t.needs,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: t.needsSoft, spreadRadius: 3)],
    ),
    child: const SizedBox.square(dimension: ChatDot.size + 1),
  ),
);

/// The most urgent state among [chats], as a collapsed group shows it:
/// waiting on the user, then working, then working in the background,
/// then a turn's end unseen; null when none is (all idle, asleep, new…).
ChatPhase? groupPhase(Iterable<ChatState> chats) {
  const order = <ChatPhase>[.waiting, .working, .background, .done];
  ChatPhase? most;
  for (final c in chats) {
    final i = order.indexOf(c.phase);
    if (i >= 0 && (most == null || i < order.indexOf(most))) most = c.phase;
  }
  return most;
}

/// [phase] (waiting, working, in the background or unseen) as a still
/// [ChatDot] draws it, its word on hover: a collapsed group's summary.
class PhaseDot extends StatelessWidget {
  const new(this.phase, {super.key});

  final ChatPhase phase;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final (word, color) = phaseWord(phase, t);
    return tooltip(context, word, switch (phase) {
      .working => _mark(
        StatusMark(
          color,
          ringing: !reduceMotion(context),
          repaint: loopRepaintOf(context),
        ),
      ),
      .background => _mark(BackgroundMark(color, t: 0)),
      .waiting => _waitingDot(t),
      _ => _dot(fill: color),
    });
  }
}

/// A chat's [ChatPhase] in a word, and its color: the same on the Mac and
/// the phone. "done" is a turn's end not yet seen; "in background", a turn
/// that ended while subagents or commands it started still run (not
/// "idle": the user would take it as done); "expired", a chat whose agent
/// deleted its session; "couldn't start", one whose reopen failed.
(String, Color) phaseWord(ChatPhase p, Tokens t) => (
  phaseName(p),
  switch (p) {
    .waiting => t.needs,
    .working || .background => t.running,
    .failed => t.crashed,
    .done => t.done,
    .expired || .asleep || .fresh || .idle || .archived => t.idle,
  },
);

/// [phaseWord]'s word alone: what the sidebar's Status groups are called.
String phaseName(ChatPhase p) => switch (p) {
  .waiting => 'needs you',
  .working => 'working',
  .background => 'in background',
  .expired => 'expired',
  .failed => "couldn't start",
  .done => 'done',
  .asleep => 'asleep',
  .fresh => 'new',
  .idle => 'idle',
  .archived => 'archived',
};

/// A time the daemon sent in milliseconds since the epoch; null for 0
/// (it didn't see it).
DateTime? msTime(int ms) =>
    ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);

/// "12s", "1m 04s".
String elapsed(Duration d) => d.inMinutes == 0
    ? '${d.inSeconds}s'
    : '${d.inMinutes}m ${two(d.inSeconds % 60)}s';

/// How long something ran, or runs while [runs]: from [started] to
/// [ended], or to now (ms since the epoch, 0 when not seen); '' unknown.
String ranFor(int started, int ended, {required bool runs}) {
  final since = msTime(started);
  final end = runs ? clock() : msTime(ended);
  return since == null || end == null ? '' : elapsed(end.difference(since));
}

/// "950 tokens", "12.4k tokens", "1M tokens": [tokens]' short count.
String tokenCount(int n) => '${tokens(n)} tokens';

/// Whether [c] is busy with no turn running: the daemon reopening its
/// session (opened after a restart or a sleep, reloaded, moved, rewound),
/// the agent replaying the chat. A turn always has its start.
bool reopening(ChatState c) => c.busy && c.started == null;

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
