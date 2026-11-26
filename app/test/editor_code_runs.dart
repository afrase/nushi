/// Reading code's contrast off the file editor's fills (issue 117), run
/// by run and word by word: what `editor_code_on_test` reads with.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/editor_ink.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:re_editor/re_editor.dart';

import 'file_edit_helpers.dart';
import 'fill_pixels.dart' show pixelAt;
import 'harness.dart';

/// Made-up Go: "int" in comments, as a type and in a string, beside a
/// number, keywords, a call and the package's name.
const editorCode =
    'package tally\n'
    '\n'
    'import "strings"\n'
    '\n'
    '// tally adds int numbers up, 42 at most.\n'
    'type tally struct{ total int }\n'
    '\n'
    'func (t *tally) add(n int) string {\n'
    '\tt.total += n // an int\n'
    '\treturn strings.Repeat("int", 42)\n'
    '}\n';

/// One run of code as measured: its own colour, the fill under it, and
/// the contrast of its brightest pixel there.
typedef CodeRun = ({String text, Color color, Color fill, double contrast});

EditorFind barFindOf(WidgetTester tester) =>
    tester.widget<EditorFindBar>(find.byType(EditorFindBar)).find;

/// The editor on [code], highlighted, its find open on "int".
Future<Daemon> openOnInt(
  WidgetTester tester,
  String theme,
  Brightness b, {
  String code = editorCode,
}) async {
  colorTheme.value = theme;
  final (d, _) = await openEditor(tester, {
    'main.go': utf8.encode(code),
  }, brightness: b);
  await untilReal(tester, () => editOf(d).highlighted);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(CodeEditor));
  await tester.pump();
  editOf(d).controller.selection = const CodeLineSelection.collapsed(
    index: 0,
    offset: 0,
  );
  await press(tester, LogicalKeyboardKey.keyF, cmd: true);
  await tester.enterText(
    find.descendant(
      of: find.byType(FindBar),
      matching: find.byType(EditableText),
    ),
    'int',
  );
  final f = barFindOf(tester);
  await untilReal(tester, () => !f.looking);
  await tester.pumpAndSettle();
  return d;
}

/// The window's picture of [area] (global), four times over.
Future<(ByteData, int)> _pixels(WidgetTester tester, Rect area) async {
  RenderObject? boundary;
  for (
    RenderObject? o = tester.renderObject(find.byType(CodeEditor));
    o != null;
    o = o.parent
  ) {
    if (o is RenderBox && o.isRepaintBoundary) boundary = o;
  }
  final box = boundary! as RenderBox;
  final at = box.globalToLocal(area.topLeft) & area.size;
  final layer = box.debugLayer! as OffsetLayer;
  return (await tester.runAsync(() async {
    final image = await layer.toImage(at, pixelRatio: 4);
    try {
      final bytes = await image.toByteData();
      return (bytes!, image.width);
    } finally {
      image.dispose();
    }
  }))!;
}

