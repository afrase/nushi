import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_editor.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/theme/theme.dart';
import 'package:re_editor/re_editor.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

/// A Go file as gofmt leaves it (tabs to indent), with tabs mid-line too.
const tabbed =
    'package main\n'
    '\n'
    'import "fmt"\n'
    '\n'
    '// point is where a label goes.\n'
    'type point struct {\n'
    '\tx, y\tint    // across\n'
    '\tlabel\tstring // the name\n'
    '}\n'
    '\n'
    'func main() {\n'
    '\tp := point{1, 2, "a"}\n'
    '\tif p.x > 0 {\n'
    '\t\tfmt.Println(p.label)\t// said once\n'
    '\t}\n'
    '}\n';

/// The editor's and the source view's code style.
TextStyle _code(BuildContext context) {
  final theme = NushiTheme.of(context);
  return theme.code(theme.t.text, size: 12);
}

/// Where the character at [offset] in [line] starts, drawn as
/// [tabStops] makes it with its strut, in columns.
double _at(String line, int offset) {
  const style = TextStyle(fontFamily: NushiTheme.codeFont, fontSize: 12);
  final column = columnWidth(style, TextScaler.noScaling);
  final p = TextPainter(
    text: TextSpan(
      style: style,
      children: tabStops([TextSpan(text: line)], fontSize: 12, column: column),
    ),
    textDirection: TextDirection.ltr,
    strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
  )..layout();
  final box = p.getBoxesForSelection(
    TextSelection(baseOffset: offset, extentOffset: offset + 1),
  );
  p.dispose();
  return box.first.left / column;
}

/// The source view's line holding [text].
RenderParagraph _sourceLine(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.textContaining(text, findRichText: true).first,
    );

/// The editor's laid-out line [index].
CodeLineRenderParagraph _editorLine(WidgetTester tester, int index) => tester
    .widget<DefaultCodeLineNumber>(find.byType(DefaultCodeLineNumber))
    .notifier
    .value!
    .paragraphs
    .firstWhere((p) => p.index == index);

/// What the app puts on the clipboard, in order.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  return copied;
}

