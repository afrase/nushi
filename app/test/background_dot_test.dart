// A chat whose turn ended while its background tasks run wears its own
// mark (#113): two dots side by side that now and then spin clockwise as
// droplets, merge and split. At rest it asks for nothing; its play draws
// outlines traced once and kept.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The background mark [dot] draws, if it draws one.
BackgroundMark? _markOf(WidgetTester tester, Finder dot) {
  final paints = find.descendant(of: dot, matching: find.byType(CustomPaint));
  for (final p in tester.widgetList<CustomPaint>(paints)) {
    if (p.painter case final BackgroundMark mark) return mark;
  }
  return null;
}

/// The room a chat's mark has.
const double _room = ChatDot.size * 1.6;

const _roomSize = Size.square(_room);

/// A 60 Hz display's frame.
const _vsync = Duration(microseconds: Duration.microsecondsPerSecond ~/ 60);

var _counting = false;
var _frames = 0;

/// The frames drawn over [span], pumped as a 60 Hz display would; with
/// [atRest], only those drawn while the marks rest.
Future<int> _framesOver(
  WidgetTester tester,
  Duration span, {
  bool atRest = false,
}) async {
  var n = 0;
  for (var t = Duration.zero; t < span; t += _vsync) {
    _frames = 0;
    _counting = true;
    final resting = !backgroundMarkPlays;
    await tester.pump(_vsync);
    _counting = false;
    if (!atRest || (resting && !backgroundMarkPlays)) n += _frames;
  }
  return n;
}

/// Pumps until the marks start to play, at most one loop.
Future<void> _untilPlay(WidgetTester tester) async {
  for (var t = Duration.zero; t < BackgroundMark.period; t += _vsync) {
    if (backgroundMarkPlays) return;
    await tester.pump(_vsync);
  }
  fail('it never played');
}

