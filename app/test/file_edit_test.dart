import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/main.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/source_editor.dart';
import 'package:re_editor/re_editor.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('a click and typing edit; ⌘S writes the bytes over the base', (
    tester,
  ) async {
    // A BOM, CRLF and no final newline, all kept.
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('a\r\nb')];
    final (d, fake) = await openEditor(tester, {'main.go': bytes});
    expect(find.byType(SourceEditor), findsOneWidget);
    final e = editOf(d);
    expect(e.text, 'a\nb');
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    expect(unsavedDot, findsNothing);
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 1,
      offset: 1,
    );
    await typeIn(tester, e, '2');
    expect(e.unsaved, isTrue);
    expect(unsavedDot, findsOneWidget);
    await cmd(tester, LogicalKeyboardKey.keyS);
    expect(fake.writes, hasLength(1));
    expect(fake.writes.single.baseSha256, sumOf(bytes));
    expect(fake.writes.single.data, [
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('a\r\nb2'),
    ]);
    expect(e.unsaved, isFalse);
    expect(unsavedDot, findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets(
    'the focus leaving for the prompt box saves; a palette, a menu and a '
    'selection in the transcript don’t',
    (tester) async {
      final (d, fake) = await openEditor(tester, {
        'main.go': utf8.encode(goSource),
      });
      final e = editOf(d);
      await tester.tap(find.byType(CodeEditor));
      await tester.pump();
      e.controller.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 0,
      );
      await typeIn(tester, e, '// ');
      // The palette, then Esc: back to the editor, nothing saved.
      unawaited(showPalette(tester.element(find.byType(CodeEditor)), d));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('editor'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(fake.writes, isEmpty);
      // The chat's menu, opened and shut: nothing saved.
      await tester.tap(find.byTooltip('Chat menu'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(fake.writes, isEmpty);
      // A selection in the transcript.
      await tester.tap(find.byType(CodeEditor));
      await tester.pump();
      final message = find.text('I tidied the parser in main.go.');
      await tester.longPress(message);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('editor'));
      expect(fake.writes, isEmpty);
      // The prompt box saves.
      await tester.tap(find.byType(EditableText).first);
      await tester.pumpAndSettle();
      expect(fake.writes, hasLength(1));
      expect(utf8.decode(fake.writes.single.data), '// $goSource');
      await endEditor(tester, d);
    },
    variant: onMac,
  );

  testWidgets('focus passing through a menu waits for where it goes', (
    tester,
  ) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(goSource)});
    final route = ModalRoute.of(tester.element(find.byType(CodeEditor)));
    expect(passing(null, route), isTrue);
    final scope = FocusScopeNode();
    addTearDown(scope.dispose);
    expect(passing(scope, route), isTrue);
    final composer = find.byType(EditableText).first;
    final node = tester.state<EditableTextState>(composer).widget.focusNode;
    expect(passing(node, route), isFalse);
    await endEditor(tester, d);
    // A long menu's filter, and a numbered menu's own focus.
    for (final digits in [false, true]) {
      await tester.pumpWidget(
        themed(
          Menu(
            digits: digits,
            entries: [
              for (var i = 0; i < 12; i++) MenuEntry('Row $i', onPick: () {}),
            ],
            builder: (context, open) =>
                Button(label: 'Open', onPressed: () => open()),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final f = digits
          ? tester
                .widget<Focus>(
                  find
                      .descendant(
                        of: find.byType(Menu),
                        matching: find.byType(Focus),
                      )
                      .first,
                )
                .focusNode!
          : tester
                .state<EditableTextState>(find.byType(EditableText))
                .widget
                .focusNode;
      expect(f, isNot(isA<FocusScopeNode>()));
      expect(passing(f, ModalRoute.of(f.context!)), isTrue);
    }
  }, variant: onMac);

  testWidgets('a change on disk: taken when clean, merged into unsaved edits '
      '(with a note), undo cleared after each', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    // Clean: taken as it is, the cursor kept, no undo past it.
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 2,
      offset: 4,
    );
    fake.putFile('main.go', utf8.encode(goSource.replaceAll('hi', 'hello')));
    await tester.pumpAndSettle();
    expect(e.text, contains('hello'));
    expect(e.unsaved, isFalse);
    expect(e.controller.selection.extentIndex, 2);
    expect(e.controller.canUndo, isFalse);
    // Unsaved, a change elsewhere: merged in, still unsaved.
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 0,
    );
    await typeIn(tester, e, '// top\n');
    expect(e.controller.canUndo, isTrue);
    fake.putFile(
      'main.go',
      utf8.encode('${goSource.replaceAll('hi', 'hello')}// end\n'),
    );
    await tester.pumpAndSettle();
    expect(e.text, startsWith('// top\npackage main'));
    expect(e.text, endsWith('}\n// end\n'));
    expect(e.unsaved, isTrue);
    expect(e.controller.canUndo, isFalse);
    expect(find.text('Merged a change from disk'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Merged a change from disk'), findsNothing);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('overlapping changes: the conflict bar’s three ways out', (
    tester,
  ) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    Future<void> conflict(String theirs) async {
      e.controller.selection = const CodeLineSelection.collapsed(
        index: 3,
        offset: 1,
      );
      await typeIn(tester, e, 'x');
      fake.putFile(
        'main.go',
        utf8.encode(goSource.replaceAll('println', theirs)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Changed on disk'), findsOneWidget);
      expect(e.theirs, isNotNull);
    }

    await conflict('fmt.Println');
    // Nothing saves meanwhile.
    await cmd(tester, LogicalKeyboardKey.keyS);
    expect(fake.writes, isEmpty);
    // Compare: the disk against the edits, in a dialog.
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.textContaining('on disk · yours'), findsOneWidget);
    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();
    // Overwrite with mine: over the version shown.
    final shown = fake.files['main.go']!;
    await tester.tap(find.text('Overwrite with mine'));
    await tester.pumpAndSettle();
    expect(fake.writes.single.baseSha256, sumOf(shown));
    expect(utf8.decode(fake.files['main.go']!), contains('xprintln'));
    expect(find.text('Changed on disk'), findsNothing);
    // Use theirs: the disk's text, nothing written, no undo back.
    await conflict('log.Print');
    await tester.tap(find.text('Use theirs'));
    await tester.pumpAndSettle();
    expect(e.text, utf8.decode(fake.files['main.go']!));
    expect(e.unsaved, isFalse);
    expect(e.controller.canUndo, isFalse);
    expect(fake.writes, hasLength(1));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets(
    'a watch message from before a save is ignored until another comes; '
    'then that sum is a real change (an agent’s revert)',
    (tester) async {
      final (d, fake) = await openEditor(tester, {
        'main.go': utf8.encode(goSource),
      });
      final e = editOf(d);
      final before = fake.fileNow('main.go');
      await typeIn(tester, e, '// mine\n');
      expect(await e.save(), isTrue);
      await tester.pumpAndSettle();
      fake.sendWatch('main.go', before);
      await tester.pumpAndSettle();
      expect(e.text, startsWith('// mine\n'));
      expect(e.theirs, isNull);
      // The save's own version, then the agent puts the old text back.
      fake.sendWatch('main.go', fake.fileNow('main.go'));
      await tester.pumpAndSettle();
      fake.putFile('main.go', utf8.encode(goSource));
      await tester.pumpAndSettle();
      expect(e.text, goSource);
      expect(e.unsaved, isFalse);
      await endEditor(tester, d);
    },
    variant: onMac,
  );

  testWidgets('deleted on disk with unsaved edits: Save writes it again', (
    tester,
  ) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    fake.putFile('main.go', null);
    await tester.pumpAndSettle();
    expect(find.text('Deleted on disk'), findsOneWidget);
    expect(find.byType(SourceEditor), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.writes.single.mustNotExist, isTrue);
    expect(utf8.decode(fake.files['main.go']!), '// mine\n$goSource');
    expect(find.text('Deleted on disk'), findsNothing);
    // Clean and gone: the preview says so, as before.
    fake.putFile('main.go', null);
    await tester.pumpAndSettle();
    expect(find.text('The file isn’t there (yet).'), findsOneWidget);
    expect(chatC(d).edits, isEmpty);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('closing edits that can’t be saved asks: Cancel keeps them', (
    tester,
  ) async {
    final (d, fake) = await openEditor(
      tester,
      {'main.go': utf8.encode(goSource), 'b.go': utf8.encode('package b\n')},
      open: ['main.go', 'b.go', 'main.go'],
    );
    final e = editOf(d);
    await typeIn(tester, e, 'x');
    fake.putFile('main.go', utf8.encode('x$goSource'.replaceAll('x', 'y')));
    await tester.pumpAndSettle();
    expect(e.theirs, isNotNull);
    expect(unsavedDot, findsOneWidget);
    // The pane's Close: asked, Cancel keeps the tabs and the text.
    await tester.tap(find.byTooltip('Close').first);
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes to main.go?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(chatC(d).previewNames, ['main.go', 'b.go']);
    expect(chatC(d).edits['main.go'], same(e));
    // ⌘W asks too; Discard closes the tab.
    await cmd(tester, LogicalKeyboardKey.keyW);
    expect(find.text('Discard your changes to main.go?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(chatC(d).previewNames, ['b.go']);
    expect(chatC(d).edits.containsKey('main.go'), isFalse);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets(
    'a failed save says so; discarded, the text is never written after',
    (tester) async {
      final (d, fake) = await openEditor(
        tester,
        {'main.go': utf8.encode(goSource), 'b.go': utf8.encode('package b\n')},
        open: ['b.go', 'main.go'],
      );
      final e = editOf(d);
      await typeIn(tester, e, '// mine\n');
      fake.down = true;
      await cmd(tester, LogicalKeyboardKey.keyS);
      expect(find.textContaining('Couldn’t save'), findsOneWidget);
      // Its tab's ✕ is a dot until hovered: ⌘W.
      expect(find.byTooltip('Unsaved'), findsOneWidget);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(
          find.descendant(
            of: find.byType(PreviewTabs),
            matching: find.text('main.go'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unsaved'), findsNothing);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await cmd(tester, LogicalKeyboardKey.keyW);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      fake.down = false;
      await tester.pumpAndSettle();
      expect(chatC(d).previewNames, ['b.go']);
      expect(fake.writes, isEmpty);
      expect(utf8.decode(fake.files['main.go']!), goSource);
      await endEditor(tester, d);
    },
    variant: onMac,
  );

  testWidgets(
    'the disk holding the editor’s text already is no change from disk',
    (tester) async {
      final (d, fake) = await openEditor(tester, {
        'main.go': utf8.encode(goSource),
      });
      final e = editOf(d);
      await typeIn(tester, e, '// mine\n');
      fake.putFile('main.go', utf8.encode(e.text));
      await tester.pumpAndSettle();
      expect(e.unsaved, isFalse);
      expect(find.text('Merged a change from disk'), findsNothing);
      expect(e.controller.canUndo, isTrue);
      await endEditor(tester, d);
    },
    variant: onMac,
  );

  testWidgets('a subagent’s pane opens beside unsaved edits, not over them', (
    tester,
  ) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(goSource)});
    await typeIn(tester, editOf(d), 'x');
    chatC(d).pane.value = 'task';
    await tester.pumpAndSettle();
    expect(chatC(d).previewNames, ['main.go']);
    expect(chatC(d).preview.value, isNotNull);
    chatC(d).pane.value = null;
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('what can’t be edited shows read-only with its reason', (
    tester,
  ) async {
    final (d, fake) = await openEditor(
      tester,
      {'mixed.txt': utf8.encode('a\r\nb\n')},
      open: ['mixed.txt'],
    );
    expect(find.byType(SourceEditor), findsNothing);
    expect(
      find.text('Read-only: its lines end both in CRLF and LF.'),
      findsOneWidget,
    );
    // A hard-linked file, as the daemon says.
    fake.sendWatch(
      'mixed.txt',
      fake.fileNow('mixed.txt')
        ..data = utf8.encode('a\n')
        ..editable = false,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Read-only: it has more than one hard link.'),
      findsOneWidget,
    );
    expect(chatC(d).edits, isEmpty);
    await endEditor(tester, d);
  }, variant: onMac);

  for (final brightness in Brightness.values) {
    testWidgets('the editing tab and the conflict bar (${brightness.name})', (
      tester,
    ) async {
      final (d, fake) = await openEditor(
        tester,
        {
          'main.go': utf8.encode(goSource),
          'parse.go': utf8.encode('package p\n'),
        },
        open: ['parse.go', 'main.go'],
        brightness: brightness,
      );
      final e = editOf(d);
      e.controller.selection = const CodeLineSelection.collapsed(
        index: 3,
        offset: 1,
      );
      await typeIn(tester, e, 'x');
      fake.putFile(
        'main.go',
        utf8.encode(goSource.replaceAll('println', 'log')),
      );
      await tester.pump(const Duration(seconds: 1));
      await untilReal(tester, () => e.highlighted);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PreviewPane),
        matchesGoldenFile('goldens/file_edit_conflict_${brightness.name}.png'),
      );
      for (final width in [1700.0, 720.0]) {
        viewport(tester, Size(width, 900), brightness: brightness);
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'file_edit_${width.toInt()}_${brightness.name}',
        );
      }
      await endEditor(tester, d);
    }, variant: onMac);
  }
}
