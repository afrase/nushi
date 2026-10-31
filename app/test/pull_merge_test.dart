import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_merge.dart';
import 'package:nushi/pull_merge_state.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// What the control's box says, whole.
String _says(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('merge-words')).first)
    .textSpan!
    .toPlainText();

const ValueKey<String> _key = ValueKey('merge-title');

Future<void> _pressMerge(WidgetTester tester) async {
  await tester.tap(find.text('Squash and merge').first);
  await tester.pumpAndSettle();
}

final _text = GetGitHubMergeTextResponse(
  mergeTitle: 'Merge pull request #412',
  mergeBody: 'Filters',
  squashTitle: 'Ignore q params (#412)',
  squashBody: '* One\n* Two',
);

void main() {
  setUpAll(loadFonts);

  group('what the control says', () {
    String words(GitHubPull p) {
      final v = mergeView(p)!;
      return '${v.lead} ${v.rest}'.trim();
    }

    test('nothing for a daemon before it, or once merged or closed', () {
      expect(mergeView(fixturePull()), isNull);
      expect(mergeView(mergePull('ready')..item.state = 'merged'), isNull);
      expect(mergeView(mergePull('ready')..item.state = 'closed'), isNull);
    });

    test('ready, with what GitHub lets past said', () {
      expect(mergeView(mergePull('ready'))!.step, MergeStep.merge);
      expect(words(mergePull('ready')), 'Ready to merge.');
      expect(
        words(mergePull('ready')..mergeState = 'unstable'),
        contains(unstableWords),
      );
      expect(
        words(mergePull('ready')..item.review = 'changes_requested'),
        contains("no rule of main's enforces it"),
      );
    });

    test('each reason, exactly', () {
      String says(List<String> blocks) {
        final p = mergePull('blocked')
          ..merge.blocks.clear()
          ..merge.blocks.addAll(blocks);
        return words(p);
      }

      expect(says(['draft']), "Can't merge yet. It's a draft.");
      expect(says(['conflicts']), "Can't merge yet. It conflicts with main.");
      // Two of the fixture's failing checks are required.
      expect(says(['checks_failing']), contains('2 required checks are'));
      expect(says(['changes_requested']), contains('Changes were requested.'));
      expect(says(['review_required']), contains('an approving review'));
      expect(says(['threads']), contains("threads aren't resolved"));
      expect(says(['behind']), contains('The branch is behind main.'));
      expect(says(['rules']), contains("A rule of main's isn't met."));
    });

    test("a branch's name can't reorder what's around it", () {
      final p = mergePull('blocked')
        ..base = 'ma\u202ein'
        ..merge.blocks.clear()
        ..merge.blocks.add('behind');
      expect(words(p), "Can't merge yet. The branch is behind main.");
    });

    test('unknown says so, and offers nothing', () {
      final p = mergePull('ready')
        ..mergeState = 'unknown'
        ..merge.canEnableAuto = true
        ..merge.blocks.add('unknown');
      expect(words(p), startsWith('Unknown, still checking.'));
      expect(mergeView(p)!.step, MergeStep.words);
    });

    test('offers nothing the viewer has no permission for', () {
      final ready = mergePull('ready')..merge.canMerge = false;
      expect(mergeView(ready)!.step, MergeStep.words);
      expect(words(ready), contains('takes write access'));
      final blocked = mergePull('blocked')..merge.canMerge = false;
      expect(mergeView(blocked)!.step, MergeStep.words);
    });

    test('auto-merge only where it can wait for something', () {
      expect(mergeView(mergePull('blocked'))!.step, MergeStep.auto);
      final notAllowed = mergePull('blocked')..merge.autoAllowed = false;
      expect(mergeView(notAllowed)!.step, MergeStep.words);
      final viewerCant = mergePull('blocked')..merge.canEnableAuto = false;
      expect(mergeView(viewerCant)!.step, MergeStep.words);
      final conflicts = mergePull('blocked')..merge.blocks.add('conflicts');
      expect(mergeView(conflicts)!.step, MergeStep.words);
      final draft = mergePull('blocked')..merge.blocks.add('draft');
      expect(mergeView(draft)!.step, MergeStep.words);
    });

    test('a queue never offers a direct merge', () {
      final ready = mergePull('ready')..merge.queue = true;
      expect(mergeView(ready)!.step, MergeStep.addToQueue);
      final waiting = mergePull('blocked')..merge.queue = true;
      expect(mergeView(waiting)!.step, MergeStep.whenReady);
      expect(words(mergePull('queue')), contains('Position 3'));
      expect(words(mergePull('queue')), contains('waiting for checks'));
      expect(words(mergePull('queue')), contains('About 14 min left'));
      expect(mergeView(mergePull('queue'))!.step, MergeStep.inQueue);
    });

    test('auto-merge on says who and how', () {
      expect(words(mergePull('auto')), contains('squash'));
      expect(words(mergePull('auto')), contains('by mona'));
    });

    test("the method: picked here, then GitHub's, then the first", () {
      final p = mergePull('ready');
      expect(pickedMethod(p), 'squash');
      mergeMethods.value = {mergeRepoKey(p): 'rebase'};
      expect(pickedMethod(p), 'rebase');
      p.merge.canRebase = false;
      expect(pickedMethod(p), 'squash');
      p
        ..merge.methods.remove('squash')
        ..merge.defaultMethod = 'squash';
      expect(pickedMethod(p), 'merge');
    });
  });

  group('merging', () {
    testWidgets(
      "asks first, with GitHub's text, then sends what the view showed",
      (tester) async {
        var whole = mergePull('ready');
        final merged = mergePull('ready')..item.state = 'merged';
        final (d, fake) = await openPullTab(
          tester,
          whole,
          more: (input) => switch (input) {
            GetGitHubPullRequest() => GetGitHubPullResponse(pull: whole),
            GetGitHubMergeTextRequest() => _text,
            MergeGitHubPullRequest() => () async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              whole = merged;
              return MergeGitHubPullResponse();
            }(),
            _ => null,
          },
        );
        expect(_says(tester), 'Ready to merge.');
        await _pressMerge(tester);
        expect(fake.calls.whereType<MergeGitHubPullRequest>(), isEmpty);
        expect(find.text('Squash and merge?'), findsOneWidget);
        final what = tester
            .widget<Text>(find.byKey(const ValueKey('merge-what')))
            .textSpan!
            .toPlainText();
        expect(what, contains('#412 into main'));
        expect(what, contains('bbbbbbb'));
        expect(find.text('Ignore q params (#412)'), findsOneWidget);
        await tester.enterText(find.byKey(_key), 'My title');
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Squash and merge'),
          ),
        );
        await tester.pump();
        // Working, and not to be pressed twice.
        expect(find.text('Merging…'), findsOneWidget);
        await tester.pumpAndSettle();
        final sent = fake.calls.whereType<MergeGitHubPullRequest>().single;
        expect(sent.headOid, 'b' * 40);
        expect(sent.base, 'main');
        expect(sent.method, 'squash');
        expect(sent.title, 'My title');
        expect(sent.body, '* One\n* Two');
        expect(find.byType(AlertDialog), findsNothing);
        // The view follows: no control on a merged pull request.
        expect(find.byKey(const ValueKey('merge-control')), findsNothing);
        expect(find.text('Merged'), findsWidgets);
        d.dispose();
      },
      variant: _mac,
    );

    testWidgets('Cancel sends nothing', (tester) async {
      final (d, fake) = await openPullTab(
        tester,
        mergePull('ready'),
        more: (input) => input is GetGitHubMergeTextRequest ? _text : null,
      );
      await _pressMerge(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<MergeGitHubPullRequest>(), isEmpty);
      d.dispose();
    }, variant: _mac);

    testWidgets('no title, no merge', (tester) async {
      final (d, fake) = await openPullTab(
        tester,
        mergePull('ready'),
        more: (input) => input is GetGitHubMergeTextRequest ? _text : null,
      );
      await _pressMerge(tester);
      await tester.enterText(find.byKey(_key), '  ');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Squash and merge'),
        ),
      );
      await tester.pump();
      expect(fake.calls.whereType<MergeGitHubPullRequest>(), isEmpty);
      d.dispose();
    }, variant: _mac);

    testWidgets('a rebase has no commit text', (tester) async {
      mergeMethods.value = {'github.com $fixtureRepo': 'rebase'};
      final (d, fake) = await openPullTab(tester, mergePull('ready'));
      await tester.tap(find.text('Rebase and merge').first);
      await tester.pumpAndSettle();
      expect(find.byKey(_key), findsNothing);
      expect(fake.calls.whereType<GetGitHubMergeTextRequest>(), isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Rebase and merge'),
        ),
      );
      await tester.pumpAndSettle();
      final sent = fake.calls.whereType<MergeGitHubPullRequest>().single;
      expect(sent.method, 'rebase');
      expect(sent.headOid, 'b' * 40);
      d.dispose();
    }, variant: _mac);

    testWidgets('a head that moved says so, and reads it again', (
      tester,
    ) async {
      const moved = 'the pull request moved on since this view';
      final (d, fake) = await openPullTab(
        tester,
        mergePull('ready'),
        more: (input) => switch (input) {
          GetGitHubMergeTextRequest() => _text,
          MergeGitHubPullRequest() => throw ConnectException(
            Code.aborted,
            moved,
            metadata: Headers()..add('nushi-reason', 'head_moved'),
          ),
          _ => null,
        },
      );
      final before = fake.calls.whereType<GetGitHubPullRequest>().length;
      await _pressMerge(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Squash and merge'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(moved), findsOneWidget);
      expect(
        fake.calls.whereType<GetGitHubPullRequest>().length,
        greaterThan(before),
      );
      d.dispose();
    }, variant: _mac);

    testWidgets("GitHub's refusal toasts, in its words, and the dialog stays", (
      tester,
    ) async {
      const words = 'GitHub: Base branch was modified. Review and try again.';
      final (d, _) = await openPullTab(
        tester,
        mergePull('ready'),
        more: (input) => switch (input) {
          GetGitHubMergeTextRequest() => _text,
          MergeGitHubPullRequest() => throw ConnectException(
            Code.failedPrecondition,
            words,
          ),
          _ => null,
        },
      );
      await _pressMerge(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Squash and merge'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      // In the dialog, and the toast.
      expect(find.text(words), findsNWidgets(2));
      expect(find.byType(SnackBar), findsOneWidget);
      d.dispose();
    }, variant: _mac);

    testWidgets('the commit text not read means no merge', (tester) async {
      final (d, fake) = await openPullTab(
        tester,
        mergePull('ready'),
        more: (input) => input is GetGitHubMergeTextRequest
            ? throw ConnectException(Code.failedPrecondition, 'GitHub: no')
            : null,
      );
      await _pressMerge(tester);
      expect(find.text('GitHub: no'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Squash and merge'),
        ),
      );
      await tester.pump();
      expect(fake.calls.whereType<MergeGitHubPullRequest>(), isEmpty);
      d.dispose();
    }, variant: _mac);

    testWidgets('picking a method is remembered for the repository', (
      tester,
    ) async {
      final (d, _) = await openPullTab(tester, mergePull('ready'));
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rebase and merge').last);
      await tester.pumpAndSettle();
      expect(mergeMethods.value['github.com $fixtureRepo'], 'rebase');
      expect(find.text('Rebase and merge'), findsWidgets);
      d.dispose();
    }, variant: _mac);

    testWidgets('what was kept from before offers nothing', (tester) async {
      final kept = mergePull('ready');
      keepPull(kept.item.ref, kept);
      final never = Completer<GetGitHubPullResponse>();
      final (d, _) = await openPullTab(
        tester,
        kept,
        more: (input) => input is GetGitHubPullRequest ? never.future : null,
      );
      expect(_says(tester), 'Ready to merge.');
      expect(find.byType(SplitButton), findsNothing);
      d.dispose();
    }, variant: _mac);
  });

  group('auto-merge', () {
    testWidgets('enabled through the confirmation, then disabled', (
      tester,
    ) async {
      var whole = mergePull('blocked');
      final (d, fake) = await openPullTab(
        tester,
        whole,
        more: (input) => switch (input) {
          GetGitHubPullRequest() => GetGitHubPullResponse(pull: whole),
          GetGitHubMergeTextRequest() => _text,
          EnableGitHubAutoMergeRequest() => () {
            whole = mergePull('auto');
            return EnableGitHubAutoMergeResponse();
          }(),
          DisableGitHubAutoMergeRequest() => () {
            whole = mergePull('blocked');
            return DisableGitHubAutoMergeResponse();
          }(),
          _ => null,
        },
      );
      expect(_says(tester), contains("Can't merge yet."));
      expect(find.text('Squash and merge'), findsNothing);
      await tester.tap(find.text('Enable auto-merge').first);
      await tester.pumpAndSettle();
      expect(find.text('Enable auto-merge?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Enable auto-merge'),
        ),
      );
      await tester.pumpAndSettle();
      final sent = fake.calls.whereType<EnableGitHubAutoMergeRequest>().single;
      expect(sent.headOid, 'b' * 40);
      expect(sent.method, 'squash');
      expect(sent.title, 'Ignore q params (#412)');
      expect(_says(tester), contains('turned on by mona'));
      await tester.tap(find.text('Disable auto-merge').first);
      await tester.pumpAndSettle();
      expect(
        fake.calls.whereType<DisableGitHubAutoMergeRequest>(),
        hasLength(1),
      );
      expect(find.text('Enable auto-merge'), findsWidgets);
      d.dispose();
    }, variant: _mac);
  });

  group('the merge queue', () {
    testWidgets('Add to queue, with the head, then Remove from queue', (
      tester,
    ) async {
      var whole = mergePull('ready')
        ..merge.queue = true
        ..merge.queueMethod = 'squash';
      final (d, fake) = await openPullTab(
        tester,
        whole,
        more: (input) => switch (input) {
          GetGitHubPullRequest() => GetGitHubPullResponse(pull: whole),
          EnqueueGitHubPullRequest() => () {
            whole = mergePull('queue');
            return EnqueueGitHubPullResponse();
          }(),
          _ => null,
        },
      );
      expect(find.text('Squash and merge'), findsNothing);
      await tester.tap(find.text('Add to queue').first);
      await tester.pumpAndSettle();
      expect(find.text('Add to the merge queue?'), findsOneWidget);
      expect(find.byKey(_key), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Add to queue'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        fake.calls.whereType<EnqueueGitHubPullRequest>().single.headOid,
        'b' * 40,
      );
      expect(_says(tester), contains('Position 3'));
      await tester.tap(find.text('Remove from queue').first);
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<DequeueGitHubPullRequest>(), hasLength(1));
      d.dispose();
    }, variant: _mac);

    testWidgets('Merge when ready asks, and joins through auto-merge', (
      tester,
    ) async {
      final whole = mergePull('blocked')..merge.queue = true;
      final (d, fake) = await openPullTab(tester, whole);
      await tester.tap(find.text('Merge when ready').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Merge when ready'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        fake.calls.whereType<EnableGitHubAutoMergeRequest>().single.headOid,
        'b' * 40,
      );
      d.dispose();
    }, variant: _mac);
  });

  testWidgets('the split button is as wide as its label', (tester) async {
    final (d, _) = await openPullTab(
      tester,
      mergePull('ready'),
      details: true,
      open: false,
    );
    final split = find.byType(SplitButton);
    final caret = find.descendant(
      of: split,
      matching: find.byIcon(Icons.keyboard_arrow_down),
    );
    final wide = tester.getTopRight(caret).dx - tester.getTopLeft(split).dx;
    expect(wide, lessThan(170));
    d.dispose();
  }, variant: _mac);

  testWidgets('the details widget has it too', (tester) async {
    final (d, _) = await openPullTab(
      tester,
      mergePull('ready'),
      details: true,
      open: false,
    );
    expect(find.byType(MergeControl), findsOneWidget);
    expect(find.text('Squash and merge'), findsOneWidget);
    expect(find.text('Merge blocked'), findsNothing);
    d.dispose();
  }, variant: _mac);
}
