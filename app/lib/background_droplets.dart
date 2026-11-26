part of 'background_mark.dart';

// The background mark's shapes (#113): the two droplets at each moment of
// the play, set tick by tick (`background_trace.dart` traces them).

/// The room the amounts below are in: `ChatDot`'s (its size times 1.6).
const double _room = 11.2;

/// A drop's radius at rest, and half the distance between the two.
const _r0 = 2.0;
const double _apart = 2.68;

/// The neck's reach at rest: too short to join the two.
const _kRest = 0.4;

/// The play's length and the loop's, in milliseconds, and a tick's.
const double _play = BackgroundMark.playTicks * 1000.0 / pulseRate;
const double _loop = BackgroundMark.ticks * 1000.0 / pulseRate;
const double _tickMs = 1000.0 / pulseRate;

/// A drop's tail lies along the way its head just came, so it curves as
/// it turned: at most [_tail] long (in [_room]'s units, from the head's
/// middle), of which the first [_hid] is inside the head and doesn't
/// show. How much of the rest shows is set tick by tick ([_tails]). Drawn
/// with [_beads] beads.
const double _tail = 3.8;
const _hid = 1.3;

/// How far out a tail's tip is flung, over its length: it lies a little
/// outside the way its head came, so it curves less than the turn and
/// never hooks in.
const _fling = 0.05;

/// The most of the turn a tail runs back along, so it never curls.
const double _curl = 1.2;
const _beads = 8;

/// The tail's thickness where it leaves the head, over the head's; and
/// how round the join is (a smooth union's width).
const _tailRoot = 1.0;

/// How long a tail is before it leaves the head that thick.
const double _rootLength = 2.6;
const _fillet = 0.8;

/// How round the thread is where it meets the heads.
const _threadFillet = 0.6;

/// One drop's head, then its tail, a chain of beads from the head's middle
/// back.
typedef _Drop = List<({Offset at, double r})>;

/// The mark at one moment: the two drops, how they're bent, how far the
/// liquid between them reaches.
class _Frame {
  new({
    required this.drops,
    required this.m,
    required this.k,
    this.neck = 0,
    this.pinch = 0,
  });

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
    // The tail: none, or from where it starts to show to its whole
    // length, as much as this tick shows of it ([_tails]). The drop's
    // speed only says which way it lies.
    final h = _h(u);
    final speed = Offset(h * turn, outward).distance;
    final shown = _key(_tails, u).clamp(0.0, 1.0);
    final length = shown <= 0 ? 0.0 : _hid + (_tail - _hid) * shown;
    // The head grows as the two overlap, so the one drop holds both:
    // by how far apart they are before the bend, which draws them in or
    // out along the line between them.
    final long = _key(_longs, u);
    final head = _headRadius(h * (1 + long));
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
                _back(h, _inward(outward) * reach * i / (_beads - 1)) +
                    _fling * length * i / (_beads - 1),
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
      // A short tail is thin where it leaves the head too, so it ends in
      // a point rather than a stub.
      final root = head * _tailRoot * min(1, total / _rootLength);
      return [
        (at: path[0], r: head),
        for (var i = 0; i < _beads; i++)
          (at: path[i], r: root * _taper(along[i] / total)),
      ];
    }

    return _Frame(
      drops: [drop(1), drop(-1)],
      m: _bend(u, long),
      k: _key(_ks, u),
      neck: _key(_necks, u),
      pinch: _key(_pinches, u),
    );
  }

  final List<_Drop> drops;

  /// Each bead's squash and stretch: a unit circle's map (area kept).
  final _Bend m;

  /// How far the neck between the two reaches (a smooth union's width).
  final double k;

  /// Half the width of the thread drawn from head to head while the two
  /// are about to touch or to part, or 0 for none.
  final double neck;

  /// How much the one drop is drawn in across its middle, so its two
  /// heads show as a waist and it's never a plain oval or a pill.
  final double pinch;
}

