import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';

export 'package:nushi/chat_pull.dart';
export 'package:nushi/pull_polls.dart';

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
