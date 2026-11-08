import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';

import 'harness.dart';

Widget _spinner({bool still = false, Tokens tokens = Tokens.dark}) => themed(
  const Center(child: SizedBox.square(dimension: 14, child: Spinner())),
  tokens: tokens,
  still: still,
);

void main() {
  testWidgets('it turns at the pulse rate, not every frame', (tester) async {
    Shine.stopAt = null; // as in the app
    addTearDown(() => Shine.stopAt = 0);
    await tester.pumpWidget(_spinner());
    var frames = 0;
    var counting = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (counting) frames++;
    });
    // A second of a 60 Hz display.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    counting = false;
    expect(frames, inInclusiveRange(pulseRate - 1, pulseRate + 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with Reduce Motion it stands still', (tester) async {
    Shine.stopAt = null;
    addTearDown(() => Shine.stopAt = 0);
    await tester.pumpWidget(_spinner(still: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final (name, tokens) in [
    ('light', Tokens.light),
    ('dark', Tokens.dark),
  ]) {
    testWidgets('golden, a still frame, $name', (tester) async {
      viewport(tester, const Size(40, 40), ratio: 3);
      await tester.pumpWidget(_spinner(tokens: tokens));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/spinner_$name.png'),
      );
    });
  }
}
