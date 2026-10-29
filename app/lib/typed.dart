import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

/// A tool call's title typing out as it arrives ([Arriving]): [span] is
/// laid out whole, so nothing reflows, and its characters after the first
/// [keep] (a verb that stays, as "Read ") show left to right, the rest
/// painted clear, a caret in the tool accent at their end. Once all are
/// there the caret fades and the title shines while [shine]. A title that
/// changes (a generic one, then the command) types what was added, or all
/// of it again, quicker. With Reduce Motion it's there whole.
class Typed extends StatefulWidget {
  const new(this.span, {super.key, this.keep = 0, this.shine = false});

  final TextSpan span;
  final int keep;
  final bool shine;

  /// Characters a second: quick, but each word can be read.
  static const rate = 90.0;

  /// The longest a title takes, and a changed one typed again.
  static const most = Duration(milliseconds: 260);
  static const again = Duration(milliseconds: 180);

  /// The caret fading once the title is all there.
  static const fade = Duration(milliseconds: 120);

  @override
  State<Typed> createState() => _TypedState();
}

class _TypedState extends State<Typed> with ClockRun {
  bool _started = false;
  int _from = 0; // characters shown as the typing started
  double _typeMs = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Arriving.of(context)) _type(widget.keep, Typed.most);
  }

  @override
  void didUpdateWidget(Typed old) {
    super.didUpdateWidget(old);
    final was = old.span.toPlainText();
    final now = widget.span.toPlainText();
    if (was == now) return;
    if (now.startsWith(was)) {
      _type(max(was.length, widget.keep), Typed.most);
    } else {
      _type(widget.keep, Typed.again);
    }
  }

  void _type(int from, Duration most) {
    final n = widget.span.toPlainText().length - from;
    if (n <= 0 || reduceMotion(context)) return;
    _from = from;
    _typeMs = min(n / Typed.rate * 1000, most.inMilliseconds.toDouble());
    runFor(Duration(microseconds: (_typeMs * 1000).round()) + Typed.fade);
  }

  @override
  Widget build(BuildContext context) {
    Widget text(InlineSpan span) =>
        Text.rich(span, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (!running) return Shine(on: widget.shine, child: text(widget.span));
    final ms = ranMs;
    final all = widget.span.toPlainText().length;
    final shown = _from + ((all - _from) * part(ms, 0, _typeMs)).floor();
    final caret = 1 - part(ms, _typeMs, Typed.fade.inMilliseconds.toDouble());
    return text(
      typedSpan(widget.span, shown, NushiTheme.of(context).t.toolAccent, caret),
    );
  }
}

/// A run's line ("Read 4 files, running make test"): what its calls did
/// ([done]), then what the running one is doing ([now], shining). The
/// line never types again: [done] changes in place, and only a new [now]
/// types in (what was added, when it grows), as [Typed] does, when the
/// run first shows ([Arriving]) and as calls follow. What [now] starts
/// typing is held until typed, [hold] at least; what comes meanwhile
/// waits, and only the latest shows then, those between skipped. With
/// Reduce Motion each shows whole as it comes.
class RunLine extends StatefulWidget {
  const new(this.done, this.now, {required this.style, super.key});

  final String done;
  final String? now;
  final TextStyle style;

  /// The least a running call's words show before the next replace them.
  static const hold = Duration(milliseconds: 250);

  @override
  State<RunLine> createState() => _RunLineState();
}

class _RunLineState extends State<RunLine> with ClockRun {
  late String _done = widget.done;
  String? _now;
  (String, String?)? _next; // what waits for the hold
  int _from = 0;
  double _typeMs = 0;
  double _holdMs = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _show(widget.done, widget.now, type: Arriving.of(context));
  }

  @override
  void didUpdateWidget(RunLine old) {
    super.didUpdateWidget(old);
    final next = (widget.done, widget.now);
    if (next == (_done, _now)) {
      _next = null;
    } else if (running && ranMs < _holdMs) {
      _next = next;
    } else {
      _show(next.$1, next.$2);
    }
  }

  @override
  void ticked() {
    if (_next case (final done, final now)? when ranMs >= _holdMs) {
      _next = null;
      _show(done, now);
    }
  }

  void _show(String done, String? now, {bool type = true}) {
    final was = _now;
    _done = done;
    _now = now;
    if (now == null || now == was || !type || reduceMotion(context)) return;
    final from = was != null && now.startsWith(was) ? was.length : 0;
    final n = now.length - from;
    if (n <= 0) return;
    _from = from;
    _typeMs = min(n / Typed.rate * 1000, Typed.most.inMilliseconds.toDouble());
    _holdMs = max(_typeMs, RunLine.hold.inMilliseconds.toDouble());
    runFor(
      Duration(
        microseconds: (max(_typeMs + Typed.fade.inMilliseconds, _holdMs) * 1000)
            .round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget text(InlineSpan span) =>
        Text.rich(span, maxLines: 1, overflow: TextOverflow.ellipsis);
    final style = widget.style;
    final now = _now;
    if (now == null) return text(TextSpan(text: _done, style: style));
    final span = TextSpan(text: now, style: style);
    final Widget doing;
    if (running && ranMs < _typeMs + Typed.fade.inMilliseconds) {
      final ms = ranMs;
      final shown =
          _from + ((now.length - _from) * part(ms, 0, _typeMs)).floor();
      final caret = 1 - part(ms, _typeMs, Typed.fade.inMilliseconds.toDouble());
      doing = text(
        typedSpan(span, shown, NushiTheme.of(context).t.toolAccent, caret),
      );
    } else {
      doing = Shine(child: text(span));
    }
    return Row(
      children: [
        if (_done.isNotEmpty)
          Flexible(
            child: text(TextSpan(text: '$_done, ', style: style)),
          ),
        Flexible(child: doing),
      ],
    );
  }
}

/// [span] with its first [shown] characters as they are and the rest
/// painted clear, a caret of [color] at [caret] opacity between them,
/// taking no room.
@visibleForTesting
TextSpan typedSpan(TextSpan span, int shown, Color color, double caret) {
  final leaves = <(String, TextStyle?)>[];
  void flatten(InlineSpan s, TextStyle? parent) {
    if (s is! TextSpan) return;
    final style = parent?.merge(s.style) ?? s.style;
    if (s.text case final t?) leaves.add((t, style));
    for (final c in s.children ?? const <InlineSpan>[]) {
      flatten(c, style);
    }
  }

  flatten(span, null);
  final out = <InlineSpan>[];
  var at = 0;
  var placed = false;
  void place(TextStyle? style) {
    if (placed) return;
    placed = true;
    final h = (style?.fontSize ?? 13) * 1.05;
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox.shrink(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: 1.5,
            maxHeight: h,
            child: ColoredBox(
              color: color.withValues(alpha: caret),
              child: SizedBox(width: 1.5, height: h),
            ),
          ),
        ),
      ),
    );
  }

  for (final (text, style) in leaves) {
    var cut = (shown - at).clamp(0, text.length);
    // Never between the halves of a surrogate pair.
    if (cut > 0 && cut < text.length && _high(text.codeUnitAt(cut - 1))) cut++;
    if (cut > 0) out.add(TextSpan(text: text.substring(0, cut), style: style));
    if (cut < text.length) {
      place(style);
      out.add(
        TextSpan(
          text: text.substring(cut),
          style: (style ?? const TextStyle()).copyWith(
            color: Colors.transparent,
          ),
        ),
      );
    }
    at += text.length;
  }
  if (!placed && caret > 0) place(leaves.lastOrNull?.$2);
  return TextSpan(children: out);
}

bool _high(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
