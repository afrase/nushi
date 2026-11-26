// The background mark (#113) as it moves, to look at: a sheet for each
// tick of one loop (the mark in a row at real size beside an idle and a
// working one, and 8 times its size, both themes), which make an
// animation at the clock's rate, and its play as a strip. Every name on
// them is made up.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_mark.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The room a chat's mark has.
const double _room = ChatDot.size * 1.6;

/// The loop's ticks at the clock's rate.
const int _ticks = BackgroundMark.ticks;

void main() {
  setUpAll(loadFonts);
  rendersOnly();

  renderTest('the background mark, tick by tick', (tester) async {
    viewport(tester, const Size(760, 250), ratio: 2);
    final d = await FakeDaemon([
      chat('i', 'claude', 'Tidy the garden notes'),
      chat(
        'w',
        'claude',
        'Draft the harbour map',
        status: ChatStatus(busy: true),
      ),
    ]).connect(tester);
    for (var i = 0; i < _ticks; i++) {
      final ms = i * 1000 ~/ pulseRate;
      // The working ring at its own pace, for contrast.
      Shine.stopAt =
          ms %
          StatusMark.period.inMilliseconds /
          StatusMark.period.inMilliseconds;
      final phase = i / _ticks;
      Widget panel(Tokens tokens) => Theme(
        data: NushiTheme(tokens).toThemeData(),
        child: Builder(
          builder: (context) {
            final theme = NushiTheme.of(context);
            final t = theme.t;
            Widget row(Widget mark, String title) => SizedBox(
              height: 28,
              child: Row(
                children: [
                  mark,
                  const SizedBox(width: 8),
                  Text(title, style: theme.ui(t.textSecondary)),
                ],
              ),
            );
            final mark = CustomPaint(
              size: const Size.square(_room),
              painter: BackgroundMark(t.running, t: phase),
            );
            return ColoredBox(
              color: t.window,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 190,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          row(mark, 'Sort the parcel'),
                          row(
                            ChatDot(chat: d.chats['i']!),
                            'Tidy the garden notes',
                          ),
                          row(
                            ChatDot(chat: d.chats['w']!),
                            'Draft the harbour map',
                          ),
                        ],
                      ),
                    ),
                    SizedBox.square(
                      dimension: _room * 8 + 20,
                      child: Center(
                        child: Transform.scale(scale: 8, child: mark),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        themed(
          Row(
            children: [
              Expanded(child: panel(Tokens.dark)),
              Expanded(child: panel(Tokens.light)),
            ],
          ),
          still: false,
          banner: false,
        ),
      );
      await tester.pump();
      await render(
        tester,
        find.byType(MaterialApp),
        'background_mark_${i.toString().padLeft(2, '0')}',
      );
    }
    d.dispose();
  });

  renderTest('the background mark, its play as a strip', (tester) async {
    // Every tick of the play from the rest before it to the rest after,
    // in two rows: each at real size above, 8 times below.
    const from = BackgroundMark.restTicks - 1;
    const count = _ticks - from + 1;
    const perRow = (count + 1) ~/ 2;
    const cellSize = 100.0;
    viewport(
      tester,
      const Size(perRow * cellSize + 40, 2 * 150 + 40),
      ratio: 2,
    );
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) {
            final theme = NushiTheme.of(context);
            final t = theme.t;
            Widget mark(int i) => CustomPaint(
              size: const Size.square(_room),
              painter: BackgroundMark(t.running, t: i % _ticks / _ticks),
            );
            Widget cell(int i) => SizedBox(
              width: cellSize,
              child: Column(
                children: [
                  Text('${i % _ticks}', style: theme.ui(t.textMuted, size: 12)),
                  const SizedBox(height: 6),
                  mark(i),
                  SizedBox.square(
                    dimension: cellSize,
                    child: Center(
                      child: Transform.scale(scale: 8, child: mark(i)),
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
                    for (var row = 0; row < 2; row++)
                      Row(
                        children: [
                          for (
                            var i = from + row * perRow;
                            i < min(from + (row + 1) * perRow, from + count);
                            i++
                          )
                            cell(i),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        still: false,
        banner: false,
      ),
    );
    await render(tester, find.byType(MaterialApp), 'background_mark_strip');
  });
}
