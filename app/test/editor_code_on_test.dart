import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/editor_find.dart';
import 'package:nushi/editor_ink.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:re_editor/re_editor.dart';

import 'editor_code_runs.dart';
import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';

// Code under the fills the file editor paints (issue 117): its find's
// hits, the current one (the selection), the selection and a hit over it
// keep the contrast each colour has on the plain background, up to 3:1,
// by lightness alone (ADR 0086's amendment), in every built-in set. Read
// off the pixels, word by word: each word's brightest pixel against the
// fill it's on.

void main() {
  setUpAll(loadFonts);

  for (final theme in builtInThemes) {
    for (final b in Brightness.values) {
      final set = '${theme.name} ${b.name}';
      testWidgets("code keeps its contrast under the editor's hits, its "
          'selection and a hit over it, in $set', (tester) async {
        final d = await openOnInt(tester, theme.id, b);
        final t = NushiTheme.of(tester.element(find.byType(CodeEditor))).t;
        // The current match is the selection; the others are hits.
        final c = editOf(d).controller..selection = barFindOf(tester).match!;
        await tester.pumpAndSettle();
        final found = await measureRuns(tester, d);
        // Then every line selected: the hits are over the selection.
        c.selection = CodeLineSelection(
          baseIndex: 0,
          baseOffset: 0,
          extentIndex: c.codeLines.length - 1,
          extentOffset: c.codeLines.last.length,
        );
        await tester.pumpAndSettle();
        final all = await measureRuns(tester, d);
        final runs = [...found, ...all];
        expectRule(runs, t.base, set);
        // The dimmest of the set's code colours is drawn on each fill.
        final dimmest = t.syntax.values
            .map((i) => i.color)
            .reduce(
              (a, b) => contrast(a, t.base) <= contrast(b, t.base) ? a : b,
            );
        final fills = {for (final r in runs) r.fill};
        // The plain background, a hit's, the selection's (the current
        // match's too) and a hit's over it.
        expect(fills, hasLength(4));
        for (final fill in fills.where((f) => f != t.base)) {
          expect(
            runs.where((r) => r.fill == fill && r.color == dimmest),
            isNotEmpty,
            reason: '$set: the dimmest code on $fill',
          );
        }
        await endEditor(tester, d);
      }, variant: onMac);
    }
  }

  testWidgets('code a find leaves, as it looks for another word or '
      'closes, is drawn as published again', (tester) async {
    final d = await openOnInt(tester, 'tokyo-night', Brightness.dark);
    final t = NushiTheme.of(tester.element(find.byType(CodeEditor))).t;
    editOf(d).controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 0,
    );
    await tester.pumpAndSettle();
    void expectAsPublished(List<CodeRun> runs, String when) {
      final plain = runs.where((r) => r.fill == t.base).toList();
      expect(plain.where((r) => r.text == 'int'), isNotEmpty);
      for (final r in plain) {
        expect(
          r.contrast,
          closeTo(contrast(r.color, t.base), 0.1),
          reason: '$when, "${r.text}" is in its own colour',
        );
      }
    }

    final f = barFindOf(tester)..query = 'tally';
    await untilReal(tester, () => !f.looking);
    await tester.pumpAndSettle();
    expectAsPublished(await measureRuns(tester, d), 'looking for another');
    f.close();
    await tester.pumpAndSettle();
    expectAsPublished(await measureRuns(tester, d), 'closed');
    await endEditor(tester, d);
  }, variant: onMac);

  for (final wrap in [false, true]) {
    final how = wrap ? 'down a long wrapped line' : 'sideways on a long line';
    testWidgets('a hit scrolled into sight $how reads by the rule as it '
        'shows', (tester) async {
      wrapLines.value = wrap;
      // A comment far longer than the window (each "int" a hit, in Tokyo
      // Night's dim comment colour), below where the find bar sits.
      final comment = '// ${List.filled(3000, 'int count').join(' ')}';
      final d = await openOnInt(
        tester,
        'tokyo-night',
        Brightness.dark,
        code: 'package tally\n${'\n' * 8}$comment\n\nfunc main() {}\n',
      );
      final t = NushiTheme.of(tester.element(find.byType(CodeEditor))).t;
      final bar = tester.widget<EditorFindBar>(find.byType(EditorFindBar));
      final scroll = wrap ? bar.down : bar.lines.across;
      final screen = scroll.position.viewportDimension;
      final hit = Color.alphaBlend(findColors(t).hit, t.base);
      // Far past the hits painted (half a screen past what showed): each
      // frame as it comes, what shows reads by the rule, a hit painted or
      // not; and once the hits there are painted, they read too.
      scroll.jumpTo(screen * 3);
      var shown = <CodeRun>[];
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump();
        final runs = await measureRuns(tester, d);
        expectRule(runs, t.base, 'frame $frame');
        if (runs.any((r) => r.fill == hit)) shown = runs;
      }
      expect(scroll.position.pixels, screen * 3);
      final comments = t.syntax[Capture.comment]!.color;
      expect(
        shown.where((r) => r.fill == hit && r.color == comments),
        isNotEmpty,
      );
      // Find closed: the comment is as published again, every word.
      barFindOf(tester).close();
      for (var frame = 0; frame < 2; frame++) {
        await tester.pump();
        final runs = await measureRuns(tester, d);
        expect(runs.where((r) => r.color == comments), isNotEmpty);
        expectRule(runs, t.base, 'closed, frame $frame');
      }
      await endEditor(tester, d);
    }, variant: onMac);
  }

  // A selection longer than the window, drawn on its fill whole: far
  // jumps sideways (a scrollbar's drag does one each frame) show its code
  // inked from the first frame, with find open and closed.
  for (final closed in [false, true]) {
    final how = closed ? 'find closed' : 'find open';
    testWidgets('a long selection reads by the rule in every frame of far '
        'jumps and a drag of the scrollbar, $how', (tester) async {
      wrapLines.value = false;
      // A comment far longer than the window, each "int" a hit, in Tokyo
      // Night's dim comment colour, below where the find bar sits.
      final comment = '// ${List.generate(3000, (i) => 'int c$i').join(' ')}';
      final d = await openOnInt(
        tester,
        'tokyo-night',
        Brightness.dark,
        code: 'package tally\n${'\n' * 8}$comment\n\nfunc main() {}\n',
      );
      final t = NushiTheme.of(tester.element(find.byType(CodeEditor))).t;
      final bar = tester.widget<EditorFindBar>(find.byType(EditorFindBar));
      if (closed) {
        bar.find.close();
        await tester.pumpAndSettle();
      }
      final selection = Color.alphaBlend(
        editorSelectionColor(tester.element(find.byType(CodeEditor))),
        t.base,
      );
      final across = bar.lines.across;
      final screen = across.position.viewportDimension;
      final c = editOf(d).controller;
      Future<void> framesAt(double x, String when, {int n = 3}) async {
        across.jumpTo(x);
        for (var frame = 0; frame < n; frame++) {
          await tester.pump();
          final runs = await measureRuns(tester, d);
          final selected = runs.where((r) => r.fill != t.base);
          expect(
            selected.where((r) => r.fill == selection),
            isNotEmpty,
            reason: '$when, frame $frame: selected code in sight',
          );
          expectRule(runs, t.base, '$when, frame $frame');
        }
      }

      c.selection = CodeLineSelection(
        baseIndex: 9,
        baseOffset: 10,
        extentIndex: 9,
        extentOffset: comment.length,
      );
      await tester.pumpAndSettle();
      for (final k in [30, 8, 60, 2]) {
        await framesAt(screen * k, 'jumped $k screens');
      }
      // The whole file selected, a jump of four screens a frame.
      c.selection = CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: c.codeLines.length - 1,
        extentOffset: 0,
      );
      across.jumpTo(0);
      await tester.pumpAndSettle();
      for (var i = 1; i <= 12; i++) {
        await framesAt(screen * 4 * i, 'dragged to ${4 * i} screens', n: 1);
      }
      expect(across.position.pixels, screen * 48);
      await endEditor(tester, d);
    }, variant: onMac);
  }

  testWidgets('a line whose code reads on its fills keeps its spans', (
    tester,
  ) async {
    final d = await openOnInt(tester, 'nushi', Brightness.dark);
    final e = editOf(d);
    final context = tester.element(find.byType(CodeEditor));
    TextSpan line(int i) => e.controller.buildTextSpan(
      context: context,
      index: i,
      textSpan: const TextSpan(),
      style: const TextStyle(fontSize: 12),
    );
    // "package tally": a keyword and plain text, both far over the floor
    // on a hit; the comment's line has its hit drawn anew in Nushi's dark
    // set only if it needs to be.
    final plain = line(0);
    e.ink = null;
    expect(plain, line(0));
    await endEditor(tester, d);
  }, variant: onMac);
}