// The play (#113, the owner's words: "the balls should spin clock wise.
// When they start to spin they should taper away from the direction they
// are moving. They should then merge together as one. Then separate kind
// of in a similar motion. They should look like droplets of water or
// gel"), set tick by tick, as it's seen, in the tables below:
//  0 to  7  the two start to turn clockwise, slowly and then faster,
//           round at first, then tails growing behind them;
//  7 to 11  they spiral in, faster; a thin neck reaches between them at 9
//           and thickens, and they join;
// 11 to 15  the tails are drawn into the one drop, which turns on, a
//           little long across its two heads;
// 15 to 25  two heads bulge out of it, still turning, the waist between
//           them thinning to a thread at 24 that parts at 25;
// 25 to 33  the two spiral out, tails behind them, slow, and a little
//           past their places, the tails drawn in;
// 30 to 38  they wobble into their places like jelly: squat as the tail
//           lands, long, squat again, less each swing, round only at
//           rest (the owner: "the ball [should] wobble also like the
//           original not become solid until is settled").
// Clockwise on screen: the angle grows, and y points down. Twice round
// over the play, faster tick after tick into the merge and slower out
// of it ([_turns]), and squashed and stretched all the way ([_longs]):
// the owner, of the first take, "the first one also had the squash and
// [stretch] more to give it more life", and at a dot's size it "appears
// to spin around multiple times" and "looks better".

/// Half the distance between the two, at each tick of the play: as they
/// settle, a little past their places and back.
const _hs = [
  2.68, 2.68, 2.68, 2.68, 2.67, 2.64, 2.58, 2.48, 2.36, 2.22, //
  2.06, 1.80, 1.45, 1.00, 0.62, 0.32, 0.56, 0.84, 1.08, 1.32, //
  1.55, 1.74, 1.88, 1.98, 2.06, 2.14, 2.24, 2.35, 2.46, 2.57, //
  2.66, 2.72, 2.74, 2.72, 2.69, 2.65, 2.64, 2.66, 2.68,
];

/// The neck's reach at each tick: out as they near, so a neck joins
/// them before they touch, and in again as they part, so it thins.
const _ks = [
  0.4, 0.4, 0.4, 0.4, 0.4, 0.5, 0.65, 0.8, 0.95, 1.0, //
  1.0, 1.0, 0.9, 0.7, 0.9, 1.2, 1.4, 0.6, 0.4, 0.4, //
  0.5, 0.65, 0.8, 0.72, 0.62, 0.5, 0.4, 0.4, 0.4, 0.4, //
  0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4,
];

/// The thread between the two heads at each tick: a thin one as they
/// first reach for each other, and one thinning as they part, so a neck
/// shows on the ticks just before and after they're one.
const _necks = [
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, //
  0.25, 0.6, 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, //
  0.0, 0.0, 0.0, 0.5, 0.35, 0.2, 0.0, 0.0, 0.0, 0.0, //
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
];

/// The one drop's waist at each tick: still there as the two settle into
/// one, and back as soon as it stretches to part.
const _pinches = [
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, //
  0.0, 0.0, 0.3, 0.3, 0.25, 0.0, 0.0, 0.2, 0.3, 0.25, //
  0.15, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, //
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
];

/// How wide the waist's band is.
const _pinchWidth = 1.3;

/// How much of its tail each drop shows at each tick. The head leads:
/// the drop is seen to move first, still round, and pulls its tail out
/// over the ticks after as it gathers speed, a little more each tick,
/// never there on one tick and whole two ticks on; it's drawn in over
/// the ticks the two become one, grown again as they part, and catches
/// its head up over the ticks the drop slows into its place.
const _tails = [
  0.0, 0.0, 0.0, 0.2, 0.34, 0.47, 0.58, 0.69, 0.8, 0.92, //
  0.9, 0.65, 0.4, 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, //
  0.0, 0.1, 0.25, 0.45, 0.65, 0.82, 0.92, 0.95, 0.88, 0.72, //
  0.54, 0.38, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
];

/// [v] (a value at each tick) at [u] milliseconds into the play, smoothly
/// between ticks (Catmull-Rom), so the speeds read from it don't jump.
double _key(List<double> v, double u) {
  assert(v.length == BackgroundMark.playTicks + 1, 'a value a tick');
  final x = (u / _tickMs).clamp(0.0, v.length - 1.0);
  final i = min(x.floor(), v.length - 2);
  final f = x - i;
  final p0 = v[max(i - 1, 0)];
  final p1 = v[i];
  final p2 = v[i + 1];
  final p3 = v[min(i + 2, v.length - 1)];
  return p1 +
      0.5 *
          f *
          (p2 -
              p0 +
              f *
                  (2 * p0 -
                      5 * p1 +
                      4 * p2 -
                      p3 +
                      f * (3 * (p1 - p2) + p3 - p0)));
}

