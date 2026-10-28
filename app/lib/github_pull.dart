import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/github_files.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How often an open pull request is asked for again (quietly).
const pullPoll = Duration(seconds: 30);

/// A pull request's details: its header (state, draft, base ← head,
/// author, reviewers and their states, whether it can merge), Start work,
/// Fix checks and Address comments, its chats; then its conversation, its
/// checks, or its files with the review threads at their lines.
class GitHubPullPane extends StatefulWidget {
  const new({required this.daemon, required this.ref, super.key, this.now});

  final Daemon daemon;
  final GitHubRef ref;
  final DateTime? now;

  @override
  State<GitHubPullPane> createState() => _GitHubPullPaneState();
}

enum _Tab { conversation, checks, files }

class _GitHubPullPaneState extends State<GitHubPullPane> {
  GitHubPull? _pull;
  String? _error;
  Timer? _poll;
  _Tab _tab = _Tab.conversation;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _poll = Timer.periodic(pullPoll, (_) => unawaited(_load(quiet: true)));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final r = await widget.daemon.client.getGitHubPull(
        GetGitHubPullRequest(ref: widget.ref, quiet: quiet),
      );
      if (mounted) {
        setState(() {
          _pull = r.pull;
          _error = null;
        });
      }
    } on Object catch (e) {
      // A failed poll keeps what shows, and says why.
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = _pull;
    if (p == null) {
      return Center(
        child: Text(
          _error ?? 'Loading…',
          style: theme.ui(_error == null ? t.textMuted : t.crashed),
        ),
      );
    }
    final failed = p.checks.where((c) => c.failed).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          daemon: widget.daemon,
          pull: p,
          now: widget.now ?? DateTime.now(),
          error: _error,
          onReview: () =>
              submitReview(context, widget.daemon, p, onDone: _load),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              Segmented(
                value: _tab,
                segments: [
                  (_Tab.conversation, 'Conversation ${p.conversation.length}'),
                  (
                    _Tab.checks,
                    failed > 0
                        ? 'Checks · $failed failed'
                        : 'Checks ${p.checks.length}',
                  ),
                  (_Tab.files, 'Files ${p.changedFiles}'),
                ],
                onChanged: (v) => setState(() => _tab = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _Tab.conversation => _Conversation(
              daemon: widget.daemon,
              pull: p,
              now: widget.now ?? DateTime.now(),
              onPosted: _load,
            ),
            _Tab.checks => GitHubChecks(daemon: widget.daemon, pull: p),
            _Tab.files => GitHubFiles(
              daemon: widget.daemon,
              pull: p,
              now: widget.now,
              onChanged: _load,
            ),
          },
        ),
      ],
    );
  }
}

/// A reviewer's state as an icon and its color.
(IconData, Color) reviewerIcon(Tokens t, String state) => switch (state) {
  'approved' => (Icons.check_circle_outline, t.done),
  'changes_requested' => (Icons.cancel_outlined, t.crashed),
  'commented' => (Icons.chat_bubble_outline, t.textSecondary),
  'dismissed' => (Icons.remove_circle_outline, t.textMuted),
  _ => (Icons.schedule, t.textMuted), // asked, not reviewed yet
};

/// Whether the pull request can merge, in a few words.
(String, Color) mergeWords(Tokens t, GitHubPull p) {
  if (p.item.state != 'open') return (itemState(p.item), itemColor(t, p.item));
  if (p.item.draft) return ('Draft: not ready to merge', t.textMuted);
  if (p.mergeable == 'conflicting') {
    return ('Conflicts with its base', t.crashed);
  }
  return switch (p.mergeState) {
    'clean' || 'has_hooks' => ('Ready to merge', t.done),
    'blocked' => ('Blocked: a review or a check its base requires', t.needs),
    'behind' => ('Behind its base', t.needs),
    'unstable' => ('Checks failing', t.needs),
    'dirty' => ('Conflicts with its base', t.crashed),
    _ => ('Checking whether it can merge…', t.textMuted),
  };
}

