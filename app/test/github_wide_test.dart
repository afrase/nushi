import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show openView;
import 'harness.dart';

/// The view in a wide window: the bar's buttons at its right edge, not
/// where the filters' share of the free width ends.
void main() {
  setUpAll(loadFonts);

  testWidgets('golden: the view in a wide window', (tester) async {
    final (_, d) = await openView(tester, size: const Size(1700, 360));
    final close = tester.getTopRight(find.byTooltip('Close (esc)'));
    expect(close.dx, greaterThan(1700 - 40));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/github_wide_dark.png'),
    );
    await closeView(tester, d);
  });
}
