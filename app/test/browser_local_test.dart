import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_local.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/web_page.dart' show PageNavigation;

import 'browser_fixture.dart';
import 'harness.dart';

// A browser tab's block on this Mac and the local network (ADR 0094): which
// hosts are local, the content rules WebKit gets, and where a page's own
// navigation may go.
void main() {
  test('local hosts: loopback, the private ranges, link-local, .local', () {
    for (final h in [
      'localhost',
      'LOCALHOST',
      'localhost.',
      'app.localhost',
      'printer.local',
      'Printer.Local.',
      '127.0.0.1',
      '127.9.8.7',
      '0.0.0.0',
      '10.0.0.1',
      '10.255.255.255',
      '172.16.0.1',
      '172.31.255.1',
      '192.168.7.5',
      '169.254.169.254', // a cloud's metadata server
      '::1',
      '[::1]',
      '::',
      '::ffff:127.0.0.1',
      '::ffff:7f00:1',
      'fc00::1',
      'fd12:3456::1',
      'fe80::1',
      'febf::1',
    ]) {
      expect(isLocalNetwork(h), isTrue, reason: h);
    }
    for (final h in [
      '',
      'example.com',
      'localhost.example.com',
      'local',
      'notlocal',
      'example.local.com',
      '8.8.8.8',
      '172.15.0.1',
      '172.32.0.1',
      '192.169.0.1',
      '169.255.0.1',
      '11.0.0.1',
      '127.0.0', // not an address
      '2001:db8::1',
      'fec0::1',
      'fc::1', // its first group is 00fc
      '::2',
    ]) {
      expect(isLocalNetwork(h), isFalse, reason: h);
    }
  });

  /// What WebKit does with [localNetworkRules]' list for a load of [url] on
  /// a page at [top]: whether a rule blocks it. Its patterns are a subset
  /// of Dart's, matched without case.
  bool blocked(String rules, String url, String top) {
    for (final rule in jsonDecode(rules) as List<Object?>) {
      final trigger = (rule! as Map<String, Object?>)['trigger']! as Map;
      RegExp re(Object? p) => RegExp(p! as String, caseSensitive: false);
      if (!re(trigger['url-filter']).hasMatch(url)) continue;
      final unless = trigger['unless-top-url']! as List;
      if (unless.any((p) => re(p).hasMatch(top))) continue;
      return true;
    }
    return false;
  }

  test('the rules block a site’s page from loading anything local', () {
    final rules = localNetworkRules(const []);
    for (final url in [
      'http://localhost:5173/',
      'http://localhost./',
      'https://app.localhost/api',
      'ws://localhost:5173/hmr',
      'wss://127.0.0.1:8443/',
      'http://user@127.0.0.1:3000/',
      'http://0.0.0.0:3000/',
      'http://10.1.2.3/',
      'http://172.20.0.5:8080/',
      'http://192.168.1.1/admin',
      'http://169.254.169.254/latest/meta-data/',
      'http://printer.local/',
      'http://[::1]:4000/',
      'http://[::]/',
      'http://[::ffff:7f00:1]/',
      'http://[fd12:3456::1]/',
      'http://[fe80::1]/',
    ]) {
      expect(blocked(rules, url, 'https://evil.example/'), isTrue, reason: url);
      // A page at a local address keeps the whole network.
      for (final top in [
        'http://localhost:3000/',
        'http://192.168.7.5/',
        'http://[::1]:4000/',
        'http://devbox.local:8080/',
      ]) {
        expect(blocked(rules, url, top), isFalse, reason: '$url on $top');
      }
    }
    for (final url in [
      'https://example.com/',
      'https://localhost.example.com/',
      'https://cdn.example/127.0.0.1/x.js',
      'https://example.com/?next=http://localhost/',
      'http://172.32.0.1/',
      'http://[2001:db8::1]/',
    ]) {
      expect(
        blocked(rules, url, 'https://evil.example/'),
        isFalse,
        reason: url,
      );
    }
    // A top address that only names a local one somewhere isn't local.
    for (final top in [
      'https://evil.example/localhost/',
      'https://localhost.evil.example/',
      'https://evil.example/?u=http://127.0.0.1/',
    ]) {
      expect(
        blocked(rules, 'http://localhost:5173/', top),
        isTrue,
        reason: top,
      );
    }
  });

  test('a site let through is an exception, by its host alone', () {
    final rules = localNetworkRules(['tools.example', 'Bad host', 'a.b/c']);
    const dev = 'http://localhost:5173/';
    expect(blocked(rules, dev, 'https://tools.example/app'), isFalse);
    expect(blocked(rules, dev, 'https://tools.example:8443/'), isFalse);
    expect(blocked(rules, dev, 'https://sub.tools.example/'), isTrue);
    expect(blocked(rules, dev, 'https://tools.example.evil.example/'), isTrue);
    expect(blocked(rules, dev, 'https://toolsXexample/'), isTrue);
    // One rule a local pattern, each with every exception; the junk left out.
    final list = jsonDecode(rules) as List<Object?>;
    expect(list, hasLength(localNetworkPatterns.length));
    final first = (list.first! as Map)['trigger'] as Map;
    expect(first['unless-top-url'], hasLength(localNetworkPatterns.length + 1));
    expect((first['unless-top-url'] as List).last, contains(r'tools\.example'));
    expect(rules, isNot(contains('Bad host')));
    expect(rules, isNot(contains('a.b/c')));
    expect((list.first! as Map)['action'], {'type': 'block'});
    // The same list for the same sites, however given.
    expect(
      localNetworkRules(['b.example', 'a.example']),
      localNetworkRules(['a.example', 'b.example', 'a.example']),
    );
  });

  test('where a page’s own navigation may go', () {
    PageNavigation go(
      String url,
      String from, {
      bool asked = false,
      Set<String> allowed = const {},
    }) => browserNavigation(
      url,
      mainFrame: true,
      from: from,
      asked: asked,
      allowed: allowed,
    );
    const dev = 'http://localhost:5173/';
    for (final (url, from, asked, allowed, to) in [
      // A site's page can't send the tab to this Mac or the network.
      (dev, 'https://evil.example/', false, <String>{}, PageNavigation.drop),
      (
        'http://192.168.1.1/',
        'https://evil.example/',
        false,
        <String>{},
        PageNavigation.drop,
      ),
      // Nor a new tab's blank page (its first load is the user's).
      (dev, 'about:blank', false, <String>{}, PageNavigation.drop),
      (dev, '', false, <String>{}, PageNavigation.drop),
      // The user typed it, or went Back, Forward or Reload.
      (dev, 'https://evil.example/', true, <String>{}, PageNavigation.stay),
      (dev, '', true, <String>{}, PageNavigation.stay),
      // A local page goes where it likes.
      (dev, 'http://localhost:3000/', false, <String>{}, PageNavigation.stay),
      (
        'http://192.168.1.1/',
        'http://printer.local/',
        false,
        <String>{},
        PageNavigation.stay,
      ),
      (
        'https://example.com/',
        'http://localhost:3000/',
        false,
        <String>{},
        PageNavigation.stay,
      ),
      // A site let through.
      (
        dev,
        'https://tools.example/',
        false,
        {'tools.example'},
        PageNavigation.stay,
      ),
      // A site's page to another site, as before.
      (
        'https://example.org/',
        'https://example.com/',
        false,
        <String>{},
        PageNavigation.stay,
      ),
    ]) {
      expect(
        go(url, from, asked: asked, allowed: allowed),
        to,
        reason: '$url from $from, asked $asked',
      );
    }
    // A frame is the content rules' to stop.
    expect(
      browserNavigation(dev, mainFrame: false, from: 'https://evil.example/'),
      PageNavigation.stay,
    );
  });

  group('who sent the main frame', () {
    const evil = 'https://evil.example/';
    const dev = 'http://localhost:5173/';
    const router = 'http://192.168.1.1/cgi-bin/reboot';
    const typed = (type: NavigationSource.typed, redirect: false);
    const step = (type: NavigationSource.step, redirect: false);
    const redirect = (type: NavigationSource.typed, redirect: true);

    /// What a main frame's navigation to [url], told [nav], does in a tab
    /// whose [source] says who sent it; one let go is told it went.
    PageNavigation decide(
      NavigationSource source,
      String url,
      MainNavigation? nav, {
      Set<String> allowed = const {},
    }) {
      final (:asked, :from) = source.take(url, nav, allowed: allowed);
      final to = browserNavigation(
        url,
        mainFrame: true,
        from: from,
        asked: asked,
        allowed: allowed,
      );
      if (to == PageNavigation.stay) source.flight = url;
      return to;
    }

    test('a typed load is the user’s; a script’s meanwhile isn’t', () {
      // The site's page on screen, the user's local load still to commit
      // (the bar shows it already): the page's own `location` to the
      // router comes first and goes nowhere, and takes nothing.
      final s = NavigationSource()
        ..committed(evil)
        ..asked(NavigationSource.typed, 'http://localhost:5173');
      expect(decide(s, router, typed), PageNavigation.drop);
      expect(decide(s, dev, typed), PageNavigation.stay);
      // Once: the same load again is the page's.
      expect(decide(s, dev, typed), PageNavigation.drop);
      // Its own redirect comes from it, so stays local.
      s.asked(NavigationSource.typed, dev);
      expect(decide(s, dev, typed), PageNavigation.stay);
      expect(decide(s, '${dev}login', redirect), PageNavigation.stay);
    });

    test('Back is the user’s only for the item it goes to', () {
      // Back to the dev server: the page's script, sending the tab to the
      // router as the user presses it, gets no ask, of either kind.
      final s = NavigationSource()
        ..committed(evil)
        ..asked(NavigationSource.step, dev);
      expect(decide(s, router, typed), PageNavigation.drop);
      expect(decide(s, router, step), PageNavigation.drop);
      expect(decide(s, dev, step), PageNavigation.stay);
      // Back with no item to go to asks nothing, and takes back the ask
      // before it.
      s
        ..asked(NavigationSource.step, dev)
        ..asked(NavigationSource.step, null);
      expect(decide(s, dev, step), PageNavigation.drop);
      // A reload of the page on screen; a form sent again counts.
      s.asked(NavigationSource.reload, dev);
      expect(
        decide(s, dev, (type: NavigationSource.resent, redirect: false)),
        PageNavigation.stay,
      );
      // An ask goes stale.
      s.asked(NavigationSource.typed, dev);
      clock = () => fixtureNow.add(const Duration(seconds: 2));
      expect(decide(s, dev, typed), PageNavigation.drop);
    });

    test('a redirect comes from the address that redirected', () {
      // The dev server on screen; its link (or Forward) to a site that
      // redirects to the router: dropped, as the site sent it.
      final s = NavigationSource()..committed(dev);
      expect(decide(s, 'https://evil.example/r', typed), PageNavigation.stay);
      expect(decide(s, router, redirect), PageNavigation.drop);
      // A site's page's redirect to another site goes.
      expect(decide(s, 'https://evil.example/r', typed), PageNavigation.stay);
      expect(decide(s, 'https://b.example/', redirect), PageNavigation.stay);
      // Committed, the site is the page on screen.
      s.committed('https://b.example/');
      expect(decide(s, dev, typed), PageNavigation.drop);
      // The dev server's own redirect goes where it likes.
      s.committed(dev);
      expect(decide(s, '${dev}a', typed), PageNavigation.stay);
      expect(
        decide(s, 'http://localhost:3000/', redirect),
        PageNavigation.stay,
      );
      // A failed load has no redirect to follow: one judged as from the
      // page on screen.
      s
        ..committed(evil)
        ..flight = dev
        ..flight = '';
      expect(decide(s, router, redirect), PageNavigation.drop);
    });

    test('without WebKit’s word, the page on screen sent it', () {
      final s = NavigationSource()
        ..committed(evil)
        ..asked(NavigationSource.typed, dev);
      expect(decide(s, dev, null), PageNavigation.drop);
      // A blank page keeps the page that opened it.
      final t = NavigationSource()
        ..committed(dev)
        ..committed('about:blank');
      expect(decide(t, router, typed), PageNavigation.stay);
    });

    // Security review 2026-11-06: without WebKit's private redirect flag,
    // a site's redirect to the router was judged by the dev server on
    // screen, and went.
    test('with no word of a redirect, the stricter of the page and the load '
        'let go sent it', () {
      const unknown = (type: NavigationSource.typed, redirect: null);
      // The dev server on screen, a link to a site let go: what follows may
      // be the site's redirect.
      final s = NavigationSource()..committed(dev);
      expect(decide(s, 'https://evil.example/r', unknown), PageNavigation.stay);
      expect(decide(s, router, unknown), PageNavigation.drop);
      // WebKit told nothing at all: the same.
      expect(decide(s, 'https://evil.example/r', unknown), PageNavigation.stay);
      expect(decide(s, router, null), PageNavigation.drop);
      // A site on screen and a local load let go: the site's.
      final t = NavigationSource()
        ..committed(evil)
        ..flight = dev;
      expect(decide(t, router, unknown), PageNavigation.drop);
      // Both local, or the site let through: it goes.
      final u = NavigationSource()
        ..committed(dev)
        ..flight = 'http://localhost:3000/';
      expect(decide(u, router, unknown), PageNavigation.stay);
      s.flight = 'https://evil.example/r';
      expect(
        decide(s, router, unknown, allowed: {'evil.example'}),
        PageNavigation.stay,
      );
    });

    test('an address as WebKit writes it', () {
      for (final (a, b, same) in [
        ('http://localhost:5173', 'http://localhost:5173/', true),
        ('http://LocalHost:80/a', 'http://localhost/a', true),
        ('http://localhost/a#f', 'http://localhost/a#f', true),
        ('http://localhost/a', 'http://localhost/b', false),
        ('http://localhost:1/', 'http://localhost:2/', false),
      ]) {
        expect(sameAddress(a, b), same, reason: '$a $b');
      }
    });
  });

  test('a site is let through, and taken off, by its host', () {
    expect(localNetworkSites.value, isEmpty);
    expect(allowLocalNetwork('Tools.Example'), isTrue);
    expect(allowLocalNetwork('evil.example/.*'), isFalse);
    expect(allowLocalNetwork('[::1]'), isFalse);
    expect(localNetworkSites.value, {'tools.example'});
    disallowLocalNetwork('TOOLS.example');
    expect(localNetworkSites.value, isEmpty);
    for (final h in ['example.com', 'a-b.example', '192.168.7.5']) {
      expect(allowableHost(h), isTrue, reason: h);
    }
    for (final h in ['', 'Example.com', 'a..b', '.a', 'a b', r'a\.b', 'a*']) {
      expect(allowableHost(h), isFalse, reason: h);
    }
  });

  testWidgets('the pane says when the page went for a local address', (
    tester,
  ) async {
    final fakes = browserFakes();
    final d = await browserApp(tester);
    d.chats['c']!.openBrowserTab('https://evil.example/');
    await tester.pumpAndSettle();
    fakes.hosts.single.blocked.value = Uri.parse('http://localhost:5173/admin');
    await tester.pump();
    expect(
      find.text(
        'This site can’t open localhost:5173: it’s on your Mac or local '
        'network. Type the address to open it.',
      ),
      findsOneWidget,
    );
    await closeView(tester, d);
  }, variant: macOnly);
}
