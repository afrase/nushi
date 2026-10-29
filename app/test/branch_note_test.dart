import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _repo = '/Users/me/nushi';
const _branch = 'nushi/bump-go-to-1-27-3-and-fix-the-flaky-tests';
const _renamed = 'Branch renamed to $_branch';

/// As the daemon adds it: no-break spaces keep it whole where it wraps.
const _told = ' ·\u00a0told\u00a0the\u00a0agent';

/// A worktree chat whose branch Nushi named after its first turn: before
/// the next prompt, and once it went with the note.
List<Item> _items({required bool told}) => [
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Bump Go to 1.27.3 and fix the flaky tests.',
  ),
  Item(
    id: 'm1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Bumped the `go` line to 1.27.3; the flaky test waited on a timer.',
  ),
  Item(
    id: 'n1',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'branch_renamed',
    text: told ? '$_renamed$_told' : _renamed,
  ),
  if (told) ...[
    Item(
      id: 'u2',
      kind: ItemKind.ITEM_KIND_USER_MESSAGE,
      text: 'Push it and open a pull request.',
    ),
    Item(
      id: 'm2',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text: 'Pushed `$_branch` and opened the pull request.',
    ),
  ],
];

/// The app [width] wide on the chat, the details panel [details] wide.
Future<Future<void> Function()> _open(
  WidgetTester tester, {
  required bool told,
  required double width,
  required double details,
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, Size(width, 620), brightness: brightness);
  showDetails.value = true;
  paneWidths.value = {'details': details};
  final c =
      chat(
          'c',
          'claude',
          'Bump Go to 1.27.3',
          folder: '$_repo/.worktrees/brave-otter',
        )
        ..worktree = Worktree(
          repo: _repo,
          path: '$_repo/.worktrees/brave-otter',
          branch: _branch,
          base: 'main',
        );
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: _items(told: told),
      ),
      GetFolderStatusRequest() => GetFolderStatusResponse(
        git: true,
        branch: _branch,
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
  await tester.pumpAndSettle();
  return () async {
    await closeView(tester, d);
  };
}

void main() {
  setUpAll(loadFonts);

  // The line in the transcript, whole and quiet, at a wide window with the
  // details panel at its usual and widest width, and at a narrow window.
  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final (size, width, details) in [
      ('usual', 1700.0, DetailsPanel.width),
      ('widest', 1700.0, 480.0),
      ('narrow', 720.0, DetailsPanel.width),
    ]) {
      for (final told in [false, true]) {
        final state = told ? 'told' : 'renamed';
        testWidgets('the rename line, $state, $size, $name', (tester) async {
          final end = await _open(
            tester,
            told: told,
            width: width,
            details: details,
            brightness: brightness,
          );
          final line = find.textContaining(_renamed);
          expect(line, findsOneWidget);
          expect(
            find.text('$_renamed$_told'),
            told ? findsOneWidget : findsNothing,
          );
          expect(
            find.descendant(
              of: find.byType(Transcript),
              matching: find.byIcon(Icons.account_tree_outlined),
            ),
            findsOneWidget,
          );
          final view = tester.getRect(find.byType(ChatView));
          final text = tester.getRect(line);
          expect(text.right, lessThanOrEqualTo(view.right));
          expect(tester.takeException(), isNull);
          if (size == 'usual') {
            await expectLater(
              find.byType(NushiApp),
              matchesGoldenFile('goldens/branch_note_${state}_$name.png'),
            );
          }
          await end();
        }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
      }
    }
  }
}
