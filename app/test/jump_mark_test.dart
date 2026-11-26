// Jump to latest on the Mac (#51): one round face, centred across the
// transcript's column; the arrow while the agent is idle, Nushi's mark
// turning on it while it works (the arrow under the pointer or focus),
// only the glyph changing; Needs you's amber pill in the same place. With
// Reduce Motion the mark stands still. The phone keeps its round arrow at
// the right.

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/logo.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';

const _shot = Key('shot');

final Finder _chip = find.byType(JumpChip);
final Finder _face = find.byKey(JumpChip.roundKey);
final Finder _logo = find.descendant(of: _chip, matching: find.byType(Logo));
final Finder _arrow = find.descendant(
  of: _chip,
  matching: find.byIcon(Icons.arrow_downward),
);

LogoPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(of: _logo, matching: find.byType(CustomPaint)),
            )
            .painter!
        as LogoPainter;

/// The round face's fill.
Color? _fill(WidgetTester tester) =>
    (tester.widget<Container>(_face).decoration! as BoxDecoration).color;

Widget _one({bool needs = false, bool working = true, VoidCallback? onTap}) =>
    Center(
      child: JumpChip(needs: needs, working: working, onTap: onTap ?? () {}),
    );

/// The app on a long chat, [busy] or not, scrolled far up; with a
/// message pinned, so the pinned messages' rail shows in the margin.
Future<Daemon> _scrolledUp(
  WidgetTester tester, {
  required bool busy,
  Size size = const Size(1400, 900),
  Brightness? brightness,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final status = ChatStatus(busy: busy);
  final c = chat('a', 'claude', 'Chat a', status: status)
    ..pinnedMessages.add('a-a20');
  final fake = FakeDaemon([c])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: longChat('a'), status: status)
        : null;
  final d = await fake.connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  final scroll = find
      .descendant(
        of: find.byType(Transcript),
        matching: find.byType(SingleChildScrollView),
      )
      .first;
  final p = tester.widget<SingleChildScrollView>(scroll).controller!.position;
  p.jumpTo(p.maxScrollExtent * 0.5);
  await tester.drag(scroll, const Offset(0, 40));
  await tester.pumpAndSettle();
  return d;
}