/// Background chats' dots, the clock running as in the app (no still
/// frame), with Reduce Motion when [still], under [tickers].
Future<Daemon> _dots(
  WidgetTester tester, {
  int count = 1,
  bool still = false,
  bool tickers = true,
}) async {
  Shine.stopAt = null;
  addTearDown(() => Shine.stopAt = 0);
  final d = await FakeDaemon([
    for (var i = 0; i < count; i++)
      chat(
        'b$i',
        'claude',
        'Sort the ledger $i',
        status: ChatStatus(background: 1),
      )..done = true,
  ]).connect(tester);
  await tester.pumpWidget(
    themed(
      TickerMode(
        enabled: tickers,
        child: Column(
          children: [
            for (var i = 0; i < count; i++) ChatDot(chat: d.chats['b$i']!),
          ],
        ),
      ),
      still: still,
    ),
  );
  await tester.pump();
  return d;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized().addPersistentFrameCallback((
      _,
    ) {
      if (_counting) _frames++;
    });
  });

  for (final still in [false, true]) {
    final how = still ? 'with Reduce Motion' : 'moving';
    testWidgets('a chat in the background wears the two dots, $how', (
      tester,
    ) async {
      final d = await FakeDaemon([
        chat(
          'b',
          'claude',
          'Sort the ledger',
          status: ChatStatus(background: 2),
        )..done = true,
        chat('i', 'codex', 'Idle one'),
        chat('w', 'codex', 'Busy one', status: ChatStatus(busy: true)),
      ]).connect(tester);
      await tester.pumpWidget(
        themed(
          ListView(
            children: [
              ChatRow(d.chats['b']!, onTap: () {}),
              ChatRow(d.chats['i']!, onTap: () {}),
              ChatRow(d.chats['w']!, onTap: () {}),
              const PhaseDot(ChatPhase.background),
            ],
          ),
          still: still,
        ),
      );
      await tester.pump();
      expect(d.chats['b']!.phase, ChatPhase.background);
      final t = NushiTheme.of(tester.element(find.byType(ChatRow).first)).t;
      Finder rowDot(String title) => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(ChatRow)),
        matching: find.byType(ChatDot),
      );
      final mark = _markOf(tester, rowDot('Sort the ledger'));
      expect(mark, isNotNull, reason: "the chat's dot");
      expect(mark!.color, t.running);
      if (still) expect(mark.t, 0, reason: 'the still frame');
      final group = _markOf(tester, find.byType(PhaseDot));
      expect(group?.color, t.running, reason: "a collapsed group's dot");
      expect(group?.t, 0, reason: 'a still mark');
      expect(_markOf(tester, rowDot('Idle one')), isNull);
      // In the dot's room, as every state's mark: no row shifts.
      for (final title in ['Sort the ledger', 'Idle one', 'Busy one']) {
        final size = tester.getSize(rowDot(title));
        expect(size.width, closeTo(_room, 0.01), reason: title);
        expect(size.height, closeTo(_room, 0.01), reason: title);
      }
      d.dispose();
    });
  }

  for (final b in Brightness.values) {
    testWidgets('golden, the background dot beside idle and working, '
        '${b.name}', (tester) async {
      final tokens = b == Brightness.dark ? Tokens.dark : Tokens.light;
      final d = await FakeDaemon([
        chat('i', 'codex', 'Idle one'),
        chat('b', 'claude', 'B', status: ChatStatus(background: 1))
          ..done = true,
        chat('w', 'claude', 'W', status: ChatStatus(busy: true)),
      ]).connect(tester);
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topLeft,
            child: enlarged(
              const Size(_room * 3 + 8, _room + 4),
              4,
              ColoredBox(
                color: tokens.window,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final id in ['i', 'b', 'w'])
                      ChatDot(chat: d.chats[id]!),
                  ],
                ),
              ),
            ),
          ),
          tokens: tokens,
          still: true,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile('goldens/background_dot_${b.name}.png'),
      );
      d.dispose();
    });
  }

  test("every tick's outline stays inside the dot's room", () {
    for (var i = 0; i < BackgroundMark.ticks; i++) {
      final b = backgroundMarkPath(
        _roomSize,
        i / BackgroundMark.ticks,
      ).getBounds();
      expect(
        b.left > 0.3 &&
            b.top > 0.3 &&
            b.right < _room - 0.3 &&
            b.bottom < _room - 0.3,
        isTrue,
        reason: 'tick $i: $b',
      );
    }
  });

  test('the still frame is two separate dots side by side', () {
    final parts = [
      for (final m in backgroundMarkPath(_roomSize, 0).computeMetrics())
        m.extractPath(0, m.length).getBounds(),
    ]..sort((a, b) => a.left.compareTo(b.left));
    expect(parts, hasLength(2));
    final [left, right] = parts;
    expect(left.right, lessThan(right.left), reason: 'apart');
    expect(left.center.dy, closeTo(right.center.dy, 0.05), reason: 'level');
    for (final p in parts) {
      expect(p.width, closeTo(p.height, 0.2), reason: 'round');
    }
    // The rest is the loop's own first and last frame: nothing jumps.
    final last = backgroundMarkPath(_roomSize, 1 - 0.5 / BackgroundMark.ticks);
    expect(last, same(backgroundMarkPath(_roomSize, 0)));
  });

  group('the play, from its outlines', () {
    // Ten times the dot's room, for a finer reading.
    const size = Size.square(_room * 10);
    final mid = size.center(Offset.zero);
    const n = BackgroundMark.ticks;
    const rest = BackgroundMark.restTicks;
    Path at(int tick) => backgroundMarkPath(size, tick % n / n);

    test('it turns clockwise on screen, never fast enough to strobe', () {
      // Each drop's head, tick by tick, while the two are apart: as they
      // start to spin and again as they separate. y points down, so a
      // growing angle is clockwise as seen.
      // From the second tick of each: on the first the turn is a few
      // degrees, less than the grid this reads it on.
      for (final (from, to) in [(rest + 2, rest + 9), (rest + 26, rest + 32)]) {
        for (var i = from; i < to; i++) {
          final before = _drops(at(i));
          final after = _drops(at(i + 1));
          expect(before, hasLength(2), reason: 'tick $i');
          expect(after, hasLength(2), reason: 'tick ${i + 1}');
          for (final d in before) {
            final a = _headOf(d);
            // The same drop a tick on: the one whose head is nearest.
            final b = after
                .map(_headOf)
                .reduce((x, y) => (x - a).distance < (y - a).distance ? x : y);
            final turn = _angleBetween(a - mid, b - mid);
            expect(turn, greaterThan(0), reason: 'tick $i, clockwise');
            expect(turn, lessThan(20 * pi / 180), reason: 'tick $i');
          }
        }
      }
    });

    test("a moving drop's tail trails behind it", () {
      // Spinning in, and spiralling out.
      for (final i in [rest + 5, rest + 7, rest + 28, rest + 30]) {
        for (final d in _drops(at(i))) {
          final head = _headOf(d);
          final r = head - mid;
          final way = Offset(-r.dy, r.dx) / r.distance; // clockwise
          var ahead = 0.0;
          var behind = 0.0;
          for (final p in _outline(d)) {
            final along = (p - head).dx * way.dx + (p - head).dy * way.dy;
            ahead = max(ahead, along);
            behind = max(behind, -along);
          }
          expect(behind, greaterThan(ahead * 1.25), reason: 'tick $i');
        }
      }
    });

    test('the drops move a tick before their tails grow', () {
      // The head leads: on the play's first tick the two have turned,
      // enough to see, and are still round; a tail shows from the next.
      final still = [for (final d in _drops(at(rest))) d.getBounds().center];
      final moved = _drops(at(rest + 1));
      expect(moved, hasLength(2));
      for (final d in moved) {
        expect(_tailOf(d) / 10, lessThan(0.1), reason: 'still round');
        final now = d.getBounds().center;
        final was = still.reduce(
          (x, y) => (x - now).distance < (y - now).distance ? x : y,
        );
        expect(
          _angleBetween(was - mid, now - mid),
          greaterThan(4 * pi / 180),
          reason: 'seen to move',
        );
      }
      for (final d in _drops(at(rest + 2))) {
        expect(_tailOf(d) / 10, greaterThan(0.12), reason: 'a tail begins');
      }
    });

    test('a tail grows and is drawn in over several ticks, never at once', () {
      // How far each drop's outline reaches past its head, tick by tick,
      // while the two are apart: from the rest into the spin, and from
      // the parting back to the rest.
      List<double> reach(int from, int to) => [
        for (var i = from; i <= to; i++)
          _drops(at(i)).map(_tailOf).reduce(max) / 10,
      ];
      final starting = reach(rest, rest + 9);
      final settling = reach(rest + 27, n);
      final full = starting.reduce(max);
      expect(full, greaterThan(1.2), reason: 'a teardrop at speed');
      expect(starting.first, lessThan(0.1), reason: 'round at rest');
      expect(settling.last, lessThan(0.1), reason: 'round at rest');
      // No tick's change is more than a third of the whole tail: it's
      // never there on one frame and full two frames on.
      for (final run in [starting, settling]) {
        for (var i = 1; i < run.length; i++) {
          expect(
            (run[i] - run[i - 1]).abs(),
            lessThan(full / 3),
            reason: '$run at $i',
          );
        }
      }
      // It's growing on at least five ticks as the spin starts, and
      // shortening on at least four as the two settle.
      int moving(List<double> run, {required bool up}) => [
        for (var i = 1; i < run.length; i++)
          if ((run[i] - run[i - 1]) * (up ? 1 : -1) > full * 0.04) i,
      ].length;
      expect(moving(starting, up: true), greaterThanOrEqualTo(5));
      expect(moving(settling, up: false), greaterThanOrEqualTo(4));
    });

    test('two at rest, one drop at the merge, joined by a neck either '
        'side of it', () {
      final parts = [for (var i = rest; i <= n; i++) _drops(at(i)).length];
      expect(parts.first, 2, reason: 'the play starts at rest');
      expect(parts.last, 2, reason: 'and ends there');
      final first = parts.indexOf(1);
      final last = parts.lastIndexOf(1);
      expect(first, greaterThan(0), reason: 'they merge');
      // One stretch of one drop, round for a moment in it.
      expect(parts.sublist(first, last + 1), everyElement(1));
      final roundest = [
        for (var i = first; i <= last; i++) _waist(_drops(at(rest + i)).single),
      ].reduce(max);
      expect(roundest, greaterThan(0.95), reason: 'round for a moment');
      // The tick they join and the last before they part: a thin neck
      // between two heads, not two drops pressed together or one round.
      for (final i in [rest + first, rest + last]) {
        expect(
          _waist(_drops(at(i)).single),
          inInclusiveRange(0.05, 0.35),
          reason: 'tick $i',
        );
      }
      // The neck thickens tick by tick as they join, and thins tick by
      // tick before they part.
      final joining = [
        for (var i = first; i < first + 3; i++)
          _waist(_drops(at(rest + i)).single),
      ];
      final parting = [
        for (var i = last - 3; i <= last; i++)
          _waist(_drops(at(rest + i)).single),
      ];
      for (var i = 1; i < joining.length; i++) {
        expect(joining[i], greaterThan(joining[i - 1]), reason: '$joining');
      }
      for (var i = 1; i < parting.length; i++) {
        expect(parting[i], lessThan(parting[i - 1]), reason: '$parting');
      }
    });

    test('every tick holds the same liquid', () {
      // Two rest drops' area on every tick, within a few per cent.
      final rest0 = _area(at(0));
      for (var i = rest; i <= n; i++) {
        expect(_area(at(i)) / rest0, closeTo(1, 0.03), reason: 'tick $i');
      }
    });

    test('the outline changes on every tick of the play', () {
      for (var i = rest; i < n; i++) {
        final a = at(i);
        final b = at(i + 1);
        var changed = 0;
        for (var y = 0.5; y < size.height; y++) {
          for (var x = 0.5; x < size.width; x++) {
            if (a.contains(Offset(x, y)) != b.contains(Offset(x, y))) {
              changed++;
            }
          }
        }
        expect(changed, greaterThan(20), reason: 'tick $i to ${i + 1}');
      }
    });
  });

  test('each outline is traced once per size and kept', () {
    forgetBackgroundMarks();
    backgroundMarkTraces = 0;
    for (var loop = 0; loop < 3; loop++) {
      for (var i = 0; i < BackgroundMark.ticks; i++) {
        backgroundMarkPath(_roomSize, i / BackgroundMark.ticks);
      }
    }
    // One for the rest, one for each of the play's ticks after its first.
    expect(backgroundMarkTraces, BackgroundMark.playTicks);
    expect(
      backgroundMarkPath(_roomSize, 0.9),
      same(backgroundMarkPath(_roomSize, 0.9)),
    );
  });

  testWidgets('over a loop it asks for frames only while it plays, and '
      'several chats share its outlines', (tester) async {
    forgetBackgroundMarks();
    backgroundMarkTraces = 0;
    final d = await _dots(tester, count: 3);
    // A whole loop from one play's start to the next's: frames for the
    // play's ticks after its first (the rest's look) and the one that
    // brings it back to rest, none while it rests.
    await _untilPlay(tester);
    var played = 0;
    var rested = 0;
    for (var t = Duration.zero; t < BackgroundMark.period; t += _vsync) {
      final playing = backgroundMarkPlays;
      _frames = 0;
      _counting = true;
      await tester.pump(_vsync);
      _counting = false;
      if (playing) {
        played += _frames;
      } else {
        rested += _frames;
      }
      if (t > _vsync * 3 && backgroundMarkPlays && !playing) break;
    }
    expect(played, BackgroundMark.playTicks);
    expect(rested, 0);
    // Three marks, every outline traced once.
    expect(backgroundMarkTraces, BackgroundMark.playTicks);
    // At rest no clock ticks for it: only the timer for the next play.
    await tester.pump(const Duration(seconds: 2)); // past the play
    expect(backgroundMarkPlays, isFalse);
    expect(pulseClock.running, isFalse);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });

  testWidgets('a mark rebuilt every second still plays each loop', (
    tester,
  ) async {
    // A rebuild swaps the painter (the old one leaves, the new one comes):
    // the only mark on screen must keep its rest's timer and its play.
    final d = await _dots(tester);
    var plays = 0;
    var played = Duration.zero;
    var was = false;
    const loops = 4;
    final span = BackgroundMark.period * loops;
    for (var t = Duration.zero; t < span; t += _vsync) {
      if (t.inMilliseconds ~/ 1000 != (t + _vsync).inMilliseconds ~/ 1000) {
        // The same tree as _dots, made anew: ChatDot builds a new painter.
        await tester.pumpWidget(
          themed(
            TickerMode(
              enabled: true,
              child: Column(children: [ChatDot(chat: d.chats['b0']!)]),
            ),
          ),
          duration: _vsync,
        );
      } else {
        await tester.pump(_vsync);
      }
      final now = backgroundMarkPlays;
      if (now && !was) plays++;
      if (now) played += _vsync;
      was = now;
    }
    expect(plays, loops);
    expect(
      played.inMilliseconds,
      closeTo(BackgroundMark.playTicks * 1000 / pulseRate * loops, 100),
    );
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });

  testWidgets('with Reduce Motion it asks for no frames', (tester) async {
    final d = await _dots(tester, still: true);
    expect(await _framesOver(tester, BackgroundMark.period * 2), 0);
    expect(pulseClock.running, isFalse);
    d.dispose();
  });

  testWidgets('in a hidden pane it asks for no frames', (tester) async {
    final d = await _dots(tester, tickers: false);
    expect(await _framesOver(tester, BackgroundMark.period * 2), 0);
    expect(pulseClock.running, isFalse);
    d.dispose();
  });

  testWidgets('with Nushi in the back it draws its rest and asks for no '
      'frames', (tester) async {
    final d = await _dots(tester);
    await _untilPlay(tester);
    await tester.pump(BackgroundMark.period ~/ 7); // mid-play
    expect(backgroundMarkPlays, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pump();
    expect(backgroundMarkPlays, isFalse, reason: 'back at rest');
    expect(await _framesOver(tester, BackgroundMark.period * 2), 0);
    // In front again, it plays on.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _untilPlay(tester);
    await tester.pump(BackgroundMark.period);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });
}

