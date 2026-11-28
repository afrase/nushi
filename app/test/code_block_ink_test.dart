import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart' show loadFonts;
import 'fill_pixels.dart';
import 'harness.dart';

// Code in a chat's code block under the selection (issue 117): on the
// selection's fill, and on a find's hit or current match under it, each
// run keeps the contrast its colour has on the block's own fill, up to
// 3:1, by lightness alone (ADR 0086's amendment), in every built-in set.
// Read off the pixels, run by run.

/// Made-up Go: "int" in comments, as a type and in a string, beside a
/// number, keywords, a call and the package's name.
const _code =
    'package tally\n'
    '\n'
    '// tally adds int numbers up, 42 at most.\n'
    'type tally struct{ total int }\n'
    '\n'
    'func (t *tally) add(n int) string {\n'
    '    t.total += n // an int\n'
    '    return strings.Repeat("int", 42)\n'
    '}\n';

const ValueKey<String> _box = ValueKey('box');

/// One run of code as measured: its own colour, the fill under it, and
/// the contrast of its brightest pixel there.
typedef _Run = ({String text, Color color, Color fill, double contrast});

/// A transcript's message holding [_code] as a block, in [tokens], its
/// matches marked by [marks]; [selected] hears what's selected.
Widget _message(
  Tokens tokens,
  TextMarks marks,
  ValueChanged<String> selected,
) => themed(
  tokens: tokens,
  banner: false,
  Builder(
    builder: (context) => Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _box,
        child: ColoredBox(
          color: NushiTheme.of(context).t.base,
          child: SizedBox(
            width: 560,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextMarksScope(
                marks: marks,
                child: SelectionArea(
                  onSelectionChanged: (c) => selected(c?.plainText ?? ''),
                  child: const Marks(
                    entry: 'm',
                    child: AgentMarkdown(
                      'It adds them up:\n\n```go\n$_code```\n',
                      transcript: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// The code block's paragraph.
RenderParagraph _codeText(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
      find.textContaining('package tally', findRichText: true).last,
    );

/// The message in [tokens], "int" found, its match [current] the
/// current one; with [selectAll] everything is selected, by a drag over
/// it.
Future<TextMarks> _open(
  WidgetTester tester,
  Tokens tokens, {
  bool selectAll = true,
  int current = 0,
}) async {
  viewport(tester, const Size(600, 340));
  final marks = TextMarks(ink: codeOnMark);
  addTearDown(marks.dispose);
  var selected = '';
  await tester.pumpWidget(_message(tokens, marks, (s) => selected = s));
  await tester.pumpAndSettle();
  final colors = findColors(tokens);
  marks.look(
    'int',
    const ['m'],
    hit: colors.hit,
    now: colors.now,
    edge: colors.edge,
  );
  tester.binding.scheduleFrame();
  await tester.pump();
  await tester.pump();
  marks.pick(marks.marks[current]);
  await tester.pump();
  if (!selectAll) return marks;
  final p = _codeText(tester);
  final text = p.text.toPlainText();
  final last = p
      .getBoxesForSelection(
        TextSelection(baseOffset: text.length - 1, extentOffset: text.length),
      )
      .last
      .toRect();
  final from = tester.getTopLeft(find.textContaining('It adds'));
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: from);
  await mouse.down(from);
  await tester.pump();
  await mouse.moveTo(p.localToGlobal(last.centerRight + const Offset(8, 0)));
  await tester.pump();
  await mouse.up();
  await mouse.removePointer();
  await tester.pumpAndSettle();
  expect(selected, contains(_code.trim()), reason: 'all the code selected');
  return marks;
}

/// Each run of the code block of two letters or more, on the fill under
/// it with everything selected: the selection over the block, or over a
/// hit's or the current match's tint (match [current]); with the contrast
/// of its brightest pixel there.
Future<List<_Run>> _measure(
  WidgetTester tester,
  Tokens t, {
  int current = 0,
}) async {
  final p = _codeText(tester);
  final text = p.text.toPlainText();
  final lower = text.toLowerCase();
  final hits = [for (final m in 'int'.allMatches(lower)) (m.start, m.end)];
  final colors = findColors(t);
  final tint = p.selectionColor!;
  final bg = t.codeBlock;
  final plain = Color.alphaBlend(tint, bg);
  final hit = Color.alphaBlend(tint, Color.alphaBlend(colors.hit, bg));
  final now = Color.alphaBlend(tint, Color.alphaBlend(colors.now, bg));
  final box = tester.renderObject<RenderBox>(find.byKey(_box));
  final (pixels, width) = await boxPixels(tester);
  final out = <_Run>[];
  var at = 0;
  void walk(InlineSpan s, Color inherited) {
    if (s is! TextSpan) return;
    final color = s.style?.color ?? inherited;
    final own = s.text ?? '';
    if (own.isNotEmpty) {
      final cuts = {at, at + own.length};
      for (final (a, b) in hits) {
        cuts.addAll([a, b]);
      }
      // A piece to a line: a box of its own each.
      for (final m in '\n'.allMatches(own)) {
        cuts.addAll([at + m.start, at + m.end]);
      }
      final edges = cuts.where((x) => x >= at && x <= at + own.length).toList()
        ..sort();
      for (var k = 0; k + 1 < edges.length; k++) {
        final (a, b) = (edges[k], edges[k + 1]);
        final piece = text.substring(a, b);
        if (RegExp('[A-Za-z0-9]').allMatches(piece).length < 2) continue;
        final inHit = hits.indexWhere((h) => a >= h.$1 && b <= h.$2);
        final fill = inHit == -1
            ? plain
            : inHit == current
            ? now
            : hit;
        for (final r in p.getBoxesForSelection(
          TextSelection(baseOffset: a, extentOffset: b),
        )) {
          final g =
              box.globalToLocal(p.localToGlobal(r.toRect().topLeft)) &
              r.toRect().size;
          // Clear of the current match's edge, round its box.
          final inner = Rect.fromLTRB(
            g.left + 3,
            g.top + 1,
            g.right - 3,
            g.bottom - 1,
          );
          var most = 1.0;
          for (var y = (inner.top * 4).ceil(); y < inner.bottom * 4; y++) {
            for (var x = (inner.left * 4).ceil(); x < inner.right * 4; x++) {
              final k = contrast(Color(pixelAt(pixels, y * width + x)), fill);
              if (k > most) most = k;
            }
          }
          out.add((text: piece, color: color, fill: fill, contrast: most));
        }
      }
      at += own.length;
    }
    for (final c in s.children ?? const <InlineSpan>[]) {
      walk(c, color);
    }
  }

  walk(p.text, t.text);
  return out;
}

void main() {
  setUpAll(loadFonts);

  for (final theme in builtInThemes) {
    for (final b in Brightness.values) {
      final set = '${theme.name} ${b.name}';
      final t = b == Brightness.dark ? theme.dark : theme.light;
      testWidgets("code keeps its contrast under a code block's selection, "
          'and a hit or the current one under it, in $set', (tester) async {
        final bg = t.codeBlock;
        // The dimmest of the set's code colours, and the match of "int"
        // the current one, so it's on that colour: a comment's (the first),
        // or a type's (the second) in Catppuccin Latte.
        final dimmest = t.syntax.entries.reduce(
          (a, b) => contrast(a.value.color, bg) <= contrast(b.value.color, bg)
              ? a
              : b,
        );
        final current = switch (dimmest.key) {
          Capture.comment => 0,
          Capture.type => 1,
          final c => throw StateError('no "int" in a $c in the sample'),
        };
        await _open(tester, t, current: current);
        final runs = await _measure(tester, t, current: current);
        for (final r in runs) {
          final own = contrast(r.color, bg);
          final target = own < codeOnTintContrast ? own : codeOnTintContrast;
          final asIs = contrast(r.color, r.fill);
          expect(
            r.contrast,
            greaterThanOrEqualTo(target - 0.15),
            reason: '$set: "${r.text}" reads ${r.contrast}:1, under $target',
          );
          expect(
            r.contrast,
            lessThanOrEqualTo((asIs > target ? asIs : target) + 0.6),
            reason: '$set: "${r.text}" is drawn brighter than the rule needs',
          );
        }
        // The dimmest colour on each fill: the selection, a hit under it
        // and the current match under it.
        final fills = {for (final r in runs) r.fill};
        expect(fills, hasLength(3), reason: 'the selection, a hit, the one');
        for (final fill in fills) {
          expect(
            runs.where((r) => r.fill == fill && r.color == dimmest.value.color),
            isNotEmpty,
            reason: '$set: the dimmest code on $fill',
          );
        }
      }, variant: onMac);
    }
  }
}
