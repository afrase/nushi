import 'package:diff_view/diff_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Diffs side by side or unified (ADR 0107): Changes' switch, the one
// column for an added file and a narrow view, and what works on a diff
// working in the unified view.

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

const _added = '''
package calc

// Neg returns minus a.
func Neg(a int) int {
	return -a
}

// Abs returns a without its sign.
func Abs(a int) int {
	if a < 0 {
		return -a
	}
	return a
}
''';

final _modified = FileChange(
  path: 'calc/calc.go',
  status: 'modified',
  oldText: _old,
  newText: _new,
  added: 7,
  removed: 3,
);

final _addedFile = FileChange(
  path: 'calc/neg.go',
  status: 'added',
  newText: _added,
  added: 15,
);

Object? _answers(Object input) => switch (input) {
  GetFolderStatusRequest() => GetFolderStatusResponse(git: true),
  ListCommitsRequest() => ListCommitsResponse(),
  GetDiffRequest() => GetDiffResponse(files: [_modified, _addedFile]),
  _ => null,
};

/// Changes on its own, [size], for chat c.
Future<(Daemon, ChatState)> _changes(
  WidgetTester tester, {
  Size size = const Size(1100, 460),
  Tokens tokens = Tokens.dark,
}) async {
  viewport(tester, size);
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
  return (d, chat);
}

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.tap(find.textContaining(name, findRichText: true).first);
  await tester.pumpAndSettle();
}

bool _unified() => find.byType(UnifiedDiff).evaluate().isNotEmpty;

DiffViewController _controller(WidgetTester tester) =>
    tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).controller;

/// Where the unified view's line numbers show [row], on screen.
Offset _gutter(WidgetTester tester, int row) {
  final c = _controller(tester);
  final r = c.resources;
  final y =
      c.unifiedGeometry.topOfRow(row) -
      c.unifiedScroll.position.pixels +
      r.lineHeight / 2;
  return tester.getTopLeft(find.byType(UnifiedDiff)) +
      Offset(r.unifiedGutter.numberRight - 4, y);
}

