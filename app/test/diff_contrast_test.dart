import 'dart:typed_data';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme/theme_file.dart';
import 'package:nushi/theme/tokyo_night.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Code on a diff's changed line or word keeps the contrast its theme gives
// it on the plain background, up to 3:1, by its lightness alone (ADR
// 0086's amendment): a comment's dim colour on Tokyo Night's changed-word
// teal read about 1.1:1.

/// A made-up change: a comment whose words change (its old line a deleted
/// line with changed words, its new one an added line with them), a
/// changed signature, a line changed inside, a number, a keyword and a
/// string that change, and an added comment. "total" is on changed and
/// unchanged lines, for a find.
final _change = FileChange(
  path: 'tally.go',
  oldText:
      '// Package tally sums small lists.\npackage tally\n'
      '// Deprecated: use the stats package.\n\n'
      '// Sum adds the numbers up.\nfunc Sum(xs []int) int {\n'
      '\ttotal := 0\n\tfor _, x := range xs {\n\t\ttotal += x\n\t}\n'
      '\treturn total\n}\n\nconst label = "sum"\n',
  newText:
      '// Package tally sums small lists.\npackage tally\n\n'
      '// Sum adds every number in xs and returns the total.\n'
      'func Sum(xs []int, start int) int {\n'
      '\ttotal := start\n\tfor _, x := range xs {\n\t\ttotal += x\n\t}\n'
      '\treturn total\n}\n\nvar label = "running sum"\n\n'
      '// Label names the sum in the logs.\n',
  added: 6,
  removed: 5,
);

/// A comment of one changed word, so the word's box holds only comment,
/// and an added line of comment.
final _oneWord = FileChange(
  path: 'note.go',
  oldText: 'package note\n\n// keep the old sum\nvar n = 1\n',
  newText:
      'package note\n\n// keep the new sum\nvar n = 1\n'
      '// and one more line\n',
  added: 2,
  removed: 1,
);

/// An added line of code alone.
final _added = FileChange(
  path: 'more.go',
  oldText: 'package more\n',
  newText: 'package more\n\nvar m = 2\n',
  added: 2,
);

/// A find's word on unchanged lines only, so every hit is on the same
/// fill and only its text tells the current one from the others.
final _found = FileChange(
  path: 'count.go',
  oldText:
      'package count\n\nfunc Count() int {\n'
      '\tcount := 0\n\tcount += step\n\treturn count\n}\n',
  newText:
      'package count\n\nconst step = 2\n\nfunc Count() int {\n'
      '\tcount := 0\n\tcount += step\n\treturn count\n}\n',
  added: 2,
);

/// [change] in a box on its own, in [tokens], with [find] if given.
Widget _box(Tokens tokens, FileChange change, {Find? find}) => themed(
  tokens: tokens,
  banner: false,
  Builder(
    builder: (context) => Container(
      color: NushiTheme.of(context).t.base,
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 736,
          child: RepaintBoundary(
            key: const ValueKey('box'),
            child: DiffBox(change, find: find),
          ),
        ),
      ),
    ),
  ),
);

/// Where [fill] is painted in [pixels] (an image [width] wide, RGBA):
/// each patch of it, a changed word's box or a changed line's band, as its
/// size and its bounding box. Specks under 400 pixels are left out.
List<(int, ({int x0, int y0, int x1, int y1}))> _patches(
  ByteData pixels,
  int width,
  Color fill,
) {
  final height = pixels.lengthInBytes ~/ (width * 4);
  final want = fill.toARGB32();
  final seen = Uint8List(width * height);
  final found = <(int, ({int x0, int y0, int x1, int y1}))>[];
  for (var start = 0; start < seen.length; start++) {
    if (seen[start] != 0 || _at(pixels, start) != want) continue;
    var (x0, y0, x1, y1, size) = (width, height, -1, -1, 0);
    final stack = [start];
    seen[start] = 1;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final (x, y) = (i % width, i ~/ width);
      size++;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
      for (final j in [
        if (x > 0) i - 1,
        if (x < width - 1) i + 1,
        if (y > 0) i - width,
        if (y < height - 1) i + width,
      ]) {
        if (seen[j] == 0 && _at(pixels, j) == want) {
          seen[j] = 1;
          stack.add(j);
        }
      }
    }
    if (size >= 400) found.add((size, (x0: x0, y0: y0, x1: x1, y1: y1)));
  }
  return found;
}

