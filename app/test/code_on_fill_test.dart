import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/preview_find.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/catppuccin.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/nord.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme/tokyo_night.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart' show loadFonts;
import 'fill_pixels.dart';
import 'harness.dart';

// Code under the fills Nushi paints itself outside a diff (issue 117): a
// find's hits and its current match in the file viewer and in a
// transcript's code block keep the contrast their colour has on the plain
// background, up to 3:1, by lightness alone (ADR 0086's amendment).

/// Made-up Go: "total" in two comments and in code, so a find has a
/// comment for its current match and others around it.
const _code =
    'package tally\n'
    '\n'
    '// total is what Sum gives back.\n'
    'func Sum(xs []int) int {\n'
    '\ttotal := 0 // the total so far\n'
    '\tfor _, x := range xs {\n'
    '\t\ttotal += x\n'
    '\t}\n'
    '\treturn total\n'
    '}\n';

const ValueKey<String> _box = ValueKey('box');

/// The file viewer showing [_code] in [tokens], its find open.
Widget _viewer(Tokens tokens, FindSlot slot) => themed(
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
            width: 520,
            height: 230,
            child: FindSlotScope(
              slot: slot,
              child: const SourceView(_code, path: 'tally.go'),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// A transcript's message holding [_code] as a block, in [tokens], its
/// matches marked by [marks].
Widget _message(Tokens tokens, TextMarks marks) => themed(
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
            width: 520,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextMarksScope(
                marks: marks,
                child: const SelectionArea(
                  child: Marks(
                    entry: 'm',
                    child: AgentMarkdown(
                      'It sums them:\n\n```go\n$_code```\n',
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

/// Opens the viewer in [tokens] with [query] found, its first match (with
/// "total", a comment) current; highlighted.
Future<void> _openViewer(
  WidgetTester tester,
  Tokens tokens, {
  String query = 'total',
}) async {
  viewport(tester, const Size(560, 260));
  final slot = FindSlot();
  await tester.pumpWidget(_viewer(tokens, slot));
  await untilReal(
    tester,
    () => tester
        .widgetList<RichText>(find.byType(RichText))
        .any(
          (r) =>
              r.text.toPlainText().contains('// total is') && _styled(r.text),
        ),
  );
  slot.view!
    ..open()
    ..query = query;
  await tester.pumpAndSettle();
}

/// Whether [span] has a run with a colour of its own (highlighted).
bool _styled(InlineSpan span) {
  var found = false;
  span.visitChildren((s) {
    if (s != span && s.style?.color != null) found = true;
    return !found;
  });
  return found;
}

/// Opens a message in [tokens] with "total" marked, its first match
/// current.
Future<TextMarks> _openMessage(WidgetTester tester, Tokens tokens) async {
  viewport(tester, const Size(560, 300));
  final marks = TextMarks(ink: codeOnMark);
  addTearDown(marks.dispose);
  await tester.pumpWidget(_message(tokens, marks));
  await tester.pumpAndSettle();
  final colors = findColors(tokens);
  marks.look(
    'total',
    const ['m'],
    hit: colors.hit,
    now: colors.now,
    edge: colors.edge,
  );
  tester.binding.scheduleFrame();
  await tester.pump();
  await tester.pump();
  marks.pick(marks.marks.first);
  await tester.pump();
  return marks;
}

/// [c]'s hue, in degrees.
double _hue(Color c) => HSLColor.fromColor(c).hue;

/// What reads on each patch of a find's hit and current fills over
/// [background] in the box, in [tokens]: the comment's own contrast on
/// [background] must hold on both (it is under 3:1 in Tokyo Night), its
/// hue kept, where before it all but vanished.
Future<void> _expectCommentReads(
  WidgetTester tester,
  Tokens tokens,
  Color background,
) async {
  final colors = findColors(tokens);
  final comment = tokens.syntax[Capture.comment]!.color;
  final own = contrast(comment, background);
  final (pixels, width) = await boxPixels(tester);
  for (final (what, tint) in [
    ('a hit', colors.hit),
    ('the current one', colors.now),
  ]) {
    final fill = Color.alphaBlend(tint, background);
    expect(
      contrast(comment, fill),
      lessThan(own - 0.4),
      reason: 'before, the comment all but vanished on $what',
    );
    // Clear of the current match's edge, a few pixels in.
    final patches = textOn(pixels, width, fill, inset: 8);
    expect(patches, isNotEmpty, reason: '$what is painted');
    for (final p in patches) {
      expect(
        p.contrast,
        greaterThanOrEqualTo(own - 0.1),
        reason: 'code on $what reads ${p.contrast}:1',
      );
    }
    // A comment's patch: its own blue-grey, lighter.
    expect(
      patches.any((p) => (_hue(p.ink) - _hue(comment)).abs() < 6),
      isTrue,
      reason: 'the comment on $what keeps its hue',
    );
  }
}

/// Selects the viewer's lines from the start of the one holding [from]
/// to the end of the one holding [to], by a drag.
Future<void> _select(WidgetTester tester, String from, String to) async {
  Rect line(String text) =>
      tester.getRect(find.textContaining(text, findRichText: true).first);
  final start = line(from);
  final end = line(to);
  final drag = await tester.startGesture(
    start.topLeft + const Offset(1, 6),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await drag.moveTo(Offset(end.right - 2, end.top + 6));
  await tester.pump();
  await drag.up();
  await tester.pumpAndSettle();
}

const List<(String, Tokens)> _themes = [
  ('tokyo-night', tokyoNightDark),
  ('tokyo-night-day', tokyoNightLight),
  ('nord', nordDark),
  ('catppuccin-latte', catppuccinLight),
];

void main() {
  setUpAll(loadFonts);

  testWidgets("a comment under the file viewer's hits reads in Tokyo Night", (
    tester,
  ) async {
    await _openViewer(tester, tokyoNightDark);
    await _expectCommentReads(tester, tokyoNightDark, tokyoNightDark.base);
  }, variant: onMac);

  testWidgets("a comment under a transcript code block's hits reads in "
      'Tokyo Night', (tester) async {
    await _openMessage(tester, tokyoNightDark);
    await _expectCommentReads(tester, tokyoNightDark, tokyoNightDark.codeBlock);
  }, variant: onMac);

  testWidgets("in the file viewer, code on the selection reads, and a hit's "
      'over it', (tester) async {
    const t = tokyoNightDark;
    await _openViewer(tester, t);
    await _select(tester, 'is what Sum', 'the total so far');
    final comment = t.syntax[Capture.comment]!.color;
    final own = contrast(comment, t.base);
    final colors = findColors(t);
    final selected = Color.alphaBlend(t.textSelection, t.base);
    final (pixels, width) = await boxPixels(tester);
    for (final (what, fill) in [
      ('the selection', selected),
      ('a hit over it', Color.alphaBlend(colors.hit, selected)),
      ('the current hit over it', Color.alphaBlend(colors.now, selected)),
    ]) {
      expect(
        contrast(comment, fill),
        lessThan(own - 0.3),
        reason: 'before, the comment faded on $what',
      );
      final patches = textOn(pixels, width, fill, inset: 8);
      expect(patches, isNotEmpty, reason: '$what is painted');
      for (final p in patches) {
        expect(
          p.contrast,
          greaterThanOrEqualTo(own - 0.1),
          reason: 'code on $what reads ${p.contrast}:1',
        );
      }
    }
  }, variant: onMac);

  testWidgets('a selection whose find changes draws its code for the new '
      'one, as one opened with it does', (tester) async {
    const t = tokyoNightDark;
    await _openViewer(tester, t);
    await _select(tester, 'is what Sum', 'the total so far');
    // "total" was found in the comments under the selection; "xs" is not
    // in them, so the comment is now on the plain selection again.
    FindSlotScope.maybeOf(tester.element(find.byType(SourceView)))!
            .view!
            .query =
        'xs';
    await tester.pumpAndSettle();
    final (changed, width) = await boxPixels(tester);
    await tester.pumpWidget(const SizedBox());
    await _openViewer(tester, t, query: 'xs');
    await _select(tester, 'is what Sum', 'the total so far');
    final (fresh, _) = await boxPixels(tester);
    final comment = t.syntax[Capture.comment]!.color;
    final selected = Color.alphaBlend(t.textSelection, t.base);
    final patches = textOn(changed, width, selected, inset: 8);
    expect(patches, isNotEmpty, reason: 'the selection is painted');
    for (final p in patches) {
      expect(
        p.contrast,
        greaterThanOrEqualTo(contrast(comment, t.base) - 0.1),
        reason: 'code on the selection reads ${p.contrast}:1',
      );
    }
    // The code, not the find bar's field (the query was set behind it):
    // left of the bar, and below it. The picture is at 4x.
    var differ = 0;
    for (var i = 0; i < changed.lengthInBytes ~/ 4; i++) {
      final (x, y) = (i % width ~/ 4, i ~/ width ~/ 4);
      if (x >= 150 && y < 50) continue;
      if (pixelAt(changed, i) != pixelAt(fresh, i)) differ++;
    }
    expect(differ, 0, reason: "the old find's ink stayed on the selection");
  }, variant: onMac);

  testWidgets('code that already reads on a hit keeps its colour', (
    tester,
  ) async {
    await _openViewer(tester, tokyoNightDark);
    const t = tokyoNightDark;
    final fill = Color.alphaBlend(findColors(t).hit, t.base);
    // `return`'s keyword: far over the floor on a hit, as published.
    final keyword = t.syntax[Capture.keyword]!.color;
    expect(contrast(keyword, fill), greaterThan(codeOnTintContrast));
    final spans = <TextSpan>[];
    for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
      r.text.visitChildren((s) {
        if (s is TextSpan && s.text == 'total') spans.add(s);
        return true;
      });
    }
    // Each hit is a run of its own; one on plain code (not a comment)
    // reads and stays as the theme has it.
    expect(spans, hasLength(5));
    final plain = spans.where((s) => s.style?.color == null).length;
    expect(plain, greaterThan(0), reason: 'the plain text is left alone');
  }, variant: onMac);

  for (final (name, tokens) in _themes) {
    renderTest('the file viewer and a code block under a find, $name', (
      tester,
    ) async {
      final stage = const String.fromEnvironment('STAGE').isEmpty
          ? 'after'
          : const String.fromEnvironment('STAGE');
      await _openViewer(tester, tokens);
      await render(tester, find.byKey(_box), '$stage-viewer-$name');
      await _select(tester, 'is what Sum', 'the total so far');
      await render(tester, find.byKey(_box), '$stage-viewer-selected-$name');
      await _openMessage(tester, tokens);
      await render(tester, find.byKey(_box), '$stage-message-$name');
    }, variant: onMac);
  }
}
