import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pane_tabs.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart';
import 'github_fixture.dart' show openView;
import 'harness.dart';
import 'jira_fixture.dart' as jira;

/// The page's Reload doesn't apply with a view in the chat's place (its
/// browser tab out of sight), so the view's ⌘R is the view's.
void _reloadOff(WidgetTester tester, Daemon d, Finder inView) {
  expect(d.chatShows, isFalse);
  final acts = appActions(tester.element(inView), d);
  expect(acts.firstWhere((a) => a.act == Act.reloadPage).enabled, isFalse);
}

void main() {
  setUpAll(loadFonts);

  group('the tabs', () {
    ChatState state() => ChatState('c', '/Users/me/nushi');

    test('each new browser tab is a tab of its own, last, apart from the '
        'files', () {
      final c = state()..openInFiles('docs/a.md');
      final one = c.openBrowserTab();
      final two = c.openBrowserTab();
      expect(c.browser.tabs.value, [one, two]);
      expect(c.browser.shown.value, two);
      // The file's tab stays and shows, beside them.
      expect(c.fileNames, ['docs/a.md']);
      expect(c.shownFile, 'docs/a.md');
      c.openInFiles('/Users/me/nushi/docs/a.md');
      expect(c.fileNames, ['docs/a.md']);
      expect(c.browser.shown.value, two);
    });

    test('closing one shows the next; closing the pane keeps them, the '
        'last one closed ends them, and the files stay', () {
      final c = state()..openInFiles('a.md');
      final one = c.openBrowserTab('http://localhost:3000');
      final two = c.openBrowserTab('http://localhost:5173');
      c
        ..showBrowserTab(one)
        ..browser.close(one);
      expect(c.browser.shown.value, two);
      expect(c.browserNames, ['http://localhost:5173']);
      // The pane's × (or a subagent's pane in its place): the tabs stay.
      c.browser.shown.value = null;
      expect(c.browserNames, ['http://localhost:5173']);
      c.showOrHideBrowser();
      expect(c.browser.shown.value, two);
      c.browser.close(two);
      expect(c.browser.tabs.value, isEmpty);
      expect(c.browser.shown.value, isNull);
      expect(c.fileNames, ['a.md']);
      expect(c.shownFile, 'a.md');
    });

    test('Browser shows the last browser tab, or a new one', () {
      final c = state()..showOrHideBrowser();
      final first = c.browser.shown.value!;
      expect(first.address.value, '');
      final second = c.openBrowserTab();
      c.openInFiles('a.md');
      expect(c.browser.shown.value, same(second));
      c.showOrHideBrowser();
      expect(c.browser.shown.value, isNull);
      c.showOrHideBrowser();
      expect(c.browser.shown.value, same(second));
      expect(c.browser.tabs.value, [first, second]);
    });

    test('the globe hides the browser tabs and brings the same ones back', () {
      final c = state()..openInFiles('a.md');
      final one = c.openBrowserTab('http://localhost:3000');
      final two = c.openBrowserTab('http://localhost:5173');
      c.showBrowserTab(one);
      expect(c.browserShown, isTrue);
      c.showOrHideBrowser();
      // The file's tab stays.
      expect(c.browserShown, isFalse);
      expect(c.shownFile, 'a.md');
      expect(c.browser.tabs.value, [one, two]);
      c.showOrHideBrowser();
      expect(c.browser.shown.value, same(one));
      expect(c.browser.tabs.value, [one, two]);
      expect(one.address.value, 'http://localhost:3000');
    });

    test('a hidden browser comes back with a new tab after its own', () {
      final c = state();
      final one = c.openBrowserTab('http://localhost:3000');
      c.showOrHideBrowser();
      expect(c.browser.shown.value, isNull);
      expect(c.browser.tabs.value, [one]);
      final fresh = c.openBrowserTab();
      expect(c.browser.tabs.value, [one, fresh]);
      expect(c.browser.shown.value, same(fresh));
      // Hiding and showing again keeps the two, the last shown showing.
      c
        ..showOrHideBrowser()
        ..showOrHideBrowser();
      expect(c.browser.tabs.value, [one, fresh]);
      expect(c.browser.shown.value, same(fresh));
    });

    test('a browser tab says its title, else its address, else New tab', () {
      final tab = BrowserTab();
      expect(tab.label, 'New tab');
      tab.address.value = 'http://localhost:3000/app';
      expect(tab.label, 'localhost:3000/app');
      tab.title.value = '  Tea shop  ';
      expect(tab.label, 'Tea shop');
      // A page names itself: a bidi override shows.
      tab.title.value = 'invoice\u202efdp.sh';
      expect(tab.label, 'invoice\ufffdfdp.sh');
      tab.title.value = 'x' * 300;
      expect(tab.label.length, 120);
    });
  });

  group('in the window', () {
    testWidgets('a new tab: its field has the focus, a hint under it, and '
        'a local address loads', (tester) async {
      final fakes = browserFakes();
      final d = await browserApp(tester);
      d.chats['c']!.openBrowserTab();
      await tester.pumpAndSettle();
      expect(find.text(browserHint), findsOneWidget);
      expect(addressEditable(tester).widget.focusNode.hasFocus, isTrue);
      expect(fakes.hosts, isEmpty); // no web view for an empty tab
      await typeAddress(tester, 'localhost:3000');
      expect(fakes.hosts.single.opened, [Uri.parse('http://localhost:3000')]);
      expect(find.text(browserHint), findsNothing);
      expect(find.text('Tea shop · dev'), findsOneWidget); // the title
      expect(
        addressEditable(tester).widget.controller.text,
        'http://localhost:3000',
      );
      expect(fakes.opened, isEmpty);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets("Files' and the browser's Close sit at the same "
        "offsets from each pane's right; a file's address opens Files beside "
        'it', (tester) async {
      browserFakes();
      final d = await browserApp(tester, width: 2400);
      final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      expect(find.byType(FilesPane), findsNothing);
      await typeAddress(tester, 'file:///Users/me/nushi/docs/a.md');
      expect(c.shownFile, '/Users/me/nushi/docs/a.md');
      expect(find.byType(FilesPane), findsOneWidget);
      expect(c.browser.shown.value, isNotNull);
      Rect at(Type pane, String tip) {
        final p = tester.getRect(find.byType(pane));
        final r = tester.getRect(
          find.descendant(of: find.byType(pane), matching: find.byTooltip(tip)),
        );
        return r.shift(Offset(-p.right, -p.top));
      }

      expect(at(FilesPane, 'Close'), at(BrowserPane, 'Close'));
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('+ shows after the chips, and the browser holds no file', (
      tester,
    ) async {
      browserFakes();
      final d = await browserApp(tester);
      final c = d.chats['c']!..openInFiles('docs/a.md');
      await tester.pumpAndSettle();
      expect(find.byTooltip('New browser tab'), findsNothing);
      c.openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      final row = find.descendant(
        of: find.byType(BrowserPane),
        matching: find.byType(PaneTabs),
      );
      expect(row, findsOneWidget);
      final plus = find.byTooltip('New browser tab');
      expect(plus, findsOneWidget);
      // Right after the last tab.
      expect(
        tester.getRect(plus).left,
        closeTo(tester.getRect(row).right + 2, 0.5),
      );
      expect(
        find.descendant(of: row, matching: find.text('a.md')),
        findsNothing,
      );
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(c.browser.tabs.value, hasLength(2));
      expect(find.text(browserHint), findsOneWidget);
      // The file's view stays beside the browser.
      expect(find.byType(FileView), findsOneWidget);
      expect(c.shownFile, 'docs/a.md');
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('the header’s globe shows a browser tab, lit, and hides it; '
        'the palette’s New browser tab adds one', (tester) async {
      browserFakes();
      final d = await browserApp(tester);
      final globe = find.byType(BrowserButton);
      // Lit: filled in the accent's soft tint, its icon in the accent.
      bool lit() => tester
          .widget<IconTap>(
            find.descendant(of: globe, matching: find.byType(IconTap)),
          )
          .lit;
      expect(lit(), isFalse);
      await tester.tap(globe);
      await tester.pumpAndSettle();
      final c = d.chats['c']!;
      expect(c.browser.shown.value, isA<BrowserTab>());
      expect(find.byType(BrowserPane), findsOneWidget);
      expect(lit(), isTrue);
      // Pressed again it hides the browser, unlit; again, the same tab.
      final shown = c.browser.shown.value;
      await tester.tap(globe);
      await tester.pumpAndSettle();
      expect(find.byType(BrowserPane), findsNothing);
      expect(lit(), isFalse);
      expect(find.byTooltip('Show browser'), findsOneWidget);
      await tester.tap(globe);
      await tester.pumpAndSettle();
      expect(c.browser.shown.value, same(shown));
      expect(c.browser.tabs.value, hasLength(1));
      expect(find.byTooltip('Hide browser'), findsOneWidget);
      runAct(tester.element(globe), d, Act.newBrowserTab);
      await tester.pumpAndSettle();
      expect(c.browser.tabs.value, hasLength(2));
      await closeView(tester, d);
    }, variant: onMac);

    // Fix review 2026-11-06: on Changes the pane isn't there, so a new tab
    // was made unseen, a second press did nothing, and the globe was lit.
    testWidgets('from Changes the globe and New browser tab go to the Chat '
        'tab, and the globe is lit only there', (tester) async {
      browserFakes();
      final d = await browserApp(tester);
      final c = d.chats['c']!;
      final globe = find.byType(BrowserButton);
      // Lit: filled in the accent's soft tint, its icon in the accent.
      bool lit() => tester
          .widget<IconTap>(
            find.descendant(of: globe, matching: find.byType(IconTap)),
          )
          .lit;
      Future<void> toChanges() async {
        c.tab.value = ChatTab.changes;
        await tester.pumpAndSettle();
        expect(find.byType(BrowserPane), findsNothing);
      }

      await toChanges();
      await tester.tap(globe);
      await tester.pumpAndSettle();
      expect(c.shownTab, ChatTab.chat);
      expect(find.byType(BrowserPane), findsOneWidget);
      expect(lit(), isTrue);
      // The browser tab still the preview's: lit only while it's in sight.
      await toChanges();
      expect(lit(), isFalse);
      await tester.tap(globe);
      await tester.pumpAndSettle();
      expect(c.shownTab, ChatTab.chat);
      expect(find.byType(BrowserPane), findsOneWidget);
      expect(c.browser.tabs.value, hasLength(1));
      await toChanges();
      runAct(tester.element(globe), d, Act.newBrowserTab);
      await tester.pumpAndSettle();
      expect(c.shownTab, ChatTab.chat);
      expect(c.browser.tabs.value, hasLength(2));
      expect(find.text(browserHint), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('⌘R reloads the page, ⌘L takes the focus to its address; '
        '⌘W closes the tab', (tester) async {
      final fakes = browserFakes();
      final d = await browserApp(tester);
      final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      final host = fakes.hosts.single;
      expect(addressEditable(tester).widget.focusNode.hasFocus, isFalse);
      await press(tester, LogicalKeyboardKey.keyR, cmd: true);
      expect(host.reloads, 1);
      await press(tester, LogicalKeyboardKey.keyL, cmd: true);
      final field = addressEditable(tester).widget;
      expect(field.focusNode.hasFocus, isTrue);
      expect(
        field.controller.selection,
        const TextSelection(
          baseOffset: 0,
          extentOffset: 'http://localhost:3000'.length,
        ),
      );
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.browser.shown.value, isNull);
      // With no browser tab they do nothing.
      final acts = appActions(tester.element(find.byType(Scaffold).first), d);
      for (final a in [Act.address, Act.reloadPage]) {
        expect(acts.firstWhere((e) => e.act == a).enabled, isFalse);
      }
      await closeView(tester, d);
    }, variant: onMac);

    // Deep review 2026-11-10, 3: a tab at a server that wasn't up showed
    // "Can't reach"; once the server started, the Servers menu and the
    // agent's show tool only showed the tab, and the failure stayed.
    testWidgets('a server’s or a page’s tab that didn’t load loads again as '
        'it’s shown', (tester) async {
      final fakes = browserFakes();
      final d = await browserApp(tester);
      final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      final host = fakes.hosts.single;
      c.showServer('http://localhost:3000');
      expect(host.reloads, 0); // it loaded
      host.failure.value = (
        kind: PageFailureKind.unreachable,
        reason: 'Could not connect to the server.',
        url: 'http://localhost:3000/',
      );
      c.showServer('http://localhost:3000');
      expect(host.reloads, 1);
      c.showPage('http://localhost:3000/');
      expect(host.reloads, 2);
      c.openBrowserTab('http://localhost:3000/menu');
      await tester.pumpAndSettle();
      final page = fakes.hosts.last..failure.value = host.failure.value;
      c.showPage('http://localhost:3000/menu');
      expect(page.reloads, 1);
      expect(fakes.hosts, hasLength(2));
      await closeView(tester, d);
    }, variant: onMac);

    // Fix review 2026-11-06: asked for the focus it had, the field took
    // nothing back, so with WebKit holding the keys ⌘L only selected.
    testWidgets('⌘L with the field already focused opens its text input '
        'again', (tester) async {
      browserFakes();
      final d = await browserApp(tester);
      d.chats['c']!.openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      await tester.tap(addressField);
      await tester.pumpAndSettle();
      final field = addressEditable(tester).widget;
      expect(field.focusNode.hasFocus, isTrue);
      tester.testTextInput.log.clear();
      await press(tester, LogicalKeyboardKey.keyL, cmd: true);
      expect(field.focusNode.hasFocus, isTrue);
      final calls = tester.testTextInput.log.map((c) => c.method);
      expect(calls, containsAllInOrder(['TextInput.setClient']));
      expect(
        field.controller.selection,
        const TextSelection(
          baseOffset: 0,
          extentOffset: 'http://localhost:3000'.length,
        ),
      );
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('GitHub keeps its ⌘R: the page’s act doesn’t apply there', (
      tester,
    ) async {
      final fakes = browserFakes();
      // openView sizes the surface itself; the next test gets its own.
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (fake, d) = await openView(
        tester,
        chats: [chat('c1', 'claude', 'Fix Sub')],
        window: true,
      );
      // A browser tab in the chat behind the view.
      d.chats['c1']!.openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      int asked() => fake.calls.whereType<ListGitHubInboxRequest>().length;
      final before = asked();
      // The focus in the view, as a click there leaves it.
      final inView = find.text('Review requested  1');
      Focus.of(tester.element(inView)).requestFocus();
      await tester.pump();
      _reloadOff(tester, d, inView);
      await press(tester, LogicalKeyboardKey.keyR, cmd: true);
      expect(asked(), before + 1);
      expect(fakes.hosts, isEmpty);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('Jira keeps its ⌘R too', (tester) async {
      final fakes = browserFakes();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (fake, d) = await jira.openView(
        tester,
        chats: [chat('c1', 'claude', 'Fix Sub')],
        window: true,
      );
      d.chats['c1']!.openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      int asked() => fake.calls.whereType<ListJiraIssuesRequest>().length;
      final before = asked();
      // The focus in the view, as a click on its list leaves it.
      final inView = find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'jira view',
      );
      tester.widget<Focus>(inView).focusNode!.requestFocus();
      await tester.pump();
      _reloadOff(tester, d, inView);
      await press(tester, LogicalKeyboardKey.keyR, cmd: true);
      expect(asked(), greaterThan(before));
      expect(fakes.hosts, isEmpty);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('⌘[ and ⌘] are the app’s Back and Forward from the address '
        'field too (ADR 0119)', (tester) async {
      browserFakes();
      final d = await browserApp(tester);
      d.select('d');
      await tester.pumpAndSettle();
      d.select('c');
      await tester.pumpAndSettle();
      d.chats['c']!.openBrowserTab();
      await tester.pumpAndSettle();
      expect(addressEditable(tester).widget.focusNode.hasFocus, isTrue);
      await press(tester, LogicalKeyboardKey.bracketLeft, cmd: true);
      expect(d.selectedId, 'd');
      await press(tester, LogicalKeyboardKey.bracketRight, cmd: true);
      expect(d.selectedId, 'c');
      await closeView(tester, d);
    }, variant: onMac);
  });

  for (final (name, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    group('looks, $name', () {
      Future<ChatState> pane(WidgetTester tester, Size size) async {
        viewport(tester, size);
        final c = ChatState('c', '/Users/me/nushi');
        await tester.pumpWidget(
          themed(
            tokens: tokens,
            Center(
              child: RepaintBoundary(
                key: const ValueKey('pane'),
                child: SizedBox.fromSize(
                  size: size,
                  child: ValueListenableBuilder(
                    valueListenable: c.browser.shown,
                    builder: (context, tab, _) => tab != null
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
            ),
          ),
        );
        return c;
      }

      testWidgets('a new tab: the title row with +, the bar, the hint', (
        tester,
      ) async {
        browserFakes();
        final c = await pane(tester, const Size(560, 300));
        c.openBrowserTab();
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('pane')),
          matchesGoldenFile('goldens/browser_new_tab_$name.png'),
        );
      }, variant: onMac);

      testWidgets('tabs, with +; the bar on a page', (tester) async {
        final fakes = browserFakes();
        final c = await pane(tester, const Size(560, 160));
        c
          ..openBrowserTab('http://localhost:5173')
          ..openBrowserTab('http://localhost:3000');
        await tester.pumpAndSettle();
        // A second page, so Back is on.
        await fakes.hosts.last.open(Uri.parse('http://localhost:3000/menu'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('pane')),
          matchesGoldenFile('goldens/browser_tabs_$name.png'),
        );
      }, variant: onMac);

      testWidgets('the browser’s icons, 2×', (tester) async {
        viewport(tester, const Size(200, 44), ratio: 2);
        final t = tokens;
        await tester.pumpWidget(
          themed(
            tokens: tokens,
            Center(
              child: RepaintBoundary(
                key: const ValueKey('icons'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: NushiTheme.iconGap,
                  children: [
                    IconTap.line(
                      LineIcon.globe,
                      tooltip: 'Browser',
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.globe,
                      tooltip: 'Browser',
                      color: t.accentInk,
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.plus,
                      tooltip: 'New browser tab',
                      size: 14,
                      padding: 4,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byKey(const ValueKey('icons')),
          matchesGoldenFile('goldens/browser_icons_$name.png'),
        );
      }, variant: onMac);

      for (final width in [1700.0, 720.0]) {
        if (!lightCopy(brightness)) {
          testWidgets('renders: the window with a browser tab, '
              '${width.toInt()} wide', (tester) async {
            browserFakes();
            final d = await browserApp(
              tester,
              width: width,
              brightness: brightness,
            );
            d.chats['c']!
              ..openInFiles('docs/plan.md')
              ..openBrowserTab('http://localhost:3000');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expectTextInside(tester, width);
            // The bar's field runs to the pane's edge, its buttons first.
            final pane = tester.getRect(find.byType(BrowserPane));
            final bar = tester.getRect(find.byType(BrowserBar));
            expect((bar.left, bar.right), (pane.left, pane.right));
            expect(
              tester.getRect(addressBox).right,
              closeTo(pane.right - BrowserBar.inset, 0.5),
            );
            await render(
              tester,
              find.byType(NushiApp),
              'browser_tab_${width.toInt()}_$name',
            );
            d.chats['c']!.openBrowserTab();
            await tester.pumpAndSettle();
            await render(
              tester,
              find.byType(NushiApp),
              'browser_new_tab_${width.toInt()}_$name',
            );
            await closeView(tester, d);
          }, variant: onMac);
        }
      }
    });
  }
}
