import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/allowed_sites.dart';
import 'package:nushi/browser_menu.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart' show loadFonts;
import 'fake_web_views.dart';
import 'harness.dart';

// A browser tab's ⋯ menu, as Claude desktop's (ADR 0094): each row, in its
// order, against the fake host and the fakes of the Mac's side.

/// A browser pane on its own, [size], its chat's preview's browser tab.
Future<ChatState> _pane(
  WidgetTester tester, {
  Size size = const Size(560, 380),
  Tokens tokens = Tokens.dark,
}) async {
  viewport(tester, size);
  final c = ChatState('c', '/Users/me/nushi');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: c.preview,
          builder: (context, tab, _) => tab is BrowserTab
              ? BrowserPane(
                  key: ObjectKey(tab),
                  chat: c,
                  tab: tab,
                  onClose: () {},
                  onExpand: () {},
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  return c;
}

Future<void> _open(WidgetTester tester, ChatState c, String address) async {
  c.openBrowserTab(address);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
}

/// The menu's row that says [label].
Finder _row(String label) => find.ancestor(
  of: find.text(label, findRichText: true),
  matching: find.byWidgetPredicate(
    (w) => w is MenuItemButton || w is SubmenuButton,
  ),
);

/// What the Local network access row says at its end.
Finder _access(String state) => find.descendant(
  of: _row('Local network access'),
  matching: find.text(state),
);

bool _enabled(WidgetTester tester, String label) =>
    switch (tester.widget(_row(label))) {
      MenuItemButton(:final onPressed) => onPressed != null,
      SubmenuButton(:final menuChildren) => menuChildren.isNotEmpty,
      _ => false,
    };

void main() {
  setUpAll(loadFonts);

  testWidgets('its rows in Claude’s order, Import cookies left out', (
    tester,
  ) async {
    browserFakes();
    final c = await _pane(tester);
    await _open(tester, c, 'https://example.com');
    final rows = [
      'Save screenshot',
      'Open links in built-in browser',
      'Manage allowed sites…',
      'Local network access',
      'Cookies',
      'Clear browsing data',
    ];
    final tops = [
      for (final r in rows)
        tester.getTopLeft(find.text(r, findRichText: true)).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(find.text('Import cookies…'), findsNothing);
    expect(find.byType(Divider), findsNWidgets(2));
  }, variant: macOnly);

  testWidgets('Save screenshot saves the page in sight as a PNG', (
    tester,
  ) async {
    final fakes = browserFakes();
    final dir = Directory.systemTemp.createTempSync('nushi-test-shot');
    addTearDown(() => dir.deleteSync(recursive: true));
    final was = screenshotPath;
    addTearDown(() => screenshotPath = was);
    String? asked;
    screenshotPath = (name) async {
      asked = name;
      return '${dir.path}/$name';
    };
    final c = await _pane(tester);
    await _open(tester, c, 'https://example.com');
    await tester.tap(find.text('Save screenshot'));
    await tester.pumpAndSettle();
    final file = File('${dir.path}/Screenshot 2026-10-29 at 12.00.00.png');
    await untilReal(
      tester,
      () => file.existsSync() && file.lengthSync() == fakePng.length,
    );
    expect(asked, startsWith('Screenshot '));
    expect(fakes.hosts.single.snapshots, 1);
    expect(file.readAsBytesSync(), fakePng);
  }, variant: macOnly);

  testWidgets('a save that fails says so and writes nothing', (tester) async {
    browserFakes();
    final dir = Directory.systemTemp.createTempSync('nushi-test-shot');
    addTearDown(() => dir.deleteSync(recursive: true));
    final was = screenshotPath;
    addTearDown(() => screenshotPath = was);
    // A folder that isn't there: the write fails.
    screenshotPath = (name) async => '${dir.path}/gone/$name';
    final c = await _pane(tester);
    await _open(tester, c, 'https://example.com');
    await tester.tap(find.text('Save screenshot'));
    await tester.pumpAndSettle();
    await untilReal(tester, () => find.byType(SnackBar).evaluate().isNotEmpty);
    expect(find.textContaining('Couldn’t save the screenshot'), findsOneWidget);
    expect(dir.listSync(recursive: true), isEmpty);
  }, variant: macOnly);

  testWidgets('a cancelled save writes nothing; a new tab has none', (
    tester,
  ) async {
    final fakes = browserFakes();
    final was = screenshotPath;
    addTearDown(() => screenshotPath = was);
    var asked = 0;
    screenshotPath = (_) async {
      asked++;
      return null;
    };
    final c = await _pane(tester);
    await _open(tester, c, 'https://example.com');
    await tester.tap(find.text('Save screenshot'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.byType(SnackBar), findsNothing);
    // A new tab has no page to take.
    c.openBrowserTab();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'Save screenshot'), isFalse);
    expect(fakes.hosts.single.snapshots, 1);
  }, variant: macOnly);

  testWidgets('Open links in built-in browser shows the setting and turns it '
      'off and on', (tester) async {
    browserFakes();
    final c = await _pane(tester);
    await _open(tester, c, 'https://example.com');
    Finder check() => find.descendant(
      of: _row('Open links in built-in browser'),
      matching: find.byIcon(Icons.check),
    );
    expect(check(), findsOneWidget);
    await tester.tap(find.text('Open links in built-in browser'));
    await tester.pumpAndSettle();
    expect(linksInBrowserTab.value, isFalse);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(check(), findsNothing);
    await tester.tap(find.text('Open links in built-in browser'));
    await tester.pumpAndSettle();
    expect(linksInBrowserTab.value, isTrue);
  }, variant: macOnly);

  group('Local network access', () {
    testWidgets('a site’s page: Blocked, and allowed for it from its '
        'submenu', (tester) async {
      browserFakes();
      final c = await _pane(tester);
      await _open(tester, c, 'https://Router.example/admin');
      expect(_access('Blocked'), findsOneWidget);
      expect(_enabled(tester, 'Local network access'), isTrue);
      await tester.tap(find.text('Local network access'));
      await tester.pumpAndSettle();
      // It names the site it's for (the bar's host is the other).
      expect(find.text('router.example'), findsNWidgets(2));
      await tester.tap(find.text('Allowed for this site'));
      await tester.pumpAndSettle();
      expect(localNetworkSites.value, {'router.example'});
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(_access('Allowed'), findsOneWidget);
      await tester.tap(find.text('Local network access'));
      await tester.pumpAndSettle();
      // The one in force is checked.
      expect(
        find.descendant(
          of: _row('Allowed for this site'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Blocked'));
      await tester.pumpAndSettle();
      expect(localNetworkSites.value, isEmpty);
    }, variant: macOnly);

    testWidgets('a local page: Allowed, and it can’t be changed', (
      tester,
    ) async {
      browserFakes();
      final c = await _pane(tester);
      await _open(tester, c, 'http://localhost:3000');
      expect(_access('Allowed'), findsOneWidget);
      expect(_enabled(tester, 'Local network access'), isFalse);
    }, variant: macOnly);

    testWidgets('a new tab has none', (tester) async {
      browserFakes();
      final c = await _pane(tester);
      await _open(tester, c, '');
      expect(find.text('Save screenshot'), findsOneWidget);
      expect(
        find.textContaining('Local network access', findRichText: true),
        findsNothing,
      );
    }, variant: macOnly);
  });

  testWidgets('Manage allowed sites… opens Allowed sites over the sites let '
      'through', (tester) async {
    browserFakes();
    localNetworkSites.value = {'router.example', 'nas.example'};
    final c = await _pane(tester);
    await _open(tester, c, 'https://example.com');
    await tester.tap(find.text('Manage allowed sites…'));
    await tester.pumpAndSettle();
    // Its own tests: allowed_sites_test.dart.
    expect(find.byType(AllowedSites), findsOneWidget);
    expect(find.text('nas.example'), findsOneWidget);
    expect(find.text('router.example'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AllowedSites), findsNothing);
  }, variant: macOnly);

  testWidgets('Clear browsing data asks first, then clears WebKit’s store '
      'and reloads the page', (tester) async {
    final fakes = browserFakes();
    var cleared = 0;
    fakeWebViews().clear = () async => cleared++;
    final c = await _pane(tester);
    await _open(tester, c, 'https://example.com');
    await tester.tap(find.text('Clear browsing data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('signs you out'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cleared, 0);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear browsing data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(fakes.hosts.single.reloads, 1);
    expect(find.text('Browsing data cleared'), findsOneWidget);
  }, variant: macOnly);

  testWidgets('the keyboard reaches it: Tab to ⋯, Space, the arrows', (
    tester,
  ) async {
    browserFakes();
    final c = await _pane(tester);
    c.openBrowserTab('https://example.com');
    await tester.pumpAndSettle();
    final more = find.byTooltip('More');
    // The button's own focus: the nearest above its icon.
    final icon = find.descendant(of: more, matching: find.byType(CustomPaint));
    final button = Focus.of(tester.element(icon.first));
    // Tab from the address field, round past the page, to the ⋯.
    await tester.tap(addressBox);
    await tester.pump();
    for (var i = 0; i < 12 && !button.hasPrimaryFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(button.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Save screenshot'), findsOneWidget);
    // Down to Open links in built-in browser, past the divider.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(linksInBrowserTab.value, isFalse);
    expect(find.text('Save screenshot'), findsNothing);
  }, variant: macOnly);

  for (final (name, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    testWidgets('looks, $name: the menu open over a site’s page', (
      tester,
    ) async {
      browserFakes();
      viewport(tester, const Size(560, 380), brightness: brightness);
      final c = await _pane(tester, tokens: tokens);
      await _open(tester, c, 'https://example.com');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/browser_menu_$name.png'),
      );
    }, variant: macOnly);
  }
}
