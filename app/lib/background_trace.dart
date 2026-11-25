part of 'background_mark.dart';

// The background mark's outline (#113): the two drops' field, each a head
// and a tail of tapered sticks, traced as one path that keeps their area.

/// A smooth union of two fields, [k] wide.
double _smin(double a, double b, double k) {
  final w = max(k - (a - b).abs(), 0.0) / k;
  return min(a, b) - w * w * k / 4;
}

/// A 2 by 2 matrix, row by row.
class _Bend {
  const new(this.a, this.b, this.c, this.d);

  /// Stretched by [s] along [angle] and squeezed by 1/[s] across it.
  factory stretch(double angle, double s) {
    final co = cos(angle);
    final si = sin(angle);
    final w = s - 1 / s;
    return _Bend(
      s * co * co + si * si / s,
      w * co * si,
      w * co * si,
      s * si * si + co * co / s,
    );
  }

  _Bend get inverse {
    final det = a * d - b * c;
    return _Bend(d / det, -b / det, -c / det, a / det);
  }

  static const identity = _Bend(1, 0, 0, 1);

  final double a;
  final double b;
  final double c;
  final double d;
}

/// The two drops' field in a room of [size]: under 0 inside, about the
/// distance to the edge; each drop its beads' smooth union, the two
/// joined by the neck's; traced at the level that keeps two drops' area.
Path _trace(_Frame f, Size size) {
  const n = 72; // cells across
  final side = size.shortestSide;
  final s = side / _room;
  final cell = side / n;
  final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
  final inv = f.m.inverse;
  final mid = size.center(Offset.zero);
  final k = f.k * s;
  final fillet = _fillet * s;
  final threadFillet = _threadFillet * s;
  final r = _r0 * s;
  final area = 2 * pi * r * r;

  // The field on a grid [cells] across, with every radius times [g]:
  // each drop its head and its tail's beads joined by tapered sticks,
  // which bend round with a little fillet, the tail run into the head
  // with a wider one, as surface tension rounds it; the two drops joined
  // by the neck's smooth union, and by the thread while there's one.
  // Worked in the bend's space (each point mapped by its inverse), where
  // every piece is a true distance, so the level that keeps the area
  // moves the outline as far everywhere and grows no knob at a tip.
  List<double> fieldAt(double g, int cells) {
    final w = side / cells;
    // Per drop: its beads as x, y, r, a box round it past which it's
    // only far, and its tail's sticks.
    final drops = [
      for (final d in f.drops)
        [
          for (var b = 0; b < d.length; b++) ...[
            ..._mapped(inv, mid + d[b].at * s),
            d[b].r * s * g,
          ],
        ],
    ];
    final reach = max(k, fillet) + 2 * w;
    final boxes = [
      for (final d in drops)
        () {
          var l = double.infinity;
          var t = l;
          var r = -l;
          var btm = -l;
          for (var b = 0; b < d.length; b += 3) {
            l = min(l, d[b] - d[b + 2]);
            r = max(r, d[b] + d[b + 2]);
            t = min(t, d[b + 1] - d[b + 2]);
            btm = max(btm, d[b + 1] + d[b + 2]);
          }
          return Rect.fromLTRB(l, t, r, btm).inflate(reach);
        }(),
    ];
    final tails = [
      for (final d in drops)
        [
          for (var b = 6; b < d.length; b += 3)
            _Stick(d[b - 3], d[b - 2], d[b - 1], d[b], d[b + 1], d[b + 2]),
        ],
    ];

    double drop(int which, double px, double py) {
      final d = drops[which];
      final box = boxes[which];
      if (px < box.left || px > box.right || py < box.top || py > box.bottom) {
        // Far: only the sign and that it's past the neck's reach count.
        return reach;
      }
      final head = _length(px - d[0], py - d[1]) - d[2];
      // The sticks meet end to end at one thickness, so their plain
      // union is smooth: a fillet there would swell each joint, a bead
      // on the thin end. A stick that can't come nearer than the
      // nearest so far is passed over.
      var tail = double.infinity;
      for (final stick in tails[which]) {
        if (stick.nearest(px, py) < tail) {
          tail = min(tail, stick.distance(px, py));
        }
      }
      return _smin(head, tail, fillet);
    }

    final neck = f.neck * s * g;
    final [ax, ay, ...] = drops[0];
    final [bx, by, ...] = drops[1];
    // The waist: a band across the line between the heads, through its
    // middle.
    final pinch = f.pinch * s;
    final axis = Offset(bx - ax, by - ay);
    final across = axis.distance < 1e-9 ? Offset.zero : axis / axis.distance;
    final band = _pinchWidth * s;
    final thread = _Stick(ax, ay, neck, bx, by, neck);

    final field = List<double>.filled((cells + 1) * (cells + 1), 0);
    for (var j = 0; j <= cells; j++) {
      for (var i = 0; i <= cells; i++) {
        // The room's edge is outside, so every outline closes inside it.
        if (i == 0 || j == 0 || i == cells || j == cells) {
          field[j * (cells + 1) + i] = w;
          continue;
        }
        final x = origin.dx + i * w;
        final y = origin.dy + j * w;
        final px = inv.a * x + inv.b * y;
        final py = inv.c * x + inv.d * y;
        var v = _smin(drop(0, px, py), drop(1, px, py), k);
        if (pinch > 0) {
          final along =
              ((px - (ax + bx) / 2) * across.dx +
                  (py - (ay + by) / 2) * across.dy) /
              band;
          v += pinch * exp(-along * along);
        }
        field[j * (cells + 1) + i] = neck <= 0
            ? v
            : _smin(v, thread.distance(px, py), threadFillet);
      }
    }
    return field;
  }

  // The mass kept by thinning the whole drop, not by tracing further in,
  // which would wear a thin tail to a blunt end: the radii scaled to two
  // drops' area, found on a grid half as fine (the fillets don't scale
  // with them, so a second step), the level then finding the rest.
  var g = 1.0;
  if (f.drops.any((d) => d.length > 1)) {
    const coarse = n ~/ 3;
    final c = side / coarse;
    for (var i = 0; i < 2; i++) {
      final inside = fieldAt(g, coarse).where((v) => v < 0).length * c * c;
      if (inside > 0) g = (g * sqrt(area / inside)).clamp(0.6, 1.0);
    }
  }
  return fieldOutline(fieldAt(g, n), n, cell, origin, area: area, step: s);
}