class _Header extends StatelessWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.now,
    required this.error,
    required this.onReview,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final DateTime now;
  final String? error;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = pull;
    final it = p.item;
    final small = theme.ui(t.textSecondary, size: 12);
    final merge = mergeWords(t, p);
    final review = reviewWords(t, it.review);
    final pending = p.pendingComments + reviewDrafts(it.ref).length;
    final chats = chatsOnItem(daemon, it.ref);
    final unresolved = p.threads.where((x) => !x.resolved).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText.rich(
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(itemState(it), itemColor(t, it)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: it.author,
                      style: theme.ui(t.text, size: 12),
                    ),
                    if (p.outside)
                      TextSpan(
                        text: ' (outside the repository)',
                        style: theme.ui(t.needs, size: 12),
                      ),
                    const TextSpan(text: ' wants '),
                    TextSpan(
                      text: p.base,
                      style: theme.code(t.text, size: 11.5),
                    ),
                    const TextSpan(text: ' ← '),
                    TextSpan(
                      text: p.crossRepo ? '${p.headRepo}:${p.head}' : p.head,
                      style: theme.code(t.text, size: 11.5),
                    ),
                  ],
                ),
                style: small,
              ),
              Text(
                '+${p.additions} −${p.deletions} in ${p.changedFiles} files',
                style: small,
              ),
              Text(merge.$1, style: theme.ui(merge.$2, size: 12)),
              if (review != null)
                Text(review.$1, style: theme.ui(review.$2, size: 12)),
            ],
          ),
          if (p.reviewers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              children: [
                for (final r in p.reviewers)
                  Tooltip(
                    message: switch (r.state) {
                      'requested' => 'Asked to review',
                      'approved' => 'Approved',
                      'changes_requested' => 'Requested changes',
                      'commented' => 'Commented',
                      _ => r.state,
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          reviewerIcon(t, r.state).$1,
                          size: 13,
                          color: reviewerIcon(t, r.state).$2,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          r.team ? '@${r.login}' : r.login,
                          style: theme.ui(t.textSecondary, size: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StartWork(daemon: daemon, item: it, button: true),
              if (p.checks.any((c) => c.failed))
                Button(
                  label: 'Fix checks',
                  icon: Icons.build_outlined,
                  onPressed: () =>
                      toAgent(context, daemon, it, kind: 'fix_checks'),
                ),
              if (unresolved > 0)
                Button(
                  label: 'Address comments',
                  icon: Icons.forum_outlined,
                  onPressed: () async {
                    final picked = unresolved == 1
                        ? const <String>[]
                        : await pickThreads(context, p);
                    if (picked == null || !context.mounted) return;
                    await toAgent(
                      context,
                      daemon,
                      it,
                      kind: 'address_comments',
                      threads: picked,
                    );
                  },
                ),
              Button(
                label: pending > 0 ? 'Review ($pending)…' : 'Review…',
                onPressed: onReview,
              ),
              for (final c in chats.take(4))
                Tap(
                  onTap: () => daemon.select(c.id),
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          c.title.isEmpty ? 'New chat' : c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(t.link, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (chats.length > 4)
                Text(
                  '+${chats.length - 4} chats',
                  style: theme.ui(t.textMuted, size: 12),
                ),
            ],
          ),
          if (error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Not current: $e',
                style: theme.ui(t.needs, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: box(color, radius: NushiTheme.control),
      child: Text(
        text,
        style: theme.ui(color, size: 12, weight: FontWeight.w500),
      ),
    );
  }
}

/// A comment or a review in the conversation: its author (marked when
/// outside the repository, or a bot), when, a review's state, its text.
class CommentEntry extends StatelessWidget {
  const new(this.comment, {required this.now, super.key});

  final GitHubComment comment;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = comment;
    final review = switch (c.review) {
      'approved' => ('approved', t.done),
      'changes_requested' => ('requested changes', t.crashed),
      'commented' => ('reviewed', t.textSecondary),
      'dismissed' => ('review dismissed', t.textMuted),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                c.author,
                style: theme.ui(t.text, size: 12.5, weight: FontWeight.w600),
              ),
              if (c.bot)
                Text('  bot', style: theme.ui(t.textMuted, size: 11.5)),
              if (c.outside)
                Tooltip(
                  message:
                      "Not the repository's owner, a member or a collaborator",
                  child: Text(
                    '  outside',
                    style: theme.ui(t.needs, size: 11.5),
                  ),
                ),
              if (review != null)
                Text('  ${review.$1}', style: theme.ui(review.$2, size: 11.5)),
              Text(
                '  ${githubAgo(c.createdMs.toInt(), now)}',
                style: theme.ui(t.textMuted, size: 11.5),
              ),
              const Spacer(),
              if (c.url.isNotEmpty)
                IconTap(
                  Icons.open_in_new,
                  size: 13,
                  tooltip: 'Open on GitHub',
                  onTap: () => openWeb(c.url),
                ),
            ],
          ),
          if (c.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AgentMarkdown(c.body, images: githubImage),
            ),
        ],
      ),
    );
  }
}

/// The description, then the comments and reviews, oldest first, and a
/// box for a comment (Markdown; ⌘⏎ posts it).
class _Conversation extends StatelessWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.now,
    required this.onPosted,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final DateTime now;
  final Future<void> Function() onPosted;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = pull;
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          CommentEntry(
            GitHubComment(
              author: p.item.author,
              outside: p.outside,
              body: p.body.isEmpty ? '' : p.body,
              createdMs: p.item.updatedMs,
            ),
            now: now,
          ),
          if (p.body.isEmpty)
            Text('No description.', style: theme.ui(t.textMuted, size: 12.5)),
          for (final c in p.conversation) CommentEntry(c, now: now),
          const SizedBox(height: 16),
          CommentBox(
            hint: 'Comment on the pull request (Markdown; ⌘⏎ posts it)',
            onPost: (text) async {
              await daemon.client.addGitHubComment(
                AddGitHubCommentRequest(
                  host: p.item.ref.host,
                  subject: p.item.id,
                  body: text,
                ),
              );
              await onPosted();
            },
          ),
        ],
      ),
    );
  }
}

/// A box for a comment or a reply: Markdown, ⌘⏎ or the button posts it;
/// what GitHub said wrong shows under it.
class CommentBox extends StatefulWidget {
  const new({
    required this.hint,
    required this.onPost,
    super.key,
    this.label = 'Comment',
    this.autofocus = false,
    this.onCancel,
  });

  final String hint;
  final String label;
  final bool autofocus;
  final Future<void> Function(String text) onPost;
  final VoidCallback? onCancel;

  @override
  State<CommentBox> createState() => _CommentBoxState();
}

class _CommentBoxState extends State<CommentBox> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPost(text);
      _text.clear();
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _post,
        const SingleActivator(LogicalKeyboardKey.escape): ?widget.onCancel,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            autofocus: widget.autofocus,
            enabled: !_busy,
            minLines: 2,
            maxLines: 8,
            style: theme.ui(t.text),
            decoration: InputDecoration(hintText: widget.hint, isDense: true),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(e, style: theme.ui(t.crashed, size: 12)),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel case final cancel?)
                Button(label: 'Cancel', onPressed: cancel),
              const SizedBox(width: 6),
              Button(
                label: _busy ? 'Posting…' : widget.label,
                hint: '⌘⏎',
                onPressed: _busy ? null : _post,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
