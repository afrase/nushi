// A chat whose turn ended while its background tasks run wears its own
// mark (#113): two dots side by side that now and then merge, spin and
// split. At rest it asks for nothing; its play draws outlines traced once
// and kept.
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

  test('the drops join through a neck a tick before they are one', () {
    // The narrowest the outline is across its middle, in any direction.
    double waist(Path p) {
      final c = _roomSize.center(Offset.zero);
      var least = double.infinity;
      for (var a = 0.0; a < pi; a += 0.05) {
        var inside = 0;
        for (var r = -_room / 2; r <= _room / 2; r += 0.05) {
          if (p.contains(c + Offset.fromDirection(a, r))) inside++;
        }
        least = min(least, inside * 0.05);
      }
      return least;
    }

    int parts(Path p) => p.computeMetrics().length;
    const n = BackgroundMark.ticks;
    // The first tick where the two are one, as they pull together.
    var i = BackgroundMark.restTicks + 1;
    while (parts(backgroundMarkPath(_roomSize, i / n)) > 1) {
      i++;
    }
    final joined = backgroundMarkPath(_roomSize, i / n);
    expect(waist(joined), inInclusiveRange(0.5, 1.5), reason: 'tick $i');
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
    expect(played.inMilliseconds, closeTo(1500 * loops, 100));
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
