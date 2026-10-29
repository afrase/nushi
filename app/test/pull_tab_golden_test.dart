import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The Pull request tab at the window's real widths (1440, and 1100: the
/// narrowest with the details panel), in both themes.
void main() {
  setUpAll(loadFonts);

  for (final width in [1440.0, 1100.0]) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      testWidgets('golden: the tab at ${width.toInt()}, $name', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          fixturePull(),
          size: Size(width, 1000),
          brightness: brightness,
        );
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/pull_tab_${width.toInt()}_$name.png'),
        );
        d.dispose();
      }, variant: _mac);
    }
  }

  // Each section, scrolled to, at 1440.
  for (final section in ['Activity 4', 'Checks · 3 failing', 'Files 12']) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      final file = section.split(' ').first.toLowerCase();
      testWidgets('golden: $file at 1440, $name', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          fixturePull(),
          size: const Size(1440, 1000),
          brightness: brightness,
        );
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/pull_tab_${file}_$name.png'),
        );
        d.dispose();
      }, variant: _mac);
    }
  }
}
