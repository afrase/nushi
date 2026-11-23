import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const fixtureRepo = 'octo/notes';

GitHubComment said(
  String author,
  String body, {
  String review = '',
  bool bot = false,
  Duration age = const Duration(minutes: 30),
  bool outside = false,
  String? id,
  String reviewId = '',
}) => GitHubComment(
  id: id ?? 'C_${author}_${body.length}_${age.inSeconds}',
  reviewId: reviewId,
  author: author,
  outside: outside,
  bot: bot,
  body: body,
  url: 'https://github.com/$fixtureRepo/pull/412#c',
  createdMs: msAgo(age),
  review: review,
);

GitHubCheck check(
  String name, {
  String state = 'success',
  bool required = false,
  String workflow = 'CI',
  int id = 0,
  List<GitHubAnnotation> annotations = const [],
}) => GitHubCheck(
  id: Int64(id),
  name: name,
  workflow: workflow,
  state: state,
  failed: state == 'failure',
  required: required,
  url: 'https://github.com/$fixtureRepo/actions/runs/1/job/$id',
  annotations: annotations,
);

/// The Danger bot's comment: a table of one message.
const dangerBody =
    '| | 1 Message |\n| --- | --- |\n'
    '| :book: | **Review App Links** · Notes: '
    '[filters-malformed-q.review.example.dev]($_review) · Traces: '
    '[Datadog](https://example.dev/traces) · You can add sample notes with: '
    '`NOTES=$_review ./bin/seed-notes` |';

const _review = 'https://filters-malformed-q.review.example.dev';

/// A review bot's long review, with its findings to address.
const aiReviewBody = r'''
## Summary

This PR treats a `q` param that isn't a hash (`q=foo` or `q[]=foo`) like a missing `q` in the admin and notebook filters, so these requests return unfiltered results instead of a 500. It touches `Admin::NotesController`, `Admin::UsersController`, `Admin::SearchHelper`, and the notebook pages. The guards are correct under Rails 8's `permit`, and well-formed `q` hashes take the same path as before.

**Risk:** Medium

## Key findings

### Must address

1. **`spec/notebooks/page_spec.rb:68-72`**: The only test for the notebooks-page guard is in a file tagged `:deprecated`, which CI never runs. Nothing has run it.
2. **`spec/reports/page_spec.rb:409`**: The example says a non-hash `q` means no filters but only checks the 201. Assert `report.filters == {}` too.

### Suggestions

- If this guard is later extended to other `q` readers, keep it per action: autocomplete endpoints take `q` as a search term.

## Test coverage

- The array case is missing for the users controller and the search helper.

## PR hygiene

- 12 files, +69/−5, one commit with a clear subject and body.

claude-opus · $2.61 · 10m 31s''';

GitHubThread thread(
  String id,
  String path,
  int line,
  List<GitHubComment> comments, {
  bool resolved = false,
  String diffHunk = '',
}) => GitHubThread(
  diffHunk: diffHunk,
  id: id,
  path: path,
  side: 'right',
  line: line,
  canReply: true,
  canResolve: !resolved,
  canUnresolve: resolved,
  resolved: resolved,
  comments: comments,
);

/// The review bot's review, mona's changes requested (with T1 and T2) and
/// her earlier review that said nothing but T3; the ids the threads'
/// comments name (API 127).
const _botReview = 'PRR_bot';
const _monaReview = 'PRR_mona';
const _monaFirst = 'PRR_mona_1';

GitHubComment _botSaid() => said(
  'github-actions',
  aiReviewBody,
  bot: true,
  review: 'commented',
  age: const Duration(minutes: 2),
  outside: true,
  id: _botReview,
);

GitHubComment _monaSaid() => said(
  'mona',
  'Thanks, the guard looks right. Two small things before this goes in.',
  review: 'changes_requested',
  age: const Duration(minutes: 1),
  id: _monaReview,
);

