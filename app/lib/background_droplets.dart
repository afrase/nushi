part of 'background_mark.dart';

// The background mark's shapes (#113): the two droplets at each moment of
// the play, and their outline traced from their fields.

/// The room the amounts below are in: `ChatDot`'s (its size times 1.6).
const double _room = 11.2;

/// A drop's radius at rest, and half the distance between the two.
const _r0 = 2.0;
const double _apart = 2.68;

/// The neck's reach at rest: too short to join the two.
const _kRest = 0.4;

/// The play's length and the loop's, in milliseconds.
const double _play = BackgroundMark.playTicks * 1000.0 / pulseRate;
const double _loop = BackgroundMark.ticks * 1000.0 / pulseRate;

/// A drop's tail lies along the way its head just came, so it curves as
/// it turned: as long as the way it goes in [_lag] milliseconds while
/// slow, and at most [_tail] (in [_room]'s units) while fast. Drawn with
/// [_beads] beads.
const double _lag = 150;
const double _tail = 3.4;

/// The most of the turn a tail runs back along, so it never curls.
const double _curl = 1.2;
const _beads = 12;

/// The tail's thickness where it leaves the head, over the head's; and
/// how round the join is (a smooth union's width).
const _tailRoot = 0.75;
const _fillet = 1.8;

/// One drop's head and tail, a chain of beads from the head back.
typedef _Drop = List<({Offset at, double r})>;

/// The mark at one moment: the two drops, how they're bent, how far the
/// liquid between them reaches.
class _Frame {
  new({required this.drops, required this.m, required this.k});

  /// The play's frame at [t] (0 to 1 in the loop), in [_room]'s units
  /// about the room's middle.
  factory at(double t) {
    final u = (t % 1) * _loop - (_loop - _play);
    if (u <= 0) {
      return _Frame(
        drops: [
          for (final s in [1, -1]) [(at: Offset(s * _apart, 0), r: _r0)],
        ],
        m: _Bend.identity,
        k: _kRest,
      );
    }
    // The way the drops go now: their turn and their way out, a
    // millisecond either side.
    final turn = (_angle(u + 1) - _angle(u - 1)) / 2;
    final outward = (_h(u + 1) - _h(u - 1)) / 2;
    // The tail's length grows with the drop's speed, up to [_tail]; it's
    // drawn in as the two become one, so no tip is left poking out of the
    // one drop.
    final h = _h(u);
    final speed = Offset(h * turn, outward).distance;
    final length =
        _tail *
        _tanh(speed * _lag) *
        Curves.easeInOut.transform(min(h / 1.8, 1));
    // The time it takes the drop to go that far: the tail runs back along
    // where it was over it.
    final reach = speed < 1e-9 ? 0.0 : length / speed;
    _Drop drop(int s) {
      // The tail: the spiral it's on, run back from the head as far as it
      // goes in [reach] milliseconds, so it lies along the way it came,
      // curved with its turn, and is as long as the drop is fast.
      final path = [
        for (var i = 0; i < _beads; i++)
          Offset.fromDirection(
                _angle(u) - min(turn * reach, _curl) * i / (_beads - 1),
                _back(h, _inward(outward) * reach * i / (_beads - 1)),
              ) *
              s.toDouble(),
      ];
      // Thinner the further back along the way it came, so a short tail
      // stays inside the head (a round drop) and a long one is a
      // teardrop's.
      final along = [0.0];
      for (var i = 1; i < _beads; i++) {
        along.add(along.last + (path[i] - path[i - 1]).distance);
      }
      final total = max(along.last, 1e-6);
      return [
        for (var i = 0; i < _beads; i++)
          (
            at: path[i],
            r: i == 0 ? _r0 : _r0 * _tailRoot * _taper(along[i] / total),
          ),
      ];
    }

    return _Frame(drops: [drop(1), drop(-1)], m: _wobble(u), k: _k(u));
  }

  final List<_Drop> drops;

  /// Each bead's squash and stretch: a unit circle's map (area kept).
  final _Bend m;

  /// How far the neck between the two reaches (a smooth union's width).
  final double k;
}

