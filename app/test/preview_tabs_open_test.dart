import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'preview_tabs_fixture.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('Open in a tab: the pane closes, the file takes the main area', (
    tester,
  ) async {
    final d = await tabsApp(tester);
    await tapAndSettle(tester, previewOf('r'));
    expect(paneView, findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('Open in a tab'));

    expect(paneView, findsNothing);
    expect(tabView, findsOneWidget);
    expect(find.byType(Composer), findsNothing);
    expect(inHeader(find.text('report.md')), findsOneWidget);
    expect(find.byTooltip('Close tab'), findsOneWidget);
    expect(find.byTooltip('Open in a tab'), findsNothing);
    Finder inTab(Finder f) => find.descendant(of: tabView, matching: f);
    expect(inTab(find.text('Live')), findsOneWidget);
    expect(inTab(find.text('docs/report.md')), findsOneWidget);
    expect(inTab(find.text('The report', findRichText: true)), findsOneWidget);
    // The whole main area, under the header.
    final area = tester.getRect(tabView);
    final header = tester.getRect(headerView);
    expect(area.width, header.width);
    expect(area.top, header.bottom);

    await tapAndSettle(tester, inTab(find.text('Source')));
    expect(inTab(find.textContaining('# The report')), findsOneWidget);
    d.dispose();
  }, variant: macOnly);

  testWidgets('⌘-click on Preview opens a tab; a plain click focuses it', (
    tester,
  ) async {
    final asked = <String>[];
    final d = await tabsApp(tester, asked: asked);
    final c = d.chats['c']!;
    await commandClick(tester, 'p');
    expect(paneView, findsNothing);
    expect(c.tabFiles, ['docs/plan.md']);
    expect(c.shownTab, ChatTab.preview);

    await tapAndSettle(tester, inHeader(find.text('Chat')));
    expect(tabView, findsNothing);
    await commandClick(tester, 'r');
    expect(c.tabFiles, ['docs/plan.md', 'docs/report.md']);
    await tapAndSettle(tester, inHeader(find.text('Chat')));
    await tapAndSettle(tester, previewOf('p'));
    expect(paneView, findsNothing, reason: 'it has a tab');
    expect(c.tabFile.value, 'docs/plan.md');
    expect(c.tabFiles, hasLength(2));
    d.dispose();
  }, variant: macOnly);

  testWidgets('⌘-click on an Artifacts row opens a tab', (tester) async {
    final d = await tabsApp(tester);
    showDetails.value = true;
    await tester.pumpAndSettle();
    final row = find.descendant(
      of: find.byType(FileRows),
      matching: find.text('plan.md'),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.tap(row);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(d.chats['c']!.tabFiles, ['docs/plan.md']);
    expect(paneView, findsNothing);
    d.dispose();
  }, variant: macOnly);

  testWidgets('the agent’s show opens the pane, tab or no tab (ADR 0068)', (
    tester,
  ) async {
    final d = await tabsApp(tester);
    final c = d.chats['c']!;
    await commandClick(tester, 'r');
    await tapAndSettle(tester, inHeader(find.text('Chat')));
    c.showAsked.value = 'docs/report.md';
    await tester.pumpAndSettle();
    expect(paneView, findsOneWidget);
    expect(c.shownTab, ChatTab.chat);

    // On a preview tab it waits, as on Changes: the agent never moves you.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    c.showStop((tab: ChatTab.preview, file: 'docs/report.md'));
    await tester.pumpAndSettle();
    c.showAsked.value = 'docs/plan.md';
    await tester.pumpAndSettle();
    expect(c.shownTab, ChatTab.preview);
    expect(c.showAsked.value, 'docs/plan.md');
    d.dispose();
  }, variant: macOnly);

  testWidgets('the pane’s buttons fold at its least width', (tester) async {
    final pages = ValueNotifier(0);
    addTearDown(pages.dispose);
    final d = await tabsApp(tester, width: 1000, pages: pages);
    final c = d.chats['c']!..openPreview('site/index.html');
    paneWidths.value = {'preview': 300};
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(paneView).width, lessThan(320));
    expect(find.byTooltip('Open in a tab'), findsNothing);
    await tapAndSettle(tester, find.byTooltip('More'));
    await tapAndSettle(tester, find.text('Open in a tab'));
    expect(c.preview.value, isNull);
    expect(c.tabFiles, ['site/index.html']);
    d.dispose();
  }, variant: macOnly);
}
