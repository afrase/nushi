import 'dart:math';

import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

/// What a [Paced] shows of its text now: the text so far, what was
/// revealed in the last 160 ms (faded in), and the caret's opacity (0
/// without one).
typedef Shown = ({String text, List<FreshRun> fresh, double caret});

/// Holds pacing while someone selects in the transcript (a pointer down,
/// or text selected): all of the text shows at once and nothing fades, as
/// spans changing under a selection lose it.
class PacingHold extends InheritedNotifier<ValueNotifier<bool>> {
  const new({required super.notifier, required super.child, super.key});

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PacingHold>()
          ?.notifier
          ?.value ??
      false;
}

/// A message's or thought's text revealed at a steady pace as it streams,
/// whole words at max(45 ch/s, backlog ÷ 0.22 s): never slower than the
/// stream and never more than about 220 ms behind it (a backlog over 1,200
/// characters jumps to within 200). Once [live] ends the rest shows within
/// 250 ms. [builder] gets what shows ([Shown]), or null when nothing is
/// paced: Reduce Motion, a chat opened with the text there (only what
/// comes after paces), the phone's web build ([paces]), a selection
/// ([PacingHold]), or once all of it shows and the caret has faded.
class Paced extends StatefulWidget {
  const new(this.text, {required this.live, required this.builder, super.key});

  final String text;
  final bool live;
  final Widget Function(BuildContext context, Shown? shown) builder;

  /// Whether text is paced here.
  static bool paces = true;

  static const _least = 45.0; // characters a second
  static const _behind = 0.22; // seconds of backlog at most, steady
  static const _end = 0.25; // seconds to show the rest once it ended
  static const fade = Duration(milliseconds: 160);
  static const caretOut = Duration(milliseconds: 300);

  @override
  State<Paced> createState() => _PacedState();
}

class _PacedState extends State<Paced> {
  double _shown = 0; // characters shown, fractional
  int _end = 0; // characters drawn: whole words
  final _steps = <(int, int, Duration)>[]; // revealed runs: from, to, when
  Duration? _last; // the clock at the last tick
  Duration? _ended; // when the text was all there and no longer live
  double? _endRate; // once it's no longer live: the rest within 250 ms
  bool _listening = false;
  bool _started = false;
  Duration _drawn = Duration.zero; // when it last rebuilt

  bool get _off =>
      !Paced.paces || reduceMotion(context) || PacingHold.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // What was there when it showed shows at once (a chat opened, a
    // message that came whole); what comes after paces.
    final paced = widget.live && Arriving.of(context);
    _end = paced ? 0 : widget.text.length;
    _shown = _end.toDouble();
    if (_end < widget.text.length) _listen();
  }

  @override
  void didUpdateWidget(Paced old) {
    super.didUpdateWidget(old);
    final text = widget.text;
    if (!text.startsWith(old.text)) {
      // Another text, not more of it: it shows as it is.
      _end = text.length;
      _shown = _end.toDouble();
      _steps.clear();
    }
    if (_end < text.length || widget.live != old.live) _listen();
  }

  @override
  void dispose() {
    if (_listening) loopClock.removeListener(_tick);
    super.dispose();
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    // The clock may start again from zero: nothing timed before counts.
    _last = null;
    _drawn = Duration.zero;
    _ended = null;
    _steps.clear();
    loopClock.addListener(_tick);
  }

  void _stop() {
    if (!_listening) return;
    _listening = false;
    loopClock.removeListener(_tick);
  }

  void _tick() {
    final now = loopClock.now;
    final dt = _last == null
        ? 0.0
        : min(0.25, (now - _last!).inMicroseconds / 1e6);
    _last = now;
    final text = widget.text;
    final received = text.length;
    if (_off) {
      _shown = received.toDouble();
    } else {
      var backlog = received - _shown;
      if (backlog > 1200) {
        _shown = received - 200.0;
        backlog = 200;
      }
      var rate = max(Paced._least, backlog / Paced._behind);
      if (widget.live) {
        _endRate = null;
      } else {
        // A steady rate that shows what's left as it ended within 250 ms.
        rate = max(rate, _endRate ??= backlog / Paced._end);
      }
      _shown = min(received.toDouble(), _shown + rate * dt);
    }
    final end = _wholeWords(text, _shown.floor(), done: !widget.live);
    if (end > _end) {
      _steps.add((_end, end, now));
      _end = end;
    }
    _steps.removeWhere((s) => now - s.$3 > Paced.fade);
    final all = _end >= received;
    if (all && !widget.live) _ended ??= now;
    final caretGone = _ended != null && now - _ended! >= Paced.caretOut || _off;
    final idle = all && _steps.isEmpty && (widget.live || caretGone);
    // At most 30 times a second, and at once when it settles.
    if (now - _drawn >= const Duration(milliseconds: 33) || idle) {
      _drawn = now;
      setState(() {});
    }
    if (idle) _stop();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final now = loopClock.now;
    final ended = _ended;
    final done = !widget.live && _end >= text.length;
    if (_off || done && ended != null && now - ended >= Paced.caretOut) {
      return widget.builder(context, null);
    }
    if (!widget.live && _end >= text.length && !_listening) {
      return widget.builder(context, null);
    }
    final shown = text.substring(0, min(_end, text.length));
    final fresh = [
      for (final (from, to, at) in _steps)
        if (to <= shown.length)
          (
            start: from,
            end: to,
            opacity:
                0.2 +
                0.8 *
                    ((now - at).inMicroseconds / Paced.fade.inMicroseconds)
                        .clamp(0.0, 1.0),
          ),
    ];
    final caret = ended == null
        ? 1.0
        : 1 - part((now - ended).inMicroseconds / 1000, 0, 300);
    return widget.builder(context, (text: shown, fresh: fresh, caret: caret));
  }
}

