import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show item;
import 'harness.dart';

Widget _app(Widget child, {Tokens tokens = Tokens.dark, bool still = false}) =>
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );

final _link = GitHubLink(
  host: 'github.com',
  repo: 'afrase/nushi',
  number: 412,
  id: 'PR_412',
  pull: true,
);

ChecksMark? _mark(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(PullDot),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((p) => p.painter)
    .whereType<ChecksMark>()
    .firstOrNull;

double _hop(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(PullDot),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .y;

void main() {
  setUpAll(loadFonts);

  Future<(PullStates, void Function())> open(
    WidgetTester tester,
    String checks, {
    bool still = false,
  }) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')..pull = _link;
    final states = PullStates.of(d)
      ..put(item(412, 'Speed up CI', checks: checks));
    await tester.pumpWidget(_app(PullDot(chat, states), still: still));
    return (states, d.dispose);
  }

  testWidgets('running: amber, the ring growing out of it; passing: green, '
      'a pop, 4 s, then it fades', (tester) async {
    final (states, done) = await open(tester, 'pending');
    const t = Tokens.dark;
    expect(_mark(tester)!.ringing, isTrue);
    expect(_mark(tester)!.color, t.needs);

    states.put(item(412, 'Speed up CI', checks: 'success'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_mark(tester)!.color, t.done);
    expect(_mark(tester)!.ringing, isFalse);
    expect(_mark(tester)!.scale, greaterThan(1.3));
    expect(find.byTooltip('#412: checks passed'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3800));
    expect(_mark(tester)!.scale, 1);
    expect(_mark(tester)!.color.a, closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_mark(tester)!.color.a, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_mark(tester), isNull);

    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('failing: it pops red, hops once and stays', (tester) async {
    final (states, done) = await open(tester, 'pending');
    states.put(item(412, 'Speed up CI', checks: 'failure'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_mark(tester)!.color, Tokens.dark.crashed);
    expect(_mark(tester)!.scale, greaterThan(1.3));
    await tester.pump(const Duration(milliseconds: 450));
    expect(_hop(tester), lessThan(-1));
    await tester.pumpAndSettle();
    expect(_hop(tester), 0);
    expect(_mark(tester)!.color, Tokens.dark.crashed);
    expect(find.byTooltip('#412: checks failing'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('passed before it showed: nothing; Reduce Motion: colors only, '
      'green still goes after 4 s', (tester) async {
    var (states, done) = await open(tester, 'success');
    expect(_mark(tester), isNull);
    await tester.pumpWidget(const SizedBox());
    done();

    (states, done) = await open(tester, 'pending', still: true);
    expect(_mark(tester)!.ringing, isFalse);
    states.put(item(412, 'Speed up CI', checks: 'success'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect((_mark(tester)!.color, _mark(tester)!.scale), (Tokens.dark.done, 1));
    await tester.pump(const Duration(seconds: 5));
    expect(_mark(tester), isNull);
    await tester.pumpWidget(const SizedBox());
    done();
  });

  test('the ring is centred on its dot: one centre, no offset', () async {
    Shine.stopAt = 0.3;
    addTearDown(() => Shine.stopAt = 0);
    // Drawn 8 times as large, its ink's middle is the box's.
    const side = 6.0 * 8;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(side, side)
      ..scale(8);
    ChecksMark(
      const Color(0xFFE9AC4C),
      ringing: true,
    ).paint(canvas, const Size.square(6));
    final image = await recorder.endRecording().toImage(
      side.toInt() * 3,
      side.toInt() * 3,
    );
    // The ring paints past the box: the box sits a box's width in, its
    // centre at 1.5 sides.
    final bytes = (await image.toByteData())!;
    var (sx, sy, n) = (0.0, 0.0, 0.0);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final a = bytes.getUint8((y * image.width + x) * 4 + 3) / 255;
        sx += a * (x + 0.5);
        sy += a * (y + 0.5);
        n += a;
      }
    }
    expect(sx / n, closeTo(side * 1.5, 0.05));
    expect(sy / n, closeTo(side * 1.5, 0.05));
  });

  // At 2×, mid-ring: the dot sits in the middle of its ring.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, the running ring on its dot, 2×, $name', (
      tester,
    ) async {
      Shine.stopAt = 0.35;
      addTearDown(() => Shine.stopAt = 0);
      final d = await FakeDaemon([]).connect(tester);
      final chat = ChatState('c', '/x')..pull = _link;
      final states = PullStates.of(d)
        ..put(item(412, 'Speed up CI', checks: 'pending'));
      final theme = NushiTheme(tokens);
      await tester.pumpWidget(
        _app(
          enlarged(
            const Size(150, 28),
            2,
            ColoredBox(
              color: tokens.raised,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text('Speed up CI', style: theme.ui(tokens.text)),
                    const SizedBox(width: 6),
                    Text('#412', style: theme.ui(tokens.textMuted, size: 11)),
                    PullDot(chat, states),
                  ],
                ),
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile('goldens/pull_dot_ring_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