/// Drags over the unified view's line numbers from row [from] to [to].
Future<void> _dragRows(WidgetTester tester, int from, int to) async {
  final drag = await tester.startGesture(
    _gutter(tester, from),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await drag.moveTo(_gutter(tester, to));
  await tester.pump();
  await drag.up();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets("Changes' switch shows the diff unified, and is remembered", (
    tester,
  ) async {
    final (d, _) = await _changes(tester);
    expect(find.byType(SideBySideDiff), findsOne);
    await tester.tap(find.byTooltip('Show unified'));
    await tester.pumpAndSettle();
    expect(_unified(), isTrue);
    expect(diffUnified.value, isTrue);
    expect(readSaved()['unified'], isTrue);
    expect(find.byTooltip('Show side by side'), findsOne);
    await tester.tap(find.byTooltip('Show side by side'));
    await tester.pumpAndSettle();
    expect(find.byType(SideBySideDiff), findsOne);
    expect(readSaved()['unified'], isFalse);
    await closeView(tester, d);
  });

  testWidgets('an added file shows one column; the switch stays as it was', (
    tester,
  ) async {
    final (d, _) = await _changes(tester);
    await _pick(tester, 'neg.go');
    expect(_unified(), isTrue);
    expect(diffUnified.value, isFalse);
    expect(find.byTooltip('Show unified'), findsOne);
    await _pick(tester, 'calc.go');
    expect(find.byType(SideBySideDiff), findsOne);
    await closeView(tester, d);
  });

  testWidgets('a deleted file shows one column too', (tester) async {
    await tester.pumpWidget(
      themed(
        DiffBox(
          FileChange(path: 'gone.go', status: 'deleted', oldText: _added),
          fit: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_unified(), isTrue);
  });

  testWidgets('a diff narrower than two panes need shows one column', (
    tester,
  ) async {
    // 720 wide: the file list leaves the diff under oneColumnBelow.
    final (d, _) = await _changes(tester, size: const Size(720, 460));
    expect(diffUnified.value, isFalse);
    expect(_unified(), isTrue);
    // The switch would change nothing here: the bar leaves it out.
    expect(find.byTooltip('Show unified'), findsNothing);
    viewport(tester, const Size(1100, 460));
    await tester.pumpAndSettle();
    expect(find.byType(SideBySideDiff), findsOne);
    expect(find.byTooltip('Show unified'), findsOne);
    await closeView(tester, d);
  });

  testWidgets('View menu and palette switch it', (tester) async {
    viewport(tester, const Size(1700, 700));
    final fake = FakeDaemon([chat('c', 'claude', 'Calc')])..answer = _answers;
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    List<String> viewMenu({String? pick}) {
      final view = tester
          .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
          .menus
          .whereType<PlatformMenu>()
          .firstWhere((m) => m.label == 'View');
      Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
        PlatformMenuItemGroup(:final members) => members.expand(items),
        _ => [m],
      };
      final all = view.menus.expand(items).toList();
      if (pick != null) all.firstWhere((m) => m.label == pick).onSelected!();
      return [for (final m in all) m.label];
    }

    viewMenu(pick: 'Show Diffs Unified');
    await tester.pumpAndSettle();
    expect(diffUnified.value, isTrue);
    expect(viewMenu(), contains('Show Diffs Side by Side'));
    final context = tester.element(find.byType(Scaffold).first);
    final act = appActions(
      context,
      d,
    ).firstWhere((a) => a.act == Act.unifiedDiff);
    expect(act.title, 'Show diffs side by side');
    act.run();
    expect(diffUnified.value, isFalse);
    await closeView(tester, d);
  }, variant: _mac);

  test('unified rows stand for lines of one side, as a comment is', () {
    final doc = TextDiff.compute('a\nb\nc\nd\n', 'a\nB\nC\nd\n').document;
    final rows = UnifiedRows.build(doc);
    // Rows: a, -b, -c, +B, +C, d.
    LineSelection pick(int from, int to) =>
        linesOfRows(rows, ModelSpan(from, to));
    expect(
      pick(0, 3),
      const LineSelection(side: PaneSide.old, anchor: 0, focus: 2),
    );
    expect(
      pick(1, 5),
      const LineSelection(side: PaneSide.neu, anchor: 1, focus: 2),
    );
    expect(
      pick(4, 6),
      const LineSelection(side: PaneSide.neu, anchor: 2, focus: 3),
    );
    // Deleted rows then an unchanged one keep the deleted lines.
    final cut = UnifiedRows.build(
      TextDiff.compute('a\nb\nc\n', 'a\nc\n').document,
    );
    // Rows: a, -b, c.
    expect(
      linesOfRows(cut, const ModelSpan(1, 3)),
      const LineSelection(side: PaneSide.old, anchor: 1, focus: 2),
    );
  });

  testWidgets('lines picked in the unified view take a review comment', (
    tester,
  ) async {
    diffUnified.value = true;
    addTearDown(() => setComments('c', []));
    await tester.pumpWidget(
      themed(
        DiffBox(
          _modified,
          fit: false,
          review: (chat: 'c', where: 'uncommitted', agent: 'Claude'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final c = _controller(tester);
    final rows = c.unifiedRows;
    // From the first deleted row through the inserted ones: the new side.
    final first = rows.rowOf(PaneSide.old, 10);
    final last = rows.rowOf(PaneSide.neu, 18);
    expect(rows.kindAt(first), UnifiedRowKind.deleted);
    await _dragRows(tester, first, last);
    expect(find.byType(ReviewCommentBox), findsOne);
    final from = rows.linesIn(ModelSpan(first, last + 1)).neu.start;
    expect(find.text('Lines ${from + 1}–19'), findsOne);
    await tester.enterText(
      find.descendant(
        of: find.byType(ReviewCommentBox),
        matching: find.byType(EditableText),
      ),
      'Why an error?',
    );
    await tester.tap(find.text('Comment'));
    await tester.pumpAndSettle();
    final made = commentsOf('c').single;
    expect((made.old, made.start, made.end), (false, from + 1, 19));
    // It shows under its last row.
    expect(find.text('Why an error?'), findsOne);
    expect(c.unifiedSlotOf(c.inlays.single), last + 1);
  });

  testWidgets('a selection in the unified view copies its text', (
    tester,
  ) async {
    diffUnified.value = true;
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
    await tester.pumpWidget(themed(DiffBox(_addedFile, fit: false)));
    await tester.pumpAndSettle();
    await _dragRows(tester, 2, 4);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(
      copied.single,
      '// Neg returns minus a.\nfunc Neg(a int) int {\n'
      '\treturn -a\n',
    );
  }, variant: _mac);

  testWidgets('a finding opens the unified view at its line, selected', (
    tester,
  ) async {
    diffUnified.value = true;
    viewport(tester, const Size(1100, 300));
    final fake = FakeDaemon([])..answer = _answers;
    final chat = ChatState('c', '/x')..scope = 'uncommitted';
    addTearDown(() => chat.scope = null);
    final d = await fake.connect(tester);
    chat.showFile('calc/calc.go', line: 26);
    await tester.pumpWidget(themed(ChangesView(chat: chat, daemon: d)));
    await tester.pumpAndSettle();
    final c = _controller(tester);
    final row = c.unifiedRows.rowOf(PaneSide.neu, 25);
    expect(c.unifiedSelection.value!.span, ModelSpan(row, row + 1));
    final y = c.viewportYOfLine(PaneSide.neu, 25)!;
    expect(y, inInclusiveRange(0, c.unifiedScroll.position.viewportDimension));
    expect(c.unifiedScroll.position.pixels, greaterThan(0));
    await closeView(tester, d);
  });

  testWidgets('find goes through the unified view, scrolled to each hit', (
    tester,
  ) async {
    diffUnified.value = true;
    final (d, chat) = await _changes(tester, size: const Size(1100, 300));
    final find_ = chat.changesFind..open();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(FindBar),
        matching: find.byType(EditableText),
      ),
      'errors',
    );
    await tester.pumpAndSettle();
    // The import's two lines, the new error and the unchanged one, in the
    // order the unified view shows them.
    expect(find.text('1 of 4'), findsOne);
    final c = _controller(tester);
    expect(
      [for (final h in find_.hits) h.split(':').take(2).join(':')],
      ['0:2', '1:3', '1:15', '1:28'],
    );
    // The last hit, near the end: the view scrolls down to it.
    find_
      ..step(1)
      ..step(1)
      ..step(1);
    await tester.pumpAndSettle();
    expect(find.text('4 of 4'), findsOne);
    final last = c.unifiedRows.rowOf(PaneSide.neu, 28);
    final top = c.unifiedGeometry.topOfRow(last);
    final p = c.unifiedScroll.position;
    expect(p.pixels, greaterThan(0));
    expect(top, inInclusiveRange(p.pixels, p.pixels + p.viewportDimension));
    await closeView(tester, d);
  });

  for (final (name, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    testWidgets('goldens: a modified file unified, an added file ($name)', (
      tester,
    ) async {
      diffUnified.value = true;
      final (d, _) = await _changes(tester, tokens: tokens);
      await expectLater(
        find.byType(ChangesView),
        matchesGoldenFile('goldens/unified_modified_$name.png'),
      );
      // Side by side picked: an added file is still one column.
      diffUnified.value = false;
      await _pick(tester, 'neg.go');
      await expectLater(
        find.byType(ChangesView),
        matchesGoldenFile('goldens/unified_added_$name.png'),
      );
      await closeView(tester, d);
    });

    testWidgets('renders: Changes unified, 1700 and 720 wide ($name)', (
      tester,
    ) async {
      final fake = FakeDaemon([chat('c', 'claude', 'Calc')])..answer = _answers;
      final d = await fake.connect(tester);
      d.select('c');
      d.chats['c']!.tab.value = ChatTab.changes;
      for (final width in [1700.0, 720.0]) {
        viewport(tester, Size(width, 760), brightness: brightness);
        for (final unified in [false, true]) {
          diffUnified.value = unified;
          await tester.pumpWidget(NushiApp(daemon: d));
          await tester.pumpAndSettle();
          final w = width.toInt();
          await render(
            tester,
            find.byType(NushiApp),
            'changes_${unified ? 'unified' : 'split'}_${w}_$name',
          );
        }
        await _pick(tester, 'neg.go');
        await render(
          tester,
          find.byType(NushiApp),
          'changes_added_${width.toInt()}_$name',
        );
        await _pick(tester, 'calc.go');
      }
      await closeView(tester, d);
    }, variant: _mac);
  }
}
