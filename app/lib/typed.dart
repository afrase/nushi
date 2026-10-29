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

  /// Characters a second, as fast as reading the verb.
  static const rate = 120.0;

  /// The longest a title takes, and a changed one typed again.
  static const most = Duration(milliseconds: 180);
  static const again = Duration(milliseconds: 120);

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
