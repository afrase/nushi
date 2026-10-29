import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';

/// The newest sentence of [text] (the last one, finished or not), plain:
/// what a folded thought shows of itself while it streams. Its start's
/// offset tells one sentence from the next.
({String text, int start}) latestSentence(String text) {
  final t = text.trimRight();
  var start = 0;
  // The last end of a sentence before the text's own last character.
  for (var i = t.length - 2; i >= 0; i--) {
    final c = t[i];
    final next = t[i + 1];
    if (c == '\n' || '.!?'.contains(c) && (next == ' ' || next == '\n')) {
      start = i + 1;
      break;
    }
  }
  final plain = t
      .substring(start)
      .replaceAll(RegExp('[*_`#>]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return (text: plain, start: start);
}

/// Under a folded "Thinking…" while it streams ([live]): the newest
/// sentence of the thought, dim and italic on one line, its start cut
/// ("…") when it's long so the newest words show. A new sentence slides
/// the old one up 6 px and out as it comes in (180 ms); when the thought
/// ends the line folds away (200 ms). With Reduce Motion it swaps and
/// goes at once.
class ThoughtLine extends StatefulWidget {
  const new(this.text, {required this.live, required this.style, super.key});

  final String text;
  final bool live;
  final TextStyle style;

  static const slideFor = Duration(milliseconds: 180);
  static const foldFor = Duration(milliseconds: 200);

  @override
  State<ThoughtLine> createState() => _ThoughtLineState();
}

class _ThoughtLineState extends State<ThoughtLine> with ClockRun {
  late ({String text, int start}) _now = latestSentence(widget.text);
  String? _old; // the sentence sliding out
  bool _folding = false;

  @override
  void didUpdateWidget(ThoughtLine old) {
    super.didUpdateWidget(old);
    final still = reduceMotion(context);
    if (old.live && !widget.live) {
      _old = null;
      _folding = !still;
      if (_folding) runFor(ThoughtLine.foldFor);
      return;
    }
    if (!widget.live) return;
    final now = latestSentence(widget.text);
    if (now.start != _now.start && _now.text.isNotEmpty && !still) {
      _old = _now.text;
      _folding = false;
      runFor(ThoughtLine.slideFor);
    }
    _now = now;
  }

  Widget _line(String s) => LayoutBuilder(
    builder: (context, box) => Text(
      _tail(
        s,
        DefaultTextStyle.of(context).style.merge(widget.style),
        MediaQuery.textScalerOf(context),
        box.maxWidth,
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: widget.style,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.live && !(_folding && running)) return const SizedBox.shrink();
    final height = (widget.style.fontSize ?? 12.5) * 1.6;
    var line = _line(_now.text);
    if (running && _folding) {
      final v = part(
        ranMs,
        0,
        ThoughtLine.foldFor.inMilliseconds.toDouble(),
        Curves.ease,
      );
      return ClipRect(
        child: Align(
          alignment: Alignment.topLeft,
          heightFactor: 1 - v,
          child: Opacity(
            opacity: 1 - v,
            child: SizedBox(height: height, child: line),
          ),
        ),
      );
    }
    if (running && _old != null) {
      final v = part(
        ranMs,
        0,
        ThoughtLine.slideFor.inMilliseconds.toDouble(),
        Curves.easeOut,
      );
      line = Stack(
        children: [
          Transform.translate(
            offset: Offset(0, -6 * v),
            child: Opacity(opacity: 1 - v, child: _line(_old!)),
          ),
          Transform.translate(
            offset: Offset(0, 6 * (1 - v)),
            child: Opacity(opacity: v, child: line),
          ),
        ],
      );
    }
    return SizedBox(
      height: height,
      child: ClipRect(child: line),
    );
  }
}

/// [s] as it fits [width] in [style]: whole, or its end after "…".
String _tail(String s, TextStyle style, TextScaler scaler, double width) {
  bool fits(String t) {
    final p = TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final ok = p.width <= width;
    p.dispose();
    return ok;
  }

  if (!width.isFinite || fits(s)) return s;
  // The longest end that fits after the ellipsis.
  var (lo, hi) = (0, s.length);
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (fits('…${s.substring(mid)}')) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  // From a word's start, unless the words are long.
  final space = s.indexOf(' ', lo);
  final from = lo > 0 && space >= 0 && space - lo < 16 ? space + 1 : lo;
  return '…${s.substring(from).trimLeft()}';
}
