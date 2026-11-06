import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

// A chat's links open in a browser tab beside it, with Open links in
// built-in browser on (ADR 0094), else in the default browser.
void main() {
  setUpAll(loadFonts);

  test('where a link opens: the setting, the room, the address', () {
    final site = Uri.parse('https://example.com/docs');
    for (final (url, setting, fits, tab) in [
      (site, true, true, true),
      (Uri.parse('http://localhost:5173/'), true, true, true),
      (site, false, true, false), // the setting off
      (site, true, false, false), // no room for the pane
      (site, false, false, false),
      // A user name: the tab loads none, so the browser has it.
      (Uri.parse('https://a@example.com/'), true, true, false),
    ]) {
      expect(
        linkInTab(url, setting: setting, fits: fits),
        tab,
        reason: '$url $setting $fits',
      );
    }
  });

  /// Links opened in the default browser while the test runs.
  List<Uri> outside() {
    final opened = <Uri>[];
    final was = openWebOutside;
    openWebOutside = (url) async => opened.add(url);
    addTearDown(() => openWebOutside = was);
    return opened;
  }

  /// The app at [width] on a chat whose agent replied with a link, and
  /// ran a tool whose output has one.
  Future<Daemon> app(WidgetTester tester, {double width = 1700}) async {
    viewport(tester, Size(width, 900));
    showDetails.value = false;
    paneWidths.value = {};
    final c = chat('c', 'claude', 'Build the tea shop');
    final fake = FakeDaemon([c])
      ..answer = (input) => input is GetChatRequest
          ? GetChatResponse(
              chat: c,
              items: [
                Item(
                  id: 't',
                  kind: ItemKind.ITEM_KIND_TOOL_CALL,
                  title: 'Fetch the tea list',
                  status: 'completed',
                  text: 'Found [the list](https://tea.example/list).',
                ),
                Item(
                  id: 'm',
                  kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                  text: 'It runs at [the dev server](http://localhost:5173/).',
                ),
              ],
            )
          : null;
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    return d;
  }

  Future<void> tapLink(WidgetTester tester, String text) async {
    await tester.tap(find.textContaining(text, findRichText: true).last);
    await tester.pumpAndSettle();
  }

  testWidgets('a message’s link opens in a browser tab beside the chat', (
    tester,
  ) async {
    final fakes = browserFakes();
    final browser = outside();
    final d = await app(tester);
    await tapLink(tester, 'the dev server');
    final tab = d.chats['c']!.preview.value;
    expect(tab, isA<BrowserTab>());
    expect((tab! as BrowserTab).address.value, 'http://localhost:5173/');
    expect(find.byType(BrowserPane), findsOneWidget);
    expect(fakes.hosts.single.opened, [Uri.parse('http://localhost:5173/')]);
    expect(browser, isEmpty);
    expect(fakes.opened, isEmpty);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('a tool call’s output’s link too, each its own tab', (
    tester,
  ) async {
    browserFakes();
    final browser = outside();
    final d = await app(tester);
    await tapLink(tester, 'the dev server');
    await tester.tap(find.text('Fetch the tea list'));
    await tester.pumpAndSettle();
    await tapLink(tester, 'the list');
    final tabs = d.chats['c']!.previewTabs.value.cast<BrowserTab>();
    expect([for (final t in tabs) t.address.value], [
      'http://localhost:5173/',
      'https://tea.example/list',
    ]);
    expect(browser, isEmpty);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('with the setting off, the default browser', (tester) async {
    browserFakes();
    final browser = outside();
    linksInBrowserTab.value = false;
    final d = await app(tester);
    await tapLink(tester, 'the dev server');
    expect(browser, [Uri.parse('http://localhost:5173/')]);
    expect(d.chats['c']!.preview.value, isNull);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('in a window too narrow for the pane, the default browser', (
    tester,
  ) async {
    browserFakes();
    final browser = outside();
    final d = await app(tester, width: 720);
    expect(d.chats['c']!.previewFits, isFalse);
    await tapLink(tester, 'the dev server');
    expect(browser, [Uri.parse('http://localhost:5173/')]);
    expect(d.chats['c']!.preview.value, isNull);
    await closeView(tester, d);
  }, variant: macOnly);

  testWidgets('outside a chat (Jira, GitHub, the phone), the default browser', (
    tester,
  ) async {
    final browser = outside();
    await tester.pumpWidget(
      themed(const AgentMarkdown('See [the issue](https://jira.example/T-1).')),
    );
    await tapLink(tester, 'the issue');
    expect(browser, [Uri.parse('https://jira.example/T-1')]);
  });

  testWidgets('Settings › General has the switch, on at first', (
    tester,
  ) async {
    final fake = FakeDaemon([])..settings = Settings(sleepAfterMinutes: 30);
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.general);
    expect(find.text('Open links in built-in browser'), findsOneWidget);
    expect(linksInBrowserTab.value, isTrue);
    final row = find.ancestor(
      of: find.text('Open links in built-in browser'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: row.first, matching: find.byType(Switch)).first,
    );
    await tester.pumpAndSettle();
    expect(linksInBrowserTab.value, isFalse);
    expect(readSaved()['linksInBrowserTab'], isFalse);
    d.dispose();
  });
}
