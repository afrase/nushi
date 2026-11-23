import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/web_find.dart';
import 'package:nushi/web_page.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart' show loadFonts;
import 'fake_page_finder.dart';
import 'fake_web_views.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'preview_find_fixture.dart';

// ⌘F in a web view (issue 63, ADR 0143): an HTML file's page and a browser
// tab find with the page's own text through their host's finder. While
// WebKit has the keys, ⌘F comes from the menu bar to the app's action,
// which asks each page shown whether its web view has them; a test plays
// that by pressing ⌘F with the prompt box focused and the fake's web view
// saying it has the keys.

const _page = 'Tea shop. Every teapot hand made; a TEAPOT a day; teapots.';

/// A page that draws a line of its text, as a web view would show it.
class _View extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFFFFFFF),
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          _page,
          style: TextStyle(fontSize: 15, color: Color(0xFF1B1B1F)),
        ),
      ),
    ),
  );
}

/// A file preview's host with [finder] (none: a platform without one).
class _Host implements PageHost {
  new(this.finder);

  @override
  final PageFinder? finder;

  @override
  Widget view(BuildContext context) => const _View();

  @override
  Future<void> load(String path, String root) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() {}
}

/// The app with `shop.html` in the preview, its page's find [finder].
Future<Daemon> _html(
  WidgetTester tester,
  PageFinder? finder, {
  double width = 1700,
  Brightness brightness = Brightness.light,
}) async {
  fakeWebViews().newPage = () => _Host(finder);
  final (d, _) = await openEditor(
    tester,
    {'shop.html': utf8.encode('<p>$_page</p>')},
    open: const ['shop.html'],
    width: width,
    brightness: brightness,
  );
  expect(find.byType(WebPage), findsOne);
  return d;
}

/// The app with a browser tab on a page, its find [finder].
Future<Daemon> _tab(
  WidgetTester tester,
  FakePageFinder finder, {
  double width = 1700,
  Brightness? brightness,
}) async {
  browserFakes();
  final make = fakeWebViews().newTab!;
  fakeWebViews().newTab = (tab) =>
      (make(tab) as FakeBrowserHost)..finder = finder;
  final d = await browserApp(tester, width: width, brightness: brightness);
  d.chats['c']!.openBrowserTab('http://localhost:3000');
  await tester.pumpAndSettle();
  expect(find.byType(BrowserPane), findsOne);
  return d;
}

/// The prompt box focused: Flutter's focus stays there while a web view
/// takes the keys (a click into a page doesn't tell Flutter).
Future<void> _focusPrompt(WidgetTester tester) async {
  await tester.tap(find.byType(EditableText).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  for (final (kind, open) in [
    ('an HTML page', _html),
    ('a browser tab', _tab),
  ]) {
    testWidgets('$kind: ⌘F with its web view holding the keys finds in the '
        "page; with the prompt box's, the chat", (tester) async {
      final finder = FakePageFinder(_page);
      final d = await open(tester, finder);
      await _focusPrompt(tester);
      finder.hasKeys = true;
      await press(tester, LogicalKeyboardKey.keyF, cmd: true);
      expect(findBar, findsOne);
      expect(find.text('Find in the page'), findsOne);
      expect(chatC(d).find.query, isNull);
      await look(tester, 'teapot');
      expect(find.text('1 of 3'), findsOne);
      expect(finder.asked.last, 'find teapot 0');
      // Esc: the marks go, and the web view has the keys back.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(findBar, findsNothing);
      expect(finder.asked.sublist(finder.asked.length - 2), ['clear', 'focus']);
      // The web view without the keys: the chat's.
      finder.hasKeys = false;
      await _focusPrompt(tester);
      await press(tester, LogicalKeyboardKey.keyF, cmd: true);
      expect(chatC(d).find.query, '');
      expect(find.text('Find in the page'), findsNothing);
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets("$kind: ⏎ and ⇧⏎ step through the page's matches, round; "
        'none said plainly; a page loaded anew is looked in again', (
      tester,
    ) async {
      final finder = FakePageFinder(_page)..hasKeys = true;
      final d = await open(tester, finder);
      await _focusPrompt(tester);
      await press(tester, LogicalKeyboardKey.keyF, cmd: true);
      await look(tester, 'teapot');
      expect(find.text('1 of 3'), findsOne);
      await stepFind(tester);
      expect(find.text('2 of 3'), findsOne);
      expect(finder.asked.last, 'show 1');
      await stepFind(tester, back: true);
      await stepFind(tester, back: true);
      expect(find.text('3 of 3'), findsOne);
      expect(finder.asked.last, 'show 2');
      finder
        ..text = 'teapot only once now'
        ..load();
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOne);
      await look(tester, 'kettle');
      expect(find.text('None'), findsOne);
      // The theme's colours, the transcript's.
      expect(finder.colors, isNotNull);
      await endEditor(tester, d);
    }, variant: onMac);
  }

  testWidgets("⌘F with the browser's address field focused finds in its "
      'page; Esc gives the field its keys back, not the web view', (
    tester,
  ) async {
    final finder = FakePageFinder(_page);
    final d = await _tab(tester, finder);
    await tester.tap(addressField);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    expect(find.text('Find in the page'), findsOne);
    expect(chatC(d).find.query, isNull);
    await look(tester, 'teapot');
    expect(addressEditable(tester).widget.focusNode.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(findBar, findsNothing);
    expect(finder.asked.last, 'clear');
    expect(finder.asked, isNot(contains('focus')));
    expect(addressEditable(tester).widget.focusNode.hasFocus, isTrue);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('⌘F from the page, the prompt box focused before: Esc gives '
      'the web view the keys, not the prompt box', (tester) async {
    final finder = FakePageFinder(_page);
    final d = await _tab(tester, finder);
    await _focusPrompt(tester);
    final prompt = FocusManager.instance.primaryFocus!;
    finder.hasKeys = true;
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    await look(tester, 'teapot');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(finder.asked.sublist(finder.asked.length - 2), ['clear', 'focus']);
    expect(prompt.hasFocus, isFalse);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a page with no find of its own (Linux, Windows) has no bar: '
      "⌘F is the chat's", (tester) async {
    final d = await _html(tester, null);
    expect(pageFinds, isEmpty);
    await _focusPrompt(tester);
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    expect(
      find.descendant(of: find.byType(FilesPane), matching: findBar),
      findsNothing,
    );
    expect(chatC(d).find.query, '');
    await endEditor(tester, d);
  }, variant: onMac);

  test('typing asks the page only for the query it ends on', () async {
    final finder = FakePageFinder(_page);
    final find = WebFind(finder)..query = '';
    for (final q in ['t', 'te', 'tea']) {
      find.query = q;
    }
    await pumpEventQueue();
    expect(finder.asked, ['find tea 0']);
    expect(find.count, isNotEmpty);
    find.dispose();
  });

  testWidgets('the bar with matches', (tester) async {
    await renderFind(tester, 'find-html', (w, b) async {
      final finder = FakePageFinder(_page)..hasKeys = true;
      final d = await _html(tester, finder, width: w, brightness: b);
      pageFinds.single.open();
      await tester.pumpAndSettle();
      await look(tester, 'teapot');
      await stepFind(tester);
      return d;
    });
    await renderFind(tester, 'find-browser', (w, b) async {
      final finder = FakePageFinder(_page)..hasKeys = true;
      final d = await _tab(tester, finder, width: w, brightness: b);
      pageFinds.single.open();
      await tester.pumpAndSettle();
      await look(tester, 'teapot');
      await stepFind(tester);
      return d;
    });
  }, variant: onMac);
}
