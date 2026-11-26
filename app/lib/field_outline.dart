import 'dart:ui';

/// The outline where [field] is at the level that encloses [area], as
/// one smoothed path without holes. [field] holds the (n + 1) by (n + 1)
/// corners of a grid [n] cells across, each [cell] wide, from [origin],
/// under 0 inside; its edge must be outside, so every outline closes.
/// Marching squares, the level found by secant steps from 0 and from a
/// fifth of [step] (the shape's scale) inside. The background mark is
/// drawn with it (`background_mark.dart`).
Path fieldOutline(
  List<double> field,
  int n,
  double cell,
  Offset origin, {
  required double area,
  required double step,
}) {
  // The level that keeps the area: two secant steps from 0.
  var l0 = 0.0;
  var a0 = _area(_loops(field, n, cell, origin, l0)) - area;
  var l1 = -0.2 * step;
  var a1 = _area(_loops(field, n, cell, origin, l1)) - area;
  for (var i = 0; i < 2 && (a1 - a0).abs() > 1e-9; i++) {
    final l2 = l1 - a1 * (l1 - l0) / (a1 - a0);
    l0 = l1;
    a0 = a1;
    l1 = l2;
    a1 = _area(_loops(field, n, cell, origin, l1)) - area;
  }
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final loop in _outer(_loops(field, n, cell, origin, l1))) {
    // Smoothed: a curve through each side's middle, its corner the point.
    final m = loop.length;
    if (m < 3) continue;
    Offset half(int i) => (loop[i % m] + loop[(i + 1) % m]) / 2;
    final start = half(0);
    path.moveTo(start.dx, start.dy);
    for (var i = 1; i <= m; i++) {
      final p = loop[i % m];
      final q = half(i);
      path.quadraticBezierTo(p.dx, p.dy, q.dx, q.dy);
    }
    path.close();
  }
  return path;
}

/// The [loops] that lie inside no other: liquid has no holes, so a gap
/// closed in by the shape (two necks meeting round it) is filled.
List<List<Offset>> _outer(List<List<Offset>> loops) => [
  for (final l in loops)
    if (!loops.any((o) => !identical(o, l) && _inside(l.first, o))) l,
];

/// Whether [p] is inside the polygon [loop] (even-odd).
bool _inside(Offset p, List<Offset> loop) {
  var inside = false;
  for (var i = 0, j = loop.length - 1; i < loop.length; j = i++) {
    final a = loop[i];
    final b = loop[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

double _area(List<List<Offset>> loops) {
  var sum = 0.0;
  for (final l in _outer(loops)) {
    var a = 0.0;
    for (var i = 0; i < l.length; i++) {
      final p = l[i];
      final q = l[(i + 1) % l.length];
      a += p.dx * q.dy - q.dx * p.dy;
    }
    sum += a.abs() / 2;
  }
  return sum;
}

/// The closed outlines where [field] crosses [level] (marching squares).
List<List<Offset>> _loops(
  List<double> field,
  int n,
  double cell,
  Offset origin,
  double level,
) {
  final w = n + 1;
  double v(int i, int j) => field[j * w + i] - level;
  // Edge ids: a horizontal edge from node (i, j) is 2(jw + i), a vertical
  // one 2(jw + i) + 1.
  int hz(int i, int j) => 2 * (j * w + i);
  int vt(int i, int j) => 2 * (j * w + i) + 1;
  Offset point(int e) {
    final node = e ~/ 2;
    final i = node % w;
    final j = node ~/ w;
    final (i2, j2) = e.isEven ? (i + 1, j) : (i, j + 1);
    final a = v(i, j);
    final b = v(i2, j2);
    final x = a / (a - b);
    return origin +
        Offset((i + (i2 - i) * x) * cell, (j + (j2 - j) * x) * cell);
  }

  final next = <int, List<int>>{};
  void join(int a, int b) {
    (next[a] ??= []).add(b);
    (next[b] ??= []).add(a);
  }

  for (var j = 0; j < n; j++) {
    for (var i = 0; i < n; i++) {
      final tl = v(i, j) < 0;
      final tr = v(i + 1, j) < 0;
      final br = v(i + 1, j + 1) < 0;
      final bl = v(i, j + 1) < 0;
      final kind = (tl ? 1 : 0) | (tr ? 2 : 0) | (br ? 4 : 0) | (bl ? 8 : 0);
      if (kind == 0 || kind == 15) continue;
      final top = hz(i, j);
      final bottom = hz(i, j + 1);
      final left = vt(i, j);
      final right = vt(i + 1, j);
      final inMiddle =
          (v(i, j) + v(i + 1, j) + v(i + 1, j + 1) + v(i, j + 1)) < 0;
      switch (kind) {
        case 1 || 14:
          join(left, top);
        case 2 || 13:
          join(top, right);
        case 3 || 12:
          join(left, right);
        case 4 || 11:
          join(right, bottom);
        case 6 || 9:
          join(top, bottom);
        case 7 || 8:
          join(left, bottom);
        case 5:
          if (inMiddle) {
            join(top, right);
            join(bottom, left);
          } else {
            join(left, top);
            join(right, bottom);
          }
        case 10:
          if (inMiddle) {
            join(left, top);
            join(right, bottom);
          } else {
            join(top, right);
            join(bottom, left);
          }
      }
    }
  }
  final loops = <List<Offset>>[];
  final seen = <int>{};
  for (final startEdge in next.keys) {
    if (seen.contains(startEdge)) continue;
    final loop = <Offset>[];
    var at = startEdge;
    var from = -1;
    while (seen.add(at)) {
      loop.add(point(at));
      final ends = next[at]!;
      final to = ends.firstWhere((e) => e != from, orElse: () => ends.first);
      from = at;
      at = to;
    }
    loops.add(loop);
  }
  return loops;
}
