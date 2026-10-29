import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/drawn.dart';
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
/// the line folds away over 200 ms, so the composer slides down rather
/// than jumps. With Reduce Motion the receipt shows still and goes at
/// once. Between turns it takes no room.
class TurnStatus extends StatefulWidget {
  const new(this.chat, {super.key, this.what});

  final ChatState chat;
  final String? what;

  static const receiptFor = Duration(milliseconds: 1400);
  static const foldFor = Duration(milliseconds: 200);

  @override
  State<TurnStatus> createState() => _TurnStatusState();
}

class _TurnStatusState extends State<TurnStatus> with ClockRun {
  late final Timer _tick;
  late bool _busy = widget.chat.busy;
  DateTime? _since; // when the running turn started, as last known
  bool _stopped = false; // someone stopped it
  String? _receipt; // "Done in 2m 30s", while it shows
  String _last = ''; // what the line said last, folding away

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_changed);
    _changed();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.chat.busy && widget.chat.started != null) setState(() {});
    });
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
    _tick.cancel();
    super.dispose();
  }

  void _changed() {
    final c = widget.chat;
    if (c.busy) {
      if (!_busy) {
        _stopped = false;
        _receipt = null;
        stopRun();
      }
      _since = c.started ?? _since ?? DateTime.now();
      _stopped |= c.stopping;
    } else if (_busy) {
      _ended();
    }
    if (_busy != c.busy) setState(() => _busy = c.busy);
  }

  /// The turn ended: a receipt if it's one to see, then the line folds.
  void _ended() {
    final c = widget.chat;
    final lasted = DateTime.now().difference(_since ?? DateTime.now());
    final still = reduceMotion(context);
    _receipt =
        !_stopped && !c.waiting && !turnFailed(c.items) && sparksFor(lasted)
        ? 'Done in ${elapsed(lasted)}'
        : null;
    _since = null;
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
    if (chat.busy || widget.what != null) return _line(context);
    if (!running) return const SizedBox.shrink();
    final ms = ranMs;
    final fold = part(
      ms,
      _receipt == null ? 0 : TurnStatus.receiptFor.inMilliseconds.toDouble(),
      TurnStatus.foldFor.inMilliseconds.toDouble(),
      Curves.ease,
    );
    final line = _receipt == null ? _line(context, folding: true) : _done(ms);
    if (fold == 0) return line;
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1 - fold,
        child: Opacity(opacity: 1 - fold, child: line),
      ),
    );
  }

  Widget _row(Widget mark, Widget text, [Widget? end]) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 4, 20, 2),
    child: Row(
      spacing: 8,
      children: [
        mark,
        Flexible(child: text),
        ?end,
      ],
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
        : widget.what ?? (waiting ? 'Waiting for you' : doing(chat.items));
    if (!folding) _last = what;
    return _row(
      CustomPaint(
        size: const Size.square(12),
        painter: StatusMark(waiting ? t.needs : t.accent),
      ),
      // "Waiting for you" crossfades in as a prompt comes, and out.
      AnimatedSwitcher(
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
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
            style: theme.ui(waiting ? t.needs : t.textSecondary, size: 12.5),
          ),
        ),
      ),
      started != null && !waiting && !folding
          ? Text(
              elapsed(DateTime.now().difference(started)),
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
          style: theme.ui(t.done, size: 12.5),
        ),
      ),
    );
  }
}
