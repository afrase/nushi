import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// An issue's details: its state, title, author (marked when outside the
/// repository), labels and assignees, Start work and its chats, its text
/// and comments, and a box for a comment.
class GitHubIssuePane extends StatefulWidget {
  const new({required this.daemon, required this.ref, super.key, this.now});

  final Daemon daemon;
  final GitHubRef ref;
  final DateTime? now;

  @override
  State<GitHubIssuePane> createState() => _GitHubIssuePaneState();
}

class _GitHubIssuePaneState extends State<GitHubIssuePane> {
  GitHubIssue? _issue;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _poll = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_load(quiet: true)),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final r = await widget.daemon.client.getGitHubIssue(
        GetGitHubIssueRequest(ref: widget.ref, quiet: quiet),
      );
      if (mounted) {
        setState(() {
          _issue = r.issue;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = githubError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final i = _issue;
    if (i == null) {
      return Center(
        child: Text(
          _error ?? 'Loading…',
          style: theme.ui(_error == null ? t.textMuted : t.crashed),
        ),
      );
    }
    final now = widget.now ?? DateTime.now();
    final it = i.item;
    final chats = chatsOnItem(widget.daemon, it.ref);
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: it.title),
                      TextSpan(
                        text: '  ${it.ref.repo}#${it.ref.number}',
                        style: theme.code(t.textMuted, size: 12.5),
                      ),
                    ],
                  ),
                  style: theme.ui(t.text, size: 16, weight: FontWeight.w600),
                ),
              ),
              IconTap(
                Icons.open_in_new,
                tooltip: 'Open on GitHub',
                onTap: it.url.isEmpty ? null : () => openWeb(it.url),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                itemState(it),
                style: theme.ui(
                  itemColor(t, it),
                  size: 12,
                  weight: FontWeight.w500,
                ),
              ),
              if (i.labels.isNotEmpty)
                Text(
                  i.labels.join(' · '),
                  style: theme.ui(t.textSecondary, size: 12),
                ),
              if (i.assignees.isNotEmpty)
                Text(
                  'Assigned to ${i.assignees.join(', ')}',
                  style: theme.ui(t.textSecondary, size: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StartWork(daemon: widget.daemon, item: it, button: true),
              for (final c in chats.take(4))
                Tap(
                  onTap: () => widget.daemon.select(c.id),
                  tooltip: 'Open the chat',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AgentMark(c.agent, size: 13, color: t.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        c.title.isEmpty ? 'New chat' : c.title,
                        style: theme.ui(t.link, size: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Not current: $e',
                style: theme.ui(t.needs, size: 12),
              ),
            ),
          CommentEntry(
            GitHubComment(
              author: it.author,
              outside: i.outside,
              body: i.body,
              createdMs: it.updatedMs,
            ),
            now: now,
          ),
          if (i.body.isEmpty)
            Text('No description.', style: theme.ui(t.textMuted, size: 12.5)),
          for (final c in i.conversation) CommentEntry(c, now: now),
          const SizedBox(height: 16),
          CommentBox(
            hint: 'Comment on the issue (Markdown; ⌘⏎ posts it)',
            onPost: (text) async {
              await widget.daemon.client.addGitHubComment(
                AddGitHubCommentRequest(
                  host: it.ref.host,
                  subject: it.id,
                  body: text,
                ),
              );
              await _load();
            },
          ),
        ],
      ),
    );
  }
}
