import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cards.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/tool_calls.dart';

import 'diff_select.dart';
import 'fake_daemon.dart';
import 'github_fixture.dart' show openView;
import 'harness.dart';

// Selecting text in each kind of diff the app shows, and copying it with
// the app's copy key wherever the diff sits: a tool call's in the
// transcript (inside the transcript's own selection), the Changes view's
// and a pull request's files.

/// A chat whose agent edited total.go.
List<Item> _edited() => [
  userSays('u', 'Start the total at start.'),
  Item(
    id: 'e1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'edit',
    title: 'Edit total.go',
    status: 'completed',
    paths: ['total.go'],
    diffs: [totalChange],
  ),
  agentSays('m', 'It starts at start now.'),
];

void main() {
  setUpAll(loadFonts);

  testWidgets("a tool call's diff in the transcript: a drag across its code "
      'copies exactly that, a double click the word', (tester) async {
    platformKeys();
    final copied = clipboardCopies(tester);
    Collapsible.opened.add('e1');
    final fake = FakeDaemon([chat('c', 'claude', 'Total')])
      ..chatItems['c'] = _edited();
    final d = await openApp(tester, fake);
    final box = find.descendant(
      of: find.byType(ToolCallView),
      matching: find.byType(DiffBox),
    );
    expect(box, findsOne);
    await dragCode(tester, from: (1, 2), to: (2, 9), within: box);
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, ['sum := start\n  for _, ']);
    await doubleClickCode(tester, 1, 10, within: box);
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, ['sum := start\n  for _, ', 'start']);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets("a permission card's diff in the transcript: a drag across "
      'its code copies exactly that', (tester) async {
    platformKeys();
    final copied = clipboardCopies(tester);
    final fake = FakeDaemon([chat('c', 'claude', 'Total')])
      ..chatItems['c'] = [
        userSays('u', 'Start the total at start.'),
        Item(
          id: 'p',
          kind: ItemKind.ITEM_KIND_PERMISSION,
          status: 'pending',
          title: 'Edit total.go',
          options: [
            Option(id: 'y', name: 'Allow once'),
            Option(id: 'n', name: 'Reject'),
          ],
          diffs: [totalChange],
        ),
      ];
    final d = await openApp(tester, fake);
    final box = find.descendant(
      of: find.byType(PermissionCard),
      matching: find.byType(DiffBox),
    );
    expect(box, findsOne);
    await dragCode(tester, from: (1, 2), to: (2, 9), within: box);
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, ['sum := start\n  for _, ']);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets("the Changes view's diff: a drag across the code copies "
      'exactly that, and a drag on the numbers still opens the comment box', (
    tester,
  ) async {
    viewport(tester, const Size(1300, 700));
    platformKeys();
    final copied = clipboardCopies(tester);
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'feature',
          defaultBase: 'main',
        ),
        ListCommitsRequest() => ListCommitsResponse(),
        GetDiffRequest() => GetDiffResponse(files: [totalChange]),
        _ => null,
      };
    final chat = ChatState('c', '/x')..scope = 'uncommitted';
    addTearDown(() => chat.scope = null);
    addTearDown(() => setComments('c', []));
    final d = await fake.connect(tester);
    await tester.pumpWidget(themed(ChangesView(chat: chat, daemon: d)));
    await tester.pumpAndSettle();
    expect(find.byType(DiffBox), findsOne);
    await dragCode(tester, from: (1, 2), to: (2, 9));
    expect(find.byType(ReviewCommentBox), findsNothing);
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, ['sum := start\n  for _, ']);
    await dragGutter(tester, 1, 2);
    expect(find.text('Lines 2–3'), findsOneWidget);
    expect(diffController(tester).textSelection.value, isNull);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets("a pull request's file: a drag across the code copies "
      'exactly that, and a drag on the numbers opens a comment of the '
      'review', (tester) async {
    platformKeys();
    final copied = clipboardCopies(tester);
    final (_, d) = await openView(
      tester,
      size: const Size(1300, 800),
      more: (input) => input is GetGitHubFilesRequest
          ? GetGitHubFilesResponse(files: [totalChange])
          : null,
    );
    await tester.tap(find.text('Add Sub and Neg'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Files changed'));
    await tester.pumpAndSettle();
    expect(find.byType(DiffBox), findsOne);
    await dragCode(tester, from: (1, 2), to: (2, 9));
    await press(tester, LogicalKeyboardKey.keyC, cmd: true);
    expect(copied, ['sum := start\n  for _, ']);
    await dragGutter(tester, 1, 2);
    expect(find.text('Lines 2–3: a comment of your review'), findsOneWidget);
    await closeView(tester, d);
  }, variant: macAndLinux);
}
