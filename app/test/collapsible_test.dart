import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    // Enlarged, so the corners show: the border's curve over the red fill.
    testWidgets('golden, a failed call, $name', (tester) async {
      tester.view.devicePixelRatio = 4;
      tester.view.physicalSize = const Size(240, 56) * 4;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(tokens).toThemeData(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(12),
              child: Collapsible(
                header: Text(r'$ cd ~/x'),
                body: SizedBox(height: 20),
                failed: true,
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(Collapsible),
        matchesGoldenFile('goldens/collapsible_failed_$name.png'),
      );
    });
  }
}
