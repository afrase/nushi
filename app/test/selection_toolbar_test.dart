import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the hover sits evenly inside the pill ($name)', (
      tester,
    ) async {
      viewport(tester, const Size(240, 80));
      await tester.pumpWidget(
        themed(
          Center(
            child: RepaintBoundary(
              key: const Key('bar'),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SelectionToolbar(onSide: () {}, onReply: () {}),
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: tester.getCenter(find.text('Reply')));
      await tester.pump();
      await pointer.moveTo(tester.getCenter(find.text('Side chat')));
      await tester.pumpAndSettle();
      final pill = tester.getRect(find.byType(SelectionToolbar));
      final text = tester.getRect(find.text('Side chat'));
      expect(text.left - pill.left, 13); // the inset, then the padding
      await expectLater(
        find.byKey(const Key('bar')),
        matchesGoldenFile('goldens/selection_toolbar_hover_$name.png'),
      );
      await pointer.removePointer();
    });
  }
}