Future<void> _copy(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  test('a tab reaches the next stop of four columns', () {
    expect(tabSize, 4);
    expect(
      [for (var c = 0; c < 9; c++) tabColumns(c)],
      [
        4, 3, 2, 1, 4, 3, 2, 1, 4, //
      ],
    );
    // At the start of a line, and after another.
    expect(_at('\tx', 1), closeTo(4, 0.01));
    expect(_at('\t\tx', 2), closeTo(8, 0.01));
    // Mid-line: to the next multiple of four, wherever it starts.
    expect(_at('ab\tc', 3), closeTo(4, 0.01));
    expect(_at('abc\tc', 4), closeTo(4, 0.01));
    expect(_at('abcd\tc', 5), closeTo(8, 0.01));
    expect(_at('a\tb\tc', 4), closeTo(8, 0.01));
    // A wide character takes two columns.
    expect(columnsOf('漢'.codeUnitAt(0)), 2);
    expect(columnsOf('é'.codeUnitAt(0)), 1);
  });

  test('the text stays as it is, its tabs real', () {
    final runs = tabStops(
      [
        const TextSpan(text: '\tx\t'),
        const TextSpan(
          text: 'y',
          style: TextStyle(color: Color(0xFF00FF00)),
        ),
        const TextSpan(text: '\tz'),
      ],
      fontSize: 10,
      column: 6,
    );
    expect(TextSpan(children: runs).toPlainText(), '\tx\ty\tz');
    // Columns 0, 5 and 9: to 4, 8 and 12, each its own size.
    expect(
      [
        for (final r in runs)
          if (r.text == '\t') r.style!.fontSize,
      ],
      [40, 30, 30],
    );
    expect(runs[3].style!.color, const Color(0xFF00FF00));
  });

  for (final wrap in [true, false]) {
    testWidgets('the source view draws tabs to their stops, wrap $wrap', (
      tester,
    ) async {
      viewport(tester, const Size(900, 600));
      await tester.pumpWidget(
        themed(SourceView(tabbed, path: 'main.go', wrap: wrap)),
      );
      await tester.pump();
      final context = tester.element(find.byType(SourceView));
      final column = columnWidth(
        DefaultTextStyle.of(context).style.merge(_code(context)),
        TextScaler.noScaling,
      );
      // Where each character starts, from where the line does.
      double x(RenderParagraph p, int offset) {
        double left(int at) => p
            .getBoxesForSelection(
              TextSelection(baseOffset: at, extentOffset: at + 1),
            )
            .first
            .left;
        return (left(offset) - left(0)) / column;
      }

      expect(x(_sourceLine(tester, 'if p.x'), 1), closeTo(4, 0.01));
      // '\tlabel' ends at column 9; its tab goes to 12.
      expect(x(_sourceLine(tester, '\tlabel'), 7), closeTo(12, 0.01));
      final call = _sourceLine(tester, 'Println');
      // Two tabs and 20 characters to column 28, the tab to 32.
      expect(x(call, 2), closeTo(8, 0.01));
      expect(x(call, 23), closeTo(32, 0.01));
      // A line is as high as one without tabs.
      expect(call.size.height, _sourceLine(tester, 'package').size.height);
      if (!wrap) {
        // The run-on width holds the widened line.
        expect(
          call.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(call.size.width),
        );
      }
    });
  }

  for (final wrap in [true, false]) {
    testWidgets('a very long line keeps its stops, in both views, wrap '
        '$wrap', (tester) async {
      // A tab, 3000 characters to column 3004, a tab to 3008.
      final long = '\t${'x' * 3000}\tend';
      double width(Iterable<Rect> boxes, double column) =>
          boxes.fold(0.0, (w, r) => w + r.width) / column;

      viewport(tester, const Size(900, 600));
      await tester.pumpWidget(
        themed(SourceView('$long\n', path: 'a.txt', wrap: wrap)),
      );
      await tester.pump();
      final context = tester.element(find.byType(SourceView));
      final column = columnWidth(
        DefaultTextStyle.of(context).style.merge(_code(context)),
        TextScaler.noScaling,
      );
      final source = _sourceLine(tester, 'xxx');
      expect(
        width(
          source
              .getBoxesForSelection(
                const TextSelection(baseOffset: 3001, extentOffset: 3002),
              )
              .map((b) => b.toRect()),
          column,
        ),
        closeTo(4, 0.01),
      );

      wrapLines.value = wrap;
      final (d, _) = await openEditor(tester, {
        'main.go': utf8.encode('package main\n$long\n'),
      });
      final editorColumn = columnWidth(
        _code(tester.element(find.byType(SourceEditor))),
        TextScaler.noScaling,
      );
      final line = _editorLine(tester, 1);
      expect(
        width(
          line.getRangeRects(const TextRange(start: 3001, end: 3002)),
          editorColumn,
        ),
        closeTo(4, 0.01),
      );
      if (wrap) {
        expect(line.height, greaterThan(line.preferredLineHeight));
      } else {
        final end = line.getOffset(const TextPosition(offset: 3002))!;
        expect(end.dx / editorColumn, closeTo(3008, 0.05));
      }
      await endEditor(tester, d);
    }, variant: onMac);
  }

  testWidgets('the source view copies its real tabs', (tester) async {
    viewport(tester, const Size(900, 600));
    await tester.pumpWidget(
      themed(const SourceView(tabbed, path: 'main.go', wrap: false)),
    );
    await tester.pump();
    final copied = _clipboard(tester);
    final from = find.textContaining('fmt.Println', findRichText: true).first;
    final to = find.textContaining('\t}', findRichText: true).first;
    final drag = await tester.startGesture(
      tester.getTopLeft(from) + const Offset(1, 4),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveTo(tester.getTopLeft(to) + const Offset(0, 4));
    await tester.pump();
    await drag.up();
    await tester.pump();
    await _copy(tester);
    expect(copied.last, contains('\t\tfmt.Println(p.label)\t// said once\n'));
  }, variant: onMac);

  testWidgets('the editor: the caret after a tab, a click past one, a copy '
      'and a save keep the real tabs', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(tabbed),
    });
    final e = editOf(d);
    final context = tester.element(find.byType(SourceEditor));
    final column = columnWidth(_code(context), TextScaler.noScaling);
    final line = _editorLine(tester, 13);
    double x(int offset) =>
        line.getOffset(TextPosition(offset: offset))!.dx / column;
    expect(x(1), closeTo(4, 0.01));
    expect(x(2), closeTo(8, 0.01));
    expect(x(23), closeTo(32, 0.01));
    // A click lands where it's drawn: each tab's near half before it,
    // its far half after it, the f after both.
    final gutter = find.byType(DefaultCodeLineNumber);
    for (final (columns, offset) in [
      (1.0, 0),
      (2.5, 1),
      (5.0, 1),
      (6.5, 2),
      (8.2, 2),
      (8.8, 3),
    ]) {
      await tester.tapAt(
        Offset(tester.getTopRight(gutter).dx, tester.getTopLeft(gutter).dy) +
            line.offset +
            Offset(columns * column, line.preferredLineHeight / 2),
      );
      await tester.pump();
      // re_editor tells a double click by the real clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      final at = e.controller.selection;
      expect(at.isCollapsed, isTrue);
      expect(
        (at.extentIndex, at.extentOffset),
        (13, offset),
        reason: 'a click $columns columns in',
      );
    }
    // Lines 13 and 14 copied as they are.
    final copied = _clipboard(tester);
    e.controller.selection = const CodeLineSelection(
      baseIndex: 13,
      baseOffset: 0,
      extentIndex: 14,
      extentOffset: 2,
    );
    await tester.pump();
    await _copy(tester);
    expect(copied.last, '\t\tfmt.Println(p.label)\t// said once\n\t}');
    // An edit and ⌘S: the bytes with their tabs.
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 11,
      offset: 1,
    );
    await typeIn(tester, e, 'q := 0\n\t');
    await cmd(tester, LogicalKeyboardKey.keyS);
    expect(
      utf8.decode(fake.writes.single.data),
      tabbed.replaceFirst('\tp :=', '\tq := 0\n\tp :='),
    );
    await endEditor(tester, d);
  }, variant: onMac);

  for (final brightness in Brightness.values) {
    testWidgets('a tab-indented file, the source view beside the editor '
        '(${brightness.name})', (tester) async {
      viewport(tester, const Size(1000, 330));
      final e = await _edit(tester);
      await tester.pumpWidget(_beside(e, brightness));
      final plain = _spans(tester);
      await untilReal(tester, () => e.highlighted && _spans(tester) > plain);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_besideKey),
        matchesGoldenFile('goldens/tab_stops_${brightness.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      e.dispose();
      e.daemon.dispose();
    });
  }
}

