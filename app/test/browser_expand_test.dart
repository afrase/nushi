import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// A browser tab's Expand, as Claude desktop's (ADR 0094): the pane takes
// the whole chat area, the transcript and its box hidden, until Collapse,
// Esc, the browser hidden or another chat.

Finder _inPane(String tooltip) => find.descendant(
  of: find.byType(BrowserPane),
  matching: find.byTooltip(tooltip),
);
Finder get _expand => _inPane('Expand');
Finder get _collapse => _inPane('Collapse');

void main() {
  setUpAll(loadFonts);

  testWidgets('Expand takes the chat area; Collapse gives it back, the same '
      'page all along', (tester) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    final beside = tester.getRect(find.byType(BrowserPane));
    expect(find.byType(Composer), findsOneWidget);
    await tester.tap(_expand);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(BrowserPane)),
      tester.getRect(find.byType(ChatView)),
    );
    // Hidden: not drawn, not reached.
    expect(find.byType(Composer), findsNothing);
    expect(find.byType(Composer, skipOffstage: false), findsOneWidget);
    expect(_expand, findsNothing);
    await tester.tap(_collapse);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BrowserPane)), beside);
    expect(find.byType(Composer), findsOneWidget);
    // One host, one load: the page wasn't made again.
    expect(fakes.hosts, hasLength(1));
    expect(fakes.hosts.single.opened, hasLength(1));
    // Its width as dragged is kept.
    expect(paneWidths.value, isNot(contains('preview')));
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('Esc collapses it', (tester) async {
    browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    await tester.tap(_expand);
    await tester.pumpAndSettle();
    // Straight away: the pane has the keys, not the hidden box.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    expect(find.byType(Composer), findsOneWidget);
    // And from its address field.
    await tester.tap(_expand);
    await tester.pumpAndSettle();
    await tester.tap(addressBox);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('Esc collapses it after another browser tab is picked', (
    tester,
  ) async {
    browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!
      ..openBrowserTab('https://example.com')
      ..openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    await tester.tap(_expand);
    await tester.pumpAndSettle();
    // The other tab's chip, picked while it's expanded: a new pane.
    await tester.tap(find.text('example.com').first);
    await tester.pumpAndSettle();
    expect(_collapse, findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'browser pane');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    expect(find.byType(Composer), findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('the browser hidden, a file’s tab or another chat collapse it', (
    tester,
  ) async {
    browserFakes();
    final d = await browserApp(tester);
    final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    Future<void> expand() async {
      await tester.tap(_expand);
      await tester.pumpAndSettle();
      expect(find.byType(Composer), findsNothing);
    }

    await expand();
    c.showOrHideBrowser();
    await tester.pumpAndSettle();
    c.showOrHideBrowser();
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);

    await expand();
    c.openPreview('docs/plan.md');
    await tester.pumpAndSettle();
    expect(find.byType(Composer), findsOneWidget);
    c.showPreviewTab(c.previewTabs.value.first);
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);

    await expand();
    d.select('d');
    await tester.pumpAndSettle();
    d.select('c');
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    expect(find.byType(Composer), findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    for (final width in [1700.0, 720.0]) {
      testWidgets('renders: expanded, $name, ${width.toInt()} wide', (
        tester,
      ) async {
        browserFakes();
        final d = await browserApp(
          tester,
          width: width,
          brightness: brightness,
        );
        d.chats['c']!
          ..openPreview('docs/plan.md')
          ..openBrowserTab('https://example.com');
        await tester.pumpAndSettle();
        await render(
          tester,
          find.byType(NushiApp),
          'browser_beside_${width.toInt()}_$name',
        );
        await tester.tap(_expand);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectTextInside(tester, width);
        // Its buttons at the main pane's edge.
        expect(
          tester.getRect(_inPane('Close')).right,
          closeTo(width - NushiTheme.windowPad - 8, 0.5),
        );
        await render(
          tester,
          find.byType(NushiApp),
          'browser_expanded_${width.toInt()}_$name',
        );
        await tester.tap(_inPane('More'));
        await tester.pumpAndSettle();
        await render(
          tester,
          find.byType(NushiApp),
          'browser_menu_${width.toInt()}_$name',
        );
        await tester.tap(find.text('Local network access'));
        await tester.pumpAndSettle();
        await render(
          tester,
          find.byType(NushiApp),
          'browser_submenu_${width.toInt()}_$name',
        );
        // A file's tab beside it, showing: chips too.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        final c = d.chats['c']!;
        c.showPreviewTab(c.previewTabs.value.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await render(
          tester,
          find.byType(NushiApp),
          'browser_file_chip_${width.toInt()}_$name',
        );
        await closeView(tester, d);
      }, variant: macOnly);
    }
  }
}
