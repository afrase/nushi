import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

final _wt = Worktree(
  repo: '/Users/me/shop',
  path: '/Users/me/shop/.worktrees/filters-malformed-q',
  branch: 'filters-malformed-q',
  base: 'main',
);

GitHubPull _merged() => fixturePull()..item.state = 'merged';

GetCleanUpResponse _clean({int changed = 0, int commits = 1}) =>
    GetCleanUpResponse(
      worktree: _wt,
      state: WorktreeState(changed: changed, commits: commits),
      changes: [
        if (changed > 0) 'M app/notebooks/page_spec.rb',
        if (changed > 1) '?? tmp/q_params_repro.rb',
      ],
    );

Finder get _card => find.ancestor(
  of: find.text('Pull request').last,
  matching: find.byType(PanelCard),
);

Finder _inCard(Finder f) => find.descendant(of: _card, matching: f);

/// The app on the chat of [pull] in its worktree, the details panel shown;
/// GetCleanUp answers [u]; the calls are in the fake's.
Future<(Daemon, FakeDaemon)> _open(
  WidgetTester tester, {
  GitHubPull? pull,
  GetCleanUpResponse? u,
  bool busy = false,
  Brightness brightness = Brightness.dark,
  Object? Function(Object input)? more,
}) async {
  cleanUpLater.value = {};
  final r = await openPullTab(
    tester,
    pull ?? _merged(),
    details: true,
    open: false,
    worktree: _wt,
    busy: busy,
    brightness: brightness,
    size: const Size(1100, 760),
    more: (input) =>
        more?.call(input) ??
        switch (input) {
          GetCleanUpRequest() => u ?? _clean(),
          DeleteGitHubBranchRequest() => DeleteGitHubBranchResponse(
            deleted: true,
          ),
          _ => null,
        },
  );
  if (busy) {
    r.$2.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1000),
        status: ChatStatus(busy: true, started: Int64(1)),
      ),
    );
    await _pump(tester);
  }
  return r;
}

