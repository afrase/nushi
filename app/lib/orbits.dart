import 'dart:math';
import 'dart:typed_data';

import 'package:nushi/logo.dart';

/// The mark as a small planetary system, on its grid (units, y down): the
/// light is a fixed sun at the origin, the agents are planets in circular
/// orbits on the rings. Planets pull on each other (weakly), merge when
/// they touch, fall into the sun, and are pulled back from past [bound].
///
/// Fixed steps of [dt] (kick, drift, kick: velocity Verlet), so an orbit
/// keeps its radius for hours. Every planet lives in a slot of fixed
/// arrays: nothing is allocated while stepping.
class Orbits {
  new() {
    reset(fade: false);
  }

  /// The step, in seconds.
  static const double dt = 1 / 120;

  /// The sun's pull (G·M): the outer ring goes round once in 48 s, the
  /// inner one in about 23 s.
  static const double mu = 4 * pi * pi * 31 * 31 * 31 / (48 * 48);

  /// A planet's pull per square unit of its radius (a disc's mass), about
  /// a hundredth of the sun's for a ring's planet. Only while disturbed:
  /// the mark's planets pulling on each other would take them a few
  /// percent off their rings within hours.
  static const double kappa = 0.2;

  /// Planets at most, not counting those fading out.
  static const most = 12;

  /// A planet added by a click.
  static const added = 2.4;

  /// The fastest a released planet goes, in units a second.
  static const fastest = 40.0;

  /// Seconds without a touch before a disturbed system goes back to the
  /// mark, and how long the planets take to fade.
  static const rest = 30.0;
  static const fadeTime = 1.5;

  /// How far the pointer reaches and the most it pulls (the sun pulls
  /// about 0.53 at the outer ring).
  static const reach = 60.0;
  static const pointerPull = 0.3;

  static const _sunSoft2 = 1.0;
  static const _pairSoft2 = 9.0;
  static const _slots = 24;

  final x = Float64List(_slots);
  final y = Float64List(_slots);
  final vx = Float64List(_slots);
  final vy = Float64List(_slots);
  final _ax = Float64List(_slots);
  final _ay = Float64List(_slots);

  /// A planet's radius and opacity.
  final radius = Float64List(_slots);
  final alpha = Float64List(_slots);

  /// What each slot holds: [free], [live] or [fading] (out).
  final state = Uint8List(_slots);
  static const free = 0;
  static const live = 1;
  static const fading = 2;

  /// Slots in use go up to (not including) this.
  int get slots => _slots;

  /// The planet held by the pointer (moved by it, not by gravity), or -1.
  int held = -1;

  /// Seconds since the last touch, and whether anything moved the
  /// planets off their own orbits since the system was last the mark.
  double idle = 0;
  bool disturbed = false;

  /// Where the pointer is, while it's over the system, and seconds since
  /// it moved: a pointer left still stops pulling once the system rests.
  double _px = 0;
  double _py = 0;
  bool _pointer = false;
  double _still = rest;

  /// Past this distance from the sun a planet is pulled back and slowed;
  /// past twice it, it's gone. About the visible area.
  double bound = 400;

  double _acc = 0;

  /// The circular orbit's speed at [r].
  static double circular(double r) {
    final d2 = r * r + _sunSoft2;
    return sqrt(mu * r * r / (d2 * sqrt(d2)));
  }

  /// Live planets.
  int get count {
    var n = 0;
    for (var i = 0; i < _slots; i++) {
      if (state[i] == live) n++;
    }
    return n;
  }

  /// Back to the mark: with [fade], the planets fade out where they are
  /// as the mark's fade in on their rings; else at once.
  void reset({bool fade = true}) {
    for (var i = 0; i < _slots; i++) {
      if (fade && state[i] == live) {
        state[i] = fading;
      } else if (!fade) {
        state[i] = free;
      }
    }
    held = -1;
    for (final (r, deg, size) in markBeads) {
      final a = deg * pi / 180;
      _put(r * cos(a), r * sin(a), size, fade ? 0 : 1);
    }
    idle = 0;
    disturbed = false;
    _accelerate();
  }

  /// A planet at ([px], [py]) on a circular orbit, unless there are
  /// [most] or it's in the sun.
  bool add(double px, double py) {
    if (count >= most || px * px + py * py <= sunRadius * sunRadius) {
      return false;
    }
    if (_put(px, py, added, 1) < 0) return false;
    touch();
    disturbed = true;
    _accelerate();
    return true;
  }

  int _put(double px, double py, double size, double opacity) {
    for (var i = 0; i < _slots; i++) {
      if (state[i] != free) continue;
      final r = sqrt(px * px + py * py);
      final v = r == 0 ? 0.0 : circular(r) / r;
      // Clockwise on screen (y down), as the angles grow.
      x[i] = px;
      y[i] = py;
      vx[i] = -py * v;
      vy[i] = px * v;
      radius[i] = size;
      alpha[i] = opacity;
      state[i] = live;
      return i;
    }
    return -1;
  }

