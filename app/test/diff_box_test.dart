import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

void main() {
  Widget box(FileChange c) => MaterialApp(
    theme: const NushiTheme(Tokens.dark).toThemeData(),
    home: Scaffold(body: DiffBox(c, fit: false)),
  );

  testWidgets('a long diff is computed off the UI thread', (tester) async {
    final old = [for (var i = 0; i < 3000; i++) 'line $i'].join('\n');
    final change = FileChange(
      path: 'a.txt',
      oldText: old,
      newText: '$old\nmore',
    );
    await tester.pumpWidget(box(change));
    expect(find.byType(Center), findsOneWidget); // still computing
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.byType(Center), findsNothing);
  });

  testWidgets('a change too long to diff says so', (tester) async {
    final huge = List.filled(maxDiffLines + 1, 'x').join('\n');
    final change = FileChange(
      path: 'a.lock',
      oldText: huge,
      newText: '$huge\ny',
    );
    await tester.pumpWidget(box(change));
    expect(find.textContaining('Too long to diff'), findsOneWidget);
    expect(lineCounts(change), (1, 0));
  });

  testWidgets('the same file in another view shows that view\'s comments', (
    tester,
  ) async {
    final change = FileChange(
      path: 'f.txt',
      oldText: 'a\nb\n',
      newText: 'a\nB\n',
    );
    setComments('c', [
      ReviewComment(
        id: '1',
        where: 'uncommitted',
        path: 'f.txt',
        old: false,
        start: 2,
        end: 2,
        quote: 'B',
        text: 'why?',
      ),
    ]);
    addTearDown(() => setComments('c', []));
    Widget view(String where) => MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: DiffBox(
          change,
          key: const ValueKey('f.txt'),
          fit: false,
          review: (chat: 'c', where: where),
        ),
      ),
    );
    await tester.pumpWidget(view('uncommitted'));
    await tester.pump();
    expect(find.text('why?'), findsOneWidget);
    await tester.pumpWidget(view('branch'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('why?'), findsNothing);
  });
}