/// A while of frames: a turn running never settles (its shine moves).
Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadFonts);

  testWidgets('merged: Clean up… and Not now; the menu keeps it', (
    tester,
  ) async {
    final (d, _) = await _open(tester);
    expect(
      _inCard(
        find.textContaining(
          "This chat's worktree and branch aren't needed any more.",
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(_inCard(find.text('Not now')));
    await tester.pumpAndSettle();
    expect(cleanUpLater.value, {'c'});
    expect(_inCard(find.text('Clean up…')), findsNothing);
    await tester.tap(_inCard(find.byTooltip('Pull request')));
    await tester.pumpAndSettle();
    expect(find.text('Clean up…'), findsOneWidget); // the menu's
    d.dispose();
  }, variant: _mac);

  testWidgets('nothing in the way: all ticked; it runs, then offers the undo', (
    tester,
  ) async {
    final (d, fake) = await _open(tester);
    await tester.tap(_inCard(find.text('Clean up…')));
    await tester.pumpAndSettle();
    expect(find.text('Clean up after #412'), findsOneWidget);
    expect(find.text('.worktrees/filters-malformed-q · clean'), findsOneWidget);
    expect(
      find.text(
        "Squash-merged, so git can't tell. GitHub says #412 merged it.",
      ),
      findsOneWidget,
    );
    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(boxes.map((b) => b.value), [true, true, true, true]);
    await tester.tap(find.text('Clean up'));
    await tester.pumpAndSettle();
    final calls = fake.calls.where(
      (c) =>
          c is DeleteGitHubBranchRequest ||
          c is ArchiveChatRequest ||
          c is RemoveChatWorktreeRequest ||
          c is DeleteChatBranchRequest,
    );
    expect(calls.map((c) => c.runtimeType), [
      DeleteGitHubBranchRequest,
      ArchiveChatRequest,
      RemoveChatWorktreeRequest,
      DeleteChatBranchRequest,
    ]);
    expect(
      fake.calls.whereType<RemoveChatWorktreeRequest>().single.force,
      isFalse,
    );
    // Its commits are a squash merge's: deleted with force.
    expect(
      fake.calls.whereType<DeleteChatBranchRequest>().single.force,
      isTrue,
    );
    expect(
      fake.calls.whereType<DeleteGitHubBranchRequest>().single.ref.number,
      412,
    );
    expect(_inCard(find.text('Branch deleted on GitHub')), findsOneWidget);
    expect(_inCard(find.text('Worktree deleted')), findsOneWidget);
    await tester.tap(_inCard(find.text('Restore branch')));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<RestoreGitHubBranchRequest>(), hasLength(1));
    expect(_inCard(find.text('Branch restored on GitHub')), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('a dirty worktree starts unticked; ticking it names the loss '
      'and forces; the branch waits for its worktree', (tester) async {
    final (d, fake) = await _open(tester, u: _clean(changed: 2));
    await tester.tap(_inCard(find.text('Clean up…')));
    await tester.pumpAndSettle();
    expect(find.text('2 uncommitted files would be lost.'), findsOneWidget);
    expect(find.text('M app/notebooks/page_spec.rb'), findsOneWidget);
    expect(
      find.text("The worktree you're keeping has it checked out."),
      findsOneWidget,
    );
    var boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(boxes.map((b) => b.value), [false, false, true, true]);
    expect(boxes[1].onChanged, isNull); // the branch: not while it stays
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Clean up, losing 2 files'), findsOneWidget);
    boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(boxes[1].onChanged, isNotNull);
    await tester.tap(find.text('Clean up, losing 2 files'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<RemoveChatWorktreeRequest>().single.force,
      isTrue,
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('mid-turn: it waits for the turn to end, then cleans up', (
    tester,
  ) async {
    final (d, fake) = await _open(tester, busy: true);
    await tester.tap(_inCard(find.text('Clean up…')));
    await _pump(tester);
    expect(find.text('Claude is mid-turn here.'), findsOneWidget);
    await tester.tap(find.text('Clean up when done'));
    await _pump(tester);
    expect(_inCard(find.text('Waiting for the turn to end…')), findsOneWidget);
    expect(fake.calls.whereType<ArchiveChatRequest>(), isEmpty);
    // Another asked for meanwhile (the ⋯ menu, say) does nothing.
    final job = CleanUpJob.of(d.chats['c']!);
    await job.run(d, (
      archive: true,
      worktree: false,
      force: false,
      branch: false,
      forceBranch: false,
      remote: false,
      stopTurn: false,
    ), null);
    expect(job.waiting, isTrue);
    fake.emit(
      EventsResponse(chatId: 'c', seq: Int64(1001), status: ChatStatus()),
    );
    await _pump(tester);
    expect(fake.calls.whereType<ArchiveChatRequest>(), hasLength(1));
    expect(_inCard(find.text('Chat archived')), findsOneWidget);
    expect(job.finished, isTrue);
    d.dispose();
  }, variant: _mac);

  testWidgets("mid-turn, a stop the daemon refuses: it says so and isn't "
      'left waiting', (tester) async {
    var stops = 0;
    final (d, fake) = await _open(
      tester,
      busy: true,
      more: (input) => input is CancelTurnRequest
          ? throw Exception('no such turn ${++stops}')
          : null,
    );
    await tester.tap(_inCard(find.text('Clean up…')));
    await _pump(tester);
    await tester.tap(find.text('Stop the turn, clean up now'));
    await _pump(tester);
    await tester.tap(find.text('Clean up'));
    await _pump(tester);
    expect(stops, 1);
    expect(
      _inCard(find.textContaining("The turn didn't stop")),
      findsOneWidget,
    );
    expect(_inCard(find.text('Waiting for the turn to end…')), findsNothing);
    final job = CleanUpJob.of(d.chats['c']!);
    expect((job.running, job.finished), (false, true));
    expect(fake.calls.whereType<ArchiveChatRequest>(), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets("the chat's ⋯ has Clean up… for a worktree chat", (tester) async {
    final (d, _) = await _open(tester);
    await tester.tap(find.byTooltip('Chat menu').first);
    await tester.pumpAndSettle();
    expect(find.text('Clean up…'), findsWidgets);
    d.dispose();
  }, variant: _mac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final (state, u, busy) in [
      ('clean', _clean(), false),
      ('guarded', _clean(changed: 2), true),
    ]) {
      testWidgets('golden: the clean-up dialog, $state, $name', (tester) async {
        final (d, _) = await _open(
          tester,
          u: u,
          busy: busy,
          brightness: brightness,
        );
        await tester.tap(_inCard(find.text('Clean up…')));
        await _pump(tester);
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/cleanup_${state}_$name.png'),
        );
        d.dispose();
      }, variant: _mac);
    }

    testWidgets('golden: the widget once cleaned up, $name', (tester) async {
      final (d, fake) = await _open(tester, brightness: brightness);
      await tester.tap(_inCard(find.text('Clean up…')));
      await tester.pumpAndSettle();
      // Keep the worktree and its branch.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clean up'));
      await tester.pumpAndSettle();
      fake.emit(
        EventsResponse(
          chatId: 'c',
          chat: chat('c', 'claude', 'Fix malformed q in admin filters')
            ..archived = true
            ..worktree = _wt
            ..folder = _wt.path
            ..pull = fixtureLink,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        _card,
        matchesGoldenFile('goldens/cleanup_done_$name.png'),
      );
      d.dispose();
    }, variant: _mac);
  }
}
