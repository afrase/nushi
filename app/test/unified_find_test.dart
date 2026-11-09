import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Changes' ⌘F in the unified view (ADR 0107): every hit marked in its
// row, the current one apart, ⏎ to each, the split view's count, and a
// switch of views while it's open.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _old = '''
package calc

import "errors"

// Add returns a plus b.
func Add(a, b int) int {
	return a + b
}

// Sub returns a minus b.
func Sub(a, b int) int {
	return a - b
}

// Mul returns a times b.
func Mul(a, b int) int {
	return a * b
}

// Div returns a over b.
func Div(a, b int) (int, error) {
	if b == 0 {
		return 0, errors.New("divide by zero")
	}
	return a / b, nil
}
''';

final String _new = _old
    .replaceFirst(
      '''
func Sub(a, b int) int {
	return a - b
}''',
      '''
func Sub(a, b int) (int, error) {
	if b < 0 && a > math.MaxInt+b {
		return 0, errors.New("overflow")
	}
	return a - b, nil
}''',
    )
    .replaceFirst('import "errors"', 'import (\n\t"errors"\n\t"math"\n)');

Object? _answers(Object input) => switch (input) {
  GetFolderStatusRequest() => GetFolderStatusResponse(git: true),
  ListCommitsRequest() => ListCommitsResponse(),
  GetDiffRequest() => GetDiffResponse(
    files: [
      FileChange(
        path: 'calc/calc.go',
        status: 'modified',
        oldText: _old,
        newText: _new,
        added: 7,
        removed: 3,
      ),
    ],
  ),
  _ => null,
};

/// The hits of "errors", as (side, line, start): the deleted import, the
/// new import's line, the new error, and the unchanged one (its old side
/// marked but not counted).
const List<(PaneSide, int, int)> _steps = [
  (PaneSide.old, 2, 8),
  (PaneSide.neu, 3, 2),
  (PaneSide.neu, 15, 12),
  (PaneSide.neu, 28, 12),
];
const (PaneSide, int) _also = (PaneSide.old, 22);

/// Changes on its own, 1100 by [height], for chat c, with ⌘F's bar open
/// on "errors".
Future<(Daemon, ChatState)> _found(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
  double height = 300,
}) async {
  viewport(tester, Size(1100, height));
  final fake = FakeDaemon([])..answer = _answers;
  final chat = ChatState('c', '/x')..scope = 'uncommitted';
  addTearDown(() => chat.scope = null);
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    themed(
      ChangesView(chat: chat, daemon: d),
      tokens: tokens,
    ),
  );
  await tester.pumpAndSettle();
  chat.changesFind.open();
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(FindBar),
      matching: find.byType(EditableText),
    ),
    'errors',
  );
  await tester.pumpAndSettle();
  return (d, chat);
}

DiffViewController _controller(WidgetTester tester) =>
    find.byType(UnifiedDiff).evaluate().isNotEmpty
    ? tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).controller
    : tester.widget<SideBySideDiff>(find.byType(SideBySideDiff)).controller;

/// The find's marks on [line] of [side], as the view draws that line:
/// each (start, length, 'find' or 'findNow').
List<(int, int, String)> _marks(DiffViewController c, PaneSide side, int line) {
  final syntax = c.lines.lineAt(side, line)!.syntax;
  return [
    for (var i = 0; i + 2 < syntax.length; i += 3)
      if (syntaxCaptures[syntax[i + 2]] case final name
          when name == 'find' || name == 'findNow')
        (syntax[i], syntax[i + 1], name),
  ];
}

/// The find's marks on unified [row], as drawn: of the line of the side
/// the row shows (an unchanged row the new side's).
List<(int, int, String)> _rowMarks(DiffViewController c, int row) {
  final rows = c.unifiedRows;
  final side = rows.textSideAt(row);
  return _marks(c, side, rows.lineAt(side, row));
}

/// The unified row of hit [i] of [_steps].
int _row(DiffViewController c, int i) =>
    c.unifiedRows.rowOf(_steps[i].$1, _steps[i].$2);

/// Whether unified [row] is inside the view, scrolled as it is.
bool _shown(DiffViewController c, int row) {
  final p = c.unifiedScroll.position;
  final top = c.unifiedGeometry.topOfRow(row);
  return top >= p.pixels &&
      top + c.resources.lineHeight <= p.pixels + p.viewportDimension;
}

/// Every hit's row marked, hit [now] as the current one, the rest not.
void _expectMarked(DiffViewController c, int now) {
  final rows = c.unifiedRows;
  for (var i = 0; i < _steps.length; i++) {
    final row = _row(c, i);
    expect(_rowMarks(c, row), [
      (_steps[i].$3, 6, i == now ? 'findNow' : 'find'),
    ], reason: 'hit $i, a ${rows.kindAt(row).name} row');
  }
}

void main() {
  setUpAll(loadFonts);

  testWidgets('every hit is marked in its unified row, the current one '
      "apart, and the count is the split view's", (tester) async {
    final (d, chat) = await _found(tester);
    expect(find.byType(SideBySideDiff), findsOne);
    expect(find.text('1 of 4'), findsOne);
    final split = chat.changesFind.hits;
    diffUnified.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(UnifiedDiff), findsOne);
    expect(find.text('1 of 4'), findsOne);
    expect(chat.changesFind.hits, split);
    final c = _controller(tester);
    final rows = c.unifiedRows;
    // One row of each kind among the hits.
    expect(
      [for (var i = 0; i < _steps.length; i++) rows.kindAt(_row(c, i))],
      [
        UnifiedRowKind.deleted,
        UnifiedRowKind.inserted,
        UnifiedRowKind.inserted,
        UnifiedRowKind.context,
      ],
    );
    _expectMarked(c, 0);
    // The unchanged line's other side is marked too, though the unified
    // view shows only its new side.
    expect(_marks(c, _also.$1, _also.$2), [(12, 6, 'find')]);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⏎ goes to each hit in the unified view, scrolled to it, '
      'and round to the first', (tester) async {
    diffUnified.value = true;
    final (d, _) = await _found(tester);
    final c = _controller(tester);
    for (var i = 0; i < _steps.length; i++) {
      expect(find.text('${i + 1} of 4'), findsOne);
      expect(_shown(c, _row(c, i)), isTrue, reason: 'hit $i in view');
      _expectMarked(c, i);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }
    expect(find.text('1 of 4'), findsOne);
    expect(_shown(c, _row(c, 0)), isTrue);
    expect(c.unifiedScroll.position.pixels, 0);
    // ⇧⏎ back to the unchanged line's hit, at the end.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('4 of 4'), findsOne);
    expect(_shown(c, _row(c, 3)), isTrue);
    _expectMarked(c, 3);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a switch of views keeps the marks and the current hit, '
      'where it was', (tester) async {
    final (d, chat) = await _found(tester);
    final c = _controller(tester);
    // The unchanged line's hit, then the deleted line's (rows inserted
    // below it in the unified view): each current across both switches,
    // at the same height.
    for (final (at, now) in [(3, 3), (1, 0)]) {
      chat.changesFind.step(at);
      await tester.pumpAndSettle();
      expect(find.text('${now + 1} of 4'), findsOne);
      final (side, line, _) = _steps[now];
      final y = c.viewportYOfLine(side, line);
      for (final unified in [true, false]) {
        diffUnified.value = unified;
        await tester.pumpAndSettle();
        expect(find.byType(unified ? UnifiedDiff : SideBySideDiff), findsOne);
        expect(_controller(tester), same(c), reason: 'the same view model');
        expect(find.text('${now + 1} of 4'), findsOne);
        _expectMarked(c, now);
        expect(
          c.viewportYOfLine(side, line),
          y,
          reason: 'hit $now where it was, unified: $unified',
        );
      }
    }
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a switch away from the current hit doesn't go back to it", (
    tester,
  ) async {
    diffUnified.value = true;
    final (d, _) = await _found(tester);
    final c = _controller(tester);
    // Scrolled from the first hit to the end.
    final p = c.unifiedScroll.position;
    p.jumpTo(p.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(_shown(c, _row(c, 0)), isFalse);
    diffUnified.value = false;
    await tester.pumpAndSettle();
    final y = c.viewportYOfLine(PaneSide.old, 2)!;
    expect(y, lessThan(0), reason: 'still scrolled past it');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('closing the bar takes the unified marks', (tester) async {
    diffUnified.value = true;
    final (d, _) = await _found(tester);
    final c = _controller(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsNothing);
    for (var i = 0; i < _steps.length; i++) {
      expect(_rowMarks(c, _row(c, i)), isEmpty);
    }
    expect(_marks(c, _also.$1, _also.$2), isEmpty);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    testWidgets('golden: find in the unified view ($name)', (tester) async {
      diffUnified.value = true;
      final (d, chat) = await _found(tester, tokens: tokens, height: 460);
      // The second hit current: the deleted line's above it, the new
      // error's below, each marked.
      chat.changesFind.step(1);
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsOne);
      await expectLater(
        find.byType(ChangesView),
        matchesGoldenFile('goldens/unified_find_$name.png'),
      );
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('renders: find in Changes unified, 1700 and 720 wide '
        '($name)', (tester) async {
      final fake = FakeDaemon([chat('c', 'claude', 'Calc')])..answer = _answers;
      final d = await fake.connect(tester);
      d.select('c');
      final c = d.chats['c']!..tab.value = ChatTab.changes;
      diffUnified.value = true;
      for (final width in [1700.0, 720.0]) {
        viewport(tester, Size(width, 760), brightness: brightness);
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        if (c.changesFind.query == null) {
          c.changesFind.open();
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(FindBar),
              matching: find.byType(EditableText),
            ),
            'errors',
          );
          await tester.pumpAndSettle();
          c.changesFind.step(3);
          await tester.pumpAndSettle();
        }
        expect(find.text('4 of 4'), findsOne);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'find_unified_${width.toInt()}_$name',
        );
      }
      await closeView(tester, d);
    }, variant: _mac);
  }
}
