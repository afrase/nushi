import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/logo.dart';
import 'package:nushi/orbits.dart';

double _r(Orbits o, int i) => sqrt(o.x[i] * o.x[i] + o.y[i] * o.y[i]);

List<int> _live(Orbits o) => [
  for (var i = 0; i < o.slots; i++)
    if (o.state[i] == Orbits.live) i,
];

/// An empty system: no planets, so only the sun pulls.
Orbits _empty() {
  final o = Orbits();
  o.state.fillRange(0, o.slots, Orbits.free);
  return o;
}

void main() {
  test("the mark's planets keep their rings, for 10,000 steps and an hour", () {
    final o = Orbits();
    expect(_live(o), hasLength(markBeads.length));
    final start = [for (final i in _live(o)) _r(o, i)];
    for (final steps in [10000, 120 * 3600]) {
      for (var s = 0; s < steps; s++) {
        o.step();
      }
      final live = _live(o);
      expect(live, hasLength(markBeads.length));
      for (final (k, i) in live.indexed) {
        expect((_r(o, i) - start[k]).abs() / start[k], lessThan(0.01));
      }
    }
    // Round in tens of seconds: the outer ring's 48 s, the inner's 23 s.
    final w = Orbits.circular(31) / 31;
    expect(2 * pi / w, closeTo(48, 0.1));
  });

  test('a planet added by a click goes round at its distance', () {
    final o = _empty();
    expect(o.add(0, -60), isTrue);
    o.disturbed = false; // no going back to the mark mid-test
    final i = _live(o).single;
    for (var s = 0; s < 10000; s++) {
      o.step();
    }
    expect((_r(o, i) - 60).abs() / 60, lessThan(0.01));
    // Clicks in the sun add nothing; past the most, nothing either.
    expect(o.add(1, 1), isFalse);
    for (var k = 1; k < Orbits.most; k++) {
      expect(o.add(20.0 + 10 * k, 0), isTrue);
    }
    expect(o.add(200, 0), isFalse);
    expect(o.count, Orbits.most);
  });

  test('planets that touch merge, keeping mass and momentum', () {
    final o = _empty()
      ..add(0, 50)
      ..add(3, 50);
    final [i, j] = _live(o);
    o.vx[i] = 2;
    o.vy[i] = -1;
    o.vx[j] = -4;
    o.vy[j] = 3;
    final mi = o.radius[i] * o.radius[i];
    final mj = o.radius[j] * o.radius[j];
    final px = mi * o.vx[i] + mj * o.vx[j];
    final py = mi * o.vy[i] + mj * o.vy[j];
    o.merge(i, j);
    final m = o.radius[i] * o.radius[i];
    expect(_live(o), [i]);
    expect(m, closeTo(mi + mj, 1e-9));
    expect(m * o.vx[i], closeTo(px, 1e-9));
    expect(m * o.vy[i], closeTo(py, 1e-9));
    expect(o.x[i], closeTo(1.5, 1e-9));

    // A step merges planets that touch.
    o
      ..add(40, 0)
      ..add(41, 0)
      ..step();
    expect(o.count, 2);
  });

  test('a planet falling into the sun is taken', () {
    final o = _empty()..add(12, 0);
    final i = _live(o).single;
    o
      ..vx[i] = 0
      ..vy[i] = 0;
    for (var s = 0; s < 120 * 10 && o.count > 0; s++) {
      o.step();
    }
    expect(o.count, 0);
  });

  test('a planet flung away is pulled back, or gone far past the bound', () {
    final o = _empty()
      ..bound = 100
      ..add(0, 90);
    final i = _live(o).single;
    o
      ..grab(i)
      ..release(0, 1000); // capped at the fastest
    expect(o.vy[i], Orbits.fastest);
    var far = 0.0;
    for (var s = 0; s < 120 * 20; s++) {
      o.step();
      far = max(far, _r(o, i));
    }
    expect(o.state[i], Orbits.live);
    expect(far, inExclusiveRange(100, 200));
    expect(_r(o, i), lessThan(130));

    o
      ..x[i] = 250
      ..y[i] = 0
      ..step();
    expect(o.count, 0);
  });

  test('left alone for half a minute, it goes back to the mark', () {
    final o = Orbits()
      ..add(50, 50)
      ..add(-70, 10);
    final first = _live(o).first;
    o
      ..grab(first)
      ..moveHeld(-40, 0)
      ..release(5, 5);
    expect(o.disturbed, isTrue);
    // Held, it never goes back.
    o.grab(_live(o).last);
    for (var s = 0; s < 120 * 40; s++) {
      o.step();
    }
    expect(o.state.where((s) => s == Orbits.fading), isEmpty);
    o.release(0, 0);
    for (var s = 0; s < 120 * 29; s++) {
      o.step();
    }
    expect(o.state.where((s) => s == Orbits.fading), isEmpty);
    // At 30 s: the planets fade out as the mark's fade in.
    for (var s = 0; s < 120 * 2; s++) {
      o.step();
    }
    expect(o.state.where((s) => s == Orbits.fading), isNotEmpty);
    for (var s = 0; s < 120 * 2; s++) {
      o.step();
    }
    expect(o.disturbed, isFalse);
    expect(o.state.where((s) => s == Orbits.fading), isEmpty);
    final live = _live(o);
    expect(live, hasLength(markBeads.length));
    for (final (k, i) in live.indexed) {
      final (ring, _, size) = markBeads[k];
      expect(o.alpha[i], 1);
      expect(o.radius[i], size);
      expect((_r(o, i) - ring).abs() / ring, lessThan(0.01));
    }
  });
}