/// Where whole words end at [at] in [text]: the end of the word [at]
/// falls in, if it has all come; else that word's start. [done], the end
/// of the text counts as a word's end.
int _wholeWords(String text, int at, {required bool done}) {
  if (at >= text.length) return text.length;
  bool space(int i) => text.codeUnitAt(i) <= 0x20;
  // To the end of this word, if a space after it has come.
  for (var i = at; i < text.length; i++) {
    if (space(i)) return i;
  }
  if (done) return text.length;
  // Back to its start, unless it's long (a path, a line of code): then
  // as far as it came, not to fall behind.
  var i = at;
  while (i > 0 && !space(i - 1)) {
    i--;
  }
  return at - i > 40 ? at : i;
}

/// The soft caret where streaming text ends: a 2 × 13 px rounded bar in the
/// muted text color, its opacity breathing between 0.35 and 0.8 every 1.2
/// s on the shared clock, times [opacity]. It takes no room.
class SoftCaret extends StatelessWidget {
  const new({required this.opacity, super.key});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = NushiTheme.of(context).t.textMuted;
    return SizedBox.shrink(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: 4,
        maxHeight: 13,
        child: RepaintBoundary(
          child: CustomPaint(
            size: const Size(4, 13),
            painter: _Caret(color, opacity),
          ),
        ),
      ),
    );
  }
}

class _Caret extends CustomPainter {
  new(this.color, this.opacity) : super(repaint: loopRepaint);

  final Color color;
  final double opacity;

  static const period = Duration(milliseconds: 1200);

  @override
  void paint(Canvas canvas, Size size) {
    final v = 0.5 - 0.5 * cos(2 * pi * loopPhase(period));
    final alpha = (0.35 + 0.45 * v) * opacity;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 0, 2, 13),
        const Radius.circular(1),
      ),
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_Caret old) =>
      old.color != color || old.opacity != opacity;
}

/// [shown]'s text in [style], plain (a thought's body): its fresh runs
/// faded, the caret at its end.
TextSpan pacedSpan(Shown shown, TextStyle style) {
  final text = shown.text;
  final color = style.color ?? const Color(0xFF000000);
  final out = <InlineSpan>[];
  var at = 0;
  for (final r in shown.fresh) {
    if (r.start < at || r.end > text.length) continue;
    out
      ..add(TextSpan(text: text.substring(at, r.start)))
      ..add(
        TextSpan(
          text: text.substring(r.start, r.end),
          style: TextStyle(color: color.withValues(alpha: color.a * r.opacity)),
        ),
      );
    at = r.end;
  }
  out.add(TextSpan(text: text.substring(at)));
  if (shown.caret > 0) {
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SoftCaret(opacity: shown.caret),
      ),
    );
  }
  return TextSpan(style: style, children: out);
}
