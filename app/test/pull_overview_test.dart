import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_check_lines.dart';
import 'package:nushi/pull_commits.dart';
import 'package:nushi/pull_merge_card.dart';
import 'package:nushi/pull_thread_card.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';
import 'pull_overview_fixture.dart';

/// The segment [name]'s cell in the merge status card.
Finder _segment(String name) => find.byKey(ValueKey('segment $name'));

void main() {
  setUpAll(loadFonts);

  test('a hunk: its last lines, numbered on the new side', () {
    final lines = hunkLines(overviewPull().threads.first.diffHunk, last: 4);
    expect(lines.map((l) => (l.$1, l.$2)), [
      (' ', 45),
      ('-', 0),
      ('+', 46),
      ('+', 47),
    ]);
    expect(lines.first.$3, '\tnext := r.URL.Query().Get("next")');
    expect(hunkLines(''), isEmpty);
  });

  test("the card's words: blocked and by what; ready", () {
    final blocked = mergeHead(overviewPull());
    expect(blocked.heading, 'Merging is blocked');
    expect(
      blocked.line,
      '2 required checks failing, changes requested, unresolved '
      'conversations.',
    );
    final ready = mergeHead(overviewPull(ready: true));
    expect(
      (ready.heading, ready.line),
      ('Ready to merge', 'All requirements are met.'),
    );
    expect(mergeHead(overviewPull()..item.state = 'merged').heading, 'Merged');
  });

  testWidgets('blocked: the card says why, each segment its state, one '
      'list open at a time', (tester) async {
    final (d, _) = await openPullTab(
      tester,
      overviewPull(),
      size: const Size(1700, 1100),
      commits: overviewCommits(),
    );
    expect(find.text('Merging is blocked'), findsOneWidget);
    expect(find.text('Send 5 to agent'), findsOneWidget);
    expect(find.text('2 failing'), findsOneWidget);
    expect(find.text('2 unresolved'), findsOneWidget);
    expect(find.text('Changes requested'), findsWidgets);
    // Checks: every check, failing first, as GitHub words them.
    await tester.tap(_segment('checks'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Failing after 2m 14s', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Successful in 3m 08s', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Send to agent'), findsWidgets);
    // Comments: the open threads, one line each; Checks' list closes.
    await tester.tap(_segment('comments'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Failing after', findRichText: true),
      findsNothing,
    );
    expect(find.text('auth/session.go:46–47'), findsWidgets);
    expect(find.text('Outdated'), findsWidgets);
    // Approvals: who reviewed, who's awaited.
    await tester.tap(_segment('approvals'));
    await tester.pumpAndSettle();
    expect(find.text('Requested changes'), findsOneWidget);
    expect(find.text('Awaiting review · code owner'), findsOneWidget);
    expect(find.text('Ping on GitHub'), findsOneWidget);
    // A second click closes it.
    await tester.tap(_segment('approvals'));
    await tester.pumpAndSettle();
    expect(find.text('Ping on GitHub'), findsNothing);
    d.dispose();
  }, variant: onMac);

  testWidgets('ready: no Send, the merge button, every segment met', (
    tester,
  ) async {
    final (d, _) = await openPullTab(
      tester,
      overviewPull(ready: true),
      size: const Size(1700, 1100),
    );
    expect(find.text('Ready to merge'), findsOneWidget);
    expect(find.textContaining('to agent'), findsNothing);
    expect(find.widgetWithText(SplitButton, 'Squash and merge'), findsOne);
    expect(find.text('5 passed'), findsOneWidget);
    expect(find.text('All resolved'), findsOneWidget);
    expect(find.text('2 approved'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('the commits: asked as the page opens, again only when the '
      'head moves; the trail opens the Commits tab', (tester) async {
    final whole = overviewPull();
    final (d, fake) = await openPullTab(
      tester,
      whole,
      size: const Size(1700, 1100),
      commits: overviewCommits(),
    );
    Iterable<Object> asked() => fake.calls.whereType<GetGitHubCommitsRequest>();
    expect(asked(), hasLength(1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(asked(), hasLength(1)); // the same head
    whole.headOid = 'f' * 40;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(asked(), hasLength(2));
    final trail = find.textContaining(
      '1 additional commit by',
      findRichText: true,
    );
    await tester.ensureVisible(trail);
    await tester.pumpAndSettle();
    await tester.tap(trail);
    await tester.pumpAndSettle();
    expect(find.byType(PullCommitsList), findsOneWidget);
    expect(find.text('Tomas committed 1h ago'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets("a thread's row in the merge status card shows the thread, "
      'open, in view', (tester) async {
    final (d, _) = await openPullTab(
      tester,
      overviewPull(),
      size: const Size(1700, 1000),
    );
    await tester.tap(_segment('comments'));
    await tester.pumpAndSettle();
    // The outdated one, folded in iris's review below the fold.
    expect(find.text('Add a case for an empty next?'), findsNothing);
    await tester.tap(find.text('auth/session_test.go:12').first);
    await tester.pumpAndSettle();
    final body = find.text('Add a case for an empty next?', findRichText: true);
    expect(body, findsOneWidget);
    final at = tester.getRect(body);
    expect(at.top, greaterThan(0));
    expect(at.bottom, lessThan(1000));
    d.dispose();
  }, variant: onMac);

  for (final dark in [true, if (rendering) false]) {
    final name = dark ? 'dark' : 'light';
    for (final width in [1700.0, 720.0]) {
      for (final shot in ['blocked', 'ready']) {
        testWidgets('renders $shot at ${width.toInt()}, $name', (tester) async {
          sidebarHidden.value = true;
          final (d, _) = await openPullTab(
            tester,
            overviewPull(ready: shot == 'ready'),
            size: const Size(1700, 1100),
            brightness: dark ? Brightness.dark : Brightness.light,
            commits: overviewCommits(),
          );
          // The chat's header folds its tabs at 720: opened wide, then
          // narrowed, as a person would.
          // At 720 the whole page, the side column under the main one.
          viewport(tester, Size(width, width < 1000 ? 2400 : 1100));
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          final at = '${width.toInt()}-$name';
          await render(tester, find.byType(NushiApp), 'pr-overview-$shot-$at');
          if (shot == 'blocked') {
            await tester.tap(_segment('checks'));
            await tester.pumpAndSettle();
            expectTextInside(tester, width);
            await render(
              tester,
              find.byType(NushiApp),
              'pr-overview-checks-open-$at',
            );
            await tester.drag(
              find.byType(CustomScrollView).last,
              const Offset(0, -1000),
            );
            await tester.pumpAndSettle();
            expectTextInside(tester, width);
            await render(
              tester,
              find.byType(NushiApp),
              'pr-overview-comments-$at',
            );
          }
          d.dispose();
        }, variant: onMac);
      }
    }
  }

  // One rule for a check's kind: the list, the Checks tab's label, a line's
  // Send to agent and Re-run, and Fix checks all count a cancelled check
  // as failing by checkKind, whatever GitHubCheck.failed a daemon sends.
  testWidgets('a cancelled check is failing everywhere, from a daemon that '
      'says it is not', (tester) async {
    final p = overviewPull()
      ..checks.clear()
      ..checks.addAll([
        // A daemon before cancelled was failed sends failed: false.
        check('deploy', state: 'cancelled', id: 51)..failed = false,
        check('test', state: 'failure', id: 54),
        check('lint', id: 52),
      ]);
    final (d, _) = await openPullTab(
      tester,
      p,
      size: const Size(1700, 1100),
      commits: overviewCommits(),
      more: (input) => input is GetGitHubJobLogRequest
          ? GetGitHubJobLogResponse(tail: 'job ${input.job}')
          : null,
    );
    expect(find.text('Checks  2 failing'), findsOneWidget);
    await tester.tap(_segment('checks'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ChecksList),
        matching: find.widgetWithText(Button, 'Send to agent'),
      ),
      findsNWidgets(2),
    );
    // Its words in the failing colour, as the failed check's.
    final deploy = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.textSpan?.toPlainText().contains('Cancelled') ?? false),
    );
    final words = tester.widget<Text>(deploy).textSpan! as TextSpan;
    expect(
      words.children!.last.style!.color,
      NushiTheme.of(tester.element(deploy)).t.crashed,
    );
    final fix = await checkReplies(d, p.item.ref, p);
    expect(fix, hasLength(2));
    d.dispose();
  }, variant: onMac);

  // Each kind of check (githubapi.KindOf, checkKind): cancelled and failed
  // as failing, neutral as passed (its icon muted), skipped, running; in
  // the Checks segment, its lights, and the Checks tab.
  for (final b in renderThemes) {
    for (final width in [1700.0, 720.0]) {
      renderTest('renders each kind of check at ${width.toInt()}, ${b.name}', (
        tester,
      ) async {
        sidebarHidden.value = true;
        final p = overviewPull()
          ..checks.clear()
          ..checks.addAll([
            // As the daemon sends it now: failed (githubapi.KindOf).
            check('deploy (preview)', state: 'cancelled', id: 51)
              ..failed = true,
            check('lint', state: 'neutral', id: 52),
            check('docs', state: 'skipped', id: 53),
            check('test (ubuntu-latest)', state: 'failure', id: 54),
            check('build', state: 'pending', id: 55),
          ]);
        final (d, _) = await openPullTab(
          tester,
          p,
          size: const Size(1700, 1100),
          brightness: b,
          commits: overviewCommits(),
        );
        viewport(tester, Size(width, width < 1000 ? 2400 : 1100));
        await tester.pumpAndSettle();
        await tester.tap(_segment('checks'));
        await tester.pumpAndSettle();
        final at = '${width.toInt()}-${b.name}';
        await render(tester, find.byType(NushiApp), 'pr-check-kinds-$at');
        await tester.tap(find.textContaining('Checks  2 failing'));
        await tester.pumpAndSettle();
        await render(tester, find.byType(NushiApp), 'pr-check-kinds-tab-$at');
        d.dispose();
      }, variant: onMac);
    }
  }
}
