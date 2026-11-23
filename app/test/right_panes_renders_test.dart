import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/main.dart';

import 'browser_fixture.dart' show browserFakes;
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'panes_app.dart';

// Full windows of a chat with its panes open, to look at (ADR 0123): the
// sets of panes at the widths that show each way they're laid out, in
// both themes. Written only with NUSHI_RENDERS set (`make renders
// TEST=test/right_panes_renders_test.dart`); never compared.

PanesOpen _set({
  bool side = false,
  bool files = false,
  bool subagent = false,
  bool command = false,
  int previews = 0,
  int browser = 0,
}) => (
  side: side,
  files: files,
  subagent: subagent,
  command: command,
  previews: previews,
  browser: browser,
);

final _sets = <String, PanesOpen>{
  'none': _set(),
  'side': _set(side: true),
  'files': _set(files: true),
  'subagent': _set(subagent: true),
  'command': _set(command: true),
  'files3': _set(previews: 3),
  'browser2': _set(browser: 2),
  'files+preview': _set(files: true, previews: 1),
  'side+files+preview': _set(side: true, files: true, previews: 1),
};

/// The windows where the layout's choices show (ADR 0123's table).
final _notable = <(double, bool, String)>[
  (1700, true, 'files+preview'),
  (1700, true, 'side+files+preview'),
  (1700, false, 'side+files+preview'),
  (1440, true, 'side'),
  (1440, true, 'files3'),
  (1440, true, 'files+preview'),
  (1200, false, 'side'),
  (1200, true, 'side'),
  (1200, true, 'subagent'),
  (900, true, 'none'),
  (900, true, 'subagent'),
  (900, false, 'files'),
];

void main() {
  rendersOnly();
  setUpAll(loadFonts);

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required double width,
    required bool sidebar,
    required PanesOpen open,
    Brightness brightness = Brightness.dark,
    bool terminal = false,
    bool expand = false,
  }) async {
    browserFakes();
    final (d, _) = await panesApp(
      tester,
      width: width,
      sidebar: sidebar,
      terminal: terminal,
      brightness: brightness,
      open: open,
    );
    if (expand) {
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
    }
    FocusManager.instance.primaryFocus?.unfocus(); // no caret
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), name);
    await closeView(tester, d);
  }

  for (final width in [1700.0, 720.0]) {
    for (final MapEntry(key: name, value: open) in _sets.entries) {
      for (final brightness in [Brightness.dark, Brightness.light]) {
        if (width == 720 && brightness == Brightness.light) continue;
        final b = brightness.name;
        renderTest('${width.round()} $name $b', (tester) async {
          await shot(
            tester,
            'rp_${width.round()}_hidden_${name}_$b',
            width: width,
            sidebar: false,
            open: open,
            brightness: brightness,
          );
        }, variant: onMac);
      }
    }
  }

  for (final (width, sidebar, name) in _notable) {
    final where = sidebar ? 'shown' : 'hidden';
    renderTest('${width.round()} $where $name', (tester) async {
      await shot(
        tester,
        'rp_notable_${width.round()}_${where}_$name',
        width: width,
        sidebar: sidebar,
        open: _sets[name]!,
        terminal: true,
      );
    }, variant: onMac);
  }

  for (final width in [1700.0, 720.0]) {
    for (final sidebar in [true, false]) {
      final where = sidebar ? 'shown' : 'hidden';
      renderTest('expanded ${width.round()} $where', (tester) async {
        await shot(
          tester,
          'rp_expanded_${width.round()}_$where',
          width: width,
          sidebar: sidebar,
          open: _set(browser: 2),
          terminal: true,
          expand: true,
        );
      }, variant: onMac);
    }
  }
}
