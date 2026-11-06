import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/main.dart';
import 'package:nushi/theme/theme.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// A browser tab's bar as Claude desktop's (ADR 0094): the host alone,
// centred, out of the field's focus, and at the field's right end a button
// that opens the page in the default browser, named in its tooltip.
void main() {
  setUpAll(loadFonts);

  Finder outside() => find.descendant(
    of: find.byType(BrowserBar),
    matching: find.byWidgetPredicate(
      (w) => w is IconTap && w.line == LineIcon.openOutside,
    ),
  );

  testWidgets('the host alone, centred in the field; the whole address in '
      'its focus', (tester) async {
    browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('https://example.com/docs/start?x=1');
    await tester.pumpAndSettle();
    final host = find.descendant(
      of: find.byType(BrowserBar),
      matching: find.text('example.com'),
    );
    expect(host, findsOneWidget);
    // Nothing of its path drawn (the field's own text is hidden under).
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('/docs'),
      ),
      findsNothing,
    );
    final field = tester.getRect(addressBox);
    expect(tester.getCenter(host).dx, closeTo(field.center.dx, 1));
    await tester.tap(addressField);
    await tester.pump();
    expect(host, findsNothing);
    expect(
      addressEditable(tester).widget.controller.text,
      'https://example.com/docs/start?x=1',
    );
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('Open in names the default browser and opens the tab’s page '
      'there', (tester) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('http://localhost:3000/menu');
    await tester.pumpAndSettle();
    expect(outside(), findsOneWidget);
    expect(find.byTooltip('Open in Google Chrome'), findsOneWidget);
    // At the field's right end, inside it.
    final field = tester.getRect(addressBox);
    final button = tester.getRect(outside());
    expect(button.right, lessThanOrEqualTo(field.right));
    expect(field.right - button.right, lessThan(8));
    // The page on screen, not what's being typed.
    await tester.enterText(addressField, 'example.com');
    await tester.tap(outside());
    await tester.pump();
    expect(fakes.opened, [Uri.parse('http://localhost:3000/menu')]);
    expect(fakes.hosts.single.opened, hasLength(1));
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('with no name from the Mac it says your browser', (tester) async {
    browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('https://example.com/');
    await tester.pumpAndSettle();
    // The Mac couldn't say, the next time a tab asked.
    defaultBrowserNameIs(null);
    d.chats['c']!.openBrowserTab('https://example.org/');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open in your browser'), findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a new tab and a blank page have no Open in', (tester) async {
    browserFakes();
    final d = await browserApp(tester);
    final tab = d.chats['c']!.openBrowserTab();
    await tester.pumpAndSettle();
    expect(outside(), findsNothing);
    tab.address.value = 'about:blank';
    await tester.pump();
    expect(outside(), findsNothing);
    tab.address.value = 'https://example.com/';
    await tester.pump();
    expect(outside(), findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  for (final (name, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    group('looks, $name', () {
      testWidgets('the bar: the host centred, Open in at the field’s end', (
        tester,
      ) async {
        browserFakes();
        const size = Size(560, 120);
        viewport(tester, size);
        final c = ChatState('c', '/Users/me/nushi');
        final tab = c.openBrowserTab('https://example.com/docs/start');
        await tester.pumpWidget(
          themed(
            tokens: tokens,
            Center(
              child: RepaintBoundary(
                key: const ValueKey('pane'),
                child: SizedBox.fromSize(
                  size: size,
                  child: BrowserPane(
                    chat: c,
                    tab: tab,
                    onClose: () {},
                    onExpand: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('pane')),
          matchesGoldenFile('goldens/browser_bar_$name.png'),
        );
      }, variant: macOnly);

      for (final width in [1700.0, 720.0]) {
        testWidgets('renders: the bar in the window, ${width.toInt()} wide', (
          tester,
        ) async {
          browserFakes();
          final d = await browserApp(
            tester,
            width: width,
            brightness: brightness,
          );
          d.chats['c']!.openBrowserTab('https://example.com/docs/start');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectTextInside(tester, width);
          final pane = tester.getRect(find.byType(BrowserPane));
          expect(tester.getRect(outside()).right, lessThan(pane.right));
          await render(
            tester,
            find.byType(NushiApp),
            'browser_bar_${width.toInt()}_$name',
          );
          // With the pointer on Open in, its tooltip.
          final mouse = await tester.createGesture(kind: .mouse);
          addTearDown(mouse.removePointer);
          await mouse.addPointer(location: tester.getCenter(outside()));
          await tester.pumpAndSettle(const Duration(seconds: 2));
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'browser_bar_tooltip_${width.toInt()}_$name',
          );
          await closeView(tester, d);
        }, variant: macOnly);
      }
    });
  }
}
