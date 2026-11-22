import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_side.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A pull request's commits, asked of GitHub (GetGitHubCommits, API 127)
/// when they first show and again when its head moves, not with each
/// poll of the pull request.
class PullCommits extends ChangeNotifier {
  new(this.daemon, this.ref);

  final Daemon daemon;
  final GitHubRef ref;

  /// The answer, oldest first; null until the first.
  GetGitHubCommitsResponse? got;
  String? error;

  /// The head they were asked for (null not yet).
  String? _head;
  int _asked = 0;
  bool _gone = false;

  /// Asks for them unless they were asked for [head] already.
  void want(String head) {
    if (head == _head && (got != null || error == null)) return;
    final again = _head != null;
    _head = head;
    unawaited(_load(quiet: again));
  }

  Future<void> _load({required bool quiet}) async {
    final n = ++_asked;
    try {
      final r = await daemon.client.getGitHubCommits(
        GetGitHubCommitsRequest(ref: ref, quiet: quiet),
      );
      if (n != _asked || _gone) return;
      got = r;
      error = null;
    } on Object catch (e) {
      if (n != _asked || _gone) return;
      error = errorText(e);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}

/// Who wrote [c]: their login, else the name git has.
String commitAuthor(GitHubCommit c) =>
    c.author.isNotEmpty ? c.author : c.authorName;

/// [c]'s id, short.
String shortSha(GitHubCommit c) =>
    c.oid.length > 7 ? c.oid.substring(0, 7) : c.oid;

/// A commit's checks as an icon and its ink; null for none.
(IconData, Color)? commitChecks(Tokens t, GitHubCommit c) => switch (c.checks) {
  'success' => (Icons.check, t.done),
  'failure' => (Icons.close, t.crashed),
  'pending' => (Icons.circle, t.needs),
  _ => null,
};

/// The Commits tab: newest first, each its headline, author, age, short
/// id with Copy and its checks; capped at the newest 100, it says so.
class PullCommitsList extends StatelessWidget {
  const new({required this.commits, super.key});

  final PullCommits commits;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: commits,
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final got = commits.got;
      if (got == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            commits.error ?? 'Loading the commits…',
            style: theme.ui(
              commits.error == null ? t.textMuted : t.crashed,
              size: 12,
            ),
          ),
        );
      }
      final list = got.commits.reversed.toList();
      if (list.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('No commits', style: theme.ui(t.textMuted)),
        );
      }
      return Column(
        key: const ValueKey('pull-commits'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (got.total > list.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Showing the newest ${list.length} of ${got.total}',
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: cardBox(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in list.indexed) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
                  CommitRow(c, roomy: true),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// One commit on a line: its mark, author's mark, headline, age, checks,
/// short id and Copy. [roomy]: the Commits tab's, with its author's name.
class CommitRow extends StatelessWidget {
  const new(this.commit, {super.key, this.roomy = false});

  final GitHubCommit commit;
  final bool roomy;

  Future<void> _copy(BuildContext context) => tryOrShow(context, () async {
    await Clipboard.setData(ClipboardData(text: commit.oid));
    if (context.mounted) {
      showToast(Toasts.maybeOf(context), 'Copied ${shortSha(commit)}');
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = commit;
    final who = commitAuthor(c);
    final age = agoAt(c.committedMs.toInt(), clock());
    final checks = commitChecks(t, c);
    return Padding(
      padding: roomy
          ? const EdgeInsets.fromLTRB(14, 8, 8, 8)
          : const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        spacing: 8,
        children: [
          if (!roomy) Icon(Icons.commit, size: 16, color: t.textMuted),
          PersonMark(who, size: roomy ? 20 : 16),
          Expanded(
            child: roomy
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        c.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.text, weight: FontWeight.w500),
                      ),
                      Text(
                        '$who committed $age',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    ],
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: c.headline),
                        TextSpan(
                          text: ' · $age',
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.textSecondary),
                  ),
          ),
          if (checks case (final icon, final ink))
            tooltip(context, switch (c.checks) {
              'success' => 'Checks passed',
              'failure' => 'Checks failing',
              _ => 'Checks running',
            }, Icon(icon, size: icon == Icons.circle ? 8 : 15, color: ink)),
          Text(shortSha(c), style: theme.code(t.textMuted, size: 12)),
          IconTap(
            Icons.copy,
            size: 13,
            tooltip: 'Copy the full SHA',
            onTap: () => _copy(context),
          ),
        ],
      ),
    );
  }
}

/// The Overview's commit trail, after the comments: the newest commit,
/// "N additional commits by …" (opens the Commits tab, [onAll]), the
/// oldest: the pull request's first, which the daemon sends on its own
/// (API 144), else the list's oldest. Nothing until they've come.
class CommitTrail extends StatelessWidget {
  const new({required this.commits, required this.onAll, super.key});

  final PullCommits commits;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: commits,
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final got = commits.got;
      if (got == null || got.commits.isEmpty) return const SizedBox.shrink();
      final list = got.commits;
      final newest = list.last;
      final oldest = got.hasFirst() ? got.first : list.first;
      final between = got.total - 2;
      final who = {
        for (final c in list.take(list.length - 1))
          if (c.oid != oldest.oid) commitAuthor(c),
      }.where((s) => s.isNotEmpty).toList();
      return Column(
        key: const ValueKey('commit-trail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommitRow(newest),
          if (between > 0)
            Tap(
              onTap: onAll,
              tooltip: 'Show the commits',
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                spacing: 8,
                children: [
                  Icon(Icons.unfold_more, size: 16, color: t.textMuted),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '$between additional '
                                'commit${between == 1 ? '' : 's'}'
                                '${who.isEmpty ? '' : ' by '}',
                          ),
                          TextSpan(
                            text: who.join(', '),
                            style: theme.ui(t.text, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          if (oldest.oid != newest.oid) CommitRow(oldest),
        ],
      );
    },
  );
}