/// Each separate drop of [p], as its own path.
List<Path> _drops(Path p) => [
  for (final m in p.computeMetrics()) m.extractPath(0, m.length)..close(),
];

/// Points round [drop]'s outline, half a pixel apart.
List<Offset> _outline(Path drop) => [
  for (final m in drop.computeMetrics())
    for (var d = 0.0; d < m.length; d += 0.5)
      m.getTangentForOffset(d)!.position,
];

/// The point of [drop] deepest inside it: its head, the roundest and
/// fullest part (a tail thins).
Offset _headOf(Path drop) {
  final edge = _outline(drop);
  final b = drop.getBounds();
  var best = b.center;
  var deepest = -1.0;
  for (var y = b.top; y <= b.bottom; y += 0.5) {
    for (var x = b.left; x <= b.right; x += 0.5) {
      final q = Offset(x, y);
      if (!drop.contains(q)) continue;
      final d = edge.map((e) => (e - q).distance).reduce(min);
      if (d > deepest) {
        deepest = d;
        best = q;
      }
    }
  }
  return best;
}

/// How far [drop]'s tail reaches past its head: the furthest its outline
/// is from its head's middle, less the nearest. About 0 for a round drop.
double _tailOf(Path drop) {
  final head = _headOf(drop);
  final far = _outline(drop).map((e) => (e - head).distance);
  return far.reduce(max) - far.reduce(min);
}

