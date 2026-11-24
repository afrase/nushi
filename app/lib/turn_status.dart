import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

/// Under the transcript while a turn runs, as in Claude Code: a mark, what
/// the agent is doing ([doing]), shining, and for how long; "Waiting for
/// you" while a permission prompt or question waits. [what] overrides it.
///
/// A turn you watched end (normally, after [Sparks.after] or more, Nushi
/// in front) leaves a receipt for [receiptFor]: its mark draws into the
/// green check, sparks leave it, and the text says "Done in 2m 30s". Then
/// the line fades out over 200 ms; as a turn starts it fades in the same
/// way. Its room is kept between turns, empty, so the composer never moves
/// as a turn starts or ends; in a short window ([roomFrom]) the box needs
/// that room, and the line folds away and grows in instead. With Reduce
/// Motion the receipt shows still and the line comes and goes at once.
class TurnStatus extends StatefulWidget {
  const new(this.chat, {super.key, this.what, this.keepsRoom = true});

  final ChatState chat;
  final String? what;

  /// Whether the line's room may be kept between turns (in a window tall
  /// enough, [roomFrom]); the phone's screen needs it for the box.
  final bool keepsRoom;

  // design: how long a state shows, not motion
  static const receiptFor = Duration(milliseconds: 1400);

  /// How tall the window (less the keyboard) is for the line's room to be
  /// kept between turns; shorter, the box needs it.
  static const roomFrom = 480.0;
  static const Duration foldFor = Motion.standard;

  @override
  State<TurnStatus> createState() => _TurnStatusState();
}

