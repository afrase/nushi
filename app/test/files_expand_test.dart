import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_panes.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_button.dart'
    show TitleButtons, hiddenHeaderStart, sidebarShut;
import 'package:nushi/source_editor.dart';
import 'package:nushi/theme/theme.dart';

import 'browser_fixture.dart';
import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'panes_app.dart';

// The Files pane's Expand, the browser's (ADR 0094) made the cover's for
// either pane (ADR 0123): it takes the whole chat pane until Collapse, Esc,
// the pane hidden, a browser tab shown, a terminal or another tab.

Finder _inFiles(String tooltip) => find.descendant(
  of: find.byType(FilesPane),
  matching: find.byTooltip(tooltip),
);
Finder get _expand => _inFiles('Expand');
Finder get _collapse => _inFiles('Collapse');

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// ⌘W.
Future<void> _close(WidgetTester tester) async {
  await press(tester, LogicalKeyboardKey.keyW, cmd: true);
}

Future<void> _esc(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('Expand takes the whole chat pane, the tree at its right; '
      'Collapse gives it back, the same file all along', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode('package main\n'),
      'b.go': utf8.encode('package b\n'),
    });
    final beside = tester.getRect(find.byType(FilesPane));
    final view = tester.state(find.byType(SourceEditor));
    final watches = fake.calls.length;
    await _tap(tester, _expand);
    final pane = tester.getRect(find.byType(Pane));
    expect(tester.getRect(find.byType(FilesPane)), pane);
    expect(find.byType(Composer), findsNothing);
    expect(find.byType(ChatHeader), findsNothing);
    // The tree at the window's edge, at its width.
    final tree = tester.getRect(find.byType(FilesTree));
    expect(tree.right, pane.right);
    expect(tree.width, 260);
    // One editor, one watch: the file's view wasn't made again.
    expect(tester.state(find.byType(SourceEditor)), same(view));
    expect(fake.calls.length, watches);
    // A file opened while it covers shows there.
    chatC(d).openInFiles('b.go');
    await tester.pumpAndSettle();
    expect(_collapse, findsOneWidget);
    await _tap(tester, _collapse);
    expect(tester.getRect(find.byType(FilesPane)), beside);
    expect(find.byType(Composer), findsOneWidget);
    expect(paneWidths.value, isNot(contains('filesPane')));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('Esc: the filter clears first, then the pane collapses; from '
      'the editor it collapses', (tester) async {
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('package main\n'),
    });
    await _tap(tester, _expand);
    // Straight away: the pane has the keys, not the hidden box.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'files pane');
    await _esc(tester);
    expect(_expand, findsOneWidget);
    // From the filter with text: one Esc clears it, the next collapses.
    await _tap(tester, _expand);
    final field = find.descendant(
      of: find.byType(FilesTree),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'main');
    await tester.pumpAndSettle();
    await _esc(tester);
    expect(_collapse, findsOneWidget);
    expect(tester.widget<EditableText>(field).controller.text, isEmpty);
    await _esc(tester);
    expect(_expand, findsOneWidget);
    // From the editor: re_editor's own Esc is left out, so it collapses.
    await _tap(tester, _expand);
    await _tap(tester, find.byType(SourceEditor));
    await _esc(tester);
    expect(_expand, findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a browser tab shown, the pane hidden or Changes put it '
      'back; a file shown while the browser covers puts that back', (
    tester,
  ) async {
    browserFakes();
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('package main\n'),
    }, width: 2400);
    final c = chatC(d);
    // A browser tab.
    await _tap(tester, _expand);
    c.openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    expect(find.byType(BrowserPane), findsOneWidget);
    // The pane hidden, and shown again: back beside.
    await _tap(tester, _expand);
    showOrHideFiles(c);
    await tester.pumpAndSettle();
    showOrHideFiles(c);
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    // Changes and back.
    await _tap(tester, _expand);
    c.tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    c.tab.value = ChatTab.chat;
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    // The browser expanded, a file shown: Files beside it again.
    await _tap(
      tester,
      find.descendant(
        of: find.byType(BrowserPane),
        matching: find.byTooltip('Expand'),
      ),
    );
    expect(find.byType(FilesPane), findsNothing);
    c.openInFiles('main.go');
    await tester.pumpAndSettle();
    expect(find.byType(FilesPane), findsOneWidget);
    expect(find.byType(FileView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BrowserPane),
        matching: find.byTooltip('Collapse'),
      ),
      findsNothing,
    );
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('expanded with the sidebar hidden, Files starts past the '
      'title buttons', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      open: (
        side: false,
        files: true,
        subagent: false,
        command: false,
        previews: 1,
        browser: 0,
      ),
    );
    expect(sidebarShut, isTrue);
    await _tap(tester, _expand);
    final files = find.descendant(
      of: find.byType(FilesPane),
      matching: find.text('Files'),
    );
    // In the window: the pane starts a margin in, and its header past the
    // title buttons from there.
    expect(
      tester.getRect(files).left,
      greaterThanOrEqualTo(NushiTheme.windowPad + hiddenHeaderStart),
    );
    expect(tester.getRect(files).left, greaterThan(TitleButtons.right));
    await render(tester, find.byType(Pane), 'files_expanded_1700');
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('⌘W stays in the Files pane with the keys: blank, beside the '
      'browser or covering it, it closes none of its tabs', (tester) async {
    browserFakes();
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('package main\n'),
    }, width: 2400);
    final c = chatC(d)
      ..openBrowserTab('http://localhost:3000')
      ..openBrowserTab('http://localhost:3001')
      ..openInFiles('main.go');
    await tester.pumpAndSettle();
    final tabs = [...c.browser.tabs.value];
    // From the tree's filter: the file closes, then nothing.
    await _tap(
      tester,
      find.descendant(
        of: find.byType(FilesTree),
        matching: find.byType(EditableText),
      ),
    );
    await _close(tester);
    expect(c.files.tabs.value, isEmpty);
    expect(find.byType(FilesBlank), findsOneWidget);
    await _close(tester);
    expect(c.browser.tabs.value, tabs);
    expect(c.browser.shown.value, tabs.last);
    // Expanded over the browser, the pane has the keys: nothing closes,
    // and it stays expanded.
    await _tap(tester, _expand);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'files pane');
    await _close(tester);
    expect(c.browser.tabs.value, tabs);
    expect(_collapse, findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a browser tab closing while Files covers leaves it expanded', (
    tester,
  ) async {
    browserFakes();
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('package main\n'),
    }, width: 2400);
    final c = chatC(d)
      ..openBrowserTab('http://localhost:3000')
      ..openBrowserTab('http://localhost:3001')
      ..openInFiles('main.go');
    await tester.pumpAndSettle();
    await _tap(tester, _expand);
    c.browser.close(c.browser.shown.value!);
    await tester.pumpAndSettle();
    expect(_collapse, findsOneWidget);
    // A tab opened, though, puts it back.
    c.openBrowserTab('http://localhost:3002');
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('covering, it stays over a subagent’s pane opening, the tree '
      'moving sides or hiding, and goes with another chat; each way back '
      'puts it where it was', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 2400,
      open: (
        side: false,
        files: true,
        subagent: false,
        command: false,
        previews: 1,
        browser: 0,
      ),
    );
    final c = d.chats['c']!;
    final pane = find.byType(FilesPane);
    final beside = tester.getRect(pane);
    final tree = tester.getRect(find.byType(FilesTree));
    await _tap(tester, _expand);
    final all = tester.getRect(find.byType(Pane));
    expect(tester.getRect(pane), all);
    // A subagent's pane takes only the browser's place: Files still covers.
    c.pane.value = 'a';
    await tester.pumpAndSettle();
    expect(_collapse, findsOneWidget);
    expect(tester.getRect(pane), all);
    c.pane.value = null;
    await tester.pumpAndSettle();
    expect(tester.getRect(pane), all);
    // The tree to the left, and hidden: still covering.
    filesTreeSide.value = TreeSide.left;
    await tester.pumpAndSettle();
    expect(_collapse, findsOneWidget);
    expect(tester.getRect(find.byType(FilesTree)).left, all.left);
    filesTree.value = false;
    await tester.pumpAndSettle();
    expect(_collapse, findsOneWidget);
    expect(find.byType(FilesTree), findsNothing);
    filesTree.value = true;
    filesTreeSide.value = TreeSide.automatic;
    await tester.pumpAndSettle();
    await _tap(tester, _collapse);
    expect(tester.getRect(pane), beside);
    expect(tester.getRect(find.byType(FilesTree)), tree);
    // Another chat and back: beside, where it was.
    await _tap(tester, _expand);
    d.select('d');
    await tester.pumpAndSettle();
    d.select('c');
    await tester.pumpAndSettle();
    expect(_expand, findsOneWidget);
    expect(tester.getRect(pane), beside);
    expect(tester.getRect(find.byType(FilesTree)), tree);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Esc in the editor’s find bar closes the bar, not the cover; '
      'the next collapses it', (tester) async {
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('package main\n'),
    });
    final beside = tester.getRect(find.byType(FilesPane));
    await _tap(tester, _expand);
    await _tap(tester, find.byType(SourceEditor));
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    expect(find.byType(EditorFindBar), findsOneWidget);
    final bar = find.descendant(
      of: find.byType(EditorFindBar),
      matching: find.byType(EditableText),
    );
    expect(bar, findsOneWidget);
    await _esc(tester);
    expect(_collapse, findsOneWidget);
    expect(
      find.descendant(of: find.byType(EditorFindBar), matching: bar),
      findsNothing,
    );
    await _esc(tester);
    expect(_expand, findsOneWidget);
    expect(tester.getRect(find.byType(FilesPane)), beside);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('⌘F under an expanded pane leaves the hidden transcript’s '
      'find shut; collapsed, it opens', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      open: (
        side: false,
        files: true,
        subagent: false,
        command: false,
        previews: 1,
        browser: 0,
      ),
    );
    final c = d.chats['c']!;
    Future<void> find0() async {
      await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    }

    await _tap(tester, _expand);
    expect(c.covered, ChatPanes.files.name);
    await find0();
    expect(c.find.query, isNull);
    expect(_collapse, findsOneWidget);
    await _tap(tester, _collapse);
    expect(c.covered, isNull);
    expect(c.find.query, isNull, reason: 'no bar left open');
    await find0();
    expect(c.find.query, '');
    await closeView(tester, d);
  }, variant: onMac);
}
