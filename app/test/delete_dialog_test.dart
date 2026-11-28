import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _repo = '/Users/me/notes';
const _wt = '$_repo/.worktrees/quiet-fox';

/// What deleting the chat would remove: its worktree, which [others] work in
/// too.
PlanDeleteChatResponse _plan(
  List<String> others, {
  bool deletes = true,
  bool cantStart = false,
}) => PlanDeleteChatResponse(
  deletesHistory: deletes,
  agentCantStart: cantStart,
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
  PlanDeleteChatResponse? plan,
  Size size = const Size(900, 620),
}) async {
  showDetails.value = false;
  final c = chat('c', 'claude', 'Tidy the note list', folder: _wt)
    ..worktree = Worktree(repo: _repo, path: _wt, branch: 'nushi/quiet-fox');
  final fake = FakeDaemon([c])
    ..answer = (input) =>
        input is PlanDeleteChatRequest ? plan ?? _plan(others) : null;
  final d = await openApp(tester, fake, size: size, brightness: brightness);
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
  }, variant: onMac);

  testWidgets('Cancel has the focus: Enter closes it and deletes nothing', (
    tester,
  ) async {
    final (fake, d) = await _open(tester, []);
    expect(focusedButton(tester), 'Cancel');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(fake.calls.whereType<DeleteChatRequest>(), isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Esc cancels it and deletes nothing', (tester) async {
    final (fake, d) = await _open(tester, []);
    expect(find.text('Delete'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(fake.calls.whereType<DeleteChatRequest>(), isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Esc does nothing while it deletes', (tester) async {
    final (fake, d) = await _open(tester, []);
    final held = Completer<DeleteChatResponse>();
    fake.answer = (input) => input is DeleteChatRequest ? held.future : null;
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Deleting…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Deleting…'), findsOneWidget);
    held.complete(DeleteChatResponse());
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Delete keeps its width while it reads Deleting…, so Cancel '
      'beside it stays put', (tester) async {
    final (fake, d) = await _open(tester, []);
    final held = Completer<DeleteChatResponse>();
    fake.answer = (input) => input is DeleteChatRequest ? held.future : null;
    Finder button(String label) =>
        find.byWidgetPredicate((w) => w is Button && w.label == label);
    final rest = tester.getRect(button('Delete'));
    final cancel = tester.getRect(button('Cancel'));
    await render(tester, find.byType(Dialog), 'busy_delete_chat_idle');
    await tester.tap(button('Delete'));
    await tester.pump();
    expect(tester.getRect(button('Deleting…')), rest);
    await render(tester, find.byType(Dialog), 'busy_delete_chat_busy');
    expect(tester.getRect(button('Cancel')), cancel);
    held.complete(DeleteChatResponse());
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a worktree nobody else works in is removed by default', (
    tester,
  ) async {
    final (_, d) = await _open(tester, []);
    expect(find.textContaining('works in it too'), findsNothing);
    final remove = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(remove.value, isTrue);
    expect(remove.onChanged, isNotNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('an agent that starts but can’t delete its history says its '
      'resume command still opens it', (tester) async {
    final (_, d) = await _open(tester, [], plan: _plan([], deletes: false));
    expect(
      find.textContaining('can’t delete its history from here, so it stays'),
      findsOne,
    );
    expect(find.textContaining('couldn’t start'), findsNothing);
    expect(find.text('7f3c2a10-5d4e'), findsOne);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('an agent that couldn’t start keeps its history, promising '
      'no resume command', (tester) async {
    final (_, d) = await _open(
      tester,
      [],
      plan: _plan([], deletes: false, cantStart: true),
    );
    expect(
      find.textContaining('couldn’t start, so its history stays:'),
      findsOne,
    );
    expect(find.textContaining('still opens'), findsNothing);
    expect(find.text('7f3c2a10-5d4e'), findsOne);
    await closeView(tester, d);
  }, variant: onMac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    if (rendering) ('light', Brightness.light),
  ]) {
    testWidgets('deleting a chat whose worktree two others work in, '
        '$name', (tester) async {
      final (_, d) = await _open(tester, [
        'Fix the build',
        'Sync on wake',
      ], brightness: brightness);
      // Both named, in the dialog, inside the window.
      expect(find.textContaining('“Fix the build”, “Sync on wake”'), findsOne);
      expectTextInside(tester, 900);
      await render(tester, find.byType(NushiApp), 'delete_others_$name');
      await closeView(tester, d);
    }, variant: onMac);
  }

  // The loss words beside Clean up…'s, to look at (`make renders`).
  for (final b in Brightness.values) {
    for (final width in [1700.0, 720.0]) {
      renderTest('a worktree that would lose files, ${width.round()} '
          'wide, ${b.name}', (tester) async {
        final plan = _plan([])
          ..worktrees.first.state = WorktreeState(
            changed: 2,
            ignored: 3,
            commits: 1,
          );
        final (_, d) = await _open(
          tester,
          [],
          plan: plan,
          brightness: b,
          size: Size(width, 760),
        );
        await render(
          tester,
          find.byType(NushiApp),
          'delete_loss_${width.round()}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