/// The pixel at [i] of [pixels] (RGBA), as ARGB.
int _at(ByteData pixels, int i) =>
    pixels.getUint8(i * 4 + 3) << 24 |
    pixels.getUint8(i * 4) << 16 |
    pixels.getUint8(i * 4 + 1) << 8 |
    pixels.getUint8(i * 4 + 2);

/// Each patch of [fill] in [pixels] (an image [width] wide, RGBA) and its
/// most contrasting pixel, largest patch first, with its box's left edge
/// (a changed line's band left of the code is the gutter's). A patch's
/// bounding box is read with the boxes of the [inside] fills' patches left
/// out (a changed line's band holds its changed words' boxes, whose text
/// is theirs), so what is left is the fill and the text drawn on it: the
/// most contrasting pixel is that text's colour, a glyph's core, which
/// antialiasing can only soften.
List<({double contrast, Color ink, Set<int> colors, int left})> _textOn(
  ByteData pixels,
  int width,
  Color fill, {
  List<Color> inside = const [],
}) {
  final masks = [
    for (final f in inside)
      for (final (_, box) in _patches(pixels, width, f)) box,
  ];
  bool masked(int x, int y) =>
      masks.any((m) => x >= m.x0 && x <= m.x1 && y >= m.y0 && y <= m.y1);
  final found =
      <(int, ({double contrast, Color ink, Set<int> colors, int left}))>[];
  for (final (size, box) in _patches(pixels, width, fill)) {
    var (most, ink) = (1.0, fill);
    final colors = <int>{};
    for (var y = box.y0; y <= box.y1; y++) {
      for (var x = box.x0; x <= box.x1; x++) {
        if (masked(x, y)) continue;
        final c = Color(_at(pixels, y * width + x));
        colors.add(c.toARGB32());
        final r = contrast(c, fill);
        if (r > most) (most, ink) = (r, c);
      }
    }
    found.add((size, (contrast: most, ink: ink, colors: colors, left: box.x0)));
  }
  found.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, patch) in found) patch];
}

/// What the box shows, at four times its size.
Future<(ByteData, int)> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('box')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 4);
    try {
      final bytes = await image.toByteData();
      return (bytes!, image.width);
    } finally {
      image.dispose();
    }
  }))!;
}

/// Waits for the diff's code colours, which come from an isolate.
Future<void> _coloured(WidgetTester tester) async {
  final split = find.byType(SideBySideDiff);
  final lines = split.evaluate().isNotEmpty
      ? tester.widget<SideBySideDiff>(split).controller.lines
      : tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).controller.lines;
  await untilReal(
    tester,
    () => lines.lineAt(PaneSide.neu, 0)!.syntax.isNotEmpty,
  );
  await tester.pump();
}

/// The diff's theme as the box drew it.
DiffThemeData _theme(WidgetTester tester) {
  final split = find.byType(SideBySideDiff);
  return split.evaluate().isNotEmpty
      ? tester.widget<SideBySideDiff>(split).theme
      : tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).theme;
}

/// [c]'s hue, in degrees.
double _hue(Color c) => HSLColor.fromColor(c).hue;

