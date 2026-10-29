import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

GitHubComment _bot(String body) =>
    said('review-bot', body, bot: true, review: 'commented');

void main() {
  setUpAll(loadFonts);

  test("a review bot's findings to address", () {
    final f = reviewFindings(_bot(aiReviewBody));
    expect(f.map((f) => (f.path, f.start, f.end)), [
      ('spec/notebooks/page_spec.rb', 68, 72),
      ('spec/reports/page_spec.rb', 409, 409),
    ]);
    expect(f.first.text, startsWith('The only test for the notebooks-page'));
    // A bold line for a heading, bullets, a place in the text.
    final b = reviewFindings(
      _bot(
        'Looks fine overall.\n\n**Must fix:**\n'
        '- The handler in `lib/a.go:12` drops the error.\n'
        '- Nothing logs a retry\n  when it gives up.\n\n'
        '**Nits:**\n- rename `x`',
      ),
    );
    expect(b.map((f) => (f.path, f.start, f.text)), [
      ('lib/a.go', 12, 'The handler in `lib/a.go:12` drops the error.'),
      ('', 0, 'Nothing logs a retry when it gives up.'),
    ]);
    // No heading that says so, or not a bot: none.
    expect(reviewFindings(_bot('## Notes\n- a.go:1 is odd')), isEmpty);
    expect(
      reviewFindings(said('mona', '### Must address\n- a.go:1 is odd')),
      isEmpty,
    );
  });

  test('the To do list: failing checks (required first), threads with a '
      "bot's finding on their lines, the findings left", () {
    final items = todoItems(fixturePull());
    String say(TodoItem i) =>
        i.check?.name ??
        (i.thread != null
            ? '${i.thread!.path} +${i.also.length}'
            : findingPlace(i.finding!));
    expect(items.map(say), [
      'rspec (admin 3/8)',
      'rubocop',
      'packwerk check',
      'app/controllers/admin/notes_controller.rb +0',
      'spec/reports/page_spec.rb +1',
      'spec/notebooks/page_spec.rb:68–72',
    ]);
    final merged = fixturePull()..item.state = 'merged';
    expect(todoItems(merged), isEmpty);
    // The thread's card carries the bot's voice too.
    final r = threadReply(items[4].thread!, also: items[4].also);
    expect(r.from, 'Review comments from @mona, @github-actions');
    expect(r.quote, contains("github-actions's review: The example says"));
    final f = findingReply(items[5].finding!);
    expect(f.from, "A finding from @github-actions's review");
    expect(
      f.quote,
      startsWith(
        "Finding in github-actions's review on "
        'spec/notebooks/page_spec.rb:68–72:',
      ),
    );
  });

  testWidgets('Send, Send picked and Send all put reply cards in the box, '
      'each saying whose', (tester) async {
    final (d, _) = await openPullTab(tester, fixturePull());
    final box = d.chats['c']!.draft.replies;
    expect(find.text('To do'), findsOneWidget);
    expect(
      find.textContaining(
        'Then waiting on @notes-reviewers',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Send').first);
    await tester.pumpAndSettle();
    expect(box.value.single.from, startsWith('Failed check CI / rspec'));
    expect(
      box.value.single.from,
      endsWith('on PR octo/notes#412 (GitHub), my pull request:'),
    );
    expect(box.value.single.quote, contains('exit code 1'));
    // Two picked: rubocop and the finding.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.tap(find.byType(Checkbox).at(5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send 2 picked'));
    await tester.pumpAndSettle();
    expect(box.value.length, 3);
    expect(box.value.last.from, startsWith("A finding from @github-actions's"));
    expect(find.text('Send 2 picked'), findsNothing); // unpicked once sent
    await tester.tap(find.text('Send all 6 to agent'));
    await tester.pumpAndSettle();
    expect(box.value.length, 6); // the same card once
    d.dispose();
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
