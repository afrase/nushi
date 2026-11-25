import 'package:fixnum/fixnum.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'harness.dart';

/// The Overview's made-up pull request: acme/lumen#218, mira's, with
/// tomas and iris reviewing.
const overviewRepo = 'acme/lumen';

const _url = 'https://github.com/$overviewRepo/pull/218';

GitHubComment _said(
  String id,
  String author,
  String body,
  Duration age, {
  String review = '',
  String reviewId = '',
}) => GitHubComment(
  id: id,
  author: author,
  body: body,
  url: '$_url#$id',
  createdMs: msAgo(age),
  review: review,
  reviewId: reviewId,
);

GitHubCheck _check(
  String name,
  String state, {
  int id = 0,
  bool required = false,
  Duration took = const Duration(minutes: 1, seconds: 12),
  String workflow = 'CI',
}) => GitHubCheck(
  id: Int64(id),
  name: name,
  workflow: workflow,
  state: state,
  failed: state == 'failure',
  required: required,
  url: 'https://github.com/$overviewRepo/actions/runs/7/job/$id',
  startedMs: msAgo(const Duration(minutes: 30)),
  completedMs: msAgo(const Duration(minutes: 30) - took),
);

const _hunk =
    '@@ -42,4 +44,5 @@ func redirectTarget(r *http.Request) string {\n'
    ' func redirectTarget(r *http.Request) string {\n'
    ' \tnext := r.URL.Query().Get("next")\n'
    '-\tif next == "" {\n'
    '+\tif next == "" || strings.HasPrefix(next, "/login") {\n'
    '+\t\treturn "/"';

/// The Overview's pull request, blocked ([ready] false): two required
/// checks failing (Actions jobs 41 and 42), tomas's changes requested
/// with one thread open and one resolved, iris's approval with an
/// outdated thread, a comment of mira's after them, iris still asked by
/// the platform team. [ready]: everything met, every thread resolved,
/// both approving, squash and merge offered.
GitHubPull overviewPull({bool ready = false}) {
  const iris = 'PRR_iris';
  const tomas = 'PRR_tomas';
  final p = GitHubPull(
    item: GitHubItem(
      ref: GitHubRef(host: 'github.com', repo: overviewRepo, number: 218),
      id: 'PR_218',
      pull: true,
      title: 'Fix login redirect loop after session expiry',
      url: _url,
      state: 'open',
      author: 'mira',
      createdMs: msAgo(const Duration(hours: 3)),
      updatedMs: msAgo(const Duration(minutes: 12)),
      checks: ready ? 'success' : 'failure',
      review: ready ? 'approved' : 'changes_requested',
      unresolved: ready ? 0 : 1,
    ),
    body:
        'When a session expires mid-request, `RequireSession` redirects to '
        '`/login?next=…` with the login page itself as `next`, so signing '
        'in loops back to the form.\n\nThis drops a `next` that points at '
        '`/login` and falls back to `/`.\n\n'
        '- [x] Unit tests for `safeNext`\n- [ ] Manual check on staging',
    base: 'main',
    head: 'fix-login-redirect',
    headRepo: overviewRepo,
    baseOid: 'a' * 40,
    headOid: 'c71d0a9${'0' * 33}',
    mergeable: 'mergeable',
    mergeState: ready ? 'clean' : 'blocked',
    additions: 84,
    deletions: 19,
    changedFiles: 4,
    commits: 3,
    labels: [
      GitHubLabel(name: 'bug', color: 'd73a4a'),
      GitHubLabel(name: 'auth', color: '1d76db'),
    ],
    assignees: ['mira'],
    reviewers: [
      GitHubReviewer(
        login: 'tomas',
        state: ready ? 'approved' : 'changes_requested',
      ),
      GitHubReviewer(login: 'iris', state: 'approved'),
      if (!ready)
        GitHubReviewer(
          login: 'platform-team',
          state: 'requested',
          team: true,
          codeOwner: true,
        ),
    ],
    reviews: [
      _said(
        iris,
        'iris',
        'Looks good to me. Nice catch on the `next` param.',
        const Duration(hours: 2),
        review: 'approved',
      ),
      _said(
        tomas,
        'tomas',
        'The fix is right, but the redirect check should live in one '
            'place. See the thread on `session.go`.',
        const Duration(minutes: 50),
        review: ready ? 'approved' : 'changes_requested',
      ),
    ],
    conversation: [
      _said(
        'IC_mira',
        'mira',
        'Moved it into `safeNext`, pushed. Can you take another look?',
        const Duration(minutes: 12),
      ),
    ],
    threads: [
      GitHubThread(
        id: 'T_session',
        path: 'auth/session.go',
        side: 'right',
        line: 47,
        startLine: 46,
        canReply: true,
        canResolve: !ready,
        canUnresolve: ready,
        resolved: ready,
        diffHunk: _hunk,
        comments: [
          _said(
            'RC_t1',
            'tomas',
            'This duplicates the check in `middleware.go`. Can '
                '`RequireSession` call `safeNext` instead?',
            const Duration(minutes: 50),
            reviewId: tomas,
          ),
          _said(
            'RC_m1',
            'mira',
            'Good point, doing that now.',
            const Duration(minutes: 30),
          ),
        ],
      ),
      GitHubThread(
        id: 'T_middleware',
        path: 'auth/middleware.go',
        side: 'right',
        line: 31,
        canReply: true,
        canUnresolve: true,
        resolved: true,
        diffHunk: '@@ -30,2 +30,2 @@\n-\tnext := q\n+\tnext := safeNext(q)',
        comments: [
          _said(
            'RC_t2',
            'tomas',
            'nit: name it `target`',
            const Duration(minutes: 50),
            reviewId: tomas,
          ),
        ],
      ),
      GitHubThread(
        id: 'T_test',
        path: 'auth/session_test.go',
        side: 'right',
        originalLine: 12,
        outdated: true,
        canReply: true,
        canResolve: !ready,
        canUnresolve: ready,
        resolved: ready,
        comments: [
          _said(
            'RC_i1',
            'iris',
            'Add a case for an empty `next`?',
            const Duration(hours: 2),
            reviewId: iris,
          ),
        ],
      ),
    ],
    checks: [
      if (ready) ...[
        _check('test (ubuntu-latest)', 'success', id: 41, required: true),
        _check('lint', 'success', id: 42, required: true),
      ] else ...[
        _check(
          'test (ubuntu-latest)',
          'failure',
          id: 41,
          required: true,
          took: const Duration(minutes: 2, seconds: 14),
        ),
        _check(
          'lint',
          'failure',
          id: 42,
          required: true,
          took: const Duration(seconds: 41),
        ),
      ],
      _check(
        'test (macos-latest)',
        'success',
        id: 43,
        took: const Duration(minutes: 3, seconds: 8),
      ),
      _check('build', 'success', id: 44),
      _check('vet', 'success', id: 45, took: const Duration(seconds: 22)),
      _check('deploy-preview', 'skipped', workflow: 'Deploy'),
    ],
    merge: GitHubMerge(
      methods: ['merge', 'squash', 'rebase'],
      defaultMethod: 'squash',
      canMerge: true,
      canRebase: true,
      autoAllowed: true,
      canEnableAuto: !ready,
      blocks: ready ? [] : ['checks_failing', 'changes_requested', 'threads'],
    ),
  );
  return p;
}