/// Each word of code in sight of two letters or more, on a fill or not:
/// its colour as the file's spans have it, the fill re_editor paints
/// under it (the selection, a find's hits but the one selected), and the
/// contrast its brightest pixel has on that fill.
Future<List<CodeRun>> measureRuns(WidgetTester tester, Daemon d) async {
  final e = editOf(d);
  final c = e.controller;
  final bar = tester.widget<EditorFindBar>(find.byType(EditorFindBar));
  final context = tester.element(find.byType(CodeEditor));
  final t = NushiTheme.of(context).t;
  final base = t.base;
  final hit = Color.alphaBlend(findColors(t).hit, base);
  final selected = Color.alphaBlend(editorSelectionColor(context), base);
  final hitSelected = Color.alphaBlend(findColors(t).hit, selected);
  final gutter = bar.gutter.currentContext!.findRenderObject()! as RenderBox;
  final origin =
      gutter.localToGlobal(Offset(gutter.size.width, 0)) +
      Offset(bar.lines.moved, 0);
  final editor = tester.getRect(find.byType(CodeEditor));
  final findBar = find.byType(FindBar).evaluate().isEmpty
      ? Rect.zero
      : tester.getRect(find.byType(FindBar)).inflate(2);
  final (pixels, width) = await _pixels(tester, editor);
  final s = c.selection;
  // What re_editor was last given to paint.
  final matches = [
    for (final m in bar.find.painted)
      (m.startIndex, m.startOffset, m.endOffset),
  ];
  final out = <CodeRun>[];
  for (final p in bar.lines.value!.paragraphs) {
    // The line's own runs, not drawn for any fill.
    final keep = e.ink;
    e.ink = null;
    final span = c.buildTextSpan(
      context: context,
      index: p.index,
      textSpan: const TextSpan(),
      style: const TextStyle(fontSize: 12),
    );
    e.ink = keep;
    var at = 0;
    for (final run in span.children!.cast<TextSpan>()) {
      final text = run.text!;
      final color = run.style?.color ?? t.text;
      // Split where a fill starts or ends, and at each word's edges, so a
      // long run is measured where it shows.
      final cuts = {at, at + text.length};
      for (final m in ' '.allMatches(text)) {
        cuts.addAll([at + m.start, at + m.end]);
      }
      if (!s.isCollapsed && p.index >= s.startIndex && p.index <= s.endIndex) {
        if (p.index == s.startIndex) cuts.add(s.startOffset);
        if (p.index == s.endIndex) cuts.add(s.endOffset);
      }
      for (final (i, a, b) in matches) {
        if (i == p.index) cuts.addAll([a, b]);
      }
      final edges = cuts.where((x) => x >= at && x <= at + text.length).toList()
        ..sort();
      for (var k = 0; k + 1 < edges.length; k++) {
        final (a, b) = (edges[k], edges[k + 1]);
        final piece = text.substring(a - at, b - at);
        if (RegExp('[A-Za-z0-9]').allMatches(piece).length < 2) continue;
        final inSelection =
            !s.isCollapsed &&
            (p.index > s.startIndex ||
                p.index == s.startIndex && a >= s.startOffset) &&
            (p.index < s.endIndex || p.index == s.endIndex && b <= s.endOffset);
        final inHit = matches.any(
          (m) => m.$1 == p.index && a >= m.$2 && b <= m.$3,
        );
        final fill = switch ((inSelection, inHit)) {
          (true, true) => hitSelected,
          (true, false) => selected,
          (false, true) => hit,
          (false, false) => base,
        };
        for (final r in p.getRangeRects(TextRange(start: a, end: b))) {
          final g = r.shift(origin + p.offset);
          // Wholly in sight: right of the gutter, inside the editor's
          // edges and clear of the find bar over it; and two characters
          // wide at least (a wrapped piece's end may be its space alone).
          if (g.width < 12 ||
              g.left < origin.dx - bar.lines.moved ||
              g.right > editor.right ||
              g.top < editor.top ||
              g.bottom > editor.bottom ||
              g.overlaps(findBar)) {
            continue;
          }
          // Clear of the caret and of the glyphs beside it.
          final inner = Rect.fromLTRB(
            g.left + 2,
            g.top + 1,
            g.right - 1,
            g.bottom - 1,
          );
          var most = 1.0;
          for (
            var y = ((inner.top - editor.top) * 4).ceil();
            y < (inner.bottom - editor.top) * 4;
            y++
          ) {
            for (
              var x = ((inner.left - editor.left) * 4).ceil();
              x < (inner.right - editor.left) * 4;
              x++
            ) {
              final px = Color(pixelAt(pixels, y * width + x));
              final k = contrast(px, fill);
              if (k > most) most = k;
            }
          }
          out.add((text: piece, color: color, fill: fill, contrast: most));
        }
      }
      at += text.length;
    }
  }
  return out;
}

/// Every run in [runs] reads by the rule on its fill: at least its own
/// contrast on [base] up to 3:1, and no further past it than it was; on
/// [base] itself, as published (no ink left from a fill that's gone).
void expectRule(List<CodeRun> runs, Color base, String set) {
  for (final r in runs) {
    final own = contrast(r.color, base);
    if (r.fill == base) {
      expect(
        r.contrast,
        lessThanOrEqualTo(own + 0.1),
        reason: '$set: "${r.text}" is inked on the plain background',
      );
    }
    final target = own < codeOnTintContrast ? own : codeOnTintContrast;
    final asIs = contrast(r.color, r.fill);
    expect(
      r.contrast,
      greaterThanOrEqualTo(target - 0.15),
      reason: '$set: "${r.text}" reads ${r.contrast}:1, under $target:1',
    );
    expect(
      r.contrast,
      lessThanOrEqualTo((asIs > target ? asIs : target) + 0.6),
      reason: '$set: "${r.text}" is drawn brighter than the rule needs',
    );
  }
}
