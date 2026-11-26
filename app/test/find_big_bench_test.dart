import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/line_search.dart';
import 'package:nushi/source_view.dart';
import 'package:re_editor/re_editor.dart';

import 'big_sql.dart';
import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'preview_find_fixture.dart';

// Timings of ⌘F in large files, to read, not to check: what a key holds
// the UI thread for in a read-only source (5 MiB the most the Files pane
// shows; 20 MB beyond it) and in the editor (1 MiB the most), a scroll
// with the matches marked, and in the editor with find open, a wheel's
// steps, a key typed into the file's longest line and a step of its
// selection. A debug build's times, a few times a release build's. It
// asserts nothing about time, and runs only with NUSHI_FIND_BENCH set:
//
//   NUSHI_FIND_BENCH=1 flutter test test/find_big_bench_test.dart

final bool _skip = !Platform.environment.containsKey('NUSHI_FIND_BENCH');

const _queries = ['s', 'se', 'sel', 'sele', 'selxq', ''];

String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

/// Prints a line of the report.
// ignore: avoid_print
void _say(String line) => print(line);

void main() {
  setUpAll(loadFonts);

  // (megabytes, rows an INSERT line): a dump's lines of 30 rows, a
  // migration's of one, and extended inserts of hundreds of kilobytes.
  for (final (mb, rows) in [(1, 30), (5, 30), (20, 30), (5, 1), (5, 5000)]) {
    testWidgets(
      'a read-only source, $mb MB, $rows rows a line',
      (tester) async {
        final text = bigSql(mb << 20, rows: rows);
        final (d, _) = await openEditor(
          tester,
          {'dump.sql': utf8.encode(text)},
          open: const [],
          readOnly: const {'dump.sql'},
        );
        final open = Stopwatch()..start();
        chatC(d).openInFiles('dump.sql');
        await tester.pumpAndSettle();
        _say(
          '$mb MB, ${'\n'.allMatches(text).length} lines, $rows rows a line: '
          'opened in ${_ms(open.elapsedMicroseconds)} ms',
        );
        await tester.tap(find.byType(SourceView));
        await tester.pumpAndSettle();
        await press(tester, LogicalKeyboardKey.keyF, cmd: true);
        await tester.pumpAndSettle();
        final lines = text.split('\n');
        final f = barFind(tester) as LaterFind;
        for (final q in _queries) {
          LineSearch.looked = 0;
          final key = Stopwatch()..start();
          tester.testTextInput.enterText(q);
          final held = key.elapsedMicroseconds;
          final looked = LineSearch.looked;
          while (f.looking) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          final counted = key.elapsedMicroseconds;
          final frame = Stopwatch()..start();
          await tester.pump();
          // A slice alone: what each later turn holds the thread for.
          final slice = Stopwatch()..start();
          LineSearch().start(
            lines,
            q,
            cut: 5000,
            done: (_, {required more}) {},
          );
          _say(
            '  "$q": the key ${_ms(held)} ms (${looked ~/ 1024} KB looked '
            'at), a slice ${_ms(slice.elapsedMicroseconds)} ms, the whole '
            'search with its frames ${_ms(counted)} ms, a frame after '
            '${_ms(frame.elapsedMicroseconds)} ms; ${f.count}',
          );
          await tester.pumpAndSettle();
        }
        tester.testTextInput.enterText('se');
        await tester.pumpAndSettle();
        final scroll = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(SourceView), const Offset(0, -400));
          await tester.pump();
        }
        _say('  scrolling: ${_ms(scroll.elapsedMicroseconds ~/ 10)} ms a drag');
        await endEditor(tester, d);
      },
      variant: onMac,
      skip: _skip,
      timeout: const Timeout.factor(10),
    );
  }

  for (final (kb, rows) in [(1000, 30), (1000, 1), (256, 5000), (1000, 5000)]) {
    testWidgets(
      'the editor, $kb KB, $rows rows a line',
      (tester) async {
        final text = bigSql(kb << 10, rows: rows);
        final (d, _) = await openEditor(
          tester,
          {'dump.sql': utf8.encode(text)},
          open: const ['dump.sql'],
        );
        _say('editor, $kb KB, ${'\n'.allMatches(text).length} lines');
        await tester.tap(find.byType(CodeEditor));
        await tester.pump();
        await press(tester, LogicalKeyboardKey.keyF, cmd: true);
        await tester.pumpAndSettle();
        final f = tester.widget<EditorFindBar>(find.byType(EditorFindBar)).find;
        for (final q in _queries) {
          final key = Stopwatch()..start();
          tester.testTextInput.enterText(q);
          await tester.pump();
          final held = key.elapsedMicroseconds;
          // re_editor looks in its isolate, on the real clock.
          await untilReal(
            tester,
            () => !f.looking,
            limit: const Duration(minutes: 1),
          );
          final frame = Stopwatch()..start();
          await tester.pump();
          _say(
            '  "$q": the key and its frame ${_ms(held)} ms, counted after '
            '${_ms(key.elapsedMicroseconds)} ms, a frame then '
            '${_ms(frame.elapsedMicroseconds)} ms, ${f.painted.length} '
            'painted; ${f.count}',
          );
        }
        tester.testTextInput.enterText('s');
        await untilReal(
          tester,
          () => !f.looking,
          limit: const Duration(minutes: 1),
        );
        final scroll = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(CodeEditor), const Offset(0, -400));
          await tester.pump();
        }
        _say('  scrolling: ${_ms(scroll.elapsedMicroseconds ~/ 10)} ms a drag');
        // The mouse's wheel, 300 px a step down and back, find open.
        final mouse = TestPointer(7, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          mouse.hover(tester.getCenter(find.byType(CodeEditor))),
        );
        await tester.pumpAndSettle();
        final wheel = Stopwatch()..start();
        for (var i = 0; i < 40; i++) {
          await tester.sendEventToBinding(
            mouse.scroll(Offset(0, i < 20 ? 300 : -300)),
          );
          await tester.pump();
        }
        _say('  the wheel: ${_ms(wheel.elapsedMicroseconds ~/ 40)} ms a step');
        // In the text, with find open on "s": keys typed into the file's
        // longest line, and its selection widened a character at a time,
        // each with its frame.
        final c = editOf(d, 'dump.sql').controller;
        var long = 0;
        for (var i = 0; i < c.codeLines.length; i++) {
          if (c.codeLines[i].length > c.codeLines[long].length) long = i;
        }
        c
          ..selection = CodeLineSelection.collapsed(index: long, offset: 5)
          ..makeCursorVisible();
        await tester.pumpAndSettle();
        final typing = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          c.replaceSelection('x');
          await tester.pump();
        }
        final typed = typing.elapsedMicroseconds ~/ 10;
        c.selection = CodeLineSelection.collapsed(index: long, offset: 5);
        await tester.pump();
        final selecting = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          c.selection = CodeLineSelection(
            baseIndex: long,
            baseOffset: 5,
            extentIndex: long,
            extentOffset: 6 + i,
          );
          await tester.pump();
        }
        _say(
          '  in its longest line, of ${c.codeLines[long].length} '
          'characters: typing '
          '${_ms(typed)} ms a key, selecting '
          '${_ms(selecting.elapsedMicroseconds ~/ 20)} ms a step',
        );
        await endEditor(tester, d);
      },
      variant: onMac,
      skip: _skip,
      timeout: const Timeout.factor(10),
    );
  }
}
