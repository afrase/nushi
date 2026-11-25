// The sheets the owner picks the background mark from (#113): every
// state's dot as it is, the background ring as it was, the half disc the
// app now draws, and two other candidates that exist only here.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The room a chat's mark has.
const double _room = ChatDot.size * 1.6;

/// The background ring as it was before the half disc, at its strongest.
class _OldRing extends CustomPainter {
  new(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.shortestSide / 2 * 0.55,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color,
  );
  @override
  bool shouldRepaint(_OldRing old) => false;
}

/// A candidate: the idle ring with a solid dot at its centre.
class _RingAndDot extends CustomPainter {
  new(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = HalfDisc.radius(size);
    canvas
      ..drawCircle(
        c,
        r - 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color,
      )
      ..drawCircle(c, r * 0.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RingAndDot old) => false;
}

/// A candidate: two small dots side by side.
class _TwoDots extends CustomPainter {
  new(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(HalfDisc.radius(size) * 0.55, size.width / 4 - 0.4);
    final gap = r + 0.6;
    canvas
      ..drawCircle(c.translate(-gap, 0), r, Paint()..color = color)
      ..drawCircle(c.translate(gap, 0), r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TwoDots old) => false;
}

Widget _painted(CustomPainter p) =>
    CustomPaint(size: const Size.square(_room), painter: p);

void main() {
  setUpAll(loadFonts);
  rendersOnly();

  for (final b in Brightness.values) {
    renderTest('the background mark and its candidates (${b.name})', (
      tester,
    ) async {
      viewport(tester, const Size(620, 700), ratio: 2, brightness: b);
      final d = await FakeDaemon([
        chat('n', 'claude', 'N', status: ChatStatus(busy: true, waiting: true)),
        chat('w', 'claude', 'W', status: ChatStatus(busy: true)),
        chat('u', 'claude', 'U')..done = true,
        chat('i', 'claude', 'I'),
        chat('b', 'claude', 'B', status: ChatStatus(background: 2))
          ..done = true,
        chat('s', 'claude', 'S', status: ChatStatus(asleep: true)),
        chat(
          'e',
          'claude',
          'E',
          status: ChatStatus(reopenFailed: true, sessionGone: true),
        )..done = true,
        chat('f', 'claude', 'F', status: ChatStatus(reopenFailed: true)),
      ]).connect(tester);
      final tokens = b == Brightness.dark ? Tokens.dark : Tokens.light;
      final running = tokens.running;
      Widget dot(String id) => ChatDot(chat: d.chats[id]!);
      final rows = <(String, Widget)?>[
        ('Needs you (as today)', dot('n')),
        ('Working (as today; its ring grows out and fades)', dot('w')),
        ('Done, not yet seen (as today)', dot('u')),
        ('Idle (as today)', dot('i')),
        ('Asleep (as today: no mark, the title fades)', dot('s')),
        ('Expired (as today)', dot('e')),
        ("Couldn't start (as today)", dot('f')),
        null,
        (
          'In background, before: a ring that pulsed',
          _painted(_OldRing(running)),
        ),
        ('In background, built: a half-filled disc', dot('b')),
        (
          'In background, other: a ring with a dot inside',
          _painted(_RingAndDot(running)),
        ),
        ('In background, other: two small dots', _painted(_TwoDots(running))),
      ];
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) {
              final theme = NushiTheme.of(context);
              final t = theme.t;
              Widget line((String, Widget) r) => SizedBox(
                height: 54,
                child: Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: Text(r.$1, style: theme.ui(t.text)),
                    ),
                    // Real size, as a sidebar row shows it beside a title.
                    SizedBox(
                      width: 150,
                      child: Row(
                        children: [
                          r.$2,
                          const SizedBox(width: 8),
                          Text(
                            'Sort the ledger',
                            style: theme.ui(t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    SizedBox.square(
                      dimension: _room * 4,
                      child: Center(
                        child: Transform.scale(scale: 4, child: r.$2),
                      ),
                    ),
                  ],
                ),
              );
              return ColoredBox(
                color: t.window,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 300,
                            child: Text('', style: theme.ui(t.text)),
                          ),
                          SizedBox(
                            width: 190,
                            child: Text(
                              'Real size',
                              style: theme.ui(t.textMuted, size: 12),
                            ),
                          ),
                          Text('4×', style: theme.ui(t.textMuted, size: 12)),
                        ],
                      ),
                      for (final r in rows)
                        if (r == null)
                          Divider(color: t.line, height: 17)
                        else
                          line(r),
                    ],
                  ),
                ),
              );
            },
          ),
          tokens: tokens,
          still: true,
          banner: false,
        ),
      );
      await tester.pump();
      await render(
        tester,
        find.byType(MaterialApp),
        'background_mark_${b.name}',
      );
      d.dispose();
    });
  }
}
