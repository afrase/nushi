import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_bar.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/files_top_row.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tree_rows.dart';

import 'browser_fixture.dart' show browserFakes;
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'right_panes_fixture.dart';

// The Files pane's second row (ADR 0123), as Claude desktop's: Collapse
// all folders, the tree's button (⇧⌘Y) and the ⋯, at its right end.

bool get _linux => defaultTargetPlatform == TargetPlatform.linux;

const PanesOpen _files = (
  side: false,
  files: true,
  subagent: false,
  command: false,
  previews: 0,
  browser: 0,
);

Finder _inBar(Finder f) =>
    find.descendant(of: find.byType(FilesBar), matching: f);

Finder _line(LineIcon icon) =>
    _inBar(find.byWidgetPredicate((w) => w is IconTap && w.line == icon));

Finder get _treeButton => _line(LineIcon.fileTree);
Finder get _collapse => _line(LineIcon.collapseAll);
Finder get _more => _inBar(find.byTooltip('More'));

IconTap _button(WidgetTester tester, Finder f) => tester.widget<IconTap>(f);

String get _treeKey => _linux ? 'Ctrl+Shift+Y' : '⇧⌘Y';

/// ⇧⌘Y (Ctrl+Shift+Y on Linux).
Future<void> _treeKeys(WidgetTester tester) =>
    press(tester, LogicalKeyboardKey.keyY, cmd: true, shift: true);

/// The View menu's items, flattened; picks the one called [pick].
List<String> _viewMenu(WidgetTester tester, {String? pick}) {
  final all = viewItems(tester);
  if (pick != null) all.firstWhere((m) => m.label == pick).onSelected!();
  return [for (final m in all) m.label];
}

AppAction _palette(WidgetTester tester, Daemon d, Act act) => appActions(
  tester.element(find.byType(ChatHeader)),
  d,
).firstWhere((a) => a.act == act);

/// The top of [e]'s box, in the window.
double _top(Element e) =>
    (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;

/// The open menu's rows, top to bottom: each row's label, '—' for a line.
List<String> _menuRows(WidgetTester tester) {
  final rows = <(double, String)>[
    for (final e
        in find
            .byWidgetPredicate((w) => w is MenuItemButton || w is SubmenuButton)
            .evaluate())
      (
        _top(e),
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byElementPredicate((x) => x == e),
                matching: find.byType(Text),
              ),
            )
            .first
            .textSpan!
            .toPlainText(),
      ),
    for (final e in find.byType(Divider).evaluate()) (_top(e), '—'),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final r in rows) r.$2];
}

Finder _menuRow(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton));

bool _checked(String label) => find
    .descendant(of: _menuRow(label), matching: find.byIcon(Icons.check))
    .evaluate()
    .isNotEmpty;