double _seg(double u, double a, double b, [Curve c = Curves.easeInOut]) =>
    c.transform(((u - a) / (b - a)).clamp(0.0, 1.0));

double _lerp(double a, double b, double v) => a + (b - a) * v;

// The play, in milliseconds from its start (#113, the owner's words: "the
// balls should spin clock wise. When they start to spin they should taper
// away from the direction they are moving. They should then merge together
// as one. Then separate kind of in a similar motion. They should look like
// droplets of water or gel"):
//    0 to  200  the two start to turn clockwise, tails growing behind them;
//  200 to  450  they spiral in, faster, each head closing on the other's
//               tail, a neck reaching between them, and join;
//  450 to  700  one drop, squashed by the meeting, settling;
//  700 to  900  still turning, two heads bulge out of it, a neck between;
//  900 to 1300  it parts, and the two spiral out, their tails behind them;
// 1300 to 1500  they slow into their places, the tails drawn in, a wobble.
// Clockwise on screen: the angle grows, and y points down. A full turn
// over the play, at most about 17 degrees a tick, so it never strobes.

// The beats, in milliseconds of the play.
const double _in0 = 200; // the spiral in starts
const double _in1 = 540; // the two are one
const double _out0 = 540; // the split starts
const double _out1 = 1250; // they're in their places
const double _neckIn0 = 360; // the neck reaches out
const double _neckIn1 = 520;
const double _neckOut0 = 540; // the neck draws in
const double _neckOut1 = 1050;

/// Half the distance between the two.
double _h(double u) {
  if (u < _in0) return _apart;
  if (u < _in1) {
    return _lerp(_apart, 0, _seg(u, _in0, _in1, const Cubic(0.45, 0, 0.7, 1)));
  }
  if (u < _out0) return 0;
  return _lerp(
    0,
    _apart,
    _seg(u, _out0, _out1, const Cubic(0.25, 0.3, 0.45, 1)),
  );
}

/// The turn so far: the spin's speed eases up from the start, holds, and
/// eases off into the settle, a whole turn in all.
double _angle(double u) => 2 * pi * _turn[u.clamp(0, _play).round()];

/// The share of the turn made by each millisecond of the play.
final List<double> _turn = () {
  double speed(double u) =>
      Curves.easeInOut.transform((u / _spinUp).clamp(0.0, 1.0)) *
      Curves.easeInOut.transform(((_spinEnd - u) / _spinDown).clamp(0.0, 1.0));
  final sums = List<double>.filled(_play.round() + 1, 0);
  for (var u = 1; u < sums.length; u++) {
    sums[u] = sums[u - 1] + speed(u - 0.5);
  }
  return [for (final s in sums) s / sums.last];
}();
const double _spinUp = 260;
const double _spinDown = 300;
const double _spinEnd = 1480;

/// Where a tail reaches back to, from the middle, for a drop [h] from it
/// that went [out] outward: further out, or nearer in but never past the
/// middle, which it closes on smoothly.
double _back(double h, double out) {
  final x = h - out;
  return (x + sqrt(x * x + 0.16)) / 2;
}

/// How much of a drop's way out its tail runs back along: all of it
/// coming in; on the way out a little, so the tail trails behind its turn
/// rather than back into the middle, where the other head hides it.
double _inward(double out) => out <= 0 ? out : out * 0.3;

/// A tail bead's radius, from the head (0) to the tail's tip (1): it
/// thins to a soft point.
double _taper(double x) => 1 - 0.68 * x;

/// The squash of the drops: the one drop's as the two meet (across the
/// way they met), and theirs as they settle (along their turn).
_Bend _wobble(double u) {
  const from = _in1 - 40;
  const to = _out0 + 120;
  if (u >= from && u < to) {
    final s = (u - from) / (to - from);
    return _Bend.stretch(
      _angle(_in1) + pi / 2,
      1 + 0.22 * exp(-2.5 * s) * sin(2 * pi * s + 0.4),
    );
  }
  if (u >= _out1) {
    final s = (u - _out1) / (_play - _out1);
    return _Bend.stretch(
      _angle(u) + pi / 2,
      1 + 0.1 * exp(-2 * s) * sin(3 * pi * s),
    );
  }
  return _Bend.identity;
}