/// [overviewPull]'s commits: three, oldest first, the middle one by an
/// author GitHub has no account for; with [total] more than listed, the
/// list is capped.
GetGitHubCommitsResponse overviewCommits({int total = 3}) =>
    GetGitHubCommitsResponse(
      total: total,
      commits: [
        GitHubCommit(
          oid: '3f9a1c2${'1' * 33}',
          headline: 'Drop a next that points at /login',
          author: 'mira',
          authorName: 'Mira',
          committedMs: msAgo(const Duration(hours: 3)),
          checks: 'success',
        ),
        GitHubCommit(
          oid: '8b2e4f0${'2' * 33}',
          headline: 'Test the redirect target',
          authorName: 'Tomas',
          committedMs: msAgo(const Duration(hours: 1)),
        ),
        GitHubCommit(
          oid: 'c71d0a9${'0' * 33}',
          headline: 'Move the redirect check into safeNext',
          author: 'mira',
          authorName: 'Mira',
          committedMs: msAgo(const Duration(minutes: 20)),
          checks: 'failure',
        ),
      ],
    );

/// A pull request of [total] commits, numbered from 1 (their headlines
/// "Commit n"), as GetGitHubCommits answers it: the newest 100, oldest
/// first, and with [withFirst] its first on its own (an older daemon
/// sends none).
GetGitHubCommitsResponse longCommits(int total, {bool withFirst = true}) {
  GitHubCommit commit(int n) => GitHubCommit(
    oid: n.toRadixString(16).padLeft(40, '0'),
    headline: 'Commit $n',
    author: n.isEven ? 'mira' : '',
    authorName: n.isEven ? 'Mira' : 'Tomas',
    committedMs: msAgo(Duration(minutes: total - n + 1)),
  );
  final from = total > 100 ? total - 99 : 1;
  return GetGitHubCommitsResponse(
    total: total,
    commits: [for (var n = from; n <= total; n++) commit(n)],
    first: withFirst ? commit(1) : null,
  );
}

/// [overviewPull] ready but for a cancelled check: "Smoke tests / smoke
/// (linux)", 30 minutes in (Actions job 46; [required] or not), among the
/// passed ones. With [mixed], two failed and one running beside it. Its
/// rollup says failure, as GitHub's does for a cancelled check.
GitHubPull cancelledPull({bool required = false, bool mixed = false}) {
  final p = overviewPull(ready: true);
  final stopped = _check(
    'smoke (linux)',
    'cancelled',
    id: 46,
    required: required,
    workflow: 'Smoke tests',
    took: const Duration(minutes: 30),
  )..failed = true;
  p.checks.insert(2, stopped);
  if (mixed) {
    p.checks[0] = _check(
      'test (ubuntu-latest)',
      'failure',
      id: 41,
      required: true,
      took: const Duration(minutes: 2, seconds: 14),
    );
    p.checks[1] = _check(
      'lint',
      'failure',
      id: 42,
      required: true,
      took: const Duration(seconds: 41),
    );
    p.checks.add(_check('e2e', 'pending', id: 47));
  }
  p
    ..item.checks = 'failure'
    ..mergeState = mixed || required ? 'blocked' : 'unstable';
  p.merge.blocks.addAll([
    if (mixed || required) 'checks_failing',
    if (mixed) 'checks_running',
  ]);
  return p;
}