/// The colour the window shows at [at], in logical points.
Future<Color> _shown(WidgetTester tester, Offset at) async {
  final ratio = tester.view.devicePixelRatio;
  final element = find.byType(NushiApp).evaluate().single;
  return (await tester.runAsync(() async {
    final image = await captureImage(element);
    try {
      final bytes = (await image.toByteData())!;
      final x = (at.dx * ratio).floor();
      final i = ((at.dy * ratio).floor() * image.width + x) * 4;
      return Color.fromARGB(
        bytes.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

/// The transcript's column's middle: the transcript's, its sides alike.
double _middle(WidgetTester tester) =>
    tester.getRect(find.byType(Transcript)).center.dx;

void main() {
  setUpAll(loadFonts);

  testWidgets('scrolled up, the chip is one round face in the middle of '
      'the column: the arrow idle, the mark working, Needs you its pill; '
      'nothing moves as it changes', (tester) async {
    final d = await _scrolledUp(tester, busy: false);
    final chat = d.chats['a']!;
    expect(_face, findsOneWidget);
    expect(_arrow, findsOneWidget);
    expect(_logo, findsNothing);
    expect(
      find.descendant(of: _chip, matching: find.byType(Text)),
      findsNothing,
    );
    expect(find.byTooltip('Jump to latest'), findsOneWidget);
    final idle = tester.getRect(_face);
    final fill = _fill(tester);
    expect(idle.size, Size.square(JumpChip.face));
    // Centred in the column, which is what keeps it clear of the pinned
    // messages' rail: that sits in the margin left of the column.
    expect(idle.center.dx, closeTo(_middle(tester), 0.5));

    // The agent starts: the mark, same size, same place, same fill.
    chat
      ..busy = true
      ..notifyListeners();
    await tester.pump();
    expect(_logo, findsOneWidget);
    expect(_arrow, findsNothing);
    expect(_painter(tester).turning, isTrue);
    expect(tester.getRect(_face), idle);
    expect(_fill(tester), fill);
    expect(find.byTooltip('Jump to latest'), findsOneWidget);

    // Needing you: the amber pill, wider, its middle where the face's was.
    chat
      ..waiting = true
      ..notifyListeners();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_face, findsNothing);
    expect(
      find.descendant(of: _chip, matching: find.text('Needs you')),
      findsOneWidget,
    );
    final needs = tester.getRect(_chip);
    expect(needs.width, greaterThan(idle.width));
    expect(needs.height, idle.height);
    expect(needs.center.dx, closeTo(idle.center.dx, 0.5));
    expect(needs.center.dy, closeTo(idle.center.dy, 0.5));

    // Answered, and the agent stops: back where it was.
    chat
      ..waiting = false
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(tester.getRect(_face), idle);
    chat
      ..busy = false
      ..notifyListeners();
    await tester.pump();
    expect(tester.getRect(_face), idle);
    expect(_arrow, findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  for (final width in [1700.0, 1000.0, 720.0]) {
    testWidgets('in the middle of the column at ${width.toInt()} wide, the '
        'sidebar shown or hidden', (tester) async {
      for (final hidden in [false, true]) {
        sidebarHidden.value = hidden;
        final d = await _scrolledUp(tester, busy: true, size: Size(width, 900));
        final face = tester.getRect(_face);
        // Centred, and so clear of the rail in the margin.
        expect(face.center.dx, closeTo(_middle(tester), 0.5));
        await closeView(tester, d);
      }
    }, variant: onMac);
  }

  testWidgets('with a side pane open: in the middle of what it leaves of '
      'the column, never under it, and a press still jumps', (tester) async {
    // Beside it, and over it (the sidebar hidden, so the pane leaves some
    // of the transcript; at 720 with it, the pane covers it all).
    for (final (width, hidden) in [(1700.0, false), (800.0, true)]) {
      sidebarHidden.value = hidden;
      final d = await _scrolledUp(tester, busy: true, size: Size(width, 900));
      toggleFiles(d.chats['a']!);
      await tester.pumpAndSettle();
      final transcript = tester.getRect(find.byType(Transcript));
      final files = tester.getRect(find.byType(FilesPane));
      final face = tester.getRect(_face);
      expect(face.right, lessThanOrEqualTo(files.left));
      expect(face.left, greaterThanOrEqualTo(transcript.left));
      if (transcript.right <= files.left) {
        // Beside: the column narrowed, the chip in its middle.
        expect(face.center.dx, closeTo(_middle(tester), 0.5));
      } else {
        // Over it: in the middle of what the pane leaves of the column.
        final left = transcript.left + NushiTheme.gutter;
        expect(face.center.dx, closeTo((left + files.left) / 2, 0.5));
      }
      // Drawn where it's pressed: its fill between the glyph and its edge,
      // not what's under it.
      final fill = _fill(tester)!;
      final shown = await _shown(
        tester,
        face.center + Offset(0, JumpChip.face * 0.42),
      );
      expect(shown, isSameColorAs(fill));
      await tester.tap(_face);
      await tester.pumpAndSettle();
      expect(_chip, findsNothing);
      toggleFiles(d.chats['a']!);
      await closeView(tester, d);
    }
  }, variant: onMac);

  testWidgets('the pointer or the focus on it shows the arrow, in place; '
      'a press jumps', (tester) async {
    var jumped = 0;
    await tester.pumpWidget(themed(_one(onTap: () => jumped++)));
    await tester.pumpAndSettle();
    final face = tester.getRect(_face);
    expect(face.size, Size.square(JumpChip.face));
    expect(_logo, findsOneWidget);
    expect(_arrow, findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(
      tester.getSemantics(find.byTooltip('Jump to latest')),
      isSemantics(isButton: true, tooltip: 'Jump to latest'),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(face.center);
    await tester.pump();
    expect(_logo, findsNothing);
    expect(_arrow, findsOneWidget);
    expect(tester.getRect(_face), face);

    await tester.tap(_face);
    expect(jumped, 1);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(_logo, findsOneWidget);

    // From the keyboard: focused, the arrow; Enter jumps.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_arrow, findsOneWidget);
    expect(_logo, findsNothing);
    expect(tester.getRect(_face), face);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(jumped, 2);
  });

  testWidgets('working, the mark is in the running ink at 0.8 of the face, '
      'its rings at least 1.5 thick, turning quicker than elsewhere', (
    tester,
  ) async {
    await tester.pumpWidget(themed(_one()));
    await tester.pumpAndSettle();
    final t = NushiTheme.of(tester.element(_face)).t;
    expect(tester.getSize(_logo), Size.square(JumpChip.face * 0.8));
    final mark = find.descendant(of: _logo, matching: find.byType(CustomPaint));
    expect(
      mark,
      paints..arc(color: t.running, strokeWidth: LogoPainter.leastStroke),
    );
    expect(_painter(tester).outerTurn, JumpChip.outerTurn);
    expect(_painter(tester).innerTurn, JumpChip.innerTurn);
    expect(JumpChip.outerTurn, lessThan(LogoPainter.driftOuter));
    expect(JumpChip.innerTurn, lessThan(LogoPainter.driftInner));

    // Under the pointer the arrow, in the idle arrow's ink.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(_face));
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(tester.widget<Icon>(_arrow).color, t.text);
  });

  testWidgets('the mark elsewhere keeps its strokes and its pace', (
    tester,
  ) async {
    const color = Color(0xFF808080);
    await tester.pumpWidget(
      themed(const Center(child: Logo(color: color, turning: true))),
    );
    await tester.pumpAndSettle();
    final mark = find.descendant(
      of: find.byType(Logo),
      matching: find.byType(CustomPaint),
    );
    // To scale, as the paint holds it (in single precision).
    final scale = Float32List.fromList([2.8 * 72 / 76]).single;
    expect(mark, paints..arc(color: color, strokeWidth: scale));
    final painter = tester.widget<CustomPaint>(mark).painter! as LogoPainter;
    expect(painter.outerTurn, LogoPainter.driftOuter);
    expect(painter.innerTurn, LogoPainter.driftInner);
  });

  testWidgets('idle on the Mac: the same face with the arrow, its words '
      'its tooltip', (tester) async {
    await tester.pumpWidget(themed(_one(working: false)));
    await tester.pumpAndSettle();
    expect(tester.getSize(_face), Size.square(JumpChip.face));
    expect(_arrow, findsOneWidget);
    expect(_logo, findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.byTooltip('Jump to latest'), findsOneWidget);
  });

  testWidgets('needing you wins: amber words, no mark, a face high', (
    tester,
  ) async {
    await tester.pumpWidget(themed(_one(needs: true)));
    await tester.pumpAndSettle();
    expect(_logo, findsNothing);
    expect(_face, findsNothing);
    expect(find.text('Needs you'), findsOneWidget);
    expect(tester.getSize(_chip).height, JumpChip.face);
    // Named as the phone's is, to a screen reader and under the pointer.
    expect(find.byTooltip('Needs you: jump to latest'), findsOneWidget);
  });

  testWidgets('the mark turns on the loop clock; with Reduce Motion it '
      'stands still', (tester) async {
    addTearDown(() => Shine.stopAt = 0);
    Shine.stopAt = 0.25;
    await tester.pumpWidget(themed(_one(), still: false));
    await tester.pump();
    final (outer, inner) = _painter(tester).turned;
    expect(outer, greaterThan(0));
    expect(inner, lessThan(0));

    await tester.pumpWidget(themed(_one(), still: true));
    await tester.pump();
    expect(_painter(tester).turning, isFalse);
    expect(_painter(tester).turned, (0.0, 0.0));
  });

  testWidgets('on the phone the round face keeps its size and its finger '
      'target', (tester) async {
    await tester.pumpWidget(themed(TouchTargets(child: _one())));
    await tester.pumpAndSettle();
    expect(tester.getSize(_face), const Size.square(JumpChip.round));
    expect(
      tester.getSize(find.byType(JumpChip)).width,
      greaterThanOrEqualTo(44),
    );
    expect(_logo, findsOneWidget);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, the mark and the arrow under the pointer, 4×, '
        '$name', (tester) async {
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          Align(
            key: _shot,
            alignment: Alignment.topLeft,
            child: enlarged(
              const Size(100, 50),
              4,
              ColoredBox(
                color: NushiTheme(tokens).t.base,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    JumpChip(needs: false, working: true, onTap: () {}),
                    ShowLook(
                      look: (hover: true, focus: false, pressed: false),
                      child: JumpChip(
                        needs: false,
                        working: true,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find
            .descendant(
              of: find.byKey(_shot),
              matching: find.byType(RepaintBoundary),
            )
            .first,
        matchesGoldenFile('goldens/jump_mark_$name.png'),
      );
    });
  }

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, idle the arrow on the same face, and Needs you, '
        '4×, $name', (tester) async {
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          Align(
            key: _shot,
            alignment: Alignment.topLeft,
            child: enlarged(
              const Size(160, 50),
              4,
              ColoredBox(
                color: NushiTheme(tokens).t.base,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    JumpChip(needs: false, onTap: () {}),
                    JumpChip(needs: true, working: true, onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find
            .descendant(
              of: find.byKey(_shot),
              matching: find.byType(RepaintBoundary),
            )
            .first,
        matchesGoldenFile('goldens/jump_chip_mac_$name.png'),
      );
    });
  }

  renderTest('renders: the mark over a working chat on the phone', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      final c = chat('a', 'claude', 'Fix the flaky relay test');
      final status = ChatStatus(busy: true);
      for (final size in const [Size(390, 844), Size(430, 932)]) {
        viewport(tester, size, ratio: 3, brightness: b);
        final fake = FakeDaemon([c])
          ..answer = (input) => input is GetChatRequest
              ? GetChatResponse(chat: c, items: longChat('a'), status: status)
              : null;
        final phone = await startPhone(tester, fake);
        await tester.tap(find.text('Fix the flaky relay test'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Transcript), const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(_logo, findsOneWidget);
        await render(
          tester,
          find.byType(PhoneApp),
          'jump_mark_phone_${size.width.toInt()}_${b.name}',
        );
        await endPhone(tester, phone);
      }
    }
  });

  renderTest('renders: the mark over a working chat on the Mac', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      for (final width in const [1700.0, 720.0]) {
        final d = await _scrolledUp(
          tester,
          busy: true,
          size: Size(width, 900),
          brightness: b,
        );
        await render(
          tester,
          find.byType(NushiApp),
          'jump_mark_mac_${width.toInt()}_${b.name}',
        );
        await closeView(tester, d);
      }
    }
  }, variant: onMac);
}
