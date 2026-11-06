import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/web_page.dart';

// What a browser tab loads and what its address field takes (ADR 0094).
void main() {
  group('what a browser tab loads', () {
    // The test's clock stands still once a test runs (fixtureNow).
    DateTime press() => clock().subtract(const Duration(milliseconds: 200));
    DateTime old() => clock().subtract(const Duration(seconds: 5));
    PageNavigation main(String url, [DateTime? pressed]) =>
        browserNavigation(url, mainFrame: true, pressed: pressed);

    test('this Mac’s pages and a blank one stay in the tab', () {
      for (final url in [
        'http://localhost:3000/',
        'http://LOCALHOST:5173/app?x=1#top',
        'https://127.0.0.1:8443/',
        'http://127.4.5.6/',
        'http://[::1]:4000/',
        'about:blank',
      ]) {
        expect(main(url), PageNavigation.stay, reason: url);
      }
    });

    test('another site, or mail, goes to the browser only on a press', () {
      for (final url in [
        'https://example.com/',
        'http://192.168.7.5:3000/',
        'http://localhost.example.com/',
        'http://localhost@example.com/', // the host is example.com
        'http://127.0.0.256/',
        'http://0.0.0.0:3000/',
        'mailto:me@example.com',
      ]) {
        expect(main(url), PageNavigation.drop, reason: url);
        expect(main(url, old()), PageNavigation.drop, reason: url);
        expect(main(url, press()), PageNavigation.open, reason: url);
      }
    });

    test('a file, and other schemes, go nowhere, a press or not', () {
      for (final url in [
        'file:///etc/passwd',
        'file:///Users/me/nushi/site/index.html',
        'data:text/html,<p>hi',
        'javascript:alert(1)',
        'blob:http://localhost:3000/1234',
        'about:srcdoc',
        'ftp://localhost/',
        'x-apple.systempreferences:',
      ]) {
        expect(main(url, press()), PageNavigation.drop, reason: url);
      }
    });

    test('a frame in the page loads anything but a file', () {
      PageNavigation frame(String url) =>
          browserNavigation(url, mainFrame: false);
      expect(frame('https://www.youtube.com/embed/x'), PageNavigation.stay);
      expect(frame('about:srcdoc'), PageNavigation.stay);
      expect(frame('file:///etc/passwd'), PageNavigation.drop);
    });

    // Fix review 2026-11-06: a Space or Return typed into a local page's
    // form let the page's script send the default browser anywhere; only
    // the pointer's press counts for a browser tab.
    test('the press is asked only for what the browser may take, and only '
        'a pointer’s', () async {
      final since = sincePressInPage;
      addTearDown(() => sincePressInPage = since);
      var asked = 0;
      sincePressInPage = ({pointerOnly = false}) async {
        asked++;
        expect(pointerOnly, isTrue);
        return const Duration(milliseconds: 100);
      };
      Future<PageNavigation> go(String url) =>
          browserPageNavigation(url, mainFrame: true);
      expect(await go('http://localhost:3000/'), PageNavigation.stay);
      expect(await go('file:///etc/passwd'), PageNavigation.drop);
      expect(await go('data:text/html,x'), PageNavigation.drop);
      expect(asked, 0);
      expect(await go('https://example.com/'), PageNavigation.open);
      expect(asked, 1);
    });

    test('loopback is localhost, 127.0.0.0/8 and ::1 only', () {
      for (final h in ['localhost', '127.0.0.1', '127.255.0.9', '::1']) {
        expect(isLoopback(h), isTrue, reason: h);
      }
      for (final h in ['', '127.0.0', '127.0.0.01', '128.0.0.1', '::2']) {
        expect(isLoopback(h), isFalse, reason: h);
      }
    });
  });

  test('what the address field takes', () {
    String? here(String text) => switch (addressOf(text)) {
      (:final url, here: true) => '$url',
      _ => null,
    };
    expect(here('localhost:3000'), 'http://localhost:3000');
    expect(here('3000'), 'http://localhost:3000');
    expect(here(':5173'), 'http://localhost:5173');
    expect(here('1'), 'http://localhost:1');
    expect(here('65535'), 'http://localhost:65535');
    expect(here(' 127.0.0.1:8080/app '), 'http://127.0.0.1:8080/app');
    expect(here('[::1]:3000'), 'http://[::1]:3000');
    expect(here('https://localhost:8443/'), 'https://localhost:8443/');
    expect(here('about:blank'), 'about:blank');
    expect(here('localhost:3000/app'), 'http://localhost:3000/app');
    expect(addressOf('example.com'), (
      url: Uri.parse('http://example.com'),
      here: false,
    ));
    for (final no in [
      '',
      'file:///etc/passwd',
      'javascript:alert(1)',
      'data:text/html,x',
      'ftp://localhost/',
      'mailto:me@example.com',
      'javascript://%0aalert(1)',
      // No such port: the field says why, not WebKit.
      '99999',
      '0',
      ':65536',
      'localhost:99999',
      'example.com:70000',
    ]) {
      expect(addressOf(no), isNull, reason: no);
    }
  });
}
