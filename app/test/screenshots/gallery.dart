// The component gallery (docs/design.md): every sheet of
// `test/gallery/sheets.dart`, dark and light, as PNGs in app/build/gallery
// (`make gallery`), drawn with shadows as the app draws them. Not part of
// `make test` (the name doesn't end in _test.dart); `gallery_test.dart`
// keeps a few sheets as goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';

import '../fake_daemon.dart';
import '../gallery/sheets.dart';
import '../harness.dart';

void main() {
  setUpAll(loadFonts);

  for (final sheet in sheets) {
    for (final tokens in [Tokens.dark, Tokens.light]) {
      final name = '${sheet.name}_${tokens.brightness.name}';
      testWidgets('gallery $name', (tester) async {
        await drawSheet(tester, sheet, tokens);
        await render(tester, find.byType(MaterialApp), name);
      }, variant: mac);
    }
  }
}
