import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
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
import 'fill_pixels.dart';
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
    final (pixels, width) = await boxPixels(tester);
    final word = Color.alphaBlend(theme.insertedWord, theme.insertedLine);
    for (final (what, fill, inside) in [
      ('an inserted word', word, <Color>[]),
      ('an inserted line', theme.insertedLine, [word]),
    ]) {
      // Before, the comment all but vanished there.
      expect(contrast(comment, fill), lessThan(own - 0.5));
      final patches = textOn(pixels, width, fill, inside: inside);
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
    final (pixels, width) = await boxPixels(tester);
    final patches = textOn(pixels, width, word);
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
    final (pixels, width) = await boxPixels(tester);
    final line = textOn(pixels, width, theme.insertedLine);
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
      final (pixels, width) = await boxPixels(tester);
      for (final (what, fill, patches, inside) in [
        ('a changed word', theme.modifiedWord, 2, <Color>[]),
        ('an added line', theme.insertedLine, 1, [theme.modifiedWord]),
      ]) {
        expect(contrast(comment, fill), lessThan(target));
        final found = textOn(pixels, width, fill, inside: inside);
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
    final (pixels, width) = await boxPixels(tester);
    // Every hit on an unchanged line is on the same fill: only its text
    // says which is current.
    final hits = textOn(
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
