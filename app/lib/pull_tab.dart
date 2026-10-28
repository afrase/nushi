import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/pull_link.dart';

/// A chat's Pull request tab: the GitHub view's pull request (its
/// conversation, review threads, checks with a failed job's log, files,
/// replies and comments) for the chat's pull request; its comments are
/// seen while it shows.
class PullTab extends StatelessWidget {
  const new({required this.chat, required this.daemon, super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final l = chat.pull;
    if (l == null) return const SizedBox.shrink();
    final ref = GitHubRef(host: l.host, repo: l.repo, number: l.number);
    return GitHubPullPane(
      key: ValueKey('${chat.id} ${l.id}'),
      daemon: daemon,
      ref: ref,
      inChat: true,
      onLoad: (p) => markPullSeen(chat.id, p),
    );
  }
}
