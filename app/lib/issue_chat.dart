import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A chat to start on a Jira issue: its site, key and summary, and a
/// worktree on [branch] if [worktree] (on when the issue is picked).
class IssueChat {
  new({
    required this.site,
    required this.key,
    required this.summary,
    required this.branch,
    this.worktree = true,
    this.github,
  });

  /// A GitHub pull request or issue: its worktree starts on a pull
  /// request's head (the daemon fetches it), an issue's on a branch named
  /// from it.
  new github(GitHubItem it)
    : this(
        site: '',
        key: '${it.ref.repo}#${it.ref.number}',
        summary: it.title,
        branch: it.pull ? '' : githubBranch(it.ref.number, it.title),
        github: GitHubLink(
          host: it.ref.host,
          id: it.id,
          repo: it.ref.repo,
          number: it.ref.number,
          pull: it.pull,
        ),
      );

  /// An issue FindJiraIssues found.
  new found(FoundJiraIssue f)
    : this(
        site: f.site,
        key: f.issue.key,
        summary: f.issue.summary,
        branch: f.branch,
      );

  final String site;
  final String key;
  final String summary;
  String branch;
  bool worktree;

  /// The GitHub item it is, if it isn't a Jira issue.
  final GitHubLink? github;
}

/// The branch for a chat on GitHub issue [n]:
/// its number, then its title's letters and digits, lowercase, words
/// joined by "-", 40 characters of title at most, cut between words.
String githubBranch(int n, String title) {
  final words = title
      .toLowerCase()
      .split(RegExp('[^a-z0-9]+'))
      .where((w) => w.isNotEmpty);
  var out = '';
  for (final w in words) {
    if (out.length + w.length + 1 > 40 && out.isNotEmpty) break;
    out = out.isEmpty ? w : '$out-$w';
  }
  if (out.length > 40) out = out.substring(0, 40);
  return out.isEmpty ? '$n' : '$n-$out';
}
