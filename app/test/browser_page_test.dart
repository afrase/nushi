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

    test('web pages anywhere, and a blank one, stay in the tab', () {
      for (final url in [
        'http://localhost:3000/',
        'http://LOCALHOST:5173/app?x=1#top',
        'https://127.0.0.1:8443/',
        'http://127.4.5.6/',
        'http://[::1]:4000/',
        'https://example.com/',
        'http://example.com/login',
        'http://192.168.7.5:3000/',
        'http://localhost.example.com/',
        'http://localhost@example.com/', // the host is example.com
        'http://0.0.0.0:3000/',
        'about:blank',
      ]) {
        expect(main(url), PageNavigation.stay, reason: url);
      }
    });

    test('mail goes to its app only on a press', () {
      const mail = 'mailto:me@example.com';
      expect(main(mail), PageNavigation.drop);
      expect(main(mail, old()), PageNavigation.drop);
      expect(main(mail, press()), PageNavigation.open);
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
        'zoommtg://zoom.us/join',
        'http:///no-host',
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
    test('the press is asked only for mail, and only a pointer’s', () async {
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
      expect(await go('https://example.com/'), PageNavigation.stay);
      expect(await go('file:///etc/passwd'), PageNavigation.drop);
      expect(await go('data:text/html,x'), PageNavigation.drop);
      expect(asked, 0);
      expect(await go('mailto:me@example.com'), PageNavigation.open);
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
    String? to(String text) => addressOf(text)?.toString();
    // This Mac, as before: http.
    expect(to('localhost:3000'), 'http://localhost:3000');
    expect(to('localhost'), 'http://localhost');
    expect(to('3000'), 'http://localhost:3000');
    expect(to(':5173'), 'http://localhost:5173');
    expect(to('1'), 'http://localhost:1');
    expect(to('65535'), 'http://localhost:65535');
    expect(to(' 127.0.0.1:8080/app '), 'http://127.0.0.1:8080/app');
    expect(to('[::1]:3000'), 'http://[::1]:3000');
    expect(to('localhost:3000/app'), 'http://localhost:3000/app');
    // The user's own network: http.
    expect(to('192.168.7.5:3000'), 'http://192.168.7.5:3000');
    expect(to('10.0.0.2'), 'http://10.0.0.2');
    expect(to('printer.local'), 'http://printer.local');
    expect(to('app.localhost:5173'), 'http://app.localhost:5173');
    expect(to('devbox:8080'), 'http://devbox:8080');
    // Any other name: https.
    expect(to('example.com'), 'https://example.com');
    expect(to('Example.COM/docs?q=1#top'), 'https://example.com/docs?q=1#top');
    expect(to('example.com:8443/app'), 'https://example.com:8443/app');
    expect(to('sub.example.co.uk'), 'https://sub.example.co.uk');
    // A scheme typed is kept.
    expect(to('http://example.com/'), 'http://example.com/');
    expect(to('https://localhost:8443/'), 'https://localhost:8443/');
    expect(to('HTTPS://example.com'), 'https://example.com');
    expect(to('about:blank'), 'about:blank');
    for (final no in [
      '',
      '   ',
      // Not an address: no search engine, the field says so.
      'tea',
      'how to brew tea',
      'example .com',
      'me@example.com',
      // Not for the tab.
      'file:///etc/passwd',
      'javascript:alert(1)',
      'javascript://%0aalert(1)',
      'data:text/html,x',
      'ftp://localhost/',
      'mailto:me@example.com',
      'about:srcdoc',
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
