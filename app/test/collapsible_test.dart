import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    // Enlarged, so the corners show: the card's fill, cut to a control's.
    testWidgets('golden, a call’s row, $name', (tester) async {
      viewport(tester, const Size(240, 60), ratio: 4);
      await tester.pumpWidget(
        themed(
          const Padding(
            padding: EdgeInsets.all(12),
            child: Collapsible(
              header: Text(r'$ cd ~/x'),
              body: SizedBox(height: 20),
            ),
          ),
          tokens: tokens,
        ),
      );
      await expectLater(
        find.byType(Collapsible),
        matchesGoldenFile('goldens/collapsible_row_$name.png'),
      );
    });
  }
}
