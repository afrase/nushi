// A few of the component gallery's sheets as goldens (docs/design.md), so
// a change to a shared control shows in review; `make gallery` draws them
// all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'gallery/sheets.dart';

/// The sheets kept: the controls every view is built from.
const _kept = {'buttons', 'small', 'fields'};

void main() {
  setUpAll(loadFonts);

  for (final sheet in sheets.where((s) => _kept.contains(s.name))) {
    for (final tokens in [Tokens.dark, Tokens.light]) {
      final name = 'gallery_${sheet.name}_${tokens.brightness.name}';
      testWidgets("the gallery's ${sheet.name}, ${tokens.brightness.name}", (
        tester,
      ) async {
        await drawSheet(tester, sheet, tokens);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/$name.png'),
        );
      }, variant: mac);
    }
  }
}
