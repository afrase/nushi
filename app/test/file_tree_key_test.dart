import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/source_editor.dart';

import 'browser_fixture.dart' show browserFakes;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'right_panes_fixture.dart';

// ⇧⌘Y (Ctrl+Shift+Y on Linux) hides and shows the Files pane's tree from
// wherever the keys are (ADR 0123): no field, list or editor keeps it,
// and it does nothing while the palette or a dialog is open.

/// ⇧⌘Y (Ctrl+Shift+Y on Linux).
Future<void> _treeKeys(WidgetTester tester) =>
    press(tester, LogicalKeyboardKey.keyY, cmd: true, shift: true);

/// The text field in [of].
Finder _field(Type of) => find
    .descendant(of: find.byType(of), matching: find.byType(EditableText))
    .first;

/// Gives the focus to the node called [label].
void _focusNamed(String label) => FocusManager.instance.rootScope.descendants
    .firstWhere((n) => n.debugLabel == label)
    .requestFocus();

/// ⇧⌘Y twice from what has the focus: the tree hides, then shows.
Future<void> _flips(WidgetTester tester, String where) async {
  expect(filesTree.value, isTrue, reason: where);
  await _treeKeys(tester);
  expect(filesTree.value, isFalse, reason: where);
  expect(find.byType(FilesTree), findsNothing, reason: where);
  await _treeKeys(tester);
  expect(filesTree.value, isTrue, reason: where);
  expect(find.byType(FilesTree), findsOneWidget, reason: where);
}

const PanesOpen _open = (
  side: true,
  files: true,
  subagent: false,
  command: false,
  previews: 1,
  browser: 1,
);

void main() {
  final spots = <(String, Future<void> Function(WidgetTester))>[
    ('the chat’s box', (_) async {}),
    ('the tree’s search field', (t) => t.tap(_field(FilesTree))),
    ('the tree', (_) async => _focusNamed('files')),
    ('the browser’s address', (t) => t.tap(_field(BrowserBar))),
    ('the side chat’s box', (t) => t.tap(_field(SideChat))),
  ];
  for (final (where, focus) in spots) {
    testWidgets('⇧⌘Y from $where', (tester) async {
      browserFakes();
      final (d, _) = await panesApp(tester, width: 2400, open: _open);
      await focus(tester);
      await tester.pumpAndSettle();
      await _flips(tester, where);
      await closeView(tester, d);
    }, variant: macAndLinux);
  }

  testWidgets('⇧⌘Y does nothing while the palette is open', (tester) async {
    browserFakes();
    final (d, _) = await panesApp(tester, width: 2400, open: _open);
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(find.byType(Palette), findsOneWidget);
    await _treeKeys(tester);
    expect(filesTree.value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Palette), findsNothing);
    await closeView(tester, d);
  }, variant: macAndLinux);

  // The editor and its find bar, and a dialog: the Mac's app (the editor's
  // harness builds the Mac's menu bar).
  testWidgets('⇧⌘Y from the editor and its find bar; nothing under Go to '
      'file’s box', (tester) async {
    final (d, _) = await openEditor(tester, {
      'main.go': utf8.encode('package main\n'),
    });
    await tester.tap(find.byType(SourceEditor));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    await _flips(tester, 'the editor');
    // Its find bar: the tree hides and shows, the bar stays open.
    await tester.tap(find.byType(SourceEditor));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    final find0 = FocusManager.instance.primaryFocus;
    expect(
      find0?.context?.findAncestorWidgetOfExactType<SourceEditor>(),
      isNotNull,
    );
    await _flips(tester, 'the editor’s find bar');
    // Go to file's box (⌘P), a dialog: nothing.
    await press(tester, LogicalKeyboardKey.keyP, cmd: true);
    expect(find.byType(OpenFileBox), findsOneWidget);
    await _treeKeys(tester);
    expect(filesTree.value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(OpenFileBox), findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);
}
