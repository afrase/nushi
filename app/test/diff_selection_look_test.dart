import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
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

void main() {
  setUpAll(loadFonts);

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