class _TurnStatusState extends State<TurnStatus> with ClockRun {
  late bool _busy = widget.chat.busy;
  String? _receipt; // "Done in 2m 30s", while it shows
  String _last = ''; // what the line said last, folding away
  bool _growing = false; // the run is the line growing in
  double _growFrom = 0; // how much of it showed as it began to
  double _shows = 0; // how much of the line showed when last built

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_changed);
    _changed();
    secondClock.addListener(_tick); // its time, while a turn runs
  }

  @override
  void didUpdateWidget(TurnStatus old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat) return;
    old.chat.removeListener(_changed);
    widget.chat.addListener(_changed);
    _busy = widget.chat.busy;
    _receipt = null;
    stopRun();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_changed);
    secondClock.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    if (widget.chat.busy && widget.chat.started != null) setState(() {});
  }

  void _changed() {
    final c = widget.chat;
    if (c.busy) {
      if (!_busy) {
        _receipt = null;
        // From what shows of a line still folding, if one is.
        _growFrom = running ? _shows : 0;
        stopRun();
        _growing = !reduceMotion(context) && _growFrom < 1;
        if (_growing) runFor(TurnStatus.foldFor);
      }
    } else if (_busy) {
      _ended();
    }
    if (_busy != c.busy) setState(() => _busy = c.busy);
  }

  /// The turn ended: a receipt if it's one to see (done, as the daemon
  /// judged it), then the line folds.
  void _ended() {
    final c = widget.chat;
    final lasted = c.lastTurn ?? Duration.zero;
    final still = reduceMotion(context);
    _growing = false;
    _receipt =
        c.ended == TurnEnd.TURN_END_DONE && !c.waiting && sparksFor(lasted)
        ? 'Done in ${elapsed(lasted)}'
        : null;
    if (_receipt == null && still) return;
    runFor(
      _receipt == null
          ? TurnStatus.foldFor
          : TurnStatus.receiptFor +
                (still ? Duration.zero : TurnStatus.foldFor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    if (widget.what != null) return _line(context);
    if (chat.busy) {
      final v = !running || !_growing
          ? 1.0
          : _growFrom +
                (1 - _growFrom) *
                    part(
                      ranMs,
                      0,
                      TurnStatus.foldFor.inMilliseconds.toDouble(),
                      Curves.ease,
                    );
      return _folded(_line(context), 1 - v);
    }
    if (!running) {
      _shows = 0;
      return _reserved(context);
    }
    final ms = ranMs;
    final fold = part(
      ms,
      _receipt == null ? 0 : TurnStatus.receiptFor.inMilliseconds.toDouble(),
      TurnStatus.foldFor.inMilliseconds.toDouble(),
      Curves.ease,
    );
    final line = _receipt == null ? _line(context, folding: true) : _done(ms);
    return _folded(line, fold);
  }

  /// [line] [fold] of the way gone. Where its room is kept ([_keeps]),
  /// it fades in its room, so nothing under or over it moves as a turn
  /// starts or ends; elsewhere it folds: its height and opacity.
  Widget _folded(Widget line, double fold) {
    _shows = 1 - fold;
    if (fold == 0) return line;
    if (_keeps(context)) return Opacity(opacity: 1 - fold, child: line);
    return Fold(
      factor: 1 - fold,
      child: Opacity(opacity: 1 - fold, child: line),
    );
  }

  /// Whether the line's room is kept between turns: where the window,
  /// less the keyboard, is [TurnStatus.roomFrom] tall or more. In a short
  /// one (a phone on its side, the keyboard up) the box needs the room
  /// more than the line, and the line folds away between turns. Never for
  /// a chat with no box (archived, or its session gone), whose bar takes
  /// the place.
  bool _keeps(BuildContext context) {
    final chat = widget.chat;
    if (!widget.keepsRoom || chat.archived || chat.sessionGone) return false;
    final tall =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return tall >= TurnStatus.roomFrom;
  }

  /// The line's room between turns, empty, where it's kept ([_keeps]):
  /// the composer stays where a turn's line puts it.
  Widget _reserved(BuildContext context) {
    if (!_keeps(context)) return const SizedBox.shrink();
    final theme = NushiTheme.of(context);
    return ExcludeSemantics(
      child: _row(
        const SizedBox.square(dimension: 12),
        Text(' ', style: theme.ui(theme.t.textSecondary, size: 12)),
      ),
    );
  }

  Widget _row(Widget mark, Widget text, [Widget? end]) => ChatColumn(
    child: Padding(
      padding: TouchTargets.of(context)
          ? const EdgeInsets.fromLTRB(22, 4, 20, 2)
          : const EdgeInsets.fromLTRB(
              NushiTheme.gutter,
              4,
              NushiTheme.gutter,
              2,
            ),
      child: Row(
        spacing: 8,
        children: [
          mark,
          Flexible(child: text),
          ?end,
        ],
      ),
    ),
  );

  /// What the agent is doing, while the turn runs; [folding], the last of
  /// it, still, as it folds away.
  Widget _line(BuildContext context, {bool folding = false}) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final waiting = !folding && chat.waiting && widget.what == null;
    final started = chat.started;
    final what = folding
        ? _last
        : widget.what ??
              (waiting
                  ? 'Waiting for you'
                  : reopening(chat)
                  ? 'Opening the session'
                  : doing(chat.items));
    if (!folding) _last = what;
    return _row(
      CustomPaint(
        size: const Size.square(12),
        painter: StatusMark(waiting ? t.needs : t.accent),
      ),
      // "Waiting for you" crossfades in as a prompt comes, and out.
      AnimatedSwitcher(
        duration: reduceMotion(context) ? Duration.zero : Motion.quick,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: Shine(
          key: ValueKey(waiting),
          on: !waiting && !folding,
          child: Text(
            what,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(waiting ? t.needs : t.textSecondary, size: 12),
          ),
        ),
      ),
      started != null && !waiting && !folding
          ? Text(
              elapsed(clock().difference(started)),
              style: theme.ui(t.textMuted, size: 12),
            )
          : null,
    );
  }

  /// The receipt [ms] in: the check drawing, sparks leaving it, the words
  /// fading in.
  Widget _done(double ms) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final still = reduceMotion(context);
    final draw = CheckPainter.drawFor.inMilliseconds.toDouble();
    return _row(
      CustomPaint(
        size: const Size.square(12),
        painter: CheckPainter(
          t.done,
          still ? 1 : part(ms, 0, draw, Curves.easeOut),
          1,
          sparks: still
              ? null
              : Sparks(
                  ms,
                  color: t.done,
                  band: t.shineBand,
                  seed: widget.chat.id.hashCode,
                ),
        ),
      ),
      Opacity(
        opacity: still ? 1 : part(ms, 0, 150),
        child: Text(
          _receipt!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(t.done, size: 12),
        ),
      ),
    );
  }
}
