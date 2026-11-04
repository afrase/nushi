import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/terminal_find.dart' show terminalStyle;

import 'fake_daemon.dart';
import 'settings_harness.dart';

void main() {
  setUpAll(loadFonts);

  // The preview draws its Nerd Font icons as the terminal does: through
  // the bundled fallback, not the picked font's ?-box
  // (docs/history/decisions-2026-10.md, [controls]).
  testWidgets('the terminal preview draws its icons from the bundled Nerd '
      'Font', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    await pumpSettings(tester, d, SettingsSection.terminal);
    final preview = tester.widget<Text>(
      find.byKey(const ValueKey('terminal-preview')),
    );
    final style = preview.style!;
    expect(style.fontFamilyFallback, terminalStyle().fontFamilyFallback);
    double width(String s, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final icons = {
      for (final r in preview.data!.runes)
        if (r >= 0xe000 && r <= 0xf8ff) String.fromCharCode(r),
    };
    expect(icons, hasLength(6)); // two folders, branch, Go, Dart, Markdown
    final symbols = TextStyle(
      fontFamily: 'Symbols Nerd Font Mono',
      fontSize: style.fontSize,
    );
    final alone = TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
    );
    for (final icon in icons) {
      final code = icon.runes.single.toRadixString(16);
      expect(width(icon, style), width(icon, symbols), reason: code);
      // JetBrains Mono alone draws its ?-box, of another width.
      expect(width(icon, alone), isNot(width(icon, symbols)), reason: code);
    }
    d.dispose();
  });
}
