import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';

/// One thing that blocks the merge, in the To do list: a failing check, a
/// review thread not resolved (with a review bot's findings on its lines,
/// [also]: one item, two voices), or a finding a review bot asked to
/// address. [id] is the same across polls.
class TodoItem {
  const new({
    required this.id,
    this.check,
    this.thread,
    this.finding,
    this.also = const [],
  });

  final String id;
  final GitHubCheck? check;
  final GitHubThread? thread;
  final ReviewFinding? finding;
  final List<ReviewFinding> also;

  /// Its reply card for the agent (a check's with its log's failing part).
  Future<Reply> reply(Daemon daemon, GitHubRef ref) {
    if (check case final c?) return checkReply(daemon, ref, c);
    if (thread case final x?) return Future.value(threadReply(x, also: also));
    return Future.value(findingReply(finding!));
  }
}

/// The findings to address in the review bots' latest comment or review
/// each (an earlier one's may be done).
List<ReviewFinding> botFindings(GitHubPull p) {
  final latest = <String, List<ReviewFinding>>{};
  for (final c in p.conversation) {
    final found = reviewFindings(c);
    if (found.isNotEmpty) latest[c.author] = found;
  }
  return [for (final f in latest.values) ...f];
}

/// What blocks the merge, first: the failing checks (required first), the
/// review threads not resolved (each with the bots' findings on its
/// lines), then the bots' findings left.
List<TodoItem> todoItems(GitHubPull p) {
  if (p.item.state != 'open') return const [];
  final findings = botFindings(p);
  final used = <ReviewFinding>{};
  final checks = [
    for (final c in p.checks)
      if (c.failed) c,
  ]..sort((a, b) => (b.required ? 1 : 0) - (a.required ? 1 : 0));
  return [
    for (final c in checks)
      TodoItem(id: 'check ${c.workflow}/${c.name}', check: c),
    for (final x in p.threads)
      if (!x.resolved)
        TodoItem(
          id: 'thread ${x.id}',
          thread: x,
          also: [
            for (final f in findings)
              if (sameSpot(f, x) && used.add(f)) f,
          ],
        ),
    for (final f in findings)
      if (!used.contains(f))
        TodoItem(
          id: 'finding ${f.path}:${f.start} ${f.text.hashCode}',
          finding: f,
        ),
  ];
}