/// [p] mapped by [m].
List<double> _mapped(_Bend m, Offset p) => [
  m.a * p.dx + m.b * p.dy,
  m.c * p.dx + m.d * p.dy,
];

double _length(double x, double y) => sqrt(x * x + y * y);

/// A stick from ([ax], [ay]) [ra] thick to another point [rb] thick: a
/// tapered capsule, whose distance is a true one, so a tail thins to its
/// tip without a bulb. What doesn't change from point to point is worked
/// out once.
class _Stick {
  new(this.ax, this.ay, this.ra, double bx, double by, this.rb)
    : ex = bx - ax,
      ey = by - ay,
      b = ra - rb,
      h = (bx - ax) * (bx - ax) + (by - ay) * (by - ay),
      mx = (ax + bx) / 2,
      my = (ay + by) / 2,
      cx = sqrt(
        max(
          (bx - ax) * (bx - ax) + (by - ay) * (by - ay) - (ra - rb) * (ra - rb),
          0,
        ),
      ),
      bound =
          sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay)) / 2 + max(ra, rb);

  final double ax;
  final double ay;
  final double ra;
  final double rb;
  final double ex;
  final double ey;
  final double b;
  final double h;
  final double mx;
  final double my;
  final double cx;

  /// How far from its middle it reaches.
  final double bound;

  /// The nearest ([px], [py]) could be to it.
  double nearest(double px, double py) => _length(px - mx, py - my) - bound;

  /// The distance from ([px], [py]) to it.
  double distance(double px, double py) {
    // One end's circle holds the other's: only the bigger counts.
    if (h <= b * b + 1e-9) {
      return ra >= rb
          ? _length(px - ax, py - ay) - ra
          : _length(px - ax - ex, py - ay - ey) - rb;
    }
    final x = px - ax;
    final y = py - ay;
    // The point in the stick's frame, in lengths of it: across, along.
    final qx = (x * ey - y * ex).abs() / h;
    final qy = (x * ex + y * ey) / h;
    final k = cx * qy - b * qx;
    if (k < 0) return sqrt(h * (qx * qx + qy * qy)) - ra;
    if (k > cx) return sqrt(h * (qx * qx + (qy - 1) * (qy - 1))) - rb;
    return cx * qx + b * qy - ra;
  }
}
