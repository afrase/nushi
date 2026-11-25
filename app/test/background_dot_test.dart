// A chat whose turn ended while its background tasks run wears its own
// shape, a half-filled disc (#113): not the idle ring recoloured, so it
// reads without its colour, its tooltip or motion.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The half disc [dot] draws, if it draws one.
HalfDisc? _halfDisc(WidgetTester tester, Finder dot) {
  final paints = find.descendant(of: dot, matching: find.byType(CustomPaint));
  for (final p in tester.widgetList<CustomPaint>(paints)) {
    if (p.painter case final HalfDisc disc) return disc;
  }
  return null;
}

/// The room a chat's mark has.
const double _room = ChatDot.size * 1.6;

void main() {
  for (final still in [false, true]) {
    final how = still ? 'with Reduce Motion' : 'moving';
    testWidgets('a chat in the background wears the half disc, $how', (
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
      ]).connect(tester);
      await tester.pumpWidget(
        themed(
          ListView(
            children: [
              ChatRow(d.chats['b']!, onTap: () {}),
              ChatRow(d.chats['i']!, onTap: () {}),
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
      final disc = _halfDisc(tester, rowDot('Sort the ledger'));
      expect(disc, isNotNull, reason: "the chat's dot");
      expect(disc!.color, t.running);
      // Still: nothing repaints it, moving or not.
      expect(disc.shouldRepaint(HalfDisc(t.running)), isFalse);
      final group = _halfDisc(tester, find.byType(PhaseDot));
      expect(group?.color, t.running, reason: "a collapsed group's dot");
      // The idle chat keeps its ring.
      expect(_halfDisc(tester, rowDot('Idle one')), isNull);
      // In the dot's room, as every state's mark.
      for (final title in ['Sort the ledger', 'Idle one']) {
        final size = tester.getSize(rowDot(title));
        expect(size.width, closeTo(ChatDot.size * 1.6, 0.01));
        expect(size.height, closeTo(ChatDot.size * 1.6, 0.01));
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

  test('the left half is solid, the right half a ring', () async {
    const side = 40.0;
    const ink = Color(0xFF2080FF); // design: a probe's colour
    final recorder = ui.PictureRecorder();
    HalfDisc(ink).paint(Canvas(recorder), const Size.square(side));
    final image = await recorder.endRecording().toImage(
      side.toInt(),
      side.toInt(),
    );
    final bytes = (await image.toByteData())!;
    image.dispose();
    int alpha(double x, double y) =>
        bytes.getUint8((y.toInt() * side.toInt() + x.toInt()) * 4 + 3);
    const c = side / 2;
    final r = HalfDisc.radius(const Size.square(side));
    expect(alpha(c - r / 2, c), 255, reason: 'the left half, filled');
    expect(alpha(c - r / 2, c - r / 2), 255);
    expect(alpha(c + r / 2, c), 0, reason: 'the right half, open');
    expect(alpha(c + r - 0.75, c), greaterThan(200), reason: 'its ring');
    expect(alpha(c + r + 2, c), 0, reason: 'nothing past it');
  });
}
