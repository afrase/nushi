import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_tabs.dart';
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

    test('each new browser tab is a tab of its own, last', () {
      final c = state()..openPreview('docs/a.md');
      final one = c.openBrowserTab();
      final two = c.openBrowserTab();
      expect(c.previewTabs.value, [const PreviewFile('docs/a.md'), one, two]);
      expect(c.preview.value, two);
      expect(c.previewFile, isNull);
      // A file still opens once, beside them.
      c.openPreview('/Users/me/nushi/docs/a.md');
      expect(c.previewTabs.value, hasLength(3));
      expect(c.previewFile, 'docs/a.md');
    });

    test('closing one shows the next; Close takes them all', () {
      final c = state()..openPreview('a.md');
      final one = c.openBrowserTab('http://localhost:3000');
      c
        ..openPreview('b.md')
        ..showPreviewTab(one)
        ..closePreview(one);
      expect(c.previewFile, 'b.md');
      expect(c.previewNames, ['a.md', 'b.md']);
      c.preview.value = null;
      expect(c.previewTabs.value, isEmpty);
    });

    test('Browser shows the last browser tab, or a new one', () {
      final c = state()..showBrowser();
      final first = c.preview.value! as BrowserTab;
      expect(first.address.value, '');
      final second = c.openBrowserTab();
      c
        ..openPreview('a.md')
        ..showBrowser();
      expect(c.preview.value, same(second));
      c.showBrowser();
      expect(c.previewTabs.value, hasLength(3));
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
    }, variant: macOnly);

    testWidgets('+ shows with a browser tab showing, never on a file’s', (
      tester,
    ) async {
      browserFakes();
      final d = await browserApp(tester);
      final c = d.chats['c']!..openPreview('docs/a.md');
      await tester.pumpAndSettle();
      expect(find.byTooltip('New browser tab'), findsNothing);
      c.openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      expect(find.byType(PreviewTabs), findsOneWidget);
      final plus = find.byTooltip('New browser tab');
      expect(plus, findsOneWidget);
      // Right after the last tab.
      final tabs = tester.getRect(find.byType(PreviewTabs));
      expect(tester.getRect(plus).left, tabs.right);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(c.previewTabs.value, hasLength(3));
      expect(find.text(browserHint), findsOneWidget);
      // Back on the file's tab: no +.
      await tester.tap(
        find.descendant(
          of: find.byType(PreviewTabs),
          matching: find.text('a.md'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPane), findsOneWidget);
      expect(find.byTooltip('New browser tab'), findsNothing);
      await closeView(tester, d);
    }, variant: macOnly);

    testWidgets('the header’s globe opens a browser tab and is lit while it '
        'shows; the palette’s New browser tab adds one', (tester) async {
      browserFakes();
      final d = await browserApp(tester);
      final globe = find.byType(BrowserButton);
      Color ink() => tester
          .widget<IconTap>(
            find.descendant(of: globe, matching: find.byType(IconTap)),
          )
          .color!;
      final t = NushiTheme.of(tester.element(globe)).t;
      expect(ink(), t.textSecondary);
      await tester.tap(globe);
      await tester.pumpAndSettle();
      final c = d.chats['c']!;
      expect(c.preview.value, isA<BrowserTab>());
      expect(find.byType(BrowserPane), findsOneWidget);
      expect(ink(), t.accentInk);
      await tester.tap(globe);
      await tester.pumpAndSettle();
      expect(c.previewTabs.value, hasLength(1));
      runAct(tester.element(globe), d, Act.newBrowserTab);
      await tester.pumpAndSettle();
      expect(c.previewTabs.value, hasLength(2));
      await closeView(tester, d);
    }, variant: macOnly);

    // Fix review 2026-11-06: on Changes the pane isn't there, so a new tab
    // was made unseen, a second press did nothing, and the globe was lit.
    testWidgets('from Changes the globe and New browser tab go to the Chat '
        'tab, and the globe is lit only there', (tester) async {
      browserFakes();
      final d = await browserApp(tester);
      final c = d.chats['c']!;
      final globe = find.byType(BrowserButton);
      Color ink() => tester
          .widget<IconTap>(
            find.descendant(of: globe, matching: find.byType(IconTap)),
          )
          .color!;
      final t = NushiTheme.of(tester.element(globe)).t;
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
      expect(ink(), t.accentInk);
      // The browser tab still the preview's: lit only while it's in sight.
      await toChanges();
      expect(ink(), t.textSecondary);
      await tester.tap(globe);
      await tester.pumpAndSettle();
      expect(c.shownTab, ChatTab.chat);
      expect(find.byType(BrowserPane), findsOneWidget);
      expect(c.previewTabs.value, hasLength(1));
      await toChanges();
      runAct(tester.element(globe), d, Act.newBrowserTab);
      await tester.pumpAndSettle();
      expect(c.shownTab, ChatTab.chat);
      expect(c.previewTabs.value, hasLength(2));
      expect(find.text(browserHint), findsOneWidget);
      await closeView(tester, d);
    }, variant: macOnly);

    testWidgets('⌘R reloads the page, ⌘L takes the focus to its address; '
        '⌘W closes the tab', (tester) async {
      final fakes = browserFakes();
      final d = await browserApp(tester);
      final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      final host = fakes.hosts.single;
      expect(addressEditable(tester).widget.focusNode.hasFocus, isFalse);
      await pressMeta(tester, LogicalKeyboardKey.keyR);
      expect(host.reloads, 1);
      await pressMeta(tester, LogicalKeyboardKey.keyL);
      final field = addressEditable(tester).widget;
      expect(field.focusNode.hasFocus, isTrue);
      expect(
        field.controller.selection,
        const TextSelection(
          baseOffset: 0,
          extentOffset: 'http://localhost:3000'.length,
        ),
      );
      await pressMeta(tester, LogicalKeyboardKey.keyW);
      expect(c.preview.value, isNull);
      // With no browser tab they do nothing.
      final acts = appActions(tester.element(find.byType(Scaffold).first), d);
      for (final a in [Act.address, Act.reloadPage]) {
        expect(acts.firstWhere((e) => e.act == a).enabled, isFalse);
      }
      await closeView(tester, d);
    }, variant: macOnly);

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
      await pressMeta(tester, LogicalKeyboardKey.keyL);
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
    }, variant: macOnly);

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
      await pressMeta(tester, LogicalKeyboardKey.keyR);
      expect(asked(), before + 1);
      expect(fakes.hosts, isEmpty);
      await closeView(tester, d);
    }, variant: macOnly);

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
      await pressMeta(tester, LogicalKeyboardKey.keyR);
      expect(asked(), greaterThan(before));
      expect(fakes.hosts, isEmpty);
      await closeView(tester, d);
    }, variant: macOnly);

    testWidgets('⌘[ and ⌘] still switch chats from the address field', (
      tester,
    ) async {
      browserFakes();
      final d = await browserApp(tester);
      d.chats['c']!.openBrowserTab();
      await tester.pumpAndSettle();
      expect(addressEditable(tester).widget.focusNode.hasFocus, isTrue);
      await pressMeta(tester, LogicalKeyboardKey.bracketRight);
      expect(d.selectedId, 'd');
      await pressMeta(tester, LogicalKeyboardKey.bracketLeft);
      expect(d.selectedId, 'c');
      await closeView(tester, d);
    }, variant: macOnly);
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
                    valueListenable: c.preview,
                    builder: (context, tab, _) => tab is BrowserTab
                        ? BrowserPane(
                            key: ObjectKey(tab),
                            chat: c,
                            tab: tab,
                            onClose: () {},
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
      }, variant: macOnly);

      testWidgets('tabs, a file’s among them, with +; the bar on a page', (
        tester,
      ) async {
        final fakes = browserFakes();
        final c = await pane(tester, const Size(560, 160));
        c
          ..openPreview('docs/plan.md')
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
      }, variant: macOnly);

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
      }, variant: macOnly);

      for (final width in [1700.0, 720.0]) {
        testWidgets('renders: the window with a browser tab, '
            '${width.toInt()} wide', (tester) async {
          browserFakes();
          final d = await browserApp(
            tester,
            width: width,
            brightness: brightness,
          );
          d.chats['c']!
            ..openPreview('docs/plan.md')
            ..openBrowserTab('http://localhost:3000');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectTextInside(tester, width);
          // The bar's field runs to the pane's edge, its buttons first.
          final pane = tester.getRect(find.byType(BrowserPane));
          final bar = tester.getRect(find.byType(BrowserBar));
          expect((bar.left, bar.right), (pane.left, pane.right));
          expect(
            tester.getRect(addressField).right,
            closeTo(pane.right - 8, 0.5),
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
        }, variant: macOnly);
      }
    });
  }
}
