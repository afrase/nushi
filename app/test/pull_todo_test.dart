import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/toast.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

GitHubComment _bot(String body) =>
    said('github-actions', body, bot: true, review: 'commented');

final FindingsSetup _setup = findingsSetup(
  'github-actions',
  findingHeadingsDefault,
);

List<ReviewFinding> _read(String body) {
  final r = readFindings(_bot(body), _setup);
  expect(r.clean, isTrue);
  return r.findings;
}

/// A re-review on a later commit whose one finding is a sentence spelled
/// out as a list (four "must address" rows of one sentence's pieces).
const _pinReview = r'''
## Outline

Re-review after c0ffee1 and 5eed0a2: the cover image is checked once and the stored copy locked to that digest.

## Key findings

### Must address

`lib/covers/store/locked_image.rb:31-58`: the lock holds only if every reader checks it. As written:

- the thumbnail job reads the file before the digest is saved;
- download streams the raw bytes;
- the preview and the export still open the path;
- digest = nil reaches File.open(path, mode, nil).

Both earlier threads are addressed: c0ffee1 adds the size limit (thread resolved), and 5eed0a2 limits cover validation to new uploads, with attach!/purge specs.

### Suggestions

- A spec for an image changed on disk would pin this down.

reviewer-xl · $0.94 · 3m 47s''';

/// The bar at the tab's foot, saying [n] cards wait in the box.
Finder _waiting(int n) => find.text(
  "$n waiting in the chat's box. They go with your next message.",
  findRichText: true,
);