/// Half the distance between the two.
double _h(double u) => _key(_hs, u);

/// The radius of two heads [h] from the middle whose union holds two
/// rest drops: [_r0] apart, more as they overlap.
double _headRadius(double h) {
  const want = 2 * pi * _r0 * _r0;
  double area(double r) {
    final d = 2 * h;
    if (d >= 2 * r) return 2 * pi * r * r;
    final lens =
        2 * r * r * acos(d / (2 * r)) - d / 2 * sqrt(4 * r * r - d * d);
    return 2 * pi * r * r - lens;
  }

  var lo = _r0;
  var hi = _r0 * sqrt2;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (area(mid) < want) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// The turn so far, smoothly between ticks.
double _angle(double u) => _key(_turned, u);

/// How far the two turn on each tick of the play, in degrees: twice
/// round in all, so the whirl is seen at the size of a chat's dot, where
/// a tail is under a pixel. From rest they gather speed tick after tick
/// as they spiral in, never up to speed at once and held, fastest while
/// they're one drop (as a skater drawing in her arms); they lose it the
/// same way as they part, and ease to a stop in their places. The pair
/// looks the same after half a turn, so 35 degrees a tick is far from
/// seeming to turn back.
const _turns = [
  4.0, 7.0, 10.0, 13.0, 16.0, 19.0, 22.0, 25.0, 28.0, 30.2, //
  32.0, 33.6, 34.6, 35.0, 35.0, 34.4, 33.0, 31.8, 30.4, 29.0, //
  27.6, 26.2, 24.8, 23.4, 22.0, 20.2, 18.0, 15.6, 12.8, 10.0, //
  7.2, 4.8, 2.6, 1.2, 0.4, 0.2, 0.0, 0.0,
];

/// The turn at each tick of the play: whole half turns by its end, so
/// the two are side by side again as at rest.
final List<double> _turned = () {
  assert(_turns.length == BackgroundMark.playTicks, 'a turn a tick');
  final sums = [0.0];
  for (final t in _turns) {
    sums.add(sums.last + t);
  }
  assert((sums.last / 180 - (sums.last / 180).round()).abs() < 1e-6, 'level');
  return [for (final s in sums) s * pi / 180];
}();

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
double _inward(double out) => out <= 0 ? out * 0.5 : out * 0.3;

/// A tail bead's radius, from the head (0) to the tail's tip (1): it
/// thins to a soft point.
double _taper(double x) => 1 - 0.86 * x;

/// How much longer along its turn than round each drop is at each tick
/// (less than 0: squat along it, long across). Squash and stretch give
/// the play its life, most of all at a dot's size, where it's what's
/// seen: a crouch as the drops start, long along their way as they gather
/// speed, short and full as the two land in each other, long across its
/// two heads as the one drop springs (a bar that turns: never a plain
/// disc, and never long the other way, so its spin shows and doesn't
/// seem to jump), long along their way again as they part, and jelly
/// until they're still:
/// squat as the tail lands in the head, long as it springs back, squat
/// again, less each swing, and round only at rest.
const _longs = [
  0.0, -0.12, 0.06, 0.12, 0.16, 0.19, 0.23, 0.26, 0.27, 0.27, //
  0.16, 0.08, 0.02, -0.02, -0.04, -0.06, -0.15, -0.22, -0.22, -0.16, //
  -0.08, 0.0, 0.06, 0.1, 0.12, 0.14, 0.2, 0.22, 0.16, 0.06, //
  -0.1, -0.18, -0.15, 0.0, 0.12, 0.1, 0.0, -0.04, 0.0,
];

/// The squash and stretch of the drops: [long] along their turn.
_Bend _bend(double u, double long) =>
    long == 0 ? _Bend.identity : _Bend.stretch(_angle(u) + pi / 2, 1 + long);
