import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:xterm2/xterm.dart' hide Terminal;

import 'fake_daemon.dart';
import 'preview_tabs_fixture.dart';

void main() {
  setUpAll(loadFonts);

  group('a chat’s tabs', () {
    ChatState state() => ChatState('c', '/Users/me/nushi');

    test('a file open in a tab isn’t opened twice, however it’s named', () {
      final c = state()
        ..openTab('docs/a.md')
        ..openTab('docs/b.md')
        ..openTab('/Users/me/nushi/docs/a.md');
      expect(c.tabFiles, ['docs/a.md', 'docs/b.md']);
      expect(c.tabFile.value, 'docs/a.md');
      c.openTab('./docs/b.md');
      expect(c.tabFiles, ['docs/a.md', 'docs/b.md']);
      expect(c.tabFile.value, 'docs/b.md');
    });

    test('closing: the next tab, the last, then Chat', () {
      final c = state()
        ..openTab('a.md')
        ..openTab('b.md')
        ..openTab('c.md')
        ..openTab('b.md');
      expect(c.tabFile.value, 'b.md');
      void close(String file, String? next, ChatTab tab) {
        c.closeTab(file);
        expect((c.tabFile.value, c.shownTab), (next, tab));
      }

      close('b.md', 'c.md', ChatTab.preview);
      close('c.md', 'a.md', ChatTab.preview);
      close('a.md', null, ChatTab.chat);
      expect(previewTabs.value, isNot(contains('c')));
    });

    test('closing one that doesn’t show leaves the one that does', () {
      final c = state()
        ..openTab('a.md')
        ..openTab('b.md')
        ..closeTab('a.md');
      expect((c.tabFile.value, c.shownTab), ('b.md', ChatTab.preview));
    });

    test('a tab takes a pane of its file, and only that', () {
      final c = state()
        ..openPreview('a.md')
        ..openTab('b.md');
      expect(c.preview.value, 'a.md');
      expect((c..openTab('a.md')).preview.value, isNull);
    });

    test('a deleted chat forgets its tabs', () {
      state().openTab('a.md');
      expect(chatsKept(), contains('c'));
      forgetChats({'c'});
      expect(previewTabs.value, isEmpty);
      expect(state().shownTab, ChatTab.chat);
    });

    test('a tab’s name, with a folder only when two share it', () {
      expect(tabLabel('docs/a.md', ['docs/a.md', 'b.md']), 'a.md');
      final two = ['docs/plan.md', 'site/plan.md', 'plan.md'];
      expect(tabLabel('docs/plan.md', two), 'plan.md · docs');
      expect(tabLabel('site/plan.md', two), 'plan.md · site');
      expect(tabLabel('plan.md', two), 'plan.md');
      final deep = ['a/x/plan.md', 'b/x/plan.md'];
      expect(tabLabel('a/x/plan.md', deep), 'plan.md · a/x');
    });

    test('those that fit, the one showing always among them', () {
      double width(String _) => 100;
      final files = ['a', 'b', 'c', 'd'];
      expect(fitTabs(files, 'a', width, 400).over, isEmpty);
      final fit = fitTabs(files, 'd', width, 250);
      expect(fit.shown, ['a', 'd']);
      expect(fit.over, ['b', 'c']);
      expect(fit.width, 200 + tabOverflowWidth);
      expect(fitTabs(files, null, width, 30).shown, isEmpty);
      expect(fitTabs(files, 'c', width, 100).shown, ['c']);
    });
  });

  testWidgets('tabs show again as they were left, saved in app.json', (
    tester,
  ) async {
    final d = await tabsApp(tester);
    d.chats['c']!.openTab('docs/report.md');
    await tester.pumpAndSettle();
    expect(readSaved()['previewTabs'], {
      'c': ['docs/report.md'],
    });
    // A new run: the chat opens on Chat with its tab there.
    d.chats['c']!.showStop((tab: ChatTab.chat, file: null));
    await tester.pumpAndSettle();
    expect(tabView, findsNothing);
    expect(inHeader(find.text('report.md')), findsOneWidget);
    d.dispose();
  }, variant: macOnly);

  testWidgets('a tab whose file is gone says so, and closes', (tester) async {
    previewTabs.value = {
      'c': ['docs/gone.md'],
    };
    final d = await tabsApp(tester);
    await tapAndSettle(tester, inHeader(find.text('gone.md')));
    expect(find.text('gone.md isn’t there any more.'), findsOneWidget);
    expect(
      find.descendant(of: tabView, matching: find.text('Live')),
      findsNothing,
    );
    await tapAndSettle(tester, find.text('Close tab'));
    expect(d.chats['c']!.tabFiles, isEmpty);
    expect(d.chats['c']!.shownTab, ChatTab.chat);
    expect(find.byType(Composer), findsOneWidget);
    d.dispose();
  }, variant: macOnly);

  testWidgets('one web view: only the tab that shows has one', (tester) async {
    previewTabs.value = {
      'c': ['site/index.html', 'docs/report.md'],
    };
    final pages = ValueNotifier(0);
    addTearDown(pages.dispose);
    final made = <int>[];
    pages.addListener(() => made.add(pages.value));
    final d = await tabsApp(tester, pages: pages);
    final c = d.chats['c']!;
    expect(pages.value, 0, reason: 'nothing runs until a tab is shown');

    await tapAndSettle(tester, inHeader(find.text('index.html')));
    expect(pages.value, 1);
    await tapAndSettle(tester, inHeader(find.text('report.md')));
    expect(pages.value, 0);
    await tapAndSettle(tester, inHeader(find.text('index.html')));
    expect(pages.value, 1, reason: 'made again');
    await tapAndSettle(tester, inHeader(find.text('Chat')));
    expect(pages.value, 0);
    expect(made.reduce((a, b) => a > b ? a : b), 1);
    expect(c.tabFiles, hasLength(2));
    d.dispose();
  }, variant: macOnly);

  testWidgets('a tab keeps its Source across a switch', (tester) async {
    previewTabs.value = {
      'c': ['docs/report.md', 'docs/plan.md'],
    };
    final d = await tabsApp(tester);
    await tapAndSettle(tester, inHeader(find.text('report.md')));
    await tapAndSettle(
      tester,
      find.descendant(of: tabView, matching: find.text('Source')),
    );
    await tapAndSettle(tester, inHeader(find.text('plan.md')));
    expect(find.textContaining('# The plan'), findsNothing);
    await tapAndSettle(tester, inHeader(find.text('report.md')));
    expect(find.textContaining('# The report'), findsOneWidget);
    d.dispose();
  }, variant: macOnly);

  group('keys', () {
    testWidgets('⌃⌘4 and on show the tabs, ⌘W closes, ⌃Tab goes through', (
      tester,
    ) async {
      previewTabs.value = {
        'c': ['docs/report.md', 'docs/plan.md'],
      };
      final d = await tabsApp(tester);
      final c = d.chats['c']!;
      await pressKeys(
        tester,
        LogicalKeyboardKey.digit5,
        meta: true,
        control: true,
      );
      expect(c.tabFile.value, 'docs/plan.md');
      await pressKeys(
        tester,
        LogicalKeyboardKey.digit4,
        meta: true,
        control: true,
      );
      expect(c.tabFile.value, 'docs/report.md');
      await pressKeys(
        tester,
        LogicalKeyboardKey.digit6,
        meta: true,
        control: true,
      );
      expect(c.tabFile.value, 'docs/report.md', reason: 'no third tab');

      await pressKeys(tester, LogicalKeyboardKey.tab, control: true);
      expect(c.tabFile.value, 'docs/plan.md');
      await pressKeys(tester, LogicalKeyboardKey.tab, control: true);
      expect(c.shownTab, ChatTab.chat);

      await pressKeys(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.tabFiles, hasLength(2), reason: '⌘W closes no Chat tab');

      await pressKeys(
        tester,
        LogicalKeyboardKey.digit4,
        meta: true,
        control: true,
      );
      await pressKeys(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.tabFiles, ['docs/plan.md']);
      expect(c.tabFile.value, 'docs/plan.md');
      await pressKeys(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.tabFiles, isEmpty);
      expect(c.shownTab, ChatTab.chat);
      d.dispose();
    }, variant: macOnly);

    testWidgets('a focused terminal keeps ⌘W; the tab stays', (tester) async {
      previewTabs.value = {
        'c': ['docs/report.md'],
      };
      terminalChats.value = {'c'};
      final d = await tabsApp(tester);
      final c = d.chats['c']!;
      await tapAndSettle(tester, inHeader(find.text('report.md')));
      await tapAndSettle(tester, find.byType(TerminalView));
      await pressKeys(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.tabFiles, ['docs/report.md']);
      // Other keys pass through it, as ⌃⌘1–3 do.
      await pressKeys(
        tester,
        LogicalKeyboardKey.digit1,
        meta: true,
        control: true,
      );
      expect(c.shownTab, ChatTab.chat);
      d.dispose();
    }, variant: macOnly);

    testWidgets('⌘W with a dialog open leaves the tab under it', (
      tester,
    ) async {
      previewTabs.value = {
        'c': ['docs/report.md'],
      };
      final d = await tabsApp(tester);
      final c = d.chats['c']!;
      await tapAndSettle(tester, inHeader(find.text('report.md')));
      await pressKeys(tester, LogicalKeyboardKey.keyK, meta: true);
      expect(find.byType(Palette), findsOneWidget);
      await pressKeys(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.tabFiles, ['docs/report.md']);
      // The menu bar's File › Close Tab, where a ⌘W no widget takes goes.
      final navigator = tester.element(find.byType(Navigator).first);
      runAct(navigator, d, Act.closeTab);
      await tester.pumpAndSettle();
      expect(c.tabFiles, ['docs/report.md']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      runAct(navigator, d, Act.closeTab);
      await tester.pumpAndSettle();
      expect(c.tabFiles, isEmpty, reason: 'the dialog is gone');
      d.dispose();
    }, variant: macOnly);

    testWidgets('the palette offers the tabs that are open', (tester) async {
      previewTabs.value = {
        'c': ['docs/report.md'],
      };
      final d = await tabsApp(tester);
      await pressKeys(tester, LogicalKeyboardKey.keyK, meta: true);
      final inPalette = find.descendant(
        of: find.byType(Palette),
        matching: find.text('Show report.md'),
      );
      expect(inPalette, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Palette),
          matching: find.text('Show a preview tab'),
        ),
        findsNothing,
      );
      await tapAndSettle(tester, inPalette);
      expect(d.chats['c']!.tabFile.value, 'docs/report.md');
      expect(tabView, findsOneWidget);
      d.dispose();
    }, variant: macOnly);
  });

  group('the header', () {
    const many = [
      'docs/report.md',
      'docs/plan.md',
      'site/plan.md',
      'a.csv',
      'site/index.html',
      'docs/a-rather-long-name-for-a-file-that-gets-cut-short.md',
      'docs/seven.md',
      'docs/eight.md',
      'docs/nine.md',
      'docs/ten.md',
      'docs/eleven.md',
    ];

    /// The tabs' row ends in ⋯ at the header's right edge, whatever's
    /// inside the row sits inside the header, and no label is cut but
    /// the one meant to be.
    void noneClipped(WidgetTester tester) {
      final header = tester.getRect(headerView);
      expect(
        tester.getTopRight(find.byTooltip('Chat menu')).dx,
        moreOrLessEquals(header.right - 8, epsilon: 6),
      );
      for (final element
          in find
              .descendant(of: headerView, matching: find.byType(Text))
              .evaluate()) {
        final box = element.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        expect(rect.left, greaterThanOrEqualTo(header.left));
        expect(rect.right, lessThanOrEqualTo(header.right));
      }
    }

    testWidgets('two with one name show a folder; too many overflow', (
      tester,
    ) async {
      previewTabs.value = {'c': many};
      final d = await tabsApp(tester, pull: true);
      final c = d.chats['c']!;
      expect(inHeader(find.text('plan.md · docs')), findsOneWidget);
      expect(inHeader(find.text('plan.md · site')), findsOneWidget);
      final over = inHeader(find.textContaining(RegExp(r'^\+\d+$')));
      expect(over, findsOneWidget);
      noneClipped(tester);

      // One from the overflow shows in the row, in place of another.
      await tapAndSettle(tester, over);
      await tapAndSettle(tester, find.text('eleven.md'));
      expect(c.tabFile.value, 'docs/eleven.md');
      expect(inHeader(find.text('eleven.md')), findsOneWidget);
      noneClipped(tester);

      // Closed from the overflow.
      await tapAndSettle(
        tester,
        inHeader(find.textContaining(RegExp(r'^\+\d+$'))),
      );
      final ten = find.ancestor(
        of: find.text('ten.md'),
        matching: find.byType(MenuItemButton),
      );
      await tapAndSettle(
        tester,
        find.descendant(of: ten, matching: find.byTooltip('Close tab')),
      );
      expect(c.tabFiles, isNot(contains('docs/ten.md')));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      d.dispose();
    }, variant: macOnly);

    for (final width in [720.0, 900.0, 1000.0, 1200.0]) {
      testWidgets('$width wide with a pull request: nothing overflows', (
        tester,
      ) async {
        previewTabs.value = {'c': many};
        final d = await tabsApp(tester, width: width, pull: true, model: true);
        d.chats['c']!.showStop((tab: ChatTab.preview, file: many[5]));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        noneClipped(tester);
        d.dispose();
      }, variant: macOnly);
    }

    testWidgets('at 720 the tabs fold into a menu, closable there', (
      tester,
    ) async {
      previewTabs.value = {
        'c': ['docs/report.md', 'docs/plan.md'],
      };
      final d = await tabsApp(tester, width: 720);
      final c = d.chats['c']!;
      await tapAndSettle(tester, inHeader(find.text('Chat')));
      await tapAndSettle(tester, find.textContaining('plan.md   ⌃⌘5'));
      expect(c.tabFile.value, 'docs/plan.md');
      expect(tabView, findsOneWidget);
      expect(inHeader(find.text('plan.md')), findsOneWidget);
      noneClipped(tester);

      await tapAndSettle(tester, inHeader(find.text('plan.md')));
      // Each row says its key.
      final row = find.ancestor(
        of: find.textContaining('report.md   ⌃⌘4'),
        matching: find.byType(MenuItemButton),
      );
      await tapAndSettle(
        tester,
        find.descendant(of: row, matching: find.byTooltip('Close tab')),
      );
      expect(c.tabFiles, ['docs/plan.md']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      d.dispose();
    }, variant: macOnly);
  });

  group('goldens', () {
    const open = ['docs/report.md', 'docs/plan.md', 'site/plan.md'];
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      for (final width in [1700.0, 720.0]) {
        testWidgets('a preview tab, $name, ${width.toInt()} wide', (
          tester,
        ) async {
          previewTabs.value = {'c': open};
          final d = await tabsApp(tester, width: width, brightness: brightness);
          d.chats['c']!.showStop((
            tab: ChatTab.preview,
            file: 'docs/report.md',
          ));
          await tester.pumpAndSettle();
          // The header's and the view's last buttons at their edge.
          final right = tester.getRect(find.byType(NushiApp)).right;
          expect(
            tester.getTopRight(find.byTooltip('Chat menu')).dx,
            greaterThan(right - 14),
          );
          expect(
            tester.getTopRight(find.byTooltip('Show in Finder')).dx,
            greaterThan(right - 14),
          );
          await expectLater(
            find.byType(NushiApp),
            matchesGoldenFile(
              'goldens/preview_tab_${name}_${width.toInt()}.png',
            ),
          );
          d.dispose();
        }, variant: macOnly);
      }
    }
  });
}
