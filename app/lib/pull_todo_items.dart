import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';

/// One thing that blocks the merge, in the To do list: a failing check, a
/// review that requested changes, a review thread not resolved (with a
/// review bot's findings on its lines: one item, two voices), or a
/// finding a review bot asked to address. [id] is the same across polls.
sealed class TodoItem {
  const new(this.id);

  final String id;

  /// Its reply card for the agent (a check's with its log's failing part).
  Future<Reply> reply(Daemon daemon, GitHubRef ref) => switch (this) {
    CheckTodo(:final check) => checkReply(daemon, ref, check),
    ReviewTodo(:final review) => Future.value(changesRequestedReply(review)),
    ThreadTodo(:final thread, :final also) => Future.value(
      threadReply(thread, also: also),
    ),
    FindingTodo(:final finding) => Future.value(findingReply(finding)),
  };

  /// What it is, in a few words, as the toast names it: "CI / rubocop",
  /// "@mona's review", "the thread on a.rb:12", "a finding on a.rb:3".
  String get what => switch (this) {
    CheckTodo(check: final c) =>
      c.workflow.isEmpty ? c.name : '${c.workflow} / ${c.name}',
    ReviewTodo(review: final r) => "${possessive('@${r.author}')} review",
    ThreadTodo(thread: final x) => 'the thread on ${threadPlace(x)}',
    FindingTodo(finding: final f) => switch (findingPlace(f)) {
      '' => 'a finding from ${possessive(f.from.author)} review',
      final where => 'a finding on $where',
    },
  };

  /// The review bots' findings it carries: a finding's own, or those on a
  /// thread's lines.
  List<ReviewFinding> get findings => switch (this) {
    ThreadTodo(:final also) => also,
    FindingTodo(:final finding) => [finding],
    _ => const [],
  };
}

/// A failing check.
final class CheckTodo extends TodoItem {
  const new(super.id, this.check);

  final GitHubCheck check;
}

/// A review whose reviewer still requests changes.
final class ReviewTodo extends TodoItem {
  const new(super.id, this.review);

  final GitHubComment review;
}

/// A review thread not resolved, and the bots' findings on its lines
/// ([also]).
final class ThreadTodo extends TodoItem {
  const new(super.id, this.thread, {this.also = const []});

  final GitHubThread thread;
  final List<ReviewFinding> also;
}

/// A finding a review bot asked to address, on no thread's lines.
final class FindingTodo extends TodoItem {
  const new(super.id, this.finding);

  final ReviewFinding finding;
}

/// Where thread [x] is: `path:12`, `path:10–12`, or the file's path.
String threadPlace(GitHubThread x) {
  if (x.onFile) return x.path;
  final line = x.outdated ? x.originalLine : x.line;
  final start = x.outdated ? x.originalStartLine : x.startLine;
  return start > 0 && start != line
      ? '${x.path}:$start–$line'
      : '${x.path}:$line';
}

/// What blocks the merge (`items`), and the review bots whose findings
/// come from a message on an older commit than the head (`older`: the
/// bot's login and that commit).
typedef Todo = ({List<TodoItem> items, Map<String, String> older});

/// What blocks the merge, first: the failing checks (required first), the
/// reviews whose reviewer still requests changes, the review threads not
/// resolved (each with the bots' findings on its lines), then, with
/// `findings` (Settings › GitHub's Findings from review bots), the bots'
/// findings left: each bot's from its newest message (a review or a
/// comment, whichever came last) only, none when that one has none.
Todo todo(GitHubPull p, {FindingsSetup? findings}) {
  if (p.item.state != 'open') return (items: const [], older: const {});
  final newest = <String, GitHubComment>{};
  if (findings != null) {
    for (final c in p.conversation) {
      if (!isFindingsBot(c, findings)) continue;
      final seen = newest[c.author];
      if (seen == null || c.createdMs >= seen.createdMs) newest[c.author] = c;
    }
  }
  final found = [
    for (final c in newest.values) ...readFindings(c, findings!).findings,
  ];
  final older = {
    for (final c in newest.values)
      if (onOlderCommit(c, p) && found.any((f) => identical(f.from, c)))
        c.author: c.commit,
  };
  final used = <ReviewFinding>{};
  final checks = [
    for (final c in p.checks)
      if (c.failed) c,
  ]..sort((a, b) => (b.required ? 1 : 0) - (a.required ? 1 : 0));
  return (
    items: [
      for (final c in checks)
        // By its id: a push and a pull request run share a name. A
        // commit status has none, and is one per name.
        CheckTodo(c.id.isZero ? 'status ${c.name}' : 'check ${c.id}', c),
      for (final r in changesRequested(p)) ReviewTodo('review ${r.author}', r),
      for (final x in p.threads)
        if (!x.resolved)
          ThreadTodo(
            'thread ${x.id}',
            x,
            also: [
              for (final f in found)
                if (sameSpot(f, x) && used.add(f)) f,
            ],
          ),
      for (final f in found)
        if (!used.contains(f))
          FindingTodo(
            'finding ${f.from.id} ${f.path}:${f.start} ${f.text.hashCode}',
            f,
          ),
    ],
    older: older,
  );
}

/// Whether review [c] was made on a commit before [p]'s head.
bool onOlderCommit(GitHubComment c, GitHubPull p) =>
    c.commit.isNotEmpty && p.headOid.isNotEmpty && c.commit != p.headOid;

/// The reviews whose reviewers still request changes (GitHub's latest
/// review of theirs says so, and they weren't asked again): each one's
/// latest such review, or, when it had no text (so not in the
/// conversation), a stand-in with none.
List<GitHubComment> changesRequested(GitHubPull p) => [
  for (final r in p.reviewers)
    if (!r.team && r.state == 'changes_requested')
      p.conversation.lastWhere(
        (c) => c.author == r.login && c.review == 'changes_requested',
        orElse: () =>
            GitHubComment(author: r.login, review: 'changes_requested'),
      ),
];

/// How many findings from each review (by its id) [items] have, on
/// threads too.
Map<String, int> findingCounts(List<TodoItem> items) {
  final out = <String, int>{};
  for (final i in items) {
    for (final f in i.findings) {
      out.update(f.from.id, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return out;
}
