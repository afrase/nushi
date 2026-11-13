import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/diagram_page_macos.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_page_macos.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    show NavigationDecision;

import 'fake_web_views.dart';

void main() {
  // Security review 2026-11-04, L5: a page the agent shows (no click,
  // ADR 0068) that leaves on its own (a script's location, a refresh)
  // opened the browser; only a press in the page just before does now.
  test('a page leaves for the browser only right after a press', () {
    const p = '/repo/out/page.html';
    final page = PageFile(p);
    final now = clock();
    const away = 'https://phish.example/login';
    expect(navigation(away, page, mainFrame: true), PageNavigation.drop);
    expect(
      navigation(
        away,
        page,
        mainFrame: true,
        pressed: now.subtract(const Duration(seconds: 5)),
      ),
      PageNavigation.drop,
    );
    expect(
      navigation(
        away,
        page,
        mainFrame: true,
        pressed: now.subtract(const Duration(milliseconds: 200)),
      ),
      PageNavigation.open,
    );
    expect(
      navigation('file://$p#menu', page, mainFrame: true),
      PageNavigation.stay,
    );
    expect(
      navigation(away, page, mainFrame: false),
      PageNavigation.stay,
    ); // a frame
  });

  // Deep review 2026-11-10, 2: WebKit loads a file through Foundation,
  // which spells an é (or a kana's dakuten) decomposed, while Dart's
  // Uri.file keeps the path's own precomposed letter: the page's own load
  // of résumé.html was refused, and its preview stayed blank.
  test('a page whose path has accented letters loads as WebKit spells it', () {
    const path = '/Users/x/café/résumé.html'; // NFC
    const webKit = 'file:///Users/x/cafe%CC%81/re%CC%81sume%CC%81.html'; // NFD
    final page = PageFile()..loading(path);
    expect(navigation(webKit, page, mainFrame: true), PageNavigation.stay);
    // Its reload and its anchors, in WebKit's spelling or Dart's.
    expect(navigation(webKit, page, mainFrame: true), PageNavigation.stay);
    expect(
      navigation('$webKit#top', page, mainFrame: true),
      PageNavigation.stay,
    );
    expect(
      navigation('${Uri.file(path)}#top', page, mainFrame: true),
      PageNavigation.stay,
    );
    // Another file is still another page, accented or not.
    for (final other in [
      'file:///Users/x/cafe%CC%81/u%CC%88ber.html',
      'file:///Users/x/cafe%CC%81/notes.html',
    ]) {
      expect(
        navigation(other, page, mainFrame: true),
        PageNavigation.drop,
        reason: other,
      );
    }
    // Only the load itself is taken on its letters, and only for this file.
    for (final other in [
      'file:///Users/x/cafe%CC%81/notes.html',
      'file:///Users/y/cafe%CC%81/re%CC%81sume%CC%81.html',
      'file:///Users/x/re%CC%81sume%CC%81.html',
    ]) {
      expect(
        navigation(other, PageFile()..loading(path), mainFrame: true),
        PageNavigation.drop,
        reason: other,
      );
    }
    final kana = PageFile()..loading('/w/が.html'); // が
    expect(
      navigation('file:///w/%E3%81%8B%E3%82%99.html', kana, mainFrame: true),
      PageNavigation.stay,
    );
  });

  // Fix review 2026-11-10: a page's link to itself by name, written
  // precomposed, resolves against WebKit's decomposed address to a path
  // with the folders WebKit's way and the name the page's: it opened the
  // browser instead of scrolling.
  test('a link to the page by name is the page, its folders as WebKit '
      'spells them', () {
    const path = '/proj/café/résumé.html'; // NFC
    const webKit = 'file:///proj/cafe%CC%81/re%CC%81sume%CC%81.html'; // NFD
    final page = PageFile()..loading(path);
    expect(navigation(webKit, page, mainFrame: true), PageNavigation.stay);
    final link = Uri.parse(webKit).resolve('résumé.html#sec');
    expect(link.path, '/proj/cafe%CC%81/r%C3%A9sum%C3%A9.html');
    expect(navigation('$link', page, mainFrame: true), PageNavigation.stay);
    expect(
      navigation(
        'file:///proj/caf%C3%A9/re%CC%81sume%CC%81.html',
        page,
        mainFrame: true,
      ),
      PageNavigation.stay,
    );
    // Its neighbours are still other pages, however they're spelled.
    for (final other in [
      Uri.parse(webKit).resolve('notes.html'),
      Uri.parse(webKit).resolve('über.html'),
      Uri.parse('file:///proj/cafe%CC%81/r%C3%A9sum%C3%A9.html/x'),
      Uri.parse('file:///other/cafe%CC%81/r%C3%A9sum%C3%A9.html'),
    ]) {
      expect(
        navigation('$other', page, mainFrame: true),
        PageNavigation.drop,
        reason: '$other',
      );
    }
  });

  test('only web, file and mail addresses leave for another app', () async {
    final opened = <Uri>[];
    fakeWebViews().open = (url) async => opened.add(url);
    for (final a in [
      'https://example.com/',
      'http://localhost:3000/',
      'file:///tmp/page.html',
      'mailto:someone@example.com',
      'javascript:alert(1)',
      'ssh://example.com',
      'vscode://file/tmp/x',
      'data:text/html,hi',
    ]) {
      await openInBrowser(Uri.parse(a));
    }
    expect(opened.map((u) => '$u'), [
      'https://example.com/',
      'http://localhost:3000/',
      'file:///tmp/page.html',
      'mailto:someone@example.com',
    ]);
  });

  // Fix review 2026-11-04: the press was taken from a Flutter Listener
  // around the web view, which on the Mac never sees one (WebKit takes a
  // press inside a platform view), so every link click was dropped. It's
  // asked of the Swift side's event monitor now, and only for a page that
  // leaves.
  test("a link's press comes from the window's events", () async {
    const p = '/repo/out/page.html';
    final page = PageFile(p);
    const away = 'https://example.com/docs';
    final web = fakeWebViews();
    var asked = 0;
    Duration? ago;
    web.since = ({pointerOnly = false}) async {
      asked++;
      expect(pointerOnly, isFalse); // a key in a file's page counts
      return ago;
    };
    expect(
      await pageNavigation(away, page, mainFrame: true),
      PageNavigation.drop,
    );
    ago = const Duration(milliseconds: 100);
    expect(
      await pageNavigation(away, page, mainFrame: true),
      PageNavigation.open,
    );
    ago = const Duration(seconds: 3);
    expect(
      await pageNavigation(away, page, mainFrame: true),
      PageNavigation.drop,
    );
    expect(asked, 3);
    expect(
      await pageNavigation('file://$p#top', page, mainFrame: true),
      PageNavigation.stay,
    );
    expect(asked, 3); // not asked for one that stays
    web.since = ({pointerOnly = false}) =>
        Future.error(StateError('no window'));
    expect(
      await pageNavigation(away, page, mainFrame: true),
      PageNavigation.drop,
    );
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

  // Deep review 2026-11-10, 19: a preview closed while its cookies were
  // being turned off still loaded its page in a web view nobody showed.
  test('a preview closed before its cookies are off loads nothing', () async {
    final was = blockCookies;
    addTearDown(() => blockCookies = was);
    final off = Completer<void>();
    blockCookies = (id) => off.future;
    final loads = CookielessLoads(Future.value(), () => 7);
    var loaded = 0;
    final waiting = loads.load(() async => loaded++);
    await pumpEventQueue();
    loads.stop();
    off.complete();
    await waiting;
    await loads.load(() async => loaded++);
    expect(loaded, 0);
  });

  // Deep review 2026-11-13, 11: a Mermaid preview's own filter refused the
  // about:blank its close loads, so the diagram ran on unseen.
  test('a diagram’s view loads its page once while open, and only '
      'about:blank once closed', () {
    const html = '/Applications/Nushi.app/mermaid/mermaid.html';
    final blank = Uri.parse('about:blank');
    final file = Uri.file(html);
    NavigationDecision open(Uri url, {bool loaded = false}) =>
        diagramNavigation(
          url,
          PageFile()..loading(html),
          loaded: loaded,
          gone: false,
        );
    NavigationDecision closed(Uri url) => diagramNavigation(
      url,
      PageFile()..loading(html),
      loaded: false,
      gone: true,
    );
    expect(open(file), NavigationDecision.navigate);
    expect(open(file, loaded: true), NavigationDecision.prevent);
    expect(open(blank), NavigationDecision.prevent);
    expect(open(Uri.parse('https://example.com/')), NavigationDecision.prevent);
    expect(closed(blank), NavigationDecision.navigate);
    expect(closed(file), NavigationDecision.prevent);
    expect(
      diagramNavigation(null, PageFile(), loaded: false, gone: true),
      NavigationDecision.prevent,
    );
  });

  // Browser tabs load any site now (ADR 0094) and share WebKit's store
  // with file previews: a site a tab signed in to must never load as a
  // preview's main frame, a press or not (docs/security.md).
  test('a file’s preview loads no site in its view, what a browser tab '
      'would', () {
    const p = '/repo/out/page.html';
    final page = PageFile(p);
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
        navigation(url, page, mainFrame: true),
        PageNavigation.drop,
        reason: url,
      );
      // A click on a link sends it to the default browser, not the view.
      expect(
        navigation(url, page, mainFrame: true, pressed: press),
        PageNavigation.open,
        reason: url,
      );
    }
  });
}
