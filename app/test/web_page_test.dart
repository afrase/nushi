import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_page_macos.dart';

import 'fake_web_views.dart';

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
    final web = fakeWebViews();
    var asked = 0;
    Duration? ago;
    web.since = ({pointerOnly = false}) async {
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
    web.since = ({pointerOnly = false}) =>
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

  // Fix review 2026-11-06: nothing showed that a preview waits for its
  // cookies to be off before it loads, or loads nothing when they can't be.
  test('a preview loads only once its cookies are off, and never if they '
      'can’t be', () async {
    final was = blockCookies;
    addTearDown(() => blockCookies = was);
    final made = Completer<void>();
    final off = Completer<void>();
    final asked = <int>[];
    blockCookies = (id) {
      asked.add(id);
      return off.future;
    };
    final loads = CookielessLoads(made.future, () => 7);
    var loaded = 0;
    final done = loads.load(() async => loaded++);
    await pumpEventQueue();
    expect(asked, isEmpty); // no native view yet
    expect(loaded, 0);
    made.complete();
    await pumpEventQueue();
    expect(asked, [7]);
    expect(loaded, 0); // its cookies still on
    off.complete();
    await done;
    expect(loaded, 1);
    await loads.load(() async => loaded++);
    expect(asked, [7]); // asked once
    expect(loaded, 2);
    // The rule can't be added: nothing loads, now or later.
    blockCookies = (id) => Future.error(PlatformException(code: 'failed'));
    final refused = CookielessLoads(Future.value(), () => 8);
    await expectLater(refused.load(() async => loaded++), throwsException);
    await expectLater(refused.load(() async => loaded++), throwsException);
    expect(loaded, 2);
  });

  // Browser tabs load any site now (ADR 0094) and share WebKit's store
  // with file previews: a site a tab signed in to must never load as a
  // preview's main frame, a press or not (docs/security.md).
  test('a file’s preview loads no site in its view, what a browser tab '
      'would', () {
    const p = '/repo/out/page.html';
    final press = clock().subtract(const Duration(milliseconds: 200));
    for (final url in [
      'https://mail.example.com/',
      'http://example.com/login',
      'http://localhost:3000/',
      'http://192.168.7.5/',
    ]) {
      // As the user typed it, which a local address needs from a tab.
      expect(
        browserNavigation(url, mainFrame: true, asked: true),
        PageNavigation.stay,
        reason: 'a tab: $url',
      );
      expect(
        navigation(url, p, mainFrame: true),
        PageNavigation.drop,
        reason: url,
      );
      // A click on a link sends it to the default browser, not the view.
      expect(
        navigation(url, p, mainFrame: true, pressed: press),
        PageNavigation.open,
        reason: url,
      );
    }
  });
}
