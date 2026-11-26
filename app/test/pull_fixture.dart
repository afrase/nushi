import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const fixtureRepo = 'octo/tally';

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
  url: 'https://github.com/$fixtureRepo/pull/537#c',
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
    '| :book: | **Export Dry Run** · Last night again, on this branch: '
    '[sightings-2026-11-25.csv]($_export) · 1,204 rows, 38 of them moved a '
    'day · Their sites: [Lima, Quito, Osaka](https://example.dev/sites) · '
    'Compare it with `tally diff $_export --since 2026-11-24` |';

const _export = 'https://files.example.dev/dry-run/export-in-site-zone.csv';

/// A review bot's long review, with its findings to address.
const aiReviewBody = '''
## Outline

The nightly export turned each sighting's UTC time into a date without a zone, so anything seen after 19:00 in Lima was filed under the next day. Rows now pass through `to_local()` with their site's zone before the CSV writer formats them; the JSON feed, which already sends offsets, is left alone. A new `zone_for(site)` reads the zone from the site record.

**Scope:** Small

## Key findings

### Must address

1. **`tests/export/test_dst.py:88-97`**: Both cases build their times with naive `datetime(...)` calls, so they compare UTC with UTC and pass with or without the fix.
2. **`tests/export/test_zones.py:188`**: Only a site west of Greenwich is tested. Osaka, where a sighting before 09:00 falls on the previous UTC day, would cover the other side.

### Suggestions

- `zone_for` builds a fresh zone object for every row; holding one per site for the run would save most of the export's new time.

## Tests missing

- Nothing covers a site whose zone is blank; it falls back to UTC with no warning.

## History

- One commit. Its message names the night the dates first went wrong.

sage-review · 18.2k tokens · 6m 18s''';

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
  "Nice catch on Lima. I'd like the blank zone logged before we ship it.",
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
    headline: "Export sighting dates in every site's own time zone",
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
        headline: 'Give each site a time zone',
        author: 'afrase',
        authorName: 'afrase',
        committedMs: msAgo(const Duration(hours: 3)),
        checks: 'success',
      ),
      GitHubCommit(
        oid: '9f8e7d6c5b4a39281706f5e4d3c2b1a098765432',
        headline: 'Format rows in their own zone',
        authorName: 'Priya',
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
    ref: GitHubRef(host: 'github.com', repo: fixtureRepo, number: 537),
    id: 'PR_537',
    pull: true,
    title: "Export sighting dates in every site's own time zone",
    url: 'https://github.com/$fixtureRepo/pull/537',
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
    GitHubLabel(name: 'export', color: '0e8a16'),
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
      'Sightings in the Americas came out a day late in the morning '
      'export: `.date()` ran on the stored UTC time. Each row is now moved '
      "into its site's zone first, and sites gained a `zone` column.\n\n"
      '- [x] Tests for Lima and the March clock change\n'
      "- [ ] Rerun last night's export and compare",
  base: 'main',
  head: 'export-in-site-zone',
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
  additions: 74,
  deletions: 9,
  changedFiles: 12,
  commits: 1,
  reviewers: [
    GitHubReviewer(
      login: 'field-data-team',
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
      'src/tally/export/nightly_sightings_csv.py',
      42,
      [
        said(
          'mona',
          'A site with no zone gets UTC here without a word. Could that be '
              "a warning in the run's summary, with the site's id?",
          age: const Duration(minutes: 1),
          reviewId: _monaReview,
        ),
      ],
      diffHunk:
          '@@ -39,4 +39,4 @@\n'
          '     # 39\n'
          '     # 40\n'
          '     # 41\n'
          '-    day = seen_at.date()\n'
          '+    day = to_local(seen_at, site).date()',
    ),
    thread(
      'T2',
      'tests/export/test_zones.py',
      188,
      [
        said(
          'mona',
          'Osaka would be a good second case: its early birds are the ones '
              'that land on the day before.',
          age: const Duration(minutes: 1),
          reviewId: _monaReview,
        ),
      ],
      diffHunk:
          '@@ -185,3 +185,5 @@ class TestZones:\n'
          '     def test_lima_evening(self):\n'
          '+        row = sighting("lima", "2026-03-08T21:30:00-05:00")\n'
          '+        assert export_date(row) == "2026-03-08"',
    ),
    thread(
      'T3',
      'src/tally/sites/zone_lookup.py',
      18,
      [
        said('mona', 'nit: `zoneinfo` over `pytz` now?', reviewId: _monaFirst),
        said('afrase', 'Switched.', reviewId: 'PRR_afrase_reply'),
      ],
      resolved: true,
      diffHunk:
          '@@ -16,3 +16,3 @@ def zone_for(site):\n'
          '     key = site.zone or "UTC"\n'
          '-    return pytz.timezone(key)\n'
          '+    return ZoneInfo(key)',
    ),
  ],
  checks: [
    check(
      'pytest (part 3)',
      state: 'failure',
      required: true,
      id: 31,
      annotations: [
        GitHubAnnotation(
          path: 'tests/export/test_zones.py',
          line: 192,
          level: 'failure',
          message: "assert '2026-03-09' == '2026-03-08'",
        ),
      ],
    ),
    check(
      'ruff',
      state: 'failure',
      required: true,
      id: 32,
      annotations: [
        GitHubAnnotation(
          path: 'src/tally/sites/zone_lookup.py',
          line: 27,
          level: 'failure',
          message:
              'DTZ001: datetime() called without a tzinfo argument; give it '
              "the site's own zone",
        ),
      ],
    ),
    check('mypy', state: 'failure', id: 33),
    for (final n in [
      'pytest (part 1)',
      'pytest (part 2)',
      'pytest (part 4)',
      'pytest (part 5)',
      'pip-audit',
      'docs build',
      'sample export',
      'sage-review',
    ])
      check(n, required: n.startsWith('pytest')),
    check('publish wheel', state: 'skipped', workflow: 'Release'),
    check('news fragment', state: 'skipped', workflow: ''),
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
    ..checks.addAll([check('pytest', required: true), check('ruff')])
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
  number: 537,
  id: 'PR_537',
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
    "Export dates in each site's zone",
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
                'Run make test PART=3\n'
                'FAILED tests/export/test_zones.py::test_lima_evening\n'
                "     assert '2026-03-09' == '2026-03-08'\n"
                '##[error]Process completed with exit code 1.',
          ),
          GetGitHubFilesRequest() => GetGitHubFilesResponse(
            files: [
              for (final (path, text) in [
                (
                  'src/tally/sites/zone_lookup.py',
                  'from zoneinfo import ZoneInfo\n\n\ndef zone_for(site):\n'
                      '    return ZoneInfo(site.zone or "UTC")\n',
                ),
                (
                  'src/tally/export/nightly_sightings_csv.py',
                  [
                    for (var i = 1; i <= 50; i++)
                      if (i == 42)
                        '    day = to_local(seen_at, site).date()'
                      else
                        '    # $i',
                  ].join('\n'),
                ),
                ('tests/export/test_zones.py', 'class TestZones:\n    pass\n'),
              ])
                FileChange(
                  path: path,
                  status: 'modified',
                  oldText: text.replaceFirst(
                    'to_local(seen_at, site)',
                    'seen_at',
                  ),
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
