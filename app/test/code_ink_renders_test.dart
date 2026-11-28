import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';
import 'package:re_editor/re_editor.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// Pictures of code under the fills the file editor and a chat's code
// block paint (issue 117): the editor with its find open and a selection
// over some of its hits, and a code block selected with the chat's find
// open, in Nushi's sets and Tokyo Night's, wide and narrow. Drawn before
// and after a change (`--dart-define=STAGE=before`), to look at.

/// Made-up Go: "total" in comments and in code.
const _code =
    'package tally\n'
    '\n'
    '// total is what Sum gives back.\n'
    'func Sum(xs []int) int {\n'
    '\ttotal := 0 // the total so far\n'
    '\tfor _, x := range xs {\n'
    '\t\ttotal += x // add it to the total\n'
    '\t}\n'
    '\treturn total\n'
    '}\n';

const String _stage = String.fromEnvironment('STAGE', defaultValue: 'after');

const _themes = ['nushi', 'tokyo-night'];

/// A drag from [from] to [to], as a mouse makes it.
Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: from);
  await tester.pump();
  await mouse.down(from);
  await tester.pump();
  await mouse.moveTo(Offset.lerp(from, to, .5)!);
  await tester.pump();
  await mouse.moveTo(to);
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

/// Where [text] starts or ends in the last paragraph holding it.
Offset _at(WidgetTester tester, String text, {required bool end}) {
  final p = tester.renderObject<RenderParagraph>(
    find.textContaining(text, findRichText: true).last,
  );
  final i = p.text.toPlainText().indexOf(text);
  final box = p
      .getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + text.length),
      )
      .first
      .toRect();
  return p.localToGlobal(
    end ? box.centerRight - const Offset(1, 0) : box.centerLeft,
  );
}

void main() {
  setUpAll(loadFonts);
  rendersOnly();

  for (final theme in _themes) {
    for (final b in Brightness.values) {
      for (final width in [1700.0, 720.0]) {
        final name = '${theme}_${width.round()}_${b.name}';

        renderTest('the editor with a find and a selection, $name', (
          tester,
        ) async {
          colorTheme.value = theme;
          final (d, _) = await openEditor(
            tester,
            {'main.go': utf8.encode(_code)},
            width: width,
            brightness: b,
          );
          await untilReal(tester, () => editOf(d).highlighted);
          await tester.pumpAndSettle();
          await tester.tap(find.byType(CodeEditor));
          await tester.pump();
          final c = editOf(d).controller
            ..selection = const CodeLineSelection.collapsed(
              index: 0,
              offset: 0,
            );
          await press(tester, LogicalKeyboardKey.keyF, cmd: true);
          final f = tester
              .widget<EditorFindBar>(find.byType(EditorFindBar))
              .find;
          await tester.enterText(
            find.descendant(
              of: find.byType(FindBar),
              matching: find.byType(EditableText),
            ),
            'total',
          );
          await untilReal(tester, () => !f.looking);
          await tester.pumpAndSettle();
          // From the comment's "is" to the next line's end: a hit over
          // the selection, the others on their own.
          c.selection = const CodeLineSelection(
            baseIndex: 2,
            baseOffset: 9,
            extentIndex: 4,
            extentOffset: 31,
          );
          await tester.pumpAndSettle();
          await render(tester, find.byType(NushiApp), '$_stage-editor-$name');
          await endEditor(tester, d);
        }, variant: onMac);

        renderTest("a chat's code block selected, $name", (tester) async {
          colorTheme.value = theme;
          showDetails.value = false;
          final fake = FakeDaemon([chat('c', 'claude', 'Tally')])
            ..chatItems['c'] = [
              userSays('u', 'How does Sum work?'),
              agentSays('m', 'It adds them up:\n\n```go\n$_code```\n'),
            ];
          final d = await openApp(
            tester,
            fake,
            size: Size(width, 700),
            brightness: b,
          );
          d.chats['c']!.find
            ..open()
            ..query = 'total';
          await tester.pumpAndSettle();
          await _drag(
            tester,
            _at(tester, 'is what Sum', end: false),
            _at(tester, 'the total so far', end: true),
          );
          await render(tester, find.byType(NushiApp), '$_stage-block-$name');
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }
}
