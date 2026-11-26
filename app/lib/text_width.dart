import 'package:flutter/widgets.dart';

/// How wide [text] sets on one line in [style] where [context] is: at its
/// text scale and, with [merge], over its default text style, as a [Text]
/// there sets it; without, [style] alone.
double textWidth(
  BuildContext context,
  String text,
  TextStyle style, {
  bool merge = true,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: merge ? DefaultTextStyle.of(context).style.merge(style) : style,
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// [path] (folders, ending in its slash) as it fits [width] on one line
/// in [style] where [context] is: whole, or cut in its middle, its start
/// and its end kept around "…" (a twin's folder before its name, issue
/// 119). The cut takes whole folders after the first first
/// ("north.example/…/tools/", then "north.example/…/"), since a twin's
/// hint differs in its first folder; only then is the first cut in its own
/// middle ("nor…mple/"). Empty where fewer than [least] of its own
/// characters (slashes aside) would show: never a lone "…".
String pathThatFits(
  BuildContext context,
  String path,
  TextStyle style,
  double width, {
  int least = 4,
}) {
  bool fits(String s) => textWidth(context, s, style) <= width;
  if (!width.isFinite || fits(path)) return path;
  final slash = path.endsWith('/') ? '/' : '';
  final body = path.substring(0, path.length - slash.length);
  final split = body.indexOf('/', 1);
  final first = split < 0 ? body : body.substring(0, split);
  final rest = split < 0
      ? const <String>[]
      : body.substring(split + 1).split('/');
  String? shown;
  for (var k = rest.length - 1; k >= 0 && rest.isNotEmpty; k--) {
    final end = [...rest.sublist(rest.length - k), ''].join('/');
    if (fits('$first/…/$end')) {
      shown = '$first/…/$end';
      break;
    }
  }
  if (shown == null) {
    // [n] of the first folder's characters kept: the first half rounded
    // up, the rest from its end.
    String cut(int n) {
      final head = (n + 1) ~/ 2;
      return '${first.substring(0, head)}…'
          '${first.substring(first.length - (n - head))}$slash';
    }

    var (lo, hi) = (0, first.length - 1);
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (fits(cut(mid))) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    shown = lo < 0 ? '' : cut(lo);
  }
  return shown.replaceAll(RegExp('[/…]'), '').length < least ? '' : shown;
}
