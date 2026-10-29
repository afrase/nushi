import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

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

/// A re-review on a later commit, as the owner's screenshot showed it
/// (four "must address" rows of one sentence's pieces).
const _pinReview = r'''
## Summary

Re-review after c0ffee1 and 5eed0a2: the webhook URL is resolved once and the connection pinned to that address.

## Key findings

### Must address

`lib/webhooks/http/pinned_connection.rb:31-58`: the pin holds only if every connection uses it. As written:

- the adapter block runs for every request and every redirect hop;
- connect dials ipaddr;
- SNI and post_connection_check still use the hostname;
- proxy = nil reaches Net::HTTP.new(host, port, nil).

Both earlier threads are addressed: c0ffee1 adds the address fallback (thread resolved), and 5eed0a2 limits webhook_url validation to URL changes, with deliver!/save specs.

### Suggestions

- A spec for a redirect to a private address would pin this down.

claude-opus · $1.12 · 4m 02s''';

void main() {
  setUpAll(loadFonts);

  test("a review bot's findings to address: a long review's shape", () {
    final f = _read(aiReviewBody);
    expect(f.map((f) => (f.path, f.start, f.end)), [
      ('spec/notebooks/page_spec.rb', 68, 72),
      ('spec/reports/page_spec.rb', 409, 409),
    ]);
    expect(f.first.text, startsWith('The only test for the notebooks-page'));
    expect(findingPlace(f.first), 'spec/notebooks/page_spec.rb:68–72');
    // Suggestions, test coverage and hygiene aren't findings.
    expect(f.any((f) => f.text.contains('autocomplete')), isFalse);
  });

  test('a sentence spelled out as a list is one finding, its place the '
      "title; the reviewer's note after it isn't one", () {
    final f = _read(_pinReview);
    expect(f, hasLength(1));
    expect(
      findingPlace(f.single),
      'lib/webhooks/http/pinned_connection.rb:31–58',
    );
    expect(f.single.text, startsWith('the pin holds only if every connection'));
    expect(
      f.single.text,
      contains(
        'As written: the adapter block runs for every request and every '
        'redirect hop; connect dials ipaddr; SNI and post_connection_check '
        'still use the hostname; proxy = nil reaches',
      ),
    );
    expect(f.single.text, endsWith('Net::HTTP.new(host, port, nil).'));
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
    String say(TodoItem i) =>
        i.check?.name ??
        (i.review != null
            ? '@${i.review!.author} review'
            : i.thread != null
            ? '${i.thread!.path} +${i.also.length}'
            : findingPlace(i.finding!));
    const base = [
      'rspec (admin 3/8)',
      'rubocop',
      'packwerk check',
      '@mona review',
      'app/controllers/admin/notes_controller.rb +0',
    ];
    // Off (the default): only what GitHub structures.
    expect(todo(fixturePull()).items.map(say), [
      ...base,
      'spec/reports/page_spec.rb +0',
    ]);
    final items = todo(fixturePull(), findings: _setup).items;
    expect(items.map(say), [
      ...base,
      'spec/reports/page_spec.rb +1',
      'spec/notebooks/page_spec.rb:68–72',
    ]);
    final merged = fixturePull()..item.state = 'merged';
    expect(todo(merged, findings: _setup).items, isEmpty);
    // The review's card is the whole review, with whose it is.
    final review = items[3].review!;
    expect(reviewReply(review).from, 'Changes requested by @mona');
    expect(reviewReply(review).quote, startsWith('mona requested changes:'));
    // The thread's card carries the bot's voice too.
    final r = threadReply(items[5].thread!, also: items[5].also);
    expect(r.from, 'Review comments from @mona, @github-actions');
    expect(r.quote, contains("github-actions' review: The example says"));
    final f = findingReply(items[6].finding!);
    expect(f.from, "A finding from @github-actions' review");
    expect(
      f.quote,
      startsWith(
        "Finding in github-actions' review on "
        'spec/notebooks/page_spec.rb:68–72:',
      ),
    );
  });

  test("only each bot's newest message: an older one's findings never "
      "show; one on an older commit's do, marked", () {
    List<TodoItem> found(GitHubPull p) => todo(
      p,
      findings: _setup,
    ).items.where((i) => i.finding != null).toList();
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
    expect(found(two).map((i) => findingPlace(i.finding!)), ['lib/x.rb:3']);
    // On an older commit: its findings, the bot marked.
    final old = fixturePull();
    old.conversation[1].commit = 'c0ffee1${'c' * 33}';
    final t = todo(old, findings: _setup);
    expect(
      t.items.where((i) => i.finding != null),
      hasLength(1),
    ); // and one on a thread
    expect(t.older, {'github-actions': 'c0ffee1${'c' * 33}'});
    old.conversation[1].commit = old.headOid;
    expect(todo(old, findings: _setup).older, isEmpty);
  });

  testWidgets('Send, Send picked and Send all put reply cards in the box, '
      'each saying whose; a toast says what went, the row "In the box ✓" '
      'until the card goes; the bar counts them', (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    final box = d.chats['c']!.draft.replies;
    Finder toast(String s) =>
        find.descendant(of: find.byType(SnackBar), matching: find.text(s));
    expect(find.text('To do'), findsOneWidget);
    expect(
      find.textContaining(
        'Then waiting on @notes-reviewers',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Send').at(1));
    await tester.pumpAndSettle();
    expect(box.value.single.from, startsWith('Failed checks on PR'));
    expect(box.value.single.quote, startsWith('Check CI / rubocop:'));
    expect(
      box.value.single.from,
      endsWith('on PR octo/notes#412 (GitHub), my pull request:'),
    );
    expect(toast("Added to the chat's box: CI / rubocop"), findsOneWidget);
    expect(toast('Go to chat'), findsOneWidget);
    expect(find.text('In the box ✓'), findsOneWidget);
    expect(find.text('Send'), findsNWidgets(5));
    // The bar, at the tab's foot.
    final bar = find.text(
      "1 waiting in the chat's box. They go with your next message.",
      findRichText: true,
    );
    expect(bar, findsOneWidget);
    expect(tester.getRect(bar).top, greaterThan(800));
    // Two picked: rspec and mona's review.
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send 2 picked'));
    await tester.pumpAndSettle();
    expect(box.value.length, 3);
    expect(box.value.last.from, startsWith('Changes requested by @mona'));
    expect(toast("Added 2 to the chat's box"), findsOneWidget);
    expect(find.text('Send 2 picked'), findsNothing); // unpicked once sent
    expect(find.text('In the box ✓'), findsNWidgets(3));
    await tester.tap(find.text('Send all 6 to agent'));
    await tester.pumpAndSettle();
    expect(box.value.length, 6); // the same card once
    expect(
      toast("Added 3 to the chat's box; 3 were there already"),
      findsOneWidget,
    );
    expect(find.text('Send'), findsNothing);
    // A card taken out: its row can send again; all sent: every row can.
    box.value = box.value.sublist(1);
    await tester.pumpAndSettle();
    expect(find.text('Send'), findsOneWidget);
    box.value = const [];
    await tester.pumpAndSettle();
    expect(find.text('In the box ✓'), findsNothing);
    expect(bar, findsNothing);
    // Go to chat, from the toast.
    await tester.tap(find.text('Send').first);
    await tester.pumpAndSettle();
    await tester.tap(toast('Go to chat'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.tab.value.name, 'chat');
    d.dispose();
  }, variant: _mac);

  testWidgets("Settings' Findings from review bots: off, no findings; on, "
      'under their bot', (tester) async {
    addTearDown(() => githubFindings.value = false);
    final (d, _) = await openPullTab(tester, fixturePull());
    expect(find.text('@mona'), findsOneWidget);
    expect(find.text('Findings from github-actions'), findsNothing);
    githubFindings.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Findings from github-actions'), findsOneWidget);
    expect(find.text('spec/notebooks/page_spec.rb:68–72'), findsOneWidget);
    expect(find.text('Send all 7 to agent'), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets("a bot's review on an older commit: its findings' group says "
      'so, and shows it', (tester) async {
    githubFindings.value = true;
    addTearDown(() => githubFindings.value = false);
    final old = fixturePull();
    old.conversation[1].commit = 'c0ffee1${'c' * 33}';
    final (d2, _) = await openPullTab(tester, old);
    expect(
      find.text(
        'Findings from github-actions  from a review on an older commit '
        '(c0ffee1) · comment /review for a fresh one',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('spec/notebooks/page_spec.rb:68–72'), findsOneWidget);
    await tester.tap(find.text('Show the review'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Risk:', findRichText: true), findsOneWidget);
    d2.dispose();
  }, variant: _mac);

  testWidgets("a check's Log: its log's failing part; Threads jumps to the "
      'list', (tester) async {
    final (d, fake) = await openPullTab(tester, fixturePull());
    await tester.tap(find.text('Log').first);
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<GetGitHubJobLogRequest>().single.job.toInt(),
      31,
    );
    expect(find.textContaining('exit code 1'), findsOneWidget);
    await tester.tap(find.text('Hide log'));
    await tester.pumpAndSettle();
    expect(find.textContaining('exit code 1'), findsNothing);
    expect(tester.getRect(find.text('To do')).top, greaterThan(200));
    await tester.tap(find.text('2 unresolved'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('To do')).top, lessThan(100));
    d.dispose();
  }, variant: _mac);
}
