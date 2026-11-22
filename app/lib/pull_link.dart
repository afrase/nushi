import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';

export 'package:nushi/chat_pull.dart';
export 'package:nushi/pull_polls.dart';

/// The daemon finds and links a chat's pull request (FindChatPull,
/// LinkChatPull, Chat.pull).
const chatPullApi = 81;

/// The daemon links a pull request found by the branch's head only for a
/// branch the chat pushed and one opened in the chat's life, nothing new
/// for an archived chat, and says the branch's otherwise when asked
/// (FindChatPullRequest.suggest, FindChatPullResponse.branch_pull); the
/// rows' ask names the chat (GetGitHubItemsRequest.chat_id).
const branchPullApi = 119;

/// Whether a tool call's lowercased title, input and tool, [what], push a
/// branch: `git push`, options between the two words allowed. The daemon's
/// gitPushRE (internal/features/chats/pushed.go) reads the same.
bool pushesBranch(String what) =>
    RegExp(r'\bgit\b[^\n|;&]*\spush\b').hasMatch(what);

/// Whether a tool call's lowercased title, input and tool, [what], open a
/// pull request: `gh pr create` in any spacing, or a `create_pull_request`
/// tool. The daemon's opensPull (internal/features/chats/pushed.go) links
/// the same calls.
bool opensPull(String what) =>
    RegExp(r'\bgh\s+pr\s+create\b').hasMatch(what) ||
    what.contains('create_pull_request');

/// Whether a tool call may have pushed the chat's branch or opened its
/// pull request ([pushesBranch], [opensPull]), once it completed.
bool pushedOrOpened(Item it) {
  if (it.kind != ItemKind.ITEM_KIND_TOOL_CALL || it.status != 'completed') {
    return false;
  }
  final what = '${it.title}\n${it.input}\n${it.tool}'.toLowerCase();
  return pushesBranch(what) || opensPull(what);
}

/// [l] as the item store keys it.
GitHubAddress addressOf(GitHubLink l) =>
    GitHubAddress(host: l.host, repo: l.repo, number: l.number, pull: l.pull);

/// What tells two links apart: host, repository (any case) and number.
String pullKey(GitHubLink l) => addressOf(l).key;

/// A pull request read whole as a row's item, for a daemon before
/// GetGitHubItems: its size, base and head, and its checks counted.
GitHubItem rowItem(GitHubPull p) {
  var passed = 0;
  var failed = 0;
  var running = 0;
  var skipped = 0;
  for (final c in p.checks) {
    switch (c.state) {
      case 'success' || 'neutral':
        passed++;
      case 'pending':
        running++;
      case 'skipped' || 'stale':
        skipped++;
      default:
        failed++;
    }
  }
  return p.item.deepCopy()
    ..pull = true
    ..additions = p.additions
    ..deletions = p.deletions
    ..changedFiles = p.changedFiles
    ..mergeState = p.mergeState
    ..unresolved = p.threads.where((x) => !x.resolved).length
    ..base = p.base
    ..head = p.head
    ..checkCounts = GitHubCheckCounts(
      passed: passed,
      failed: failed,
      running: running,
      skipped: skipped,
    );
}

/// [links] in the widget's order (ADR 0117): as linked, except that a
/// stack (one's base is another's head, in one repository) lists its base
/// first, each pull request right after the one it's on.
List<GitHubLink> orderPulls(
  List<GitHubLink> links,
  GitHubItem? Function(GitHubLink) item,
) {
  GitHubLink? baseOf(GitHubLink l) {
    final it = item(l);
    if (it == null || it.base.isEmpty) return null;
    for (final o in links) {
      final oi = item(o);
      if (pullKey(o) != pullKey(l) &&
          oi != null &&
          oi.head == it.base &&
          o.host == l.host &&
          o.repo.toLowerCase() == l.repo.toLowerCase()) {
        return o;
      }
    }
    return null;
  }

  final bases = {for (final l in links) pullKey(l): baseOf(l)};
  final out = <GitHubLink>[];
  final done = <String>{};
  void add(GitHubLink l) {
    if (!done.add(pullKey(l))) return;
    out.add(l);
    for (final o in links) {
      if (bases[pullKey(o)] case final b? when pullKey(b) == pullKey(l)) {
        add(o);
      }
    }
  }

  // Each stack where its first linked one is, from its base.
  for (final l in links) {
    var root = l;
    final seen = {pullKey(l)};
    for (
      var b = bases[pullKey(root)];
      b != null && seen.add(pullKey(b));
      b = bases[pullKey(b)]
    ) {
      root = b;
    }
    add(root);
    add(l); // one in a cycle
  }
  return out;
}