/// A file being edited, of [tabbed], on a daemon with nothing else.
Future<FileEdit> _edit(WidgetTester tester) async {
  final d = await FakeDaemon([]).connect(tester);
  final (file, _) = decodeFile(utf8.encode(tabbed));
  return FileEdit(d, 'c', 'main.go', file!, 'sum');
}

final GlobalKey _besideKey = GlobalKey();

/// The source view (left) and the editor of [e] (right), lines unwrapped.
Widget _beside(FileEdit e, Brightness b) => themed(
  tokens: b == Brightness.light ? Tokens.light : Tokens.dark,
  RepaintBoundary(
    key: _besideKey,
    child: Builder(
      builder: (context) => ColoredBox(
        color: NushiTheme.of(context).t.base,
        child: Row(
          children: [
            const Expanded(
              child: SourceView(
                tabbed,
                path: 'main.go',
                wrap: false,
                padding: EdgeInsets.fromLTRB(28, 22, 28, 28),
              ),
            ),
            Expanded(
              child: SourceEditor(
                edit: e,
                wrap: false,
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// The spans the source view shows: more once it is highlighted.
int _spans(WidgetTester tester) {
  var n = 0;
  for (final r in tester.widgetList<RichText>(
    find.descendant(
      of: find.byType(SourceView),
      matching: find.byType(RichText),
    ),
  )) {
    r.text.visitChildren((_) {
      n++;
      return true;
    });
  }
  return n;
}