void main() {
  setUpAll(loadFonts);

  test("a review bot's findings to address: a long review's shape", () {
    final f = _read(aiReviewBody);
    expect(f.map((f) => (f.path, f.start, f.end)), [
      ('spec/catalogue/list_spec.rb', 57, 63),
      ('spec/members/loan_spec.rb', 316, 316),
    ]);
    expect(f.first.text, startsWith('The one example for the catalogue-list'));
    expect(findingPlace(f.first), 'spec/catalogue/list_spec.rb:57–63');
    // Suggestions, missing tests and the commit log aren't findings.
    expect(f.any((f) => f.text.contains('export endpoint')), isFalse);
  });

  test('a sentence spelled out as a list is one finding, its place the '
      "title; the reviewer's note after it isn't one", () {
    final f = _read(_pinReview);
    expect(f, hasLength(1));
    expect(findingPlace(f.single), 'lib/covers/store/locked_image.rb:31–58');
    expect(f.single.text, startsWith('the lock holds only if every reader'));
    expect(
      f.single.text,
      contains(
        'As written: the thumbnail job reads the file before the digest is '
        'saved; download streams the raw bytes; the preview and the export '
        'still open the path; digest = nil reaches',
      ),
    );
    expect(f.single.text, endsWith('File.open(path, mode, nil).'));
    expect(f.single.text, isNot(contains('Both earlier threads')));
  });

  test('places: path:line, a backticked path, bold; one said later is no '
      'place', () {
    final f = _read(
      'Looks fine overall.\n\n**Must address:**\n'
      '- `lib/a.go:12-14` — the handler drops the error.\n'
      '- app/b.rb:7: nothing logs a retry\n  when it gives up.\n'
      '- `config/routes.rb`: the route is public.\n'
      '- The handler in `lib/c.go:3` drops the error.\n\n'
      '**Nits:**\n- rename `x`',
    );
    expect(f.map((f) => (findingPlace(f), f.text)), [
      ('lib/a.go:12–14', 'the handler drops the error.'),
      ('app/b.rb:7', 'nothing logs a retry when it gives up.'),
      ('config/routes.rb', 'the route is public.'),
      ('', 'The handler in `lib/c.go:3` drops the error.'),
    ]);
  });

  test('paragraphs are findings each; "None" is none; a shape not known '
      'gives none rather than pieces', () {
    expect(
      _read(
        '### Must address\n\n`a.rb:3`: first one.\nStill first.\n\n'
        'Second one.',
      ).map((f) => f.text),
      ['first one. Still first.', 'Second one.'],
    );
    expect(
      _read('### Must address\n\nNone. The fix holds:\n- a;\n- b.'),
      isEmpty,
    );
    // A list, a note, a list again: not a shape this reads.
    final mixed = readFindings(
      _bot('## Must address\n- one\n\nA note.\n\n- two'),
      _setup,
    );
    expect((mixed.found, mixed.clean), (true, false));
    expect(mixed.findings, isEmpty);
    // A clause left alone.
    final clause = readFindings(_bot('## Must address\n- only half;'), _setup);
    expect(clause.clean, isFalse);
    // No heading that says so, a bot not named, or not a bot: none.
    expect(_read('## Notes\n- a.go:1 is odd'), isEmpty);
    expect(isFindingsBot(said('other', 'x', bot: true), _setup), isFalse);
    expect(isFindingsBot(said('mona', 'x'), _setup), isFalse);
    expect(
      isFindingsBot(said('github-actions[bot]', 'x', bot: true), _setup),
      isTrue,
    );
    // The headings are the setting's.
    final mine = findingsSetup('github-actions', 'Blockers');
    expect(
      readFindings(_bot('## Blockers\n- `a.rb:1`: x.'), mine).findings,
      hasLength(1),
    );
    expect(readFindings(_bot(aiReviewBody), mine).found, isFalse);
  });

  test('the To do list: failing checks (required first), changes '
      "requested, threads with a bot's finding on their lines, the "
      'findings left (only when Settings reads them)', () {
    String say(TodoItem i) => switch (i) {
      CheckTodo(:final check) => check.name,
      ReviewTodo(:final review) => '@${review.author} review',
      ThreadTodo(:final thread, :final also) =>
        '${thread.path} +${also.length}',
      FindingTodo(:final finding) => findingPlace(finding),
    };
    const base = [
      'specs (staff 3/8)',
      'linters',
      'layering check',
      '@mona review',
      'app/controllers/staff/loans_controller.rb +0',
    ];
    // Off (the default): only what GitHub structures.
    expect(todo(fixturePull()).items.map(say), [
      ...base,
      'spec/members/loan_spec.rb +0',
    ]);
    final items = todo(fixturePull(), findings: _setup).items;
    expect(items.map(say), [
      ...base,
      'spec/members/loan_spec.rb +1',
      'spec/catalogue/list_spec.rb:57–63',
    ]);
    final merged = fixturePull()..item.state = 'merged';
    expect(todo(merged, findings: _setup).items, isEmpty);
    // The review's card is the whole review, with whose it is.
    final review = (items[3] as ReviewTodo).review;
    expect(changesRequestedReply(review).from, 'Changes requested by @mona');
    expect(
      changesRequestedReply(review).quote,
      startsWith('mona requested changes:'),
    );
    // The thread's card carries the bot's voice too.
    final thread = items[5] as ThreadTodo;
    final r = threadReply(thread.thread, also: thread.also);
    expect(r.from, 'Review comments from @mona, @github-actions');
    expect(r.quote, contains("github-actions' review: The example says"));
    final f = findingReply((items[6] as FindingTodo).finding);
    expect(f.from, "A finding from @github-actions' review");
    expect(
      f.quote,
      startsWith(
        "Finding in github-actions' review on "
        'spec/catalogue/list_spec.rb:57–63:',
      ),
    );
  });

  test('two failing checks of one name (a push run and a pull request '
      "run) are two rows; a commit status's row is by its name", () {
    final p = fixturePull()
      ..checks.clear()
      ..checks.addAll([
        check('test', state: 'failure', id: 7),
        check('test', state: 'failure', id: 8),
        check('ci/circleci', state: 'failure'),
      ]);
    expect(todo(p).items.whereType<CheckTodo>().map((i) => i.id), [
      'check 7',
      'check 8',
      'status ci/circleci',
    ]);
  });

  test("only each bot's newest message: an older one's findings never "
      "show; one on an older commit's do, marked", () {
    List<FindingTodo> found(GitHubPull p) =>
        todo(p, findings: _setup).items.whereType<FindingTodo>().toList();
    // The newest says none.
    final none = fixturePull()
      ..conversation.add(
        said(
          'github-actions',
          '## Key findings\n\n### Must address\n\nNone.',
          bot: true,
          review: 'commented',
          age: const Duration(seconds: 30),
        ),
      );
    expect(found(none), isEmpty);
    // The newest is a plain comment with no findings section at all.
    final comment = fixturePull()
      ..conversation.add(
        said(
          'github-actions',
          'Review app deployed.',
          bot: true,
          age: const Duration(seconds: 30),
        ),
      );
    expect(found(comment), isEmpty);
    // Two messages with findings: the newest's only, never both.
    final two = fixturePull()
      ..conversation.add(
        said(
          'github-actions',
          '### Must address\n- `lib/x.rb:3`: still broken.',
          bot: true,
          age: const Duration(seconds: 30),
        ),
      );
    expect(found(two).map((i) => findingPlace(i.finding)), ['lib/x.rb:3']);
    // On an older commit: its findings, the bot marked.
    final old = fixturePull();
    old.conversation[1].commit = 'c0ffee1${'c' * 33}';
    final t = todo(old, findings: _setup);
    expect(
      t.items.whereType<FindingTodo>(),
      hasLength(1),
    ); // and one on a thread
    expect(t.older, {'github-actions': 'c0ffee1${'c' * 33}'});
    old.conversation[1].commit = old.headOid;
    expect(todo(old, findings: _setup).older, isEmpty);
  });

  testWidgets("the merge status card's Send 6 to agent and a failing "
      "check's Send to agent put reply cards in the box, each saying whose; "
      'a toast only when none went; the bar counts them', (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    final box = d.chats['c']!.draft.replies;
    Finder toast(String s) =>
        find.descendant(of: find.byType(ToastLine), matching: find.text(s));
    await tester.tap(find.byKey(const ValueKey('segment checks')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to agent').at(1));
    await tester.pumpAndSettle();
    expect(box.value.single.from, startsWith('Failed checks on PR'));
    expect(box.value.single.quote, startsWith('Check CI / linters:'));
    expect(
      box.value.single.from,
      endsWith('on PR octo/shelf#412 (GitHub), my pull request:'),
    );
    expect(find.byType(ToastLine), findsNothing);
    // The bar, at the tab's foot.
    final bar = _waiting(1);
    expect(bar, findsOneWidget);
    expect(tester.getRect(bar).top, greaterThan(800));
    await tester.tap(find.text('Send 6 to agent'));
    await tester.pumpAndSettle();
    expect(box.value.length, 6); // the same card once
    expect(box.value[3].from, startsWith('Changes requested by @mona'));
    expect(_waiting(6), findsOneWidget);
    expect(find.byType(ToastLine), findsNothing);
    // All of them there already: only a toast can say so.
    await tester.tap(find.text('Send 6 to agent'));
    await tester.pumpAndSettle();
    expect(toast("All 6 are in the chat's box already"), findsOneWidget);
    box.value = const [];
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    // Go to chat, from the bar.
    await tester.tap(find.text('Send 6 to agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Go to chat'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.tab.value.name, 'chat');
    d.dispose();
  }, variant: onMac);

  testWidgets("Settings' Findings from review bots: off, no findings; on, "
      'in the Comments segment, sent with the rest', (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    await tester.tap(find.byKey(const ValueKey('segment comments')));
    await tester.pumpAndSettle();
    expect(find.text('spec/catalogue/list_spec.rb:57–63'), findsNothing);
    githubFindings.value = true;
    await tester.pumpAndSettle();
    expect(find.text('2 unresolved · 1 finding'), findsOneWidget);
    expect(find.text('spec/catalogue/list_spec.rb:57–63'), findsOneWidget);
    expect(find.text('Send 7 to agent'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets("a bot's review on an older commit says so in its card", (
    tester,
  ) async {
    githubFindings.value = true;
    final old = fixturePull();
    old.conversation[1].commit = 'c0ffee1${'c' * 33}';
    old.reviews[1].commit = 'c0ffee1${'c' * 33}';
    final (d2, _) = await openPullTab(tester, old);
    expect(
      find.text(
        'On an older commit (c0ffee1): some findings may be done · comment '
        '/review for a fresh one',
      ),
      findsOneWidget,
    );
    d2.dispose();
  }, variant: onMac);

  testWidgets("a check's log, from its ⋯: its failing part", (tester) async {
    final (d, fake) = await openPullTab(tester, fixturePull());
    await tester.tap(find.byKey(const ValueKey('segment checks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show the log'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<GetGitHubJobLogRequest>().single.job.toInt(),
      31,
    );
    expect(find.textContaining('exit code 1'), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide the log'));
    await tester.pumpAndSettle();
    expect(find.textContaining('exit code 1'), findsNothing);
    d.dispose();
  }, variant: onMac);

  testWidgets("a check's log that failed to come: hidden and shown again, "
      'asked again, and the error goes', (tester) async {
    var refuse = true;
    final (d, fake) = await openPullTab(
      tester,
      fixturePull(),
      more: (input) => input is GetGitHubJobLogRequest && refuse
          ? throw StateError('down')
          : null,
    );
    Future<void> toggle(String entry) async {
      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('segment checks')));
    await tester.pumpAndSettle();
    await toggle('Show the log');
    expect(find.text('Bad state: down'), findsOneWidget);
    refuse = false;
    await toggle('Hide the log');
    expect(find.text('Bad state: down'), findsNothing);
    await toggle('Show the log');
    // The refused call never reached the fake's calls.
    expect(fake.calls.whereType<GetGitHubJobLogRequest>(), hasLength(1));
    expect(find.textContaining('exit code 1'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('nothing blocks, a reviewer still asked: the card says ready, '
      'Approvals says who, with Ping on GitHub', (tester) async {
    final p = mergePull('ready')
      ..conversation.clear()
      ..reviewers.add(
        GitHubReviewer(login: 'library-keepers', state: 'requested'),
      );
    final (d, _) = await openPullTab(tester, p);
    expect(find.text('Ready to merge'), findsOneWidget);
    expect(find.text('1 approved · 1 awaited'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('segment approvals')));
    await tester.pumpAndSettle();
    expect(find.text('library-keepers'), findsNWidgets(2)); // and the side's
    expect(find.text('Ping on GitHub'), findsOneWidget);
    d.dispose();
  }, variant: onMac);
}
