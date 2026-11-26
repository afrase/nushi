import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const fixtureRepo = 'octo/shelf';

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
    '| :book: | **Trial Site Links** · Shelf: '
    '[shelf-page-size-fix.sample.example.dev]($_review) · Graphs: '
    '[Plotter](https://example.dev/graphs) · You can add sample books with: '
    '`BOOKS=$_review ./bin/fill-shelf` |';

const _review = 'https://shelf-page-size-fix.sample.example.dev';

/// A review bot's long review, with its findings to address.
const aiReviewBody = r'''
## Outline

This PR reads an `n` param that isn't a number (`n=all` or `n[]=20`) like a missing `n` in the staff and catalogue listings, so these requests return the first page instead of a 500. It touches `Staff::LoansController`, `Staff::BooksController`, `Staff::LookupHelper`, and the catalogue pages. The checks hold up under Ruby 3.4's `Integer()`, and well-formed `n` values take the same path as before.

**Scope:** Small

## Key findings

### Must address

1. **`spec/catalogue/list_spec.rb:57-63`**: The one example for the catalogue-list check sits in a file marked `:slow`, which CI skips on pulls. It has never run.
2. **`spec/members/loan_spec.rb:316`**: The example says a bad `n` gives the first page but only checks the 200. Assert `loans.size == 25` as well.

### Suggestions

- If this check later covers other `n` readers, keep it per action: the export endpoint takes `n` as a row limit, not a page.

## Tests missing

- The list case is missing for the books controller and the lookup helpers.

## Commit log

- 12 files, +69/−5, one commit, with a message that says why.

reviewer-xl · $3.48 · 12m 05s''';

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
  'Thanks, the checks read right. Two small things, then this can land.',
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
    headline: "Read an n that isn't a number as page 1 in listings",
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
        headline: 'Check the staff listing',
        author: 'afrase',
        authorName: 'afrase',
        committedMs: msAgo(const Duration(hours: 3)),
        checks: 'success',
      ),
      GitHubCommit(
        oid: '9f8e7d6c5b4a39281706f5e4d3c2b1a098765432',
        headline: 'Check the catalogue page too',
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
    title: "Read an n that isn't a number as page 1 in listings",
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
    GitHubLabel(name: 'staff', color: '0e8a16'),
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
      '**Why and how:** staff and catalogue listings call '
      "`Integer(params[:n])`, so an `n` that isn't a number (`n=all` or "
      '`n[]=20`) raises and the page 500s. This treats them as a '
      'missing `n`.\n\n'
      '- [x] Specs for each listing that uses `n`\n'
      '- [ ] Specs pass on my Mac (CI will rerun)',
  base: 'main',
  head: 'shelf-page-size-fix',
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
      login: 'library-keepers',
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
      'app/controllers/staff/loans_controller.rb',
      42,
      [
        said(
          'mona',
          "Could we log when a bad `n` gets dropped? Otherwise we'd never "
              'learn which client keeps sending words here.',
          age: const Duration(minutes: 1),
          reviewId: _monaReview,
        ),
      ],
      diffHunk:
          '@@ -39,4 +39,4 @@\n'
          '     # 39\n'
          '     # 40\n'
          '     # 41\n'
          '-      n\n'
          '+      Integer(n) rescue nil',
    ),
    thread(
      'T2',
      'spec/members/loan_spec.rb',
      316,
      [
        said(
          'mona',
          'The example says a bad `n` gives the first page but only checks '
              'the 200. Could it also assert `loans.size == 25`?',
          age: const Duration(minutes: 1),
          reviewId: _monaReview,
        ),
      ],
      diffHunk:
          '@@ -312,3 +312,5 @@ describe "members" do\n'
          '   it "reads a bad n as one" do\n'
          '+    get "/members", params: { n: "all" }\n'
          '+    expect(response).to have_http_status(200)',
    ),
    thread(
      'T3',
      'app/helpers/staff/lookup_helper.rb',
      18,
      [
        said('mona', 'nit, `.delete` reads better to me', reviewId: _monaFirst),
        said('afrase', 'Done.', reviewId: 'PRR_afrase_reply'),
      ],
      resolved: true,
      diffHunk:
          '@@ -16,3 +16,3 @@ module LookupHelper\n'
          '     def isbn\n'
          '-      params[:isbn].to_s.gsub(" ", "").downcase\n'
          '+      isbn_param.delete(" ")',
    ),
  ],
  checks: [
    check(
      'specs (staff 3/8)',
      state: 'failure',
      required: true,
      id: 31,
      annotations: [
        GitHubAnnotation(
          path: 'spec/staff/books_controller_spec.rb',
          line: 73,
          level: 'failure',
          message: 'expected 3 loans, got 0',
        ),
      ],
    ),
    check(
      'linters',
      state: 'failure',
      required: true,
      id: 32,
      annotations: [
        GitHubAnnotation(
          path: 'app/helpers/staff/lookup_helper.rb',
          line: 27,
          level: 'failure',
          message:
              'Naming/OneLetter: name the variable for what it holds, '
              'rather than by a lone letter',
        ),
      ],
    ),
    check('layering check', state: 'failure', id: 33),
    for (final n in [
      'specs (staff 1/8)',
      'specs (staff 2/8)',
      'specs (staff 4/8)',
      'specs (staff 5/8)',
      'sec-scan',
      'js-fmt',
      'trial-site',
      'review-by-bot',
    ])
      check(n, required: n.startsWith('specs')),
    check('preview', state: 'skipped', workflow: 'Launch'),
    check('changelog row', state: 'skipped', workflow: ''),
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
    ..checks.addAll([check('specs', required: true), check('linters')])
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
    'Fix the page size in staff lists',
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
                'Run bin/specs shard 3\n'
                'Failures:\n  1) Staff::BooksController listing\n'
                '     expected 3 loans, got 0\n'
                '##[error]Process completed with exit code 1.',
          ),
          GetGitHubFilesRequest() => GetGitHubFilesResponse(
            files: [
              for (final (path, text) in [
                (
                  'app/helpers/staff/lookup_helper.rb',
                  'module Staff\n  module LookupHelper\n  end\nend\n',
                ),
                (
                  'app/controllers/staff/loans_controller.rb',
                  [
                    for (var i = 1; i <= 50; i++)
                      if (i == 42)
                        '      Integer(n) rescue nil'
                      else
                        '    # $i',
                  ].join('\n'),
                ),
                ('spec/members/loan_spec.rb', 'describe "members" do\nend\n'),
              ])
                FileChange(
                  path: path,
                  status: 'modified',
                  oldText: text.replaceFirst('Integer(n) rescue nil', 'n'),
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