/// The neck's reach: out as they spiral in, so the ticks before they are
/// one show a bridge between them, and in again as they part.
double _k(double u) {
  const most = 3.0;
  if (u < _neckIn0) return _kRest;
  if (u < _neckIn1) {
    return _lerp(_kRest, most, _seg(u, _neckIn0, _neckIn1, Curves.easeOut));
  }
  if (u < _neckOut0) return most;
  return _lerp(most, _kRest, _seg(u, _neckOut0, _neckOut1, Curves.easeOut));
}

double _tanh(double x) {
  final e = exp(-2 * x);
  return (1 - e) / (1 + e);
}

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
  final r = _r0 * s;
  final area = 2 * pi * r * r;

  // The field with every radius times [g]: each drop its head and its
  // tail's beads joined by tapered sticks (each the distance to its
  // segment less a radius run from one end's to the other's), the tail
  // run into the head with a fillet, as surface tension rounds it; the
  // two drops joined by the neck's smooth union.
  List<double> fieldAt(double g) {
    // Per drop: its beads as x, y, r (the first stick starts at the
    // tail's root), and a box round it past which it's only far.
    final drops = [
      for (final d in f.drops)
        [
          for (var b = 0; b < d.length; b++) ...[
            mid.dx + d[b].at.dx * s,
            mid.dy + d[b].at.dy * s,
            d[b].r * s * g,
          ],
        ],
    ];
    final reach = max(k, fillet) + 2 * cell;
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
    double from(double x, double y) {
      final lx = inv.a * x + inv.b * y;
      final ly = inv.c * x + inv.d * y;
      return sqrt(lx * lx + ly * ly);
    }

    double drop(List<double> d, Rect box, double px, double py) {
      if (!box.contains(Offset(px, py))) {
        // Far: only the sign and that it's past the neck's reach count.
        return reach;
      }
      final head = from(px - d[0], py - d[1]) - d[2];
      var tail = double.infinity;
      var x0 = d[0];
      var y0 = d[1];
      var r0 = d[2] * _tailRoot;
      for (var b = 3; b < d.length; b += 3) {
        final x1 = d[b];
        final y1 = d[b + 1];
        final r1 = d[b + 2];
        final abx = x1 - x0;
        final aby = y1 - y0;
        final len2 = abx * abx + aby * aby;
        final v = len2 < 1e-9
            ? 0.0
            : (((px - x0) * abx + (py - y0) * aby) / len2).clamp(0.0, 1.0);
        tail = min(
          tail,
          from(px - x0 - abx * v, py - y0 - aby * v) - (r0 + (r1 - r0) * v),
        );
        x0 = x1;
        y0 = y1;
        r0 = r1;
      }
      return _smin(head, tail, fillet);
    }

    final field = List<double>.filled((n + 1) * (n + 1), 0);
    for (var j = 0; j <= n; j++) {
      for (var i = 0; i <= n; i++) {
        // The room's edge is outside, so every outline closes inside it.
        if (i == 0 || j == 0 || i == n || j == n) {
          field[j * (n + 1) + i] = cell;
          continue;
        }
        final px = origin.dx + i * cell;
        final py = origin.dy + j * cell;
        field[j * (n + 1) + i] = _smin(
          drop(drops[0], boxes[0], px, py),
          drop(drops[1], boxes[1], px, py),
          k,
        );
      }
    }
    return field;
  }

  // The mass kept by thinning the whole drop, not by tracing further in,
  // which would wear a thin tail to a needle: the radii scaled to about
  // two drops' area (by the cells inside), the level then finding the
  // rest.
  final first = fieldAt(1);
  final inside = first.where((v) => v < 0).length * cell * cell;
  final g = inside <= 0 ? 1.0 : sqrt(area / inside).clamp(0.7, 1.0);
  final field = g > 0.99 ? first : fieldAt(g);
  return fieldOutline(field, n, cell, origin, area: area, step: s);
}
