import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The Pull request tab at the window's real widths (1440, and 1100: the
/// narrowest with the details panel), in both themes, its text inside the
/// window. At 1440 it's the tab's window golden (the sidebar hidden: it has
/// its own); the rest are renders.
void main() {
  setUpAll(loadFonts);

  for (final width in [1440.0, 1100.0]) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      testWidgets('the tab at ${width.toInt()}, $name', (tester) async {
        final golden = width == 1440;
        if (golden) sidebarHidden.value = true;
        final (d, _) = await openPullTab(
          tester,
          fixturePull(),
          size: Size(width, 1000),
          brightness: brightness,
        );
        expectTextInside(tester, width);
        final shot = 'pull_tab_${width.toInt()}_$name';
        if (golden) {
          await expectLater(
            find.byType(NushiApp),
            matchesGoldenFile('goldens/$shot.png'),
          );
        } else {
          await render(tester, find.byType(NushiApp), shot);
        }
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
      testWidgets('$file at 1440, $name', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          fixturePull(),
          size: const Size(1440, 1000),
          brightness: brightness,
        );
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
        expectTextInside(tester, 1440);
        await render(tester, find.byType(NushiApp), 'pull_tab_${file}_$name');
        d.dispose();
      }, variant: _mac);
    }
  }
}
