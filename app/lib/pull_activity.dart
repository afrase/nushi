import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/pull_activity_parts.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The pull request's activity, quieted under the To do list: the
/// description, then the comments and reviews, oldest first, each beside
/// its author's avatar; a bot's comment one line (Show); a review a card
/// whose long text shows its start, its findings and threads pointing at
/// To do ([onTodo]) rather than repeated, its resolved threads one line
/// each; a trailing line of a bot's numbers (model, cost, time) muted. A
/// box for a comment ends it.
class PullActivity extends StatelessWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.now,
    required this.me,
    required this.onPosted,
    required this.onTodo,
    super.key,
    this.findings = const {},
    this.shown,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final DateTime now;

  /// The findings in To do from each review (by its id).
  final Map<String, int> findings;

  /// A review To do pointed at (its id) and the key it's found by.
  final (String, GlobalKey)? shown;

  /// Who the user is on the pull request's host ('' when not known).
  final String me;
  final Future<void> Function() onPosted;
  final VoidCallback onTodo;

  @override
  Widget build(BuildContext context) {
    final p = pull;
    // A reviewer's threads show under their latest review only.
    final latest = <String, GitHubComment>{};
    for (final c in p.conversation) {
      if (c.review.isNotEmpty) latest[c.author] = c;
    }
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _Entry(
            comment: GitHubComment(
              author: p.item.author,
              outside: p.outside,
              body: p.body,
              createdMs: p.item.updatedMs,
            ),
            what: 'description',
            now: now,
            pull: p,
            onTodo: onTodo,
          ),
          for (final c in p.conversation)
            _Entry(
              key: shown?.$1 == c.id ? shown!.$2 : null,
              findings: findings[c.id] ?? 0,
              comment: c,
              now: now,
              pull: p,
              onTodo: onTodo,
              threads: latest[c.author] == c,
            ),
          _Gutter(
            login: me,
            child: CommentBox(
              hint: 'Comment on the pull request',
              note: me.isEmpty
                  ? 'Markdown'
                  : 'Markdown · posts to GitHub as $me',
              primary: true,
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
          ),
        ],
      ),
    );
  }
}

/// [child] beside [login]'s avatar (a bot's mark for a [bot]).
class _Gutter extends StatelessWidget {
  const new({required this.login, required this.child, this.bot = false});