void main() {
  setUpAll(loadFonts);

  testWidgets('the tree’s button hides the tree and shows it, lit while it '
      'shows, its tooltip saying so; the viewer takes its room and nothing '
      'else moves', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    expect(filesTree.value, isTrue, reason: 'on at first');
    expect(find.byType(FilesTree), findsOneWidget);
    expect(_button(tester, _treeButton).lit, isTrue);
    expect(find.byTooltip('Hide file tree $_treeKey'), findsOneWidget);
    final pane = tester.getRect(find.byType(FilesPane));
    final buttons = [
      for (final f in [_collapse, _treeButton, _more]) tester.getRect(f),
    ];
    // At the pane's right end, 8 in, the tree's under Expand, the ⋯
    // under ×.
    expect(buttons.last.right, pane.right - PaneEndButtons.inset);
    expect(buttons[0].right, buttons[1].left);
    expect(buttons[1].right, buttons[2].left);
    expect(tester.getRect(find.byTooltip('Expand')).left, buttons[1].left);

    await tester.tap(_treeButton);
    await tester.pumpAndSettle();
    expect(filesTree.value, isFalse);
    expect(readSaved()['filesTree'], isFalse);
    expect(find.byType(FilesTree), findsNothing);
    expect(_button(tester, _treeButton).lit, isFalse);
    expect(find.byTooltip('Show file tree $_treeKey'), findsOneWidget);
    expect(tester.getRect(find.byType(FilesPane)), pane);
    expect([
      for (final f in [_collapse, _treeButton, _more]) tester.getRect(f),
    ], buttons);
    // The blank viewer points at the way that's there.
    final go = _linux ? 'Ctrl+P' : '⌘P';
    expect(
      find.text(
        'Go to a file with $go, or click a file path in the '
        'conversation',
      ),
      findsOneWidget,
    );
    expect(tester.getRect(find.byType(FilesBlank)).width, pane.width);
    await render(tester, find.byType(NushiApp), 'files_tree_hidden');

    await tester.tap(_treeButton);
    await tester.pumpAndSettle();
    expect(filesTree.value, isTrue);
    expect(find.byType(FilesTree), findsOneWidget);
    expect(tester.getRect(find.byType(FilesPane)), pane);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('⇧⌘Y, the ⋯, View › Show File Tree and the palette show and '
      'hide it in step with the button', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    Future<void> expectShown({required bool shown}) async {
      expect(filesTree.value, shown);
      expect(find.byType(FilesTree), shown ? findsOneWidget : findsNothing);
      expect(_button(tester, _treeButton).lit, shown);
      expect(
        _palette(tester, d, Act.fileTree).title,
        shown ? 'Hide the file tree' : 'Show the file tree',
      );
      if (!_linux) {
        expect(
          _viewMenu(tester),
          contains(shown ? 'Hide File Tree' : 'Show File Tree'),
        );
      }
      await tester.tap(_more);
      await tester.pumpAndSettle();
      expect(_checked('Show file tree'), shown);
      await tester.tap(_more); // closes it
      await tester.pumpAndSettle();
      expect(find.text('Show file tree'), findsNothing);
    }

    await _treeKeys(tester);
    await expectShown(shown: false);
    await _treeKeys(tester);
    await expectShown(shown: true);

    await tester.tap(_more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show file tree'));
    await tester.pumpAndSettle();
    await expectShown(shown: false);

    runAct(tester.element(find.byType(ChatHeader)), d, Act.fileTree);
    await tester.pumpAndSettle();
    await expectShown(shown: true);

    if (!_linux) {
      _viewMenu(tester, pick: 'Hide File Tree');
      await tester.pumpAndSettle();
      await expectShown(shown: false);
      // The item has the key, so it comes while WebKit has the keys too.
      final view = tester
          .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
          .menus
          .whereType<PlatformMenu>()
          .firstWhere((m) => m.label == 'View');
      final item = view.menus
          .expand((m) => m is PlatformMenuItemGroup ? m.members : [m])
          .firstWhere((m) => m.label == 'Show File Tree');
      expect(item.shortcut, fileTreeKey);
    }
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('on Changes with Files open, View and the palette both say '
      'Show, picking it shows the tree on the Chat tab, and the label '
      'follows the tab', (tester) async {
    final (d, _) = await panesApp(tester, width: 1700, open: _files);
    final c = d.chats['c']!..tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    expect(filesTree.value, isTrue);
    expect(_viewMenu(tester), contains('Show File Tree'));
    expect(_palette(tester, d, Act.fileTree).title, 'Show the file tree');
    _viewMenu(tester, pick: 'Show File Tree');
    await tester.pumpAndSettle();
    expect(c.tab.value, ChatTab.chat);
    expect(filesTree.value, isTrue);
    expect(find.byType(FilesTree), findsOneWidget);
    // No pref changed on the way: the menu followed the tab.
    expect(_viewMenu(tester), contains('Hide File Tree'));
    expect(_palette(tester, d, Act.fileTree).title, 'Hide the file tree');
    c.tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    expect(_viewMenu(tester), contains('Show File Tree'));
    await closeView(tester, d);
  }, variant: onMac);

  for (final was in [true, false]) {
    testWidgets('with Files closed, ⇧⌘Y opens it with its tree, from the '
        'Changes tab too, the tree’s pref $was before', (tester) async {
      final (d, _) = await panesApp(tester, width: 1700, details: false);
      final c = d.chats['c']!;
      filesTree.value = was;
      c.tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      await _treeKeys(tester);
      expect(c.tab.value, ChatTab.chat);
      expect(filesChats.value, {'c'});
      // Set on, not flipped: on before, it stays on.
      expect(filesTree.value, isTrue);
      expect(readSaved()['filesTree'], isTrue);
      expect(find.byType(FilesTree), findsOneWidget);
      await closeView(tester, d);
    }, variant: macAndLinux);
  }

  testWidgets('hiding the tree lets Files come beside a window too narrow '
      'for it with its tree', (tester) async {
    // A 700 wide: Files is beside from 860 with its tree, 660 without.
    final (d, _) = await panesApp(
      tester,
      width: windowFor(700, sidebar: false),
      details: false,
      open: _files,
    );
    final header = find.byType(ChatHeader);
    final pane = find.byType(FilesPane);
    expect(tester.getRect(pane).left, lessThan(tester.getRect(header).right));
    await tester.tap(_treeButton);
    await tester.pumpAndSettle();
    expect(tester.getRect(pane).left, tester.getRect(header).right);
    expect(tester.takeException(), isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('beside the browser, hiding the tree moves their boundary: '
      'Files narrows to its least without the tree and the browser takes '
      'the room back', (tester) async {
    // A 1300: 940 for the panes beside the transcript's least. With the
    // tree Files gives 320 of its 820 down to its 500, then the browser
    // 120 of its 560; without, Files gives all 440, to 380 (its least is
    // 300).
    browserFakes();
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1300, sidebar: false),
      details: false,
      open: (
        side: false,
        files: true,
        subagent: false,
        command: false,
        previews: 1,
        browser: 1,
      ),
    );
    final files = find.byType(FilesPane);
    final browser = find.byType(BrowserPane);
    expect(tester.getRect(files).width, 500);
    expect(tester.getRect(browser).width, 440);
    final right = tester.getRect(browser).right;
    filesTree.value = false;
    await tester.pumpAndSettle();
    expect(tester.getRect(files).width, 380);
    expect(tester.getRect(browser).width, 560);
    expect(tester.getRect(files).right, tester.getRect(browser).left);
    expect(tester.getRect(browser).right, right);
    filesTree.value = true;
    await tester.pumpAndSettle();
    expect(tester.getRect(files).width, 500);
    expect(tester.getRect(browser).width, 440);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Collapse all folders closes every folder at once and ends '
      'their watches; it is off with none open in the ⋯ and the palette, '
      'and View’s item, built ahead, does nothing then', (tester) async {
    final cancels = <String>[];
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
      folderCancels: cancels,
    );
    final tree = folderTreeOf(d.chats['c']!);
    expect(_button(tester, _collapse).onTap, isNull);
    expect(_palette(tester, d, Act.collapseFolders).enabled, isFalse);
    // The menu bar isn't rebuilt as folders open: its item stays on, and
    // picking it with none open does nothing (runAct skips it).
    _viewMenu(tester, pick: 'Collapse All Folders');
    await tester.pumpAndSettle();
    expect(tree.open, isEmpty);

    await tester.tap(find.text('auth'));
    await tester.pumpAndSettle();
    // Its listing has an auth folder in it too: opened as well.
    await tester.tap(
      find
          .descendant(of: find.byType(TreeRowView), matching: find.text('auth'))
          .last,
    );
    await tester.pumpAndSettle();
    expect(tree.open, {'auth', 'auth/auth'});
    expect(find.text('README.md'), findsNWidgets(3));
    expect(_button(tester, _collapse).onTap, isNotNull);
    expect(_palette(tester, d, Act.collapseFolders).enabled, isTrue);
    await tester.tap(_more);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MenuItemButton>(_menuRow('Collapse all folders')).onPressed,
      isNotNull,
    );
    await tester.tap(_more);
    await tester.pumpAndSettle();

    var told = 0;
    tree.addListener(() => told++);
    expect(cancels, isEmpty);
    await tester.tap(_collapse);
    await tester.pumpAndSettle();
    expect(told, 1);
    expect(tree.open, isEmpty);
    // Closed, their listings are no longer watched; the top level still is.
    expect(cancels, unorderedEquals(['auth', 'auth/auth']));
    expect(tree.selected, 'auth', reason: 'the top folder that held it');
    expect(find.text('README.md'), findsOneWidget);
    expect(_button(tester, _collapse).onTap, isNull);
    expect(_palette(tester, d, Act.collapseFolders).enabled, isFalse);

    // With the tree hidden there's nothing to collapse.
    tree.setOpen('auth', open: true);
    filesTree.value = false;
    await tester.pumpAndSettle();
    expect(_button(tester, _collapse).onTap, isNull);
    expect(_palette(tester, d, Act.collapseFolders).enabled, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⋯: Claude desktop’s rows, its order and lines, its checks and '
      'keys', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    await tester.tap(_more);
    await tester.pumpAndSettle();
    expect(_menuRows(tester), [
      'Go to file or search',
      '—',
      'Show file tree',
      'File tree position',
      '—',
      'Collapse all folders',
      '—',
      'Preview tabs',
      '—',
      'Word wrap',
      'Indent guides',
      'Show whitespace',
      'Scroll past end',
      'Tab size',
    ]);
    expect(_checked('Show file tree'), isTrue);
    expect(_checked('Preview tabs'), isTrue);
    expect(_checked('Word wrap'), isTrue);
    expect(_checked('Indent guides'), isTrue);
    expect(_checked('Show whitespace'), isFalse);
    expect(_checked('Scroll past end'), isFalse);
    expect(
      tester.widget<MenuItemButton>(_menuRow('Collapse all folders')).onPressed,
      isNull,
    );
    final go = _linux ? 'Ctrl+P' : '⌘P';
    expect(
      find.descendant(
        of: _menuRow('Go to file or search'),
        matching: find.text(go, findRichText: true),
      ),
      findsOneWidget,
    );
    // Show file tree's check before its key, the key at the row's end;
    // a row without a key has its check there.
    final key = find.descendant(
      of: _menuRow('Show file tree'),
      matching: find.text(_treeKey, findRichText: true),
    );
    final check = find.descendant(
      of: _menuRow('Show file tree'),
      matching: find.byIcon(Icons.check),
    );
    final wrap = find.descendant(
      of: _menuRow('Word wrap'),
      matching: find.byIcon(Icons.check),
    );
    expect(tester.getRect(check).right, lessThan(tester.getRect(key).left));
    expect(tester.getRect(check).left, lessThan(tester.getRect(wrap).left));
    expect(
      tester.getRect(key).right,
      moreOrLessEquals(tester.getRect(wrap).right, epsilon: 4),
    );

    await tester.tap(find.text('Show whitespace'));
    await tester.pumpAndSettle();
    expect(showWhitespace.value, isTrue);
    await tester.tap(_more);
    await tester.pumpAndSettle();
    expect(_checked('Show whitespace'), isTrue);
    await render(tester, find.byType(NushiApp), 'files_menu');
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('with the tree hidden, a click on the file’s name shows the '
      'tree on it', (tester) async {
    final (d, _) = await panesApp(tester, width: 1700, open: _files);
    filesTree.value = false;
    final c = d.chats['c']!..openInFiles('README.md');
    await tester.pumpAndSettle();
    expect(find.byType(FilesTree), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(FilesTopRow),
        matching: find.text('README.md'),
      ),
    );
    await tester.pumpAndSettle();
    expect(filesTree.value, isTrue);
    expect(find.byType(FilesTree), findsOneWidget);
    expect(folderTreeOf(c).selected, 'README.md');
    await closeView(tester, d);
  }, variant: macAndLinux);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the ⋯ open over the pane, $name', (tester) async {
      final (d, _) = await panesApp(tester, width: 1700);
      viewport(tester, const Size(560, 500));
      final c = d.chats['c']!;
      filesChats.value = {'c'};
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 520,
              height: 500,
              child: FilesPane(chat: c, daemon: d, onClose: () {}),
            ),
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_more);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/files_menu_$name.png'),
      );
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('the second row’s icons, 2×, $name', (tester) async {
      viewport(tester, const Size(220, 44), ratio: 2);
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          Center(
            child: RepaintBoundary(
              key: const ValueKey('icons'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (icon, lit, on) in [
                    (LineIcon.collapseAll, false, true),
                    (LineIcon.collapseAll, false, false),
                    (LineIcon.fileTree, true, true),
                    (LineIcon.fileTree, false, true),
                    (LineIcon.more, false, true),
                  ])
                    IconTap.line(
                      icon,
                      tooltip: '',
                      size: 18,
                      padding: 7,
                      color: tokens.text,
                      lit: lit,
                      onTap: on ? () {} : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('icons')),
        matchesGoldenFile('goldens/files_icons_$name.png'),
      );
    }, variant: onMac);
  }
}
