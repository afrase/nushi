import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

String _text(String name, int lines) =>
    [for (var i = 1; i <= lines; i++) '// $name line $i'].join('\n');

/// A review's finding opens the chat's Changes at its file and line: a
/// changed file in the diff, any other as it is now.
void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a file opens at a line, changed or not ($name)', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(900, 420);
      addTearDown(tester.view.reset);
      final asked = <GetFileRequest>[];
      final fake = FakeDaemon([])
        ..answer = (input) => switch (input) {
          GetFolderStatusRequest() => GetFolderStatusResponse(git: true),
          ListCommitsRequest() => ListCommitsResponse(),
          GetDiffRequest() => GetDiffResponse(
            files: [
              FileChange(
                path: 'calc/calc.go',
                status: 'modified',
                oldText: _text('calc', 60),
                newText: _text('calc', 60).replaceFirst('line 40', 'line 40!'),
                added: 1,
                removed: 1,
              ),
            ],
          ),
          GetFileRequest() => () {
            asked.add(input);
            return GetFileResponse(
              file: FileChange(
                path: input.path,
                status: 'unchanged',
                oldText: _text('util', 90),
                newText: _text('util', 90),
              ),
            );
          }(),
          _ => null,
        };
      final chat = ChatState('c', '/x')..scope = 'uncommitted';
      addTearDown(() => chat.scope = null);
      final daemon = await fake.connect(tester);
      chat.showFile('calc/calc.go', line: 40);
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: ChangesView(chat: chat, daemon: daemon),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<DiffBox>(find.byType(DiffBox)).line, 40);
      expect(asked, isEmpty);

      chat.showFile('calc/util.go', line: 70);
      await tester.pumpAndSettle();
      expect(asked.single.folder, '/x');
      expect(find.text('calc/util.go has no changes here'), findsOne);
      final box = tester.widget<DiffBox>(find.byType(DiffBox));
      expect(
        (box.change.status, box.line, box.review),
        ('unchanged', 70, null),
      );
      await expectLater(
        find.byType(ChangesView),
        matchesGoldenFile('goldens/open_line_$name.png'),
      );

      // Picking a changed file leaves the one shown as it is.
      await tester.tap(
        find.textContaining('calc.go', findRichText: true).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('calc/util.go has no changes here'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      daemon.dispose();
    });
  }

  testWidgets("a file's late answer doesn't replace the one picked since", (
    tester,
  ) async {
    final later = Completer<GetFileResponse>();
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(git: true),
        ListCommitsRequest() => ListCommitsResponse(),
        GetDiffRequest() => GetDiffResponse(
          files: [
            FileChange(
              path: 'calc/calc.go',
              status: 'modified',
              oldText: _text('calc', 60),
              newText: _text('calc', 60).replaceFirst('line 40', 'line 40!'),
              added: 1,
              removed: 1,
            ),
          ],
        ),
        GetFileRequest() => later.future,
        _ => null,
      };
    final chat = ChatState('c', '/x')..scope = 'uncommitted';
    addTearDown(() => chat.scope = null);
    final daemon = await fake.connect(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: ChangesView(chat: chat, daemon: daemon),
        ),
      ),
    );
    await tester.pumpAndSettle();
    chat.showFile('calc/util.go', line: 70);
    await tester.pumpAndSettle();
    // calc.go picked while util.go is still being read.
    await tester.tap(find.textContaining('calc.go', findRichText: true).first);
    await tester.pumpAndSettle();
    later.complete(
      GetFileResponse(
        file: FileChange(
          path: 'calc/util.go',
          status: 'unchanged',
          oldText: _text('util', 90),
          newText: _text('util', 90),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('calc/util.go has no changes here'), findsNothing);
    expect(
      tester.widget<DiffBox>(find.byType(DiffBox)).change.path,
      'calc/calc.go',
    );
    await tester.pumpWidget(const SizedBox());
    daemon.dispose();
  });
}
