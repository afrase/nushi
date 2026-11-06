import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/web_page.dart';

void main() {
  // Security review 2026-11-04, L5: a page the agent shows (no click,
  // ADR 0068) that leaves on its own (a script's location, a refresh)
  // opened the browser; only a press in the page just before does now.
  test('a page leaves for the browser only right after a press', () {
    const p = '/repo/out/page.html';
    final now = clock();
    const away = 'https://phish.example/login';
    expect(navigation(away, p, mainFrame: true), PageNavigation.drop);
    expect(
      navigation(
        away,
        p,
        mainFrame: true,
        pressed: now.subtract(const Duration(seconds: 5)),
      ),
      PageNavigation.drop,
    );
    expect(
      navigation(
        away,
        p,
        mainFrame: true,
        pressed: now.subtract(const Duration(milliseconds: 200)),
      ),
      PageNavigation.open,
    );
    expect(
      navigation('file://$p#menu', p, mainFrame: true),
      PageNavigation.stay,
    );
    expect(
      navigation(away, p, mainFrame: false),
      PageNavigation.stay,
    ); // a frame
  });

  // Fix review 2026-11-04: the press was taken from a Flutter Listener
  // around the web view, which on the Mac never sees one (WebKit takes a
  // press inside a platform view), so every link click was dropped. It's
  // asked of the Swift side's event monitor now, and only for a page that
  // leaves.
  test("a link's press comes from the window's events", () async {
    const p = '/repo/out/page.html';
    const away = 'https://example.com/docs';
    final since = sincePressInPage;
    addTearDown(() => sincePressInPage = since);
    var asked = 0;
    Duration? ago;
    sincePressInPage = ({pointerOnly = false}) async {
      asked++;
      expect(pointerOnly, isFalse); // a key in a file's page counts
      return ago;
    };
    expect(await pageNavigation(away, p, mainFrame: true), PageNavigation.drop);
    ago = const Duration(milliseconds: 100);
    expect(await pageNavigation(away, p, mainFrame: true), PageNavigation.open);
    ago = const Duration(seconds: 3);
    expect(await pageNavigation(away, p, mainFrame: true), PageNavigation.drop);
    expect(asked, 3);
    expect(
      await pageNavigation('file://$p#top', p, mainFrame: true),
      PageNavigation.stay,
    );
    expect(asked, 3); // not asked for one that stays
    sincePressInPage = ({pointerOnly = false}) =>
        Future.error(StateError('no window'));
    expect(await pageNavigation(away, p, mainFrame: true), PageNavigation.drop);
  });

  // A file's preview shares WebKit's store with browser tabs, and WebKit
  // takes a file: page's frames as first party: it asks the Swift side to
  // strip its web view's cookies before anything loads (docs/security.md).
  testWidgets('a file’s preview asks for its web view’s cookies off', (
    tester,
  ) async {
    final asked = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('nushi/browser'),
      (call) async {
        asked.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('nushi/browser'),
        null,
      ),
    );
    await blockCookies(42);
    expect(asked.map((c) => (c.method, c.arguments)), [('noCookies', 42)]);
  });
}