/// The angle from [a] to [b], from -pi to pi: positive is clockwise on
/// screen (y down).
double _angleBetween(Offset a, Offset b) {
  final d = b.direction - a.direction;
  return atan2(sin(d), cos(d));
}

/// [p]'s area, by its pixels.
double _area(Path p) {
  final b = p.getBounds();
  var inside = 0;
  for (var y = b.top.floorToDouble() + 0.5; y < b.bottom; y++) {
    for (var x = b.left.floorToDouble() + 0.5; x < b.right; x++) {
      if (p.contains(Offset(x, y))) inside++;
    }
  }
  return inside.toDouble();
}

/// How thin [drop] is at its waist over its fullest: its widths across
/// its long axis (from its second moments), the least in its middle
/// third over the most. About 1 for a round drop, small for two heads
/// joined by a thin neck.
double _waist(Path drop) {
  final b = drop.getBounds();
  final pts = <Offset>[];
  for (var y = b.top + 0.25; y < b.bottom; y += 0.5) {
    for (var x = b.left + 0.25; x < b.right; x += 0.5) {
      if (drop.contains(Offset(x, y))) pts.add(Offset(x, y));
    }
  }
  final c = pts.reduce((a, b) => a + b) / pts.length.toDouble();
  var xx = 0.0;
  var yy = 0.0;
  var xy = 0.0;
  for (final p in pts) {
    final d = p - c;
    xx += d.dx * d.dx;
    yy += d.dy * d.dy;
    xy += d.dx * d.dy;
  }
  final along = Offset.fromDirection(0.5 * atan2(2 * xy, xx - yy));
  final across = Offset(-along.dy, along.dx);
  double width(double t) {
    var w = 0;
    for (var q = -b.longestSide; q <= b.longestSide; q += 0.5) {
      if (drop.contains(c + along * t + across * q)) w++;
    }
    return w * 0.5;
  }

  var reach = 0.0;
  for (final p in pts) {
    final t = (p - c).dx * along.dx + (p - c).dy * along.dy;
    reach = max(reach, t.abs());
  }
  final widths = [
    for (var t = -reach; t <= reach; t += reach / 15) (t: t, w: width(t)),
  ];
  final fullest = widths.map((e) => e.w).reduce(max);
  final waist = widths
      .where((e) => e.t.abs() <= reach / 3)
      .map((e) => e.w)
      .reduce(min);
  return waist / fullest;
}