/// [fixturePull]'s one commit (its head), as GetGitHubCommits answers it
/// (API 127); with [many], three, oldest first, the last its head, for a
/// pull request whose `commits` is 3: one by an author GitHub has no
/// account for, one with no checks.
GetGitHubCommitsResponse fixtureCommits({bool many = false}) {
  final head = GitHubCommit(
    oid: 'b' * 40,
    headline: "Ignore q params that aren't hashes in admin filters",
    author: 'afrase',
    authorName: 'afrase',
    committedMs: msAgo(const Duration(minutes: 20)),
    checks: 'failure',
  );
  if (!many) return GetGitHubCommitsResponse(total: 1, commits: [head]);
  return GetGitHubCommitsResponse(
    total: 3,
    commits: [
      GitHubCommit(
        oid: '1a2b3c4d5e6f708192a3b4c5d6e7f80912345678',
        headline: 'Guard the admin filters',
        author: 'afrase',
        authorName: 'afrase',
        committedMs: msAgo(const Duration(hours: 3)),
        checks: 'success',
      ),
      GitHubCommit(
        oid: '9f8e7d6c5b4a39281706f5e4d3c2b1a098765432',
        headline: 'Guard the notebook pages too',
        authorName: 'Tomas',
        committedMs: msAgo(const Duration(hours: 2)),
      ),
      head,
    ],
  );
}

