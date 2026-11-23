import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/pane_tabs.dart';

import 'browser_fixture.dart' show browserFakes;
import 'harness.dart';
import 'panes_app.dart';

// The browser pane squeezed (ADR 0123): its Servers, ⋯ and + go before
// the showing chip has less than its least, and a lone chip shrinks to
// its icon and ✕ rather than being cut; nothing overflows.

/// [d]'s chat c's browser pane alone, [width] wide.
Future<void> _pane(WidgetTester tester, Daemon d, double width) async {
  final c = d.chats['c']!;
  await tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 400,
          child: BrowserPane(
            chat: c,
            tab: c.browser.shown.value!,
            daemon: d,
            onClose: () {},
            onExpand: () {},
          ),
        ),
      ),
      banner: false,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('from its least down, the showing chip stays whole, its ✕ in '
      'sight, and nothing overflows', (tester) async {
    browserFakes();
    final (d, _) = await panesApp(tester, width: 1700);
    viewport(tester, const Size(600, 400));
    d.chats['c']!.openBrowserTab('http://localhost:3000');
    // An overflow at any width fails the test as the binding reports it,
    // with the widget and its constraints.
    for (var w = 320.0; w >= 100; w -= 5) {
      await _pane(tester, d, w);
      final row = tester.getRect(find.byType(PaneTabs));
      final close = tester.getRect(
        find.descendant(
          of: find.byType(PaneTabs),
          matching: find.byTooltip('Close tab'),
        ),
      );
      // While the tabs have a chip's least, its ✕ is inside them.
      if (row.width >= previewChipLeast) {
        expect(close.right, lessThanOrEqualTo(row.right + 0.5), reason: '$w');
        expect(close.left, greaterThanOrEqualTo(row.left), reason: '$w');
      }
      // The + only with room for a chip at its least beside it.
      if (find.byTooltip('New browser tab').evaluate().isNotEmpty) {
        expect(row.width, greaterThanOrEqualTo(previewTabLeast), reason: '$w');
      }
    }
    await closeView(tester, d);
  }, variant: onMac);
}
