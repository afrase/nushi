import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// A browser tab loads any site (ADR 0094): what the address field takes
// and what it says when it takes nothing.
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
}
