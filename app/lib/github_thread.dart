import 'package:flutter/material.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The key of thread [x]'s reply box, on pull request [ref]: the Files
/// tab's card and To do's row share it.
String threadDraft(GitHubRef ref, GitHubThread x) =>
    githubDraft(ref, 'thread ${x.id}');

/// Thread [thread]'s reply box: posts the reply, then [onClose]s and asks
/// for the pull request again ([onChanged]); Cancel [onClose]s.
class ThreadReplyBox extends StatelessWidget {
  const new({
    required this.daemon,
    required this.ref,
    required this.thread,
    required this.onClose,
    required this.onChanged,
    super.key,
  });

  final Daemon daemon;

  /// The pull request it's on.
  final GitHubRef ref;
  final GitHubThread thread;
  final VoidCallback onClose;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) => CommentBox(
    draft: threadDraft(ref, thread),
    hint: 'Reply (Markdown; $cmdEnterLabel posts it)',
    label: 'Reply',
    autofocus: true,
    onCancel: onClose,
    onPost: (text) async {
      await daemon.client.replyGitHubThread(
        ReplyGitHubThreadRequest(host: ref.host, thread: thread.id, body: text),
      );
      if (context.mounted) onClose();
      await onChanged();
    },
  );
}

/// A note's frame under its lines.
class Inlay extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: cardBox(t, radius: NushiTheme.control),
      child: child,
    );
  }
}

/// A review thread under its lines: its comments (an author outside the
/// repository marked), whether it's outdated (and where it was) or
/// resolved (folded, a click opens it), Reply, Resolve or Unresolve.
class ThreadCard extends StatefulWidget {
  const new({
    required this.daemon,
    required this.ref,
    required this.thread,
    required this.onChanged,
    super.key,
  });

  final Daemon daemon;

  /// The pull request it's on.
  final GitHubRef ref;
  final GitHubThread thread;
  final Future<void> Function() onChanged;

  @override
  State<ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<ThreadCard> {
  /// The reply box shows: opened, or a reply written there not posted yet.
  late bool _replying = commentDraft(threadDraft(widget.ref, widget.thread))
      .isNotEmpty;
  late bool _open = !widget.thread.resolved || _replying;
  bool _busy = false;

  Future<void> _resolve(bool resolve) async {
    setState(() => _busy = true);
    await tryOrShow(context, () async {
      await widget.daemon.client.resolveGitHubThread(
        ResolveGitHubThreadRequest(
          host: widget.ref.host,
          thread: widget.thread.id,
          resolve: resolve,
        ),
      );
      await widget.onChanged();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final x = widget.thread;
    final where = x.onFile
        ? 'On the file'
        : x.outdated
        ? 'Outdated · was line ${x.originalLine}'
        : x.startLine > 0 && x.startLine != x.line
        ? 'Lines ${x.startLine}–${x.line}'
        : 'Line ${x.line}';
    final authors = {for (final c in x.comments) c.author}.join(', ');
    final n = x.comments.length;
    final folded = '$n comment${n == 1 ? '' : 's'} by $authors';
    return Inlay(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tap(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Icon(
                  _open ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: t.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      where,
                      if (x.resolved) 'Resolved',
                      if (!_open) folded,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(
                      x.resolved
                          ? t.textMuted
                          : x.outdated
                          ? t.needs
                          : t.textSecondary,
                      size: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_open) ...[
            for (final c in x.comments) CommentEntry(c, sendable: false),
            const SizedBox(height: 8),
            if (_replying)
              ThreadReplyBox(
                daemon: widget.daemon,
                ref: widget.ref,
                thread: x,
                onClose: () => setState(() => _replying = false),
                onChanged: widget.onChanged,
              )
            else
              Row(
                spacing: 6,
                children: [
                  if (x.canReply)
                    Button(
                      label: 'Reply',
                      onPressed: () => setState(() => _replying = true),
                    ),
                  if (x.canResolve && !x.resolved)
                    Button(
                      label: 'Resolve',
                      onPressed: _busy ? null : () => _resolve(true),
                    ),
                  if (x.canUnresolve && x.resolved)
                    Button(
                      label: 'Unresolve',
                      onPressed: _busy ? null : () => _resolve(false),
                    ),
                  if (SendToAgent.maybeOf(context) case final to?)
                    SendButton(
                      label: 'Send to agent',
                      onPressed: () => to.send(
                        threadReply(x),
                        'the thread on ${threadPlace(x)}',
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
