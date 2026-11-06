import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    await typeAddress(tester, 'file://server/share/a.md');
    expect(find.textContaining('Not a file on this Mac'), findsOneWidget);
    expect(fakes.hosts, isEmpty);
    expect(fakes.opened, isEmpty);
    expect(find.text(browserHint), findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a typed file address, or a path from /, opens the file’s '
      'preview, the browser tab kept', (tester) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    final c = d.chats['c']!;
    final tab = c.openBrowserTab('https://example.com/');
    await tester.pumpAndSettle();
    await typeAddress(tester, 'file:///Users/me/nushi/docs/My%20plan.md');
    expect(c.previewFile, '/Users/me/nushi/docs/My plan.md');
    expect(c.previewTabs.value.first, tab);
    expect(tab.address.value, 'https://example.com/');
    // The tab's page loaded only what it was opened at.
    expect(fakes.hosts.single.opened, [Uri.parse('https://example.com/')]);
    c.showPreviewTab(tab);
    await tester.pumpAndSettle();
    await typeAddress(tester, '/Users/me/nushi/README.md');
    expect(c.previewFile, '/Users/me/nushi/README.md');
    expect(fakes.opened, isEmpty);
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
    final field = tester.getRect(addressBox);
    expect(tester.getRect(mark).right, lessThanOrEqualTo(field.left));
    final pane = tester.getRect(find.byType(BrowserPane));
    expect(field.right, closeTo(pane.right - BrowserBar.inset, 0.5));
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
    fakes.hosts.single.failure.value = (
      code: -1202,
      reason: _untrusted,
      url: 'https://self-signed.badssl.com/',
    );
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

  // Fix review 2026-11-06: the bar followed WebKit's URL, which is a
  // navigation's as soon as it starts. A page could start one to a site
  // that never answers and keep its own fake form up, and take input, under
  // that site's name, its "Not secure" gone.
  testWidgets('the bar stays on the page shown until a load commits', (
    tester,
  ) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    final tab = d.chats['c']!.openBrowserTab('http://evil.example/');
    await tester.pumpAndSettle();
    final host = fakes.hosts.single;
    final mark = find.descendant(
      of: find.byType(BrowserBar),
      matching: find.text('Not secure'),
    );
    String field() => addressEditable(tester).widget.controller.text;
    expect(mark, findsOneWidget);
    // A navigation starts, and never finishes.
    host.urlChanged('https://www.mybank.com:444/');
    await tester.pump();
    expect(tab.address.value, 'http://evil.example/');
    expect(field(), 'http://evil.example/');
    expect(mark, findsOneWidget);
    // The page's own history moves the bar.
    host.urlChanged('http://evil.example/step2#top');
    await tester.pump();
    expect(field(), 'http://evil.example/step2#top');
    // A load that commits moves it anywhere.
    host.committed('https://www.mybank.com/');
    await tester.pump();
    expect(field(), 'https://www.mybank.com/');
    expect(mark, findsNothing);
    await closeView(tester, d);
  }, variant: macOnly);

  // Fix review 2026-11-06: a page could send the tab to
  // https://www.paypal.com@evil.example/, and the bar and a failure's
  // heading read the user name as the host.
  testWidgets('the bar never shows a user name, and keeps the host’s end '
      'in sight', (tester) async {
    final fakes = browserFakes();
    final d = await browserApp(tester, width: 720);
    d.chats['c']!.openBrowserTab('https://example.com/');
    await tester.pumpAndSettle();
    final host = fakes.hosts.single;
    final bar = find.byType(BrowserBar);
    String shown() => tester
        .widgetList<RichText>(
          find.descendant(of: bar, matching: find.byType(RichText)),
        )
        .map((t) => t.text.toPlainText())
        .join('|');
    host.committed('https://www.paypal.com@evil.example/signin');
    await tester.pump();
    expect(
      addressEditable(tester).widget.controller.text,
      'https://evil.example/signin',
    );
    expect(shown(), isNot(contains('paypal')));
    // The host only, as Claude desktop's bar.
    expect(shown(), contains('evil.example'));
    expect(shown(), isNot(contains('/signin')));
    // A host longer than the field loses its start, not its end.
    const long =
        'www.paypal.com.account-verify.secure-login.support-centre.billing'
        '.customer-service.evil.example';
    host.committed('https://$long/signin');
    await tester.pump();
    final text = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().endsWith('evil.example'),
      ),
    );
    expect(text, findsOneWidget);
    expect(tester.widget<RichText>(text).text.toPlainText(), startsWith('…'));
    // Its end drawn, not cut by the ellipsis at the right.
    expect(
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getRect(text).right,
      lessThanOrEqualTo(tester.getRect(addressBox).right),
    );
    // In the field's focus, the whole address, to edit.
    await tester.tap(addressField);
    await tester.pump();
    expect(text, findsNothing);
    expect(
      addressEditable(tester).widget.controller.text,
      'https://$long/signin',
    );
    // A failure names the address that failed, by its host.
    host.failure.value = (
      code: -1004,
      reason: 'Could not connect to the server.',
      url: 'https://www.paypal.com@evil.example:8443/',
    );
    await tester.pump();
    expect(find.text('Can’t reach evil.example:8443'), findsOneWidget);
    await closeView(tester, d);
  }, variant: macOnly);

  // Fix review 2026-11-06: a provisional load that fails puts WebKit's URL
  // back on the page shown, and the heading named that page.
  testWidgets('a failure names the address that failed, not the tab’s', (
    tester,
  ) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('https://good.example/');
    await tester.pumpAndSettle();
    final host = fakes.hosts.single..urlChanged('https://expired.badssl.com/');
    host.failure.value = (
      code: -1201,
      reason: 'The certificate for this server has expired.',
      url: 'https://expired.badssl.com/',
    );
    await tester.pump();
    expect(
      find.text('expired.badssl.com’s certificate isn’t valid'),
      findsOneWidget,
    );
    expect(host.tab.address.value, 'https://good.example/');
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
        host.failure.value = (
          code: -1202,
          reason: _untrusted,
          url: 'https://self-signed.badssl.com/',
        );
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
            ..failure.value = (
              code: -1202,
              reason: _untrusted,
              url: 'https://self-signed.badssl.com/',
            );
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'browser_certificate_${width.toInt()}_$name',
          );
          // A host made to read as another site's, longer than the field.
          fakes.hosts.single
            ..failure.value = null
            ..committed(
              'https://www.paypal.com.account-verify.secure-login'
              '.support-centre.billing.evil.example/signin?next=%2Fhome',
            );
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'browser_long_host_${width.toInt()}_$name',
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