  final String login;
  final bool bot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: bot
              ? Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: t.selected,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 13,
                    color: t.textSecondary,
                  ),
                )
              : login.isEmpty
              ? const SizedBox(width: 22)
              : Avatar(name: login, id: login, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

/// A trailing line of a bot's numbers ("claude-opus · $2.61 · 10m 31s"):
/// short, after a blank line, with dots between its parts or money, tokens
/// or a duration in it.
final _numbers = RegExp(
  r'(\$\d|\btokens?\b|\b\d+m\s?\d+s\b|·.*·)',
  caseSensitive: false,
);

/// [body] and its trailing line of numbers, apart ('' when it has none).
(String, String) _splitFoot(String body) {
  final b = body.trimRight();
  final cut = b.lastIndexOf('\n\n');
  if (cut < 0) return (b, '');
  final last = b.substring(cut + 2).trim();
  if (last.contains('\n') || last.length > 140 || !_numbers.hasMatch(last)) {
    return (b, '');
  }
  return (b.substring(0, cut), last.replaceAll(r'\', ''));
}

class _Entry extends StatefulWidget {
  const new({
    required this.comment,
    required this.now,
    required this.pull,
    required this.onTodo,
    super.key,
    this.what = '',
    this.threads = false,
    this.findings = 0,
  });

  /// Its findings in To do.
  final int findings;

  final GitHubComment comment;
  final DateTime now;
  final GitHubPull pull;
  final VoidCallback onTodo;

  /// What it is, when not a comment or a review: "description".
  final String what;

  /// Its author's review threads show under it.
  final bool threads;

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    // A bot's comment (not a review): its line, the comment's own entry.
    if (c.bot && c.review.isEmpty && widget.what.isEmpty) {
      return _Gutter(
        login: c.author,
        bot: true,
        child: CommentEntry(c, now: widget.now, mark: false),
      );
    }
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (text, foot) = c.bot ? _splitFoot(c.body) : (c.body, '');
    final long = longText(text);
    final clamped = long && !_open;
    final findings = widget.findings;
    final threads = widget.threads
        ? [
            for (final x in widget.pull.threads)
              if (x.comments.isNotEmpty && x.comments.first.author == c.author)
                x,
          ]
        : const <GitHubThread>[];
    final open = threads.where((x) => !x.resolved).length;
    final pill = switch (c.review) {
      'approved' => ('Approved', t.done, Icons.check_circle_outline),
      'changes_requested' => (
        'Requested changes',
        t.crashed,
        Icons.cancel_outlined,
      ),
      'dismissed' => ('Dismissed', t.textMuted, Icons.remove_circle_outline),
      _ => null,
    };
    final meta = widget.what.isNotEmpty
        ? '${widget.what} · '
        : c.review.isNotEmpty
        ? 'reviewed · '
        : '';
    final when = githubAgo(c.createdMs.toInt(), widget.now);
    final body = AgentMarkdown(
      githubText(clamped ? textStart(text) : text),
      images: githubImage,
    );
    return _Gutter(
      login: c.author,
      bot: c.bot,
      child: framed(
        border: t.borderSubtle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: t.raised,
              padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          c.author,
                          style: theme.ui(
                            t.text,
                            size: 12.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (c.outside && !c.bot)
                          Tooltip(
                            message:
                                "Not the repository's owner, a member or a "
                                'collaborator',
                            child: Text(
                              '  outside',
                              style: theme.ui(t.needs, size: 11.5),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$meta$when',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.ui(t.textMuted, size: 12),
                          ),
                        ),
                        if (pill case (
                          final words,
                          final color,
                          final icon,
                        )) ...[
                          const SizedBox(width: 8),
                          ReviewPill(words, color, icon),
                        ],
                      ],
                    ),
                  ),
                  if (c.body.isNotEmpty && SendToAgent.maybeOf(context) != null)
                    SendButton(
                      label: 'Send to agent',
                      tooltip:
                          "Send to the agent: a reply card in the chat's "
                          'box, to send',
                      onPressed: () =>
                          SendToAgent.maybeOf(context)?.onSend(commentReply(c)),
                    ),
                  if (c.url.isNotEmpty)
                    IconTap(
                      Icons.open_in_new,
                      size: 13,
                      tooltip: 'Open on GitHub',
                      onTap: () => openWeb(c.url),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  if (text.isEmpty)
                    Text(
                      widget.what.isNotEmpty ? 'No description.' : 'No text.',
                      style: theme.ui(t.textMuted, size: 12.5),
                    )
                  else if (clamped)
                    Clamped(body)
                  else
                    body,
                  if (findings > 0 || open > 0 || long)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (findings > 0)
                          PointerChip(
                            '$findings '
                            'finding${findings == 1 ? '' : 's'} to '
                            'address · in To do',
                            icon: Icons.warning_amber_rounded,
                            color: t.findingsAccent,
                            onTap: widget.onTodo,
                          ),
                        if (open > 0)
                          PointerChip(
                            '$open unresolved '
                            'thread${open == 1 ? '' : 's'} · in To do',
                            icon: Icons.forum_outlined,
                            color: t.needs,
                            onTap: widget.onTodo,
                          ),
                        if (long)
                          PointerChip(
                            _open
                                ? 'Show less'
                                : c.review.isEmpty
                                ? 'Show the whole comment'
                                : 'Show the whole review',
                            onTap: () => setState(() => _open = !_open),
                          ),
                      ],
                    ),
                  for (final x in threads)
                    if (x.resolved) ResolvedThread(x, now: widget.now),
                  if (foot.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: t.textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            foot,
                            style: theme.ui(t.textMuted, size: 11.5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
