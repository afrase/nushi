import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  final files = [
    for (final p in [
      'app/lib/theme/a.dart',
      'app/lib/theme/b.dart',
      'app/lib/x.dart',
      'docs/deep/only/c.md',
      'main.go',
    ])
      FileChange(path: p, added: 2, removed: 1),
  ];

  String show(List<ChangeRow> rows) =>
      rows.map((r) => '${'  ' * r.depth}${r.name} +${r.added}').join('\n');

  test('a tree with single-folder chains joined, folders first', () {
    expect(show(changeRows(files, flat: false)), '''
app/lib +6
  theme +4
    a.dart +2
    b.dart +2
  x.dart +2
docs/deep/only +2
  c.md +2
main.go +2''');
  });

  test('collapsed folders hide what is inside; flat lists paths', () {
    expect(
      show(changeRows(files, flat: false, collapsed: {'app/lib/theme'})),
      startsWith('app/lib +6\n  theme +4\n  x.dart +2\n'),
    );
    expect(changeRows(files, flat: true).map((r) => r.name), [
      for (final f in files) f.path,
    ]);
  });

  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('a long name scrolls sideways, never cut', (tester) async {
    await _pane(tester);
    final sideways = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(sideways.position.maxScrollExtent, greaterThan(100));
    for (final p
        in tester
            .renderObjectList<RenderParagraph>(find.byType(RichText))
            .where((p) => p.text.toPlainText().contains('+'))) {
      expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
      expect(p.size.width, closeTo(p.getMaxIntrinsicWidth(1e6), 0.5));
    }
    // The longest name, whole, with its counts after it.
    expect(
      find.text(
        'rolling_reserves_total_cents_calculator.rb  +120 −48',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // A sideways scroll (a trackpad's, or shift and the wheel).
    final at = tester.getCenter(find.byType(FileList));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: at, scrollDelta: const Offset(80, 0)),
    );
    await tester.pump();
    expect(sideways.offset, 80);
  }, variant: mac);

  testWidgets('the selected row is highlighted across the whole width', (
    tester,
  ) async {
    await _pane(tester);
    final tap = find.ancestor(
      of: find.textContaining('short.rb', findRichText: true),
      matching: find.byType(Container),
    );
    final widest = tester.getSize(find.byType(SingleChildScrollView)).width;
    expect(tester.getSize(tap.first).width, greaterThan(widest));
  });

  testWidgets('selecting by mouse and by keyboard', (tester) async {
    final picked = await _pane(tester);
    await tester.tap(find.text('README.md  +120 −48', findRichText: true));
    expect(picked, ['README.md']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    // From the selected one, short.rb, up and down the tree.
    expect(picked.last, _long[0]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(picked.last, _long[2]);
  });

  setUpAll(loadFonts);
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the tree scrolled sideways ($name)', (tester) async {
      await _pane(tester, tokens: tokens);
      final sideways = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!;
      // Scrolled, and the pointer near the bottom: the sideways scrollbar.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(120, 100));
      addTearDown(mouse.removePointer);
      sideways.jumpTo(60);
      await tester.pump();
      await mouse.moveTo(const Offset(120, 195));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/file_tree_$name.png'),
      );
    }, variant: mac);
  }
}

const _deep = 'app/lib/features/settlements/rolling_reserves';
const _long = [
  '$_deep/rolling_reserves_total_cents_calculator.rb',
  '$_deep/short.rb',
  'spec/rolling_reserves_spec.rb',
  'README.md',
];

/// A [FileList] of [_long] as a tree in a pane 240 wide, `short.rb`
/// selected with two review comments; what's picked is returned.
Future<List<String>> _pane(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  viewport(tester, const Size(240, 200));
  final picked = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NativeScroll(),
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        backgroundColor: tokens.raised,
        body: FileList(
          files: [
            for (final p in _long)
              FileChange(path: p, added: 120, removed: 48, status: 'modified'),
          ],
          selected: _long[1],
          onSelect: picked.add,
          marks: {_long[1]: 2},
        ),
      ),
    ),
  );
  return picked;
}