/// A pull request with something to act on: three failing checks, changes
/// requested with two threads open, a code owners' team still to approve,
/// the Danger bot's comment and a review bot's long review. Opened three
/// hours ago, labelled and assigned; each thread names its review and has
/// its diff hunk (API 127).
GitHubPull fixturePull() => GitHubPull(
  item: GitHubItem(
    ref: GitHubRef(host: 'github.com', repo: fixtureRepo, number: 412),
    id: 'PR_412',
    pull: true,
    title: "Ignore q params that aren't hashes in admin filters",
    url: 'https://github.com/$fixtureRepo/pull/412',
    state: 'open',
    author: 'afrase',
    updatedMs: msAgo(const Duration(minutes: 1)),
    createdMs: msAgo(const Duration(hours: 3)),
    checks: 'failure',
    review: 'changes_requested',
    unresolved: 2,
  ),
  labels: [
    GitHubLabel(name: 'bug', color: 'd73a4a'),
    GitHubLabel(name: 'admin', color: '0e8a16'),
  ],
  assignees: ['afrase', 'mira'],
  reviews: [
    said(
      'mona',
      '',
      review: 'commented',
      age: const Duration(minutes: 25),
      id: _monaFirst,
    ),
    _botSaid(),
    _monaSaid(),
  ],
  body:
      '**Explanation:** admin and notebook filters call '
      "`params[:q].permit(…)`, so a `q` that isn't a hash (`q=foo` or "
      '`q[]=foo`) raises and the page 500s. This treats those like a '
      'missing `q`.\n\n'
      '- [x] Tests for each filter that reads `q`\n'
      '- [ ] Specs run locally (CI will run them)',
  base: 'main',
  head: 'filters-malformed-q',
  headRepo: fixtureRepo,
  baseOid: 'a' * 40,
  headOid: 'b' * 40,
  mergeable: 'mergeable',
  mergeState: 'blocked',
  // As the daemon says it (API 96): blocked by the failing required checks
  // and the changes asked for; no auto-merge here.
  merge: GitHubMerge(
    canMerge: true,
    blocks: ['checks_failing', 'changes_requested'],
  ),
  additions: 69,
  deletions: 5,
  changedFiles: 12,
  commits: 1,
  reviewers: [
    GitHubReviewer(
      login: 'notes-reviewers',
      state: 'requested',
      team: true,
      codeOwner: true,
    ),
    GitHubReviewer(login: 'mona', state: 'changes_requested'),
    GitHubReviewer(login: 'github-actions', state: 'commented'),
  ],
  conversation: [
    said(
      'github-actions',
      dangerBody,
      bot: true,
      age: const Duration(minutes: 11),
      outside: true,
    ),
    _botSaid(),
    _monaSaid(),
  ],
  threads: [
    thread(
      'T1',
      'app/controllers/admin/notes_controller.rb',
      42,
      [
        said(
          'mona',
          'Can we log when we drop a malformed `q`? Otherwise we lose the '
              'signal that someone is sending scalars here.',
          age: const Duration(minutes: 1),
          reviewId: _monaReview,
        ),
      ],
      diffHunk:
          '@@ -39,4 +39,4 @@\n'
          '     # 39\n'
          '     # 40\n'
          '     # 41\n'
          '-      q\n'
          '+      q.is_a?(Hash) ? q : {}',
    ),
    thread(
      'T2',
      'spec/reports/page_spec.rb',
      409,
      [
        said(
          'mona',
          'The example says a non-hash `q` means no filters but only checks '
              'the 201. Can it assert `report.filters == {}` too?',
          age: const Duration(minutes: 1),
          reviewId: _monaReview,
        ),
      ],
      diffHunk:
          '@@ -405,3 +405,5 @@ describe "reports" do\n'
          '   it "ignores a non-hash q" do\n'
          '+    get "/reports", params: { q: "foo" }\n'
          '+    expect(response).to have_http_status(201)',
    ),
    thread(
      'T3',
      'app/helpers/admin/search_helper.rb',
      18,
      [
        said(
          'mona',
          'nit, `.presence` reads better here',
          reviewId: _monaFirst,
        ),
        said('afrase', 'Done.', reviewId: 'PRR_afrase_reply'),
      ],
      resolved: true,
      diffHunk:
          '@@ -16,3 +16,3 @@ module SearchHelper\n'
          '     def term\n'
          '-      params[:term].blank? ? nil : params[:term]\n'
          '+      params[:term].presence',
    ),
  ],
  checks: [
    check(
      'rspec (admin 3/8)',
      state: 'failure',
      required: true,
      id: 31,
      annotations: [
        GitHubAnnotation(
          path: 'spec/admin/users_controller_spec.rb',
          line: 88,
          level: 'failure',
          message: 'expected 5 users, got 0',
        ),
      ],
    ),
    check(
      'rubocop',
      state: 'failure',
      required: true,
      id: 32,
      annotations: [
        GitHubAnnotation(
          path: 'app/helpers/admin/search_helper.rb',
          line: 21,
          level: 'failure',
          message:
              'Style/GuardClause: use a guard clause instead of wrapping '
              'the code in a conditional',
        ),
      ],
    ),
    check('packwerk check', state: 'failure', id: 33),
    for (final n in [
      'rspec (admin 1/8)',
      'rspec (admin 2/8)',
      'rspec (admin 4/8)',
      'rspec (admin 5/8)',
      'brakeman',
      'eslint',
      'review-app',
      'claude-review',
    ])
      check(n, required: n.startsWith('rspec')),
    check('staging', state: 'skipped', workflow: 'Deploy'),
    check('release notes', state: 'skipped', workflow: ''),
  ],
);

/// [fixturePull] in a state its Merge control can show: "ready" (nothing in
/// the way), "blocked" (as it is, a rule's reasons), "auto" (auto-merge on) or
/// "queue" (third in its merge queue). The viewer has write access; the
/// repository allows all three methods, and squash was used last.
GitHubPull mergePull(String state) {
  final merge = GitHubMerge(
    methods: ['merge', 'squash', 'rebase'],
    defaultMethod: 'squash',
    canMerge: true,
    canRebase: true,
    autoAllowed: true,
  );
  final p = fixturePull()..merge = merge;
  if (state == 'blocked') {
    return p
      ..merge.blocks.addAll(['checks_failing', 'changes_requested', 'threads'])
      ..merge.canEnableAuto = true;
  }
  p
    ..mergeState = 'clean'
    ..checks.clear()
    ..checks.addAll([check('rspec', required: true), check('rubocop')])
    ..reviewers.clear()
    ..reviewers.add(GitHubReviewer(login: 'mona', state: 'approved'))
    ..threads.clear()
    ..item.checks = 'success'
    ..item.review = 'approved'
    ..item.unresolved = 0;
  switch (state) {
    case 'auto':
      p
        ..mergeState = 'blocked'
        ..merge.blocks.add('rules')
        ..merge.canDisableAuto = true
        ..merge.auto = GitHubAutoMerge(by: 'mona', method: 'squash');
    case 'queue':
      p
        ..merge.queue = true
        ..merge.queueMethod = 'squash'
        ..merge.entry = GitHubQueueEntry(
          position: 3,
          state: 'awaiting_checks',
          by: 'afrase',
          etaSeconds: 840,
        );
  }
  return p;
}