void main() {
  setUpAll(loadFonts);

  testWidgets('a comment on an inserted word reads in Tokyo Night as its '
      'comments do on the plain background, unified', (tester) async {
    viewport(tester, const Size(760, 200));
    diffUnified.value = true;
    await tester.pumpWidget(_box(tokyoNightDark, _oneWord));
    await tester.pumpAndSettle();
    await _coloured(tester);
    final theme = _theme(tester);
    final comment = tokyoNightDark.syntax[Capture.comment]!.color;
    final own = contrast(comment, theme.background);
    expect(
      own,
      inInclusiveRange(2.7, 3),
      reason: 'about 2.8, its comments on the background',
    );
    final (pixels, width) = await _pixels(tester);
    final word = Color.alphaBlend(theme.insertedWord, theme.insertedLine);
    for (final (what, fill, inside) in [
      ('an inserted word', word, <Color>[]),
      ('an inserted line', theme.insertedLine, [word]),
    ]) {
      // Before, the comment all but vanished there.
      expect(contrast(comment, fill), lessThan(own - 0.5));
      final patches = _textOn(pixels, width, fill, inside: inside);
      expect(patches, isNotEmpty, reason: '$what is painted');
      // Every patch of the code holds only comment; one at the image's
      // left edge is the gutter's, under the line numbers.
      for (final p in patches.where((p) => p.left > 0)) {
        expect(
          p.contrast,
          inInclusiveRange(own - 0.1, own + 0.3),
          reason: 'the comment on $what reads ${p.contrast}:1',
        );
        // Only its lightness moved: still the comment's blue-grey.
        expect(
          (_hue(p.ink) - _hue(comment)).abs(),
          lessThan(6),
          reason: 'the comment on $what keeps its hue',
        );
      }
    }
  }, variant: onMac);

  testWidgets('a colour that reads over 3:1 on the background is lifted '
      'to 3:1 on a tint, not to its own contrast', (tester) async {
    viewport(tester, const Size(760, 200));
    diffUnified.value = true;
    await tester.pumpWidget(_box(tokyoNightDark, _oneWord));
    await tester.pumpAndSettle();
    final theme = _theme(tester);
    // A made-up comment colour, the theme's own lightened until it reads
    // 3.8:1 on the background: over the floor there, under it on a tint.
    // With the floor at 4.5 it would be lifted to 3.8, its own contrast.
    final hsl = HSLColor.fromColor(
      tokyoNightDark.syntax[Capture.comment]!.color,
    );
    var (lo, hi) = (hsl.lightness, 1.0);
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (contrast(hsl.withLightness(mid).toColor(), theme.background) < 3.8) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final comment = hsl.withLightness(hi).toColor();
    final own = contrast(comment, theme.background);
    expect(own, inInclusiveRange(3.7, 3.9));
    final word = Color.alphaBlend(theme.insertedWord, theme.insertedLine);
    expect(contrast(comment, word), lessThan(3));
    final tokens = withColors(tokyoNightDark, {'syntax.comment': comment});
    await tester.pumpWidget(_box(tokens, _oneWord));
    await tester.pumpAndSettle();
    await _coloured(tester);
    final (pixels, width) = await _pixels(tester);
    final patches = _textOn(pixels, width, word);
    expect(patches, isNotEmpty, reason: 'an inserted word is painted');
    for (final p in patches) {
      expect(
        p.contrast,
        inInclusiveRange(2.9, 3.3),
        reason: 'the comment on an inserted word reads ${p.contrast}:1',
      );
    }
  }, variant: onMac);

  testWidgets('a token that already reads on a tint keeps its colour', (
    tester,
  ) async {
    viewport(tester, const Size(760, 200));
    diffUnified.value = true;
    await tester.pumpWidget(_box(tokyoNightDark, _added));
    await tester.pumpAndSettle();
    await _coloured(tester);
    final theme = _theme(tester);
    final keyword = tokyoNightDark.syntax[Capture.keyword]!.color;
    // `var` on the added line reads well over the floor there.
    expect(contrast(keyword, theme.insertedLine), greaterThan(3.5));
    final (pixels, width) = await _pixels(tester);
    final line = _textOn(pixels, width, theme.insertedLine);
    expect(
      line.any((p) => p.colors.contains(keyword.toARGB32())),
      isTrue,
      reason: 'the keyword is drawn in its own colour on an added line',
    );
  }, variant: onMac);

  for (final (name, tokens) in [
    ('Tokyo Night', tokyoNightDark),
    ('Tokyo Night Day', tokyoNightLight),
  ]) {
    testWidgets('a comment on a changed word reads in $name, side by side', (
      tester,
    ) async {
      viewport(tester, const Size(760, 200));
      await tester.pumpWidget(_box(tokens, _oneWord));
      await tester.pumpAndSettle();
      await _coloured(tester);
      final theme = _theme(tester);
      final comment = tokens.syntax[Capture.comment]!.color;
      final own = contrast(comment, theme.background);
      final target = own < 3 ? own : 3.0;
      final (pixels, width) = await _pixels(tester);
      for (final (what, fill, patches, inside) in [
        ('a changed word', theme.modifiedWord, 2, <Color>[]),
        ('an added line', theme.insertedLine, 1, [theme.modifiedWord]),
      ]) {
        expect(contrast(comment, fill), lessThan(target));
        final found = _textOn(pixels, width, fill, inside: inside);
        expect(
          found.length,
          greaterThanOrEqualTo(patches),
          reason: '$name: $what is painted',
        );
        for (final p in found.take(patches)) {
          // Just far enough: to the target, not past it.
          expect(
            p.contrast,
            inInclusiveRange(target - 0.1, target + 0.5),
            reason: '$name: the comment on $what reads ${p.contrast}:1',
          );
        }
      }
    }, variant: onMac);
  }

  testWidgets("a find's current hit and its other hits stay apart", (
    tester,
  ) async {
    viewport(tester, const Size(760, 260));
    final f = Find()..query = 'count';
    addTearDown(f.dispose);
    await tester.pumpWidget(_box(tokyoNightLight, _found, find: f));
    await tester.pumpAndSettle();
    await _coloured(tester);
    await tester.pumpAndSettle();
    expect(f.hits, isNotEmpty);
    final theme = _theme(tester);
    final (pixels, width) = await _pixels(tester);
    // Every hit on an unchanged line is on the same fill: only its text
    // says which is current.
    final hits = _textOn(
      pixels,
      width,
      Color.alphaBlend(theme.modifiedWord, theme.background),
    );
    double apart(Color a, Color b) {
      final d = (_hue(a) - _hue(b)).abs();
      return d > 180 ? 360 - d : d;
    }

    const t = tokyoNightLight;
    final now = [
      for (final p in hits)
        if (apart(p.ink, t.accentInk) < 30) p,
    ];
    final rest = [
      for (final p in hits)
        if (apart(p.ink, t.needs) < 30) p,
    ];
    expect(hits.length, greaterThanOrEqualTo(4));
    expect(now, hasLength(1), reason: 'the current hit, in the accent');
    expect(rest, hasLength(hits.length - 1), reason: 'the others, amber');
    for (final p in hits) {
      expect(p.contrast, greaterThan(2.9), reason: 'it reads on the fill');
    }
  }, variant: onMac);

  // The made-up change in the Changes view with a find open, in every
  // built-in theme's both sets, unified and side by side wide, unified
  // narrow.
  for (final theme in builtInThemes) {
    for (final b in Brightness.values) {
      for (final (unified, width) in [
        (true, 1700.0),
        (false, 1700.0),
        (true, 720.0),
      ]) {
        final view = unified ? 'unified' : 'split';
        renderTest('the Changes view in ${theme.name}, $view, '
            '${width.round()} ${b.name}', (tester) async {
          showDetails.value = false;
          colorTheme.value = theme.id;
          diffUnified.value = unified;
          final fake = FakeDaemon([chat('c', 'claude', 'Tally')])
            ..chatItems['c'] = [userSays('u', 'Let Sum take a start.')]
            ..answer = (input) => switch (input) {
              GetFolderStatusRequest() => GetFolderStatusResponse(
                git: true,
                branch: 'feature',
                defaultBase: 'main',
              ),
              ListCommitsRequest() => ListCommitsResponse(),
              GetDiffRequest() => GetDiffResponse(files: [_change]),
              _ => null,
            };
          final d = await openApp(
            tester,
            fake,
            size: Size(width, 700),
            brightness: b,
          );
          await tester.tap(find.text('Changes'));
          await tester.pumpAndSettle();
          await _coloured(tester);
          d.chats['c']!.changesFind
            ..open()
            ..query = 'total';
          await tester.pumpAndSettle();
          await render(
            tester,
            find.byType(NushiApp),
            '${theme.id}_${view}_${width.round()}_${b.name}',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }
}
