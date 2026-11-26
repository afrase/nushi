import 'package:flutter/gestures.dart' show kDoubleTapSlop, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/files_top_row.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pane_tabs.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tree_rows.dart';

import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'right_panes_fixture.dart';

// Preview tabs (ADR 0070), as Claude desktop's and VS Code's: a click in
// the Files pane's tree opens a provisional tab, in italics, which the
// next click's file takes the place of until it's kept.

const PanesOpen _files = (
  side: false,
  files: true,
  subagent: false,
  command: false,
  previews: 0,
  browser: 0,
);

/// The tree's row of [path].
Finder _row(String path) =>
    find.byWidgetPredicate((w) => w is TreeRowView && w.row.path == path);

/// [name] in the Files pane's top row (the one file's name, or a tab).
Finder _top(String name) =>
    find.descendant(of: find.byType(FilesTopRow), matching: find.text(name));

bool _italic(WidgetTester tester, String name) =>
    tester.widget<Text>(_top(name)).style?.fontStyle == FontStyle.italic;

/// The names in italics in the Files pane's top row.
List<String> _italics(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byType(FilesTopRow), matching: find.byType(Text)),
  ))
    if (t.style?.fontStyle == FontStyle.italic) t.data ?? '',
];

/// Clicks twice on [f], [apart].
Future<void> _twice(WidgetTester tester, Finder f, Duration apart) async {
  await tester.tap(f);
  await tester.pump(apart);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

const _quick = Duration(milliseconds: 200);
final Duration _slow = kDoubleTapTimeout + const Duration(milliseconds: 50);

/// The app with Files open and its auth folder open: README.md and
/// auth/README.md to click.
Future<void> _tree(WidgetTester tester) async {
  await tester.tap(_row('auth'));
  await tester.pumpAndSettle();
  expect(_row('auth/README.md'), findsOneWidget);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a click opens an italic tab the next click’s file takes the '
      'place of, at once: nothing waits for a second click', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    final c = d.chats['c']!;
    await _tree(tester);
    await tester.tap(_row('README.md'));
    await tester.pump();
    expect(c.shownFile, 'README.md', reason: 'shown with no wait');
    await tester.pumpAndSettle();
    expect(_italic(tester, 'README.md'), isTrue);
    // Tree rows aren't italic.
    expect(
      tester
          .widget<Text>(
            find.descendant(of: _row('README.md'), matching: find.byType(Text)),
          )
          .style
          ?.fontStyle,
      isNot(FontStyle.italic),
    );
    await tester.pump(_slow);
    await tester.tap(_row('auth/README.md'));
    await tester.pumpAndSettle();
    expect(c.files.tabs.value, const [PreviewFile('auth/README.md')]);
    expect(c.files.provisional.value, const PreviewFile('auth/README.md'));
    expect(_italic(tester, 'README.md'), isTrue);
    await render(tester, find.byType(NushiApp), 'files_preview_tab');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a double click in the tree keeps the tab; two slow clicks, '
      'or quick ones on two rows, don’t', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    final c = d.chats['c']!;
    await _tree(tester);
    await _twice(tester, _row('README.md'), _slow);
    expect(c.files.provisional.value, const PreviewFile('README.md'));
    await tester.pump(_slow);

    await tester.tap(_row('auth/README.md'));
    await tester.pump(_quick);
    await tester.tap(_row('README.md'));
    await tester.pumpAndSettle();
    expect(c.files.provisional.value, const PreviewFile('README.md'));
    expect(c.files.tabs.value, hasLength(1));
    await tester.pump(_slow);

    await _twice(tester, _row('README.md'), _quick);
    expect(c.files.provisional.value, isNull);
    expect(_italic(tester, 'README.md'), isFalse);
    await tester.pump(_slow);
    await tester.tap(_row('auth/README.md'));
    await tester.pumpAndSettle();
    expect(c.files.tabs.value, const [
      PreviewFile('README.md'),
      PreviewFile('auth/README.md'),
    ]);
    // Measured in italics too: its name isn't cut with room to spare.
    expect(find.byType(PaneTabs), findsOneWidget);
    // The provisional tab is auth's: its folder before its name, both in
    // italics, whole.
    expect(_italics(tester), ['auth/', 'README.md']);
    await render(tester, find.byType(NushiApp), 'files_preview_tabs');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a double click on its tab or its name keeps it; so do ⏎ in '
      'the tree, any other way of opening it, and a pin', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    // The one file's name.
    final c = d.chats['c']!..openInFiles('PLAN.md', keep: false);
    await tester.pumpAndSettle();
    await _twice(tester, _top('PLAN.md'), _quick);
    expect(c.files.provisional.value, isNull);

    // A tab.
    c.openInFiles('NOTES.md', keep: false);
    await tester.pumpAndSettle();
    expect(find.byType(PaneTabs), findsOneWidget);
    await tester.pump(_slow);
    await _twice(tester, _top('NOTES.md'), _quick);
    expect(c.files.provisional.value, isNull);

    // ⏎ on its row.
    await tester.pump(_slow);
    await tester.tap(_row('README.md'));
    await tester.pumpAndSettle();
    expect(c.files.provisional.value, const PreviewFile('README.md'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(c.files.provisional.value, isNull);

    // Another way of opening it (the conversation, ⌘P, the agent).
    c
      ..openInFiles('a.md', keep: false)
      ..openInFiles('./a.md');
    expect(c.files.provisional.value, isNull);

    // A pin.
    c.openInFiles('b.md', keep: false);
    togglePin(c, 'b.md');
    expect(c.files.provisional.value, isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('one click on its tab shows it and leaves it provisional, '
      'so the next click in the tree takes its place', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    final c = d.chats['c']!
      ..openInFiles('PLAN.md')
      ..openInFiles('NOTES.md', keep: false);
    await tester.pumpAndSettle();
    const notes = PreviewFile('NOTES.md');
    // Another tab, then back to it: a click on each, well apart.
    await tester.tap(_top('PLAN.md'));
    await tester.pump(_slow);
    expect(c.files.shown.value, const PreviewFile('PLAN.md'));
    await tester.tap(_top('NOTES.md'));
    await tester.pump(_slow);
    expect(c.files.shown.value, notes);
    expect(c.files.provisional.value, notes);
    expect(_italic(tester, 'NOTES.md'), isTrue);
    // A click on it as it shows.
    await tester.tap(_top('NOTES.md'));
    await tester.pump(_slow);
    expect(c.files.provisional.value, notes);
    // The tree's next click takes its place.
    await tester.tap(_row('README.md'));
    await tester.pumpAndSettle();
    expect(c.files.tabs.value, const [
      PreviewFile('PLAN.md'),
      PreviewFile('README.md'),
    ]);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('the lone name’s first click shows it in the tree, as a '
      'single click does, and leaves it provisional; the second keeps it', (
    tester,
  ) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    final c = d.chats['c']!..openInFiles('README.md', keep: false);
    await tester.pumpAndSettle();
    final tree = folderTreeOf(c)..select('auth');
    await tester.tap(_top('README.md'));
    await tester.pump(_quick);
    expect(tree.selected, 'README.md');
    expect(c.files.provisional.value, const PreviewFile('README.md'));
    await tester.tap(_top('README.md'));
    await tester.pumpAndSettle();
    expect(c.files.provisional.value, isNull);
    expect(tree.selected, 'README.md');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('two quick clicks further apart than a double click’s slop '
      'are two clicks: the tab stays provisional', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    final c = d.chats['c']!;
    await _tree(tester);
    final row = tester.getRect(_row('README.md'));
    expect(row.width - 20, greaterThan(kDoubleTapSlop));
    await tester.tapAt(row.centerLeft + const Offset(10, 0));
    await tester.pump(_quick);
    await tester.tapAt(row.centerRight - const Offset(10, 0));
    await tester.pumpAndSettle();
    expect(c.files.provisional.value, const PreviewFile('README.md'));
    // Within the slop, it's a double click.
    await tester.pump(_slow);
    await tester.tapAt(row.center);
    await tester.pump(_quick);
    await tester.tapAt(row.center + const Offset(4, 0));
    await tester.pumpAndSettle();
    expect(c.files.provisional.value, isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('with Preview tabs off, every click keeps its tab', (
    tester,
  ) async {
    previewTabs.value = false;
    final (d, _) = await panesApp(
      tester,
      width: 1700,
      details: false,
      open: _files,
    );
    final c = d.chats['c']!;
    await _tree(tester);
    await tester.tap(_row('README.md'));
    await tester.pump(_slow);
    await tester.tap(_row('auth/README.md'));
    await tester.pumpAndSettle();
    expect(c.files.tabs.value, hasLength(2));
    expect(c.files.provisional.value, isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('an edit keeps it: its first unsaved change', (tester) async {
    final (d, _) = await openEditor(tester, {
      'main.go': goSource.codeUnits,
      'b.go': goSource.codeUnits,
    }, open: const []);
    final c = chatC(d)..openInFiles('main.go', keep: false);
    await tester.pumpAndSettle();
    expect(c.files.provisional.value, const PreviewFile('main.go'));
    await typeIn(tester, editOf(d), 'x');
    expect(c.files.provisional.value, isNull);
    c.openInFiles('b.go', keep: false);
    await tester.pumpAndSettle();
    expect(c.files.tabs.value, hasLength(2), reason: 'not in its place');
    await endEditor(tester, d);
  }, variant: onMac);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a provisional tab among kept ones, $name', (tester) async {
      final (d, _) = await panesApp(tester, width: 1700);
      final c = d.chats['c']!
        ..openInFiles('PLAN.md')
        ..openInFiles('auth/redirect.go')
        ..openInFiles('NOTES.md', keep: false);
      viewport(tester, const Size(640, 200));
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 200,
              child: FilesPane(chat: c, daemon: d, onClose: () {}),
            ),
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(FilesPane),
        matchesGoldenFile('goldens/files_preview_tabs_$name.png'),
      );
      await closeView(tester, d);
    }, variant: onMac);
  }
}