  /// The live planet at ([px], [py]), within [slop] of its edge, the
  /// nearest; or -1.
  int hit(double px, double py, double slop) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < _slots; i++) {
      if (state[i] != live) continue;
      final dx = x[i] - px;
      final dy = y[i] - py;
      final d = sqrt(dx * dx + dy * dy);
      if (d <= radius[i] + slop && d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  /// A touch: the pointer moved, pressed or let go.
  void touch() => idle = 0;

  /// The pointer is at ([px], [py]), or (null) left.
  void point(double? px, double? py) {
    _pointer = px != null && py != null;
    if (_pointer) {
      _px = px!;
      _py = py!;
      _still = 0;
      touch();
    }
  }

  /// Takes planet [i]: it stops and follows [moveHeld].
  void grab(int i) {
    held = i;
    vx[i] = 0;
    vy[i] = 0;
    disturbed = true;
    touch();
  }

  void moveHeld(double px, double py) {
    if (held < 0) return;
    x[held] = px;
    y[held] = py;
    touch();
  }

  /// Lets the held planet go at ([ux], [uy]), units a second, capped.
  void release(double ux, double uy) {
    if (held < 0) return;
    final s = sqrt(ux * ux + uy * uy);
    final k = s > fastest ? fastest / s : 1.0;
    vx[held] = ux * k;
    vy[held] = uy * k;
    held = -1;
    touch();
    _accelerate();
  }

  /// Runs [seconds] of the system in steps (a tenth of a second at most:
  /// after a pause it goes on, it doesn't catch up).
  void advance(double seconds) {
    _acc += min(seconds, 0.1);
    while (_acc >= dt) {
      step();
      _acc -= dt;
    }
  }

  /// One step of [dt].
  void step() {
    const h = dt / 2;
    for (var i = 0; i < _slots; i++) {
      if (state[i] == free || i == held) continue;
      vx[i] += _ax[i] * h;
      vy[i] += _ay[i] * h;
      x[i] += vx[i] * dt;
      y[i] += vy[i] * dt;
    }
    _accelerate();
    for (var i = 0; i < _slots; i++) {
      if (state[i] == free || i == held) continue;
      vx[i] += _ax[i] * h;
      vy[i] += _ay[i] * h;
    }
    if (_collide()) _accelerate();
    _fade();
    idle += dt;
    _still += dt;
    if (disturbed && idle >= rest && held < 0) reset();
  }

  void _accelerate() {
    final pulls = _pointer && _still < rest;
    for (var i = 0; i < _slots; i++) {
      if (state[i] == free) continue;
      final xi = x[i];
      final yi = y[i];
      var d2 = xi * xi + yi * yi + _sunSoft2;
      var f = -mu / (d2 * sqrt(d2));
      var ax = xi * f;
      var ay = yi * f;
      final r = sqrt(xi * xi + yi * yi);
      if (r > bound) {
        f = -0.05 * (r - bound) / r;
        ax += xi * f;
        ay += yi * f;
      }
      if (state[i] == live && disturbed) {
        for (var j = 0; j < _slots; j++) {
          if (j == i || state[j] != live) continue;
          final dx = x[j] - xi;
          final dy = y[j] - yi;
          d2 = dx * dx + dy * dy + _pairSoft2;
          f = kappa * radius[j] * radius[j] / (d2 * sqrt(d2));
          ax += dx * f;
          ay += dy * f;
        }
      }
      if (state[i] == live && pulls) {
        final dx = _px - xi;
        final dy = _py - yi;
        final d = sqrt(dx * dx + dy * dy);
        if (d < reach && d > 0) {
          final k = 1 - d / reach;
          f = pointerPull * k * k / d;
          ax += dx * f;
          ay += dy * f;
          disturbed = true;
        }
      }
      _ax[i] = ax;
      _ay[i] = ay;
    }
  }

  /// Planets that touch merge (mass and momentum kept), the sun takes
  /// those that fall into it, and those far past [bound] are gone; past
  /// [bound], planets slow down. Whether a planet went.
  bool _collide() {
    var gone = false;
    const damp = 1 - 0.5 * dt;
    for (var i = 0; i < _slots; i++) {
      if (state[i] == free) continue;
      final r2 = x[i] * x[i] + y[i] * y[i];
      if (i != held && (r2 < sunRadius * sunRadius || r2 > 4 * bound * bound)) {
        _drop(i);
        gone = true;
        continue;
      }
      if (r2 > bound * bound) {
        vx[i] *= damp;
        vy[i] *= damp;
      }
    }
    for (var i = 0; i < _slots; i++) {
      if (state[i] != live || i == held) continue;
      for (var j = i + 1; j < _slots; j++) {
        if (state[j] != live || j == held) continue;
        final dx = x[j] - x[i];
        final dy = y[j] - y[i];
        final touching = radius[i] + radius[j];
        if (dx * dx + dy * dy < touching * touching) {
          merge(i, j);
          gone = true;
        }
      }
    }
    return gone;
  }

  /// Planet [j] into [i]: their masses (as their discs' areas), centre of
  /// mass and momentum.
  void merge(int i, int j) {
    final mi = radius[i] * radius[i];
    final mj = radius[j] * radius[j];
    final m = mi + mj;
    x[i] = (x[i] * mi + x[j] * mj) / m;
    y[i] = (y[i] * mi + y[j] * mj) / m;
    vx[i] = (vx[i] * mi + vx[j] * mj) / m;
    vy[i] = (vy[i] * mi + vy[j] * mj) / m;
    radius[i] = sqrt(m);
    alpha[i] = max(alpha[i], alpha[j]);
    _drop(j);
  }

  void _drop(int i) {
    state[i] = free;
    if (held == i) held = -1;
  }

  void _fade() {
    const step = dt / fadeTime;
    for (var i = 0; i < _slots; i++) {
      if (state[i] == fading) {
        alpha[i] -= step;
        if (alpha[i] <= 0) _drop(i);
      } else if (state[i] == live && alpha[i] < 1) {
        alpha[i] = min(1, alpha[i] + step);
      }
    }
  }
}