final fixtureLink = GitHubLink(
  host: 'github.com',
  repo: fixtureRepo,
  number: 412,
  id: 'PR_412',
  pull: true,
);

/// The app at [size] on a chat linked to [whole], its Pull request tab
/// open; [more] answers the calls the fixture doesn't, [commits] its
/// commits (else [fixtureCommits]'s one).
Future<(Daemon, FakeDaemon)> openPullTab(
  WidgetTester tester,
  GitHubPull whole, {
  Size size = const Size(1440, 900),
  bool details = false,
  Brightness brightness = Brightness.dark,
  Object? Function(Object input)? more,
  bool open = true,
  Worktree? worktree,
  bool busy = false,
  GetGitHubCommitsResponse? commits,
}) async {
  showDetails.value = details;
  collapsedWidgets.value = {};
  widgetOrder.value = ['Pull request'];
  pullSeenComments.value = {};
  final c = chat(
    'c',
    'claude',
    'Fix malformed q in admin filters',
    status: busy ? ChatStatus(busy: true) : null,
  );
  if (worktree != null) {
    c
      ..worktree = worktree
      ..folder = worktree.path;
  }
  final fake = FakeDaemon([c])
    ..answer = (input) =>
        more?.call(input) ??
        switch (input) {
          FindChatPullRequest() => FindChatPullResponse(
            host: 'github.com',
            repo: whole.item.ref.repo,
            branch: whole.head,
            pull: GitHubLink(
              host: whole.item.ref.host,
              repo: whole.item.ref.repo,
              number: whole.item.ref.number,
              id: whole.item.id,
              pull: true,
            ),
          ),
          GetGitHubPullRequest() => GetGitHubPullResponse(pull: whole),
          GetGitHubCommitsRequest() => commits ?? fixtureCommits(),
          ListGitHubHostsRequest() => ListGitHubHostsResponse(
            hosts: [
              GitHubHost(host: 'github.com', login: 'afrase', source: 'gh'),
            ],
          ),
          GetGitHubJobLogRequest() => GetGitHubJobLogResponse(
            tail:
                'Run bundle exec rspec\n'
                'Failures:\n  1) Admin::UsersController filters\n'
                '     expected 5 users, got 0\n'
                '##[error]Process completed with exit code 1.',
          ),
          GetGitHubFilesRequest() => GetGitHubFilesResponse(
            files: [
              for (final (path, text) in [
                (
                  'app/helpers/admin/search_helper.rb',
                  'module Admin\n  module SearchHelper\n  end\nend\n',
                ),
                (
                  'app/controllers/admin/notes_controller.rb',
                  [
                    for (var i = 1; i <= 50; i++)
                      if (i == 42)
                        '      q.is_a?(Hash) ? q : {}'
                      else
                        '    # $i',
                  ].join('\n'),
                ),
                ('spec/reports/page_spec.rb', 'describe "reports" do\nend\n'),
              ])
                FileChange(
                  path: path,
                  status: 'modified',
                  oldText: text.replaceFirst('q.is_a?(Hash) ? q : {}', 'q'),
                  newText: text,
                  added: 1,
                  removed: 1,
                ),
            ],
          ),
          _ => null,
        };
  final d = await openApp(tester, fake, size: size, brightness: brightness);
  if (open) {
    await tester.tap(
      find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text('Pull request'),
      ),
    );
    await tester.pumpAndSettle();
  }
  return (d, fake);
}
