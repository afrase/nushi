import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
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
}
