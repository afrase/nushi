import 'dart:math' as math;

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';

import 'diff_select.dart';
import 'fake_daemon.dart';
import 'github_fixture.dart' show openView;
import 'harness.dart';

// How selected code looks in a diff: in the app's selection colour, over
// a removed, a changed and an added line, in every theme; in the Changes
// view and a pull request's file at full size.

/// A made-up change: its first two lines changed, a line added further
/// down.
final _change = FileChange(
  path: 'total.go',
  oldText:
      'func total(xs []int) int {\n  sum := 0\n  for _, x := range xs {\n'
      '    sum += x\n  }\n  return sum\n}\n',
  newText:
      'func total(xs []int, start int) int {\n  sum := start\n'
      '  for _, x := range xs {\n    sum += x\n  }\n'
      '  log.Printf("total %d", sum)\n  return sum\n}\n',
  added: 3,
  removed: 2,
);

/// A side-by-side diff with its changed and added lines' code selected,
/// over a unified one with the removed, changed and added rows' selected.
Widget _boxes(Tokens tokens) => themed(
  tokens: tokens,
  banner: false,
  Builder(
    builder: (context) => Container(
      color: NushiTheme.of(context).t.base,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            width: 736,
            child: DiffBox(_change, key: const ValueKey('split')),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 480,
            child: DiffBox(_change, key: const ValueKey('unified')),
          ),
        ],
      ),
    ),
  ),
);

/// Selects the code of both boxes of [_boxes].
Future<void> _select(WidgetTester tester) async {
  diffController(
    tester,
    within: find.byKey(const ValueKey('split')),
  ).textSelection.select(
    const CodeSelection(
      side: PaneSide.neu,
      anchor: CodePosition(1, 2),
      focus: CodePosition(2, 21),
    ),
  );
  diffController(
    tester,
    within: find.byKey(const ValueKey('unified')),
  ).textSelection.select(
    const CodeSelection.unified(
      anchor: CodePosition(1, 2),
      focus: CodePosition(7, 12),
    ),
  );
  await tester.pumpAndSettle();
}

/// CIE76's distance between [a] and [b]: about 2 is the least an eye
/// tells apart side by side.
double _deltaE(Color a, Color b) {
  List<double> lab(Color c) {
    double lin(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) * 1.0;
    final (r, g, b) = (lin(c.r), lin(c.g), lin(c.b));
    double f(double t) =>
        t > 0.008856 ? math.pow(t, 1 / 3) * 1.0 : 7.787 * t + 16 / 116;
    final x = f((r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047);
    final y = f(r * 0.2126 + g * 0.7152 + b * 0.0722);
    final z = f((r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883);
    return [116 * y - 16, 500 * (x - y), 200 * (y - z)];
  }

  final (p, q) = (lab(a), lab(b));
  return math.sqrt(
    math.pow(p[0] - q[0], 2) +
        math.pow(p[1] - q[1], 2) +
        math.pow(p[2] - q[2], 2),
  );
}

void main() {
  setUpAll(loadFonts);

  // Selected code reads over every kind of line, and a selected changed
  // line is told from a changed word that isn't selected, in every theme's
  // both sets, in a pane and in a code block.
  test('selected code reads over every line in every theme', () {
    final failures = <String>[];
    for (final theme in builtInThemes) {
      for (final b in Brightness.values) {
        final t = theme.of(b);
        for (final (where, surface) in [
          ('pane', null),
          ('code', t.codeBlock),
        ]) {
          final d = diffTheme(t, surface: surface);
          Color over(Color line) => Color.alphaBlend(d.textSelection!, line);
          for (final (kind, line) in [
            ('added', d.insertedLine),
            ('removed', d.deletedLine),
            ('changed', d.modifiedLine),
          ]) {
            final c = contrast(d.text, over(line));
            if (c < 3) {
              failures.add(
                '${theme.id} ${b.name} $where $kind: text '
                '${c.toStringAsFixed(2)}:1',
              );
            }
          }
          final e = _deltaE(over(d.modifiedLine), d.modifiedWord);
          if (e < 5) {
            failures.add(
              '${theme.id} ${b.name} $where: a selected changed line is '
              '${e.toStringAsFixed(1)} from a changed word',
            );
          }
        }
      }
    }
    expect(failures, isEmpty);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, selected code in a diff, $name', (tester) async {
      viewport(tester, const Size(760, 430));
      await tester.pumpWidget(_boxes(tokens));
      await tester.pumpAndSettle();
      await _select(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/diff_selection_$name.png'),
      );
    }, variant: onMac);
  }

  // The selection over each kind of line, in every theme's both sets.
  for (final theme in builtInThemes) {
    for (final b in Brightness.values) {
      renderTest('selected code, ${theme.id} ${b.name}', (tester) async {
        viewport(tester, const Size(760, 430), ratio: 2);
        await tester.pumpWidget(_boxes(theme.of(b)));
        await tester.pumpAndSettle();
        await _select(tester);
        await render(
          tester,
          find.byType(MaterialApp),
          'diff_selection_${theme.id}_${b.name}',
        );
      }, variant: onMac);
    }
  }

  for (final width in [1700.0, 720.0]) {
    for (final b in Brightness.values) {
      renderTest('the Changes view, code selected over a changed and an '
          'added line, ${width.round()} ${b.name}', (tester) async {
        showDetails.value = false;
        final fake = FakeDaemon([chat('c', 'claude', 'Total')])
          ..chatItems['c'] = [userSays('u', 'Start the total at start.')]
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
        await dragCode(tester, from: (1, 2), to: (5, 12));
        await render(
          tester,
          find.byType(NushiApp),
          'changes_selection_${width.round()}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }

  for (final b in Brightness.values) {
    renderTest("a pull request's file, code selected over a comment box, "
        '${b.name}', (tester) async {
      final (_, d) = await openView(
        tester,
        size: const Size(1700, 900),
        window: true,
        tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
        more: (input) => input is GetGitHubFilesRequest
            ? GetGitHubFilesResponse(files: [_change])
            : null,
      );
      await tester.tap(find.text('Add Sub and Neg'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Files changed'));
      await tester.pumpAndSettle();
      await dragGutter(tester, 6, 6);
      await dragCode(tester, from: (1, 2), to: (5, 12));
      await render(
        tester,
        find.byType(NushiApp),
        'pull_file_selection_${b.name}',
      );
      await closeView(tester, d);
    }, variant: onMac);
  }
}
