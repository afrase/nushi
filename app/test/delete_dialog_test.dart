import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _repo = '/Users/me/notes';
const _wt = '$_repo/.worktrees/quiet-fox';

/// What deleting the chat would remove: its worktree, which [others] work in
/// too.
PlanDeleteChatResponse _plan(List<String> others) => PlanDeleteChatResponse(
  deletesHistory: true,
  sessions: [AgentSession(sessionId: '7f3c2a10-5d4e', folder: _wt)],
  worktrees: [
    WorktreePlan(
      worktree: Worktree(
        repo: _repo,
        path: _wt,
        branch: 'nushi/quiet-fox',
        base: 'main',
      ),
      state: WorktreeState(),
      others: others,
    ),
  ],
);

/// The app showing the chat, its Delete dialog open.
Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester,
  List<String> others, {
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, const Size(900, 620), brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Tidy the note list', folder: _wt)
    ..worktree = Worktree(repo: _repo, path: _wt, branch: 'nushi/quiet-fox');
  final fake = FakeDaemon([c])
    ..answer = (input) => input is PlanDeleteChatRequest ? _plan(others) : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
  unawaited(
    showDeleteChat(tester.element(find.byType(ChatView)), d.chats['c']!, d),
  );
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a worktree another chat works in stays: its choice is off '
      'and says why', (tester) async {
    final (fake, d) = await _open(tester, ['Fix the build']);
    expect(
      find.text('“Fix the build” works in it too, so it stays.'),
      findsOne,
    );
    final remove = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect([remove.value, remove.onChanged], [false, null]);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    final req = fake.calls.whereType<DeleteChatRequest>().single;
    expect(
      [req.worktrees.single.removeWorktree, req.worktrees.single.deleteBranch],
      [false, false],
    );
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a worktree nobody else works in is removed by default', (
    tester,
  ) async {
    final (_, d) = await _open(tester, []);
    expect(find.textContaining('works in it too'), findsNothing);
    final remove = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(remove.value, isTrue);
    expect(remove.onChanged, isNotNull);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('golden: deleting a chat whose worktree two others work in, '
        '$name', (tester) async {
      final (_, d) = await _open(tester, [
        'Fix the build',
        'Sync on wake',
      ], brightness: brightness);
      await expectLater(
        find.byType(NushiApp),
        matchesGoldenFile('goldens/delete_others_$name.png'),
      );
      await closeView(tester, d);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
