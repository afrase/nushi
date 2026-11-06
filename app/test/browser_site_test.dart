import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/main.dart';
import 'package:nushi/theme/theme.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// A browser tab loads any site (ADR 0094): what the address field takes
// and what it says when it takes nothing, the bar's "Not secure", and why
// a page didn't load.
void main() {
  setUpAll(loadFonts);

  testWidgets('a site loads in the tab, https unless typed otherwise', (
    tester,
  ) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab();
    await tester.pumpAndSettle();
    await typeAddress(tester, 'example.com/docs');
    final host = fakes.hosts.single;
    expect(host.opened, [Uri.parse('https://example.com/docs')]);
    expect(find.text(browserHint), findsNothing);
    expect(
      addressEditable(tester).widget.controller.text,
      'https://example.com/docs',
    );
    await typeAddress(tester, 'http://neverssl.com');
    await typeAddress(tester, '192.168.7.5:8080');
    expect(host.opened.skip(1), [
      Uri.parse('http://neverssl.com'),
      Uri.parse('http://192.168.7.5:8080'),
    ]);
    // Nothing goes to the default browser.
    expect(fakes.opened, isEmpty);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a word, a file or a script loads nothing, and the field '
      'says why', (tester) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab();
    await tester.pumpAndSettle();
    for (final text in ['tea', 'how to brew tea', 'javascript:alert(1)']) {
      await typeAddress(tester, text);
      expect(find.textContaining('Not an address'), findsOneWidget);
    }
    await typeAddress(tester, 'file:///etc/passwd');
    expect(find.textContaining('A file opens in a file’s tab'), findsOneWidget);
    expect(fakes.hosts, isEmpty);
    expect(fakes.opened, isEmpty);
    expect(find.text(browserHint), findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('"Not secure" marks plain http from another machine, the '
      'page’s address, not the field’s', (tester) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    final tab = d.chats['c']!.openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    final mark = find.descendant(
      of: find.byType(BrowserBar),
      matching: find.text('Not secure'),
    );
    expect(mark, findsNothing);
    await typeAddress(tester, 'http://example.com');
    expect(mark, findsOneWidget);
    // Between the buttons and the field, the field still to the edge.
    final field = tester.getRect(addressField);
    expect(tester.getRect(mark).right, lessThanOrEqualTo(field.left));
    final pane = tester.getRect(find.byType(BrowserPane));
    expect(field.right, closeTo(pane.right - 8, 0.5));
    // Typing elsewhere leaves it: the page is still the http one.
    await tester.enterText(addressField, 'example.com');
    await tester.pump();
    expect(mark, findsOneWidget);
    fakes.hosts.single.tab.address.value = 'https://example.com/';
    await tester.pump();
    expect(mark, findsNothing);
    expect(tab.address.value, 'https://example.com/');
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a certificate WebKit refused says so, over the page', (
    tester,
  ) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('https://self-signed.badssl.com/');
    await tester.pumpAndSettle();
    fakes.hosts.single.failure.value = (code: -1202, reason: _untrusted);
    await tester.pump();
    expect(
      find.text('self-signed.badssl.com’s certificate isn’t valid'),
      findsOneWidget,
    );
    expect(find.text(_untrusted), findsOneWidget);
    // A new load clears it.
    fakes.hosts.single.failure.value = null;
    await tester.pump();
    expect(find.textContaining('certificate'), findsNothing);
    await closeView(tester, d);
  }, variant: macOnly);

  for (final (name, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    group('looks, $name', () {
      Future<FakeBrowserHost> pane(
        WidgetTester tester,
        Size size,
        String address,
      ) async {
        final fakes = browserFakes();
        viewport(tester, size);
        final c = ChatState('c', '/Users/me/nushi');
        final tab = c.openBrowserTab(address);
        await tester.pumpWidget(
          themed(
            tokens: tokens,
            Center(
              child: RepaintBoundary(
                key: const ValueKey('pane'),
                child: SizedBox.fromSize(
                  size: size,
                  child: BrowserPane(chat: c, tab: tab, onClose: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return fakes.hosts.single;
      }

      testWidgets('a page over plain http: "Not secure" in the bar', (
        tester,
      ) async {
        await pane(tester, const Size(560, 120), 'http://neverssl.com/');
        await expectLater(
          find.byKey(const ValueKey('pane')),
          matchesGoldenFile('goldens/browser_not_secure_$name.png'),
        );
      }, variant: macOnly);

      testWidgets('a certificate refused', (tester) async {
        final host = await pane(
          tester,
          const Size(560, 300),
          'https://self-signed.badssl.com/',
        );
        host.failure.value = (code: -1202, reason: _untrusted);
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('pane')),
          matchesGoldenFile('goldens/browser_certificate_$name.png'),
        );
      }, variant: macOnly);

      for (final width in [1700.0, 720.0]) {
        testWidgets('renders: a site in the window, ${width.toInt()} wide', (
          tester,
        ) async {
          final fakes = browserFakes();
          final d = await browserApp(
            tester,
            width: width,
            brightness: brightness,
          );
          d.chats['c']!.openBrowserTab('http://neverssl.com/');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'browser_not_secure_${width.toInt()}_$name',
          );
          // An https page whose certificate WebKit refused.
          fakes.hosts.single
            ..tab.address.value = 'https://self-signed.badssl.com/'
            ..failure.value = (code: -1202, reason: _untrusted);
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'browser_certificate_${width.toInt()}_$name',
          );
          await closeView(tester, d);
        }, variant: macOnly);
      }
    });
  }
}

/// WebKit's words for a certificate it doesn't trust (-1202), as a probe
/// app got them for self-signed.badssl.com.
const _untrusted =
    'The certificate for this server is invalid. You might be connecting '
    'to a server that is pretending to be “self-signed.badssl.com” which '
    'could put your confidential information at risk.';
