// Jump to latest while the agent works (#51): a round face with Nushi's
// mark turning on it, the arrow under the pointer, a press jumping as
// ever; needing you wins, and with Reduce Motion the mark stands still.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
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

final Finder _face = find.byKey(JumpChip.roundKey);
final Finder _logo = find.descendant(
  of: find.byType(JumpChip),
  matching: find.byType(Logo),
);
final Finder _arrow = find.descendant(
  of: find.byType(JumpChip),
  matching: find.byIcon(Icons.arrow_downward),
);

LogoPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(of: _logo, matching: find.byType(CustomPaint)),
            )
            .painter!
        as LogoPainter;

Widget _chip({bool needs = false, bool working = true, VoidCallback? onTap}) =>
    Center(
      child: JumpChip(needs: needs, working: working, onTap: onTap ?? () {}),
    );

/// The app on a long chat, [busy] or not, scrolled far up.
Future<Daemon> _scrolledUp(
  WidgetTester tester, {
  required bool busy,
  Size size = const Size(1400, 900),
  Brightness? brightness,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final status = ChatStatus(busy: busy);
  final c = chat('a', 'claude', 'Chat a', status: status);
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

void main() {
  setUpAll(loadFonts);

  testWidgets('scrolled up while the agent works, the chip is the mark; '
      'idle, it says Jump to latest', (tester) async {
    var d = await _scrolledUp(tester, busy: true);
    expect(_logo, findsOneWidget);
    expect(find.text('Jump to latest'), findsNothing);
    expect(_painter(tester).turning, isTrue);
    await closeView(tester, d);

    d = await _scrolledUp(tester, busy: false);
    expect(_logo, findsNothing);
    expect(find.text('Jump to latest'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('on the Mac a small round face; the pointer over it shows '
      'the arrow, and a press jumps', (tester) async {
    var jumped = 0;
    await tester.pumpWidget(themed(_chip(onTap: () => jumped++)));
    await tester.pumpAndSettle();
    final face = tester.getRect(_face);
    expect(face.width, JumpChip.face);
    expect(face.height, JumpChip.face);
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
    // Nothing moves as it swaps.
    expect(tester.getRect(_face), face);

    await tester.tap(_face);
    expect(jumped, 1);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(_logo, findsOneWidget);
  });

  testWidgets('needing you wins: amber words, no mark', (tester) async {
    await tester.pumpWidget(themed(_chip(needs: true)));
    await tester.pumpAndSettle();
    expect(_logo, findsNothing);
    expect(find.text('Needs you'), findsOneWidget);
  });

  testWidgets('the mark turns on the loop clock; with Reduce Motion it '
      'stands still', (tester) async {
    addTearDown(() => Shine.stopAt = 0);
    Shine.stopAt = 0.25;
    await tester.pumpWidget(themed(_chip(), still: false));
    await tester.pump();
    final (outer, inner) = _painter(tester).turned;
    expect(outer, greaterThan(0));
    expect(inner, lessThan(0));

    await tester.pumpWidget(themed(_chip(), still: true));
    await tester.pump();
    expect(_painter(tester).turning, isFalse);
    expect(_painter(tester).turned, (0.0, 0.0));
  });

  testWidgets('on the phone the round face keeps its size and its finger '
      'target', (tester) async {
    await tester.pumpWidget(themed(TouchTargets(child: _chip())));
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
