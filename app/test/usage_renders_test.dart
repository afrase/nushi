import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/place.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'settings_harness.dart';
import 'usage_fixtures.dart';

/// Settings › Usage in the whole window, to look at: a week where the
/// cache does most of the work, with a cost and without, wide and at the
/// narrowest window, in both themes. Tall, so the whole page shows.
void main() {
  setUpAll(loadFonts);
  rendersOnly();

  for (final (name, usage) in <(String, GetUsageResponse Function())>[
    ('cached', cachedUsage),
    ('nocost', noCostUsage),
  ]) {
    for (final (width, height) in const [(1700.0, 2300.0), (720.0, 2900.0)]) {
      for (final b in Brightness.values) {
        renderTest('the page, $name, ${width.toInt()}, ${b.name}', (
          tester,
        ) async {
          final d = await pumpSettingsApp(
            tester,
            settingsFake()..usage = usage(),
            SettingsSection.usage,
            size: Size(width, height),
            brightness: b,
          );
          await render(
            tester,
            find.byType(NushiApp),
            'usage-$name-${width.toInt()}-${b.name}',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }
}
