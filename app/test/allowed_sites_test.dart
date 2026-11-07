import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/allowed_sites.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'browser_fixture.dart' show macOnly;
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

// The browser ⋯ menu's Allowed sites dialog, as Claude desktop's (ADR
// 0094): Add URL, the sites' rows, Clear all, Done and ×.

/// The dialog open over a plain window of [size].
Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(720, 520),
  Tokens tokens = Tokens.dark,
  double ratio = 1,
}) async {
  viewport(
    tester,
    size,
    ratio: ratio,
    brightness: tokens == Tokens.light ? Brightness.light : Brightness.dark,
  );
  await tester.pumpWidget(
    themed(
      Builder(
        builder: (context) => Center(
          child: Button(
            label: 'Open',
            onPressed: () => showAllowedSites(context),
          ),
        ),
      ),
      tokens: tokens,
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _add(
  WidgetTester tester,
  String text, {
  bool enter = false,
}) async {
  await tester.enterText(find.byType(TextField), text);
  if (enter) {
    await tester.testTextInput.receiveAction(TextInputAction.done);
  } else {
    await tester.tap(find.byTooltip('Add'));
  }
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<Button>(find.widgetWithText(Button, label)).onPressed != null;

void main() {
  setUpAll(loadFonts);

  test('Add URL takes a host or a URL as the address field does', () {
    for (final (text, host) in [
      ('example.com', 'example.com'),
      ('  Example.COM  ', 'example.com'),
      ('https://tools.example/a/b?c#d', 'tools.example'),
      ('http://Router.example:8080/admin', 'router.example'),
      ('8.8.8.8', '8.8.8.8'),
      ('nas.example', 'nas.example'), // already there: the same host
    ]) {
      expect(siteToAllow(text, {'nas.example'}), (
        host: host,
        error: null,
      ), reason: text);
    }
    for (final (text, error) in [
      ('localhost:3000', 'always reaches it'),
      ('192.168.7.5', 'always reaches it'),
      ('printer.local', 'always reaches it'),
      ('http://[::1]:4000', 'always reaches it'),
      ('https://[2001:db8::1]/', 'can’t be allowed'),
      ('word', 'isn’t a site’s address'),
      ('a b.example', 'isn’t a site’s address'),
      ('file:///etc/hosts', 'isn’t a site’s address'),
      ('about:blank', 'isn’t a site’s address'),
      ('https://me@bank.example', 'isn’t a site’s address'),
    ]) {
      final r = siteToAllow(text, const {});
      expect(r.host, isNull, reason: text);
      expect(r.error, contains(error), reason: text);
    }
  });

  testWidgets('adds a host and a URL, by + and by Return, and refuses what '
      'it can’t hold', (tester) async {
    await _open(tester);
    expect(find.text('No sites allowed'), findsOneWidget);
    await _add(tester, 'tools.example');
    expect(localNetworkSites.value, {'tools.example'});
    expect(find.text('tools.example'), findsOneWidget);
    // Return adds too, and the field is ready for the next.
    await _add(tester, 'https://Router.example/admin', enter: true);
    expect(localNetworkSites.value, {'tools.example', 'router.example'});
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
    // In order.
    expect(
      tester.getTopLeft(find.text('router.example')).dy,
      lessThan(tester.getTopLeft(find.text('tools.example')).dy),
    );
    // A local address needs nothing; a word isn't a site. The text stays
    // to fix, and the error goes as it's changed.
    await _add(tester, 'localhost:3000');
    expect(find.textContaining('always reaches it'), findsOneWidget);
    expect(find.text('localhost:3000'), findsOneWidget);
    await _add(tester, 'word');
    expect(find.text('That isn’t a site’s address.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'wor');
    await tester.pump();
    expect(find.text('That isn’t a site’s address.'), findsNothing);
    expect(localNetworkSites.value, hasLength(2));
    // One already there changes nothing.
    var changes = 0;
    void count() => changes++;
    localNetworkSites.addListener(count);
    addTearDown(() => localNetworkSites.removeListener(count));
    await _add(tester, 'TOOLS.example');
    expect(changes, 0);
    expect(find.text('tools.example'), findsOneWidget);
    expect(find.textContaining('address'), findsNothing);
    expect(find.textContaining('reaches it'), findsNothing);
  }, variant: macOnly);

  testWidgets('a row’s bin takes its site off', (tester) async {
    localNetworkSites.value = {'router.example', 'nas.example'};
    await _open(tester);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('nas.example'),
          matching: find.byType(Row),
        ),
        matching: find.byTooltip('Remove'),
      ),
    );
    await tester.pumpAndSettle();
    expect(localNetworkSites.value, {'router.example'});
    expect(find.text('nas.example'), findsNothing);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('No sites allowed'), findsOneWidget);
  }, variant: macOnly);

  testWidgets('Clear all asks first, and is off with nothing to clear', (
    tester,
  ) async {
    localNetworkSites.value = {'router.example', 'nas.example'};
    await _open(tester);
    expect(_enabled(tester, 'Clear all'), isTrue);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all allowed sites?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(localNetworkSites.value, hasLength(2));
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    // The confirmation's own button.
    await tester.tap(find.text('Clear all').last);
    await tester.pumpAndSettle();
    expect(localNetworkSites.value, isEmpty);
    expect(find.text('Allowed sites'), findsOneWidget);
    expect(find.text('No sites allowed'), findsOneWidget);
    expect(_enabled(tester, 'Clear all'), isFalse);
  }, variant: macOnly);

  testWidgets('Done and × close it', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Allowed sites'), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Allowed sites'), findsNothing);
  }, variant: macOnly);

  for (final (name, tokens) in [
    ('light', Tokens.light),
    ('dark', Tokens.dark),
  ]) {
    testWidgets('looks, $name: two sites and a refused one', (tester) async {
      localNetworkSites.value = {
        'keishicho-gto.metro.tokyo.lg.jp',
        'nas.example',
      };
      await _open(tester, tokens: tokens, ratio: 2);
      await _add(tester, 'localhost:3000');
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/allowed_sites_$name.png'),
      );
    }, variant: macOnly);
  }

  for (final width in [1700.0, 720.0]) {
    testWidgets('render at ${width.round()}', (tester) async {
      localNetworkSites.value = {'keishicho-gto.metro.tokyo.lg.jp'};
      await _open(tester, size: Size(width, 900));
      await render(
        tester,
        find.byType(MaterialApp),
        'allowed_sites_${width.round()}',
      );
      localNetworkSites.value = const {};
      await tester.pumpAndSettle();
      await render(
        tester,
        find.byType(MaterialApp),
        'allowed_sites_${width.round()}_empty',
      );
    }, variant: macOnly);
  }
}
