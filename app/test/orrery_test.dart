import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/logo.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/orbits.dart';
import 'package:nushi/orrery.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

// The default 800 × 600 screen: the mark (72) over 16 and a 20-high label,
// centred.
const _centre = Offset(400, 246 + 36);
final double _u = markUnit(72);

Future<Orbits> _orrery(WidgetTester tester, {bool still = false}) async {
  final o = Orbits();
  await tester.pumpWidget(
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Orrery(
            orbits: o,
            label: const SizedBox(width: 100, height: 20),
          ),
        ),
      ),
    ),
  );
  return o;
}

Offset _at(Orbits o, int i) => _centre + Offset(o.x[i], o.y[i]) * _u;

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  testWidgets('it moves while the app is active, not while it is inactive', (
    tester,
  ) async {
    final o = await _orrery(tester);
    final x0 = o.x[0];
    await tester.pump(const Duration(seconds: 1));
    final x1 = o.x[0];
    expect(x1, isNot(x0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    expect(o.x[0], x1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 2));
    expect(o.x[0], x1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(o.x[0], isNot(x1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a dialog over it pauses it', (tester) async {
    final o = await _orrery(tester);
    final context = tester.element(find.byType(Orrery));
    unawaited(
      showDialog<void>(context: context, builder: (_) => const Text('over')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final x = o.x[0];
    await tester.pump(const Duration(seconds: 2));
    expect(o.x[0], x);
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(o.x[0], isNot(x));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('under Reduce motion it is the still mark', (tester) async {
    final o = await _orrery(tester, still: true);
    expect(find.byType(Logo), findsOneWidget);
    final x = o.x[0];
    await tester.pump(const Duration(seconds: 2));
    expect(o.x[0], x);
    await tester.tapAt(_centre + const Offset(-60, 0));
    await tester.pump();
    expect(o.count, markBeads.length);
  });

  testWidgets('dragging a planet and letting go flings it', (tester) async {
    final o = await _orrery(tester);
    // The outer ring's planet at 0° goes down the screen (clockwise).
    expect(o.vy[0], greaterThan(0));
    expect(o.vx[0], closeTo(0, 1e-9));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: _at(o, 0) + const Offset(30, 0));
    await mouse.moveTo(_at(o, 0));
    await tester.pump();
    await mouse.down(_at(o, 0));
    expect(o.held, 0);
    for (var k = 1; k <= 10; k++) {
      await tester.pump(const Duration(milliseconds: 20));
      await mouse.moveBy(
        const Offset(-6, -6),
        timeStamp: Duration(milliseconds: 20 * k),
      );
    }
    // Held, it follows the pointer.
    expect(_at(o, 0).dx, closeTo(_centre.dx + 31 * _u - 60, 0.01));
    await mouse.up(timeStamp: const Duration(milliseconds: 210));
    await mouse.removePointer();
    expect(o.held, -1);
    expect(o.vx[0], lessThan(-1));
    expect(o.vy[0], lessThan(-1));
    expect(o.disturbed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a click on empty space adds a planet, on a planet none', (
    tester,
  ) async {
    final o = await _orrery(tester);
    await tester.tapAt(_centre + const Offset(-120, 0));
    await tester.pump();
    expect(o.count, markBeads.length + 1);
    await tester.tapAt(_at(o, 1));
    await tester.pump();
    expect(o.count, markBeads.length + 1);
    // The label's own.
    await tester.tapAt(_centre + const Offset(0, 36 + 16 + 10));
    await tester.pump();
    expect(o.count, markBeads.length + 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the empty pane at rest ($name)', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(360, 240);
      addTearDown(tester.view.reset);
      final d = await FakeDaemon([]).connect(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(body: NothingOpen(d)),
        ),
      );
      await expectLater(
        find.byType(NothingOpen),
        matchesGoldenFile('goldens/orrery_$name.png'),
      );
      await tester.pumpWidget(const SizedBox());
      d.dispose();
    });
  }
}
