import 'package:flutter/material.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/pull_reactions.dart';
import 'package:nushi/pull_side.dart';
import 'package:nushi/pull_thread_card.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The Comments heading's filter: everything, only review threads not
/// resolved, or only what the user wrote or answered.
enum CommentFilter { all, unresolved, mine }

/// One entry of the Comments: a review (with the threads made in it), a
/// comment, or threads whose review isn't known (from an older daemon);
/// `at` places it in time.
typedef CommentItem = ({
  GitHubComment? comment,
  List<GitHubThread> threads,
  int at,
});

/// [p]'s comments, the newest first, as GitHub's page has them (ADR
/// 0137): each review with its threads (placed by their first comment's
/// review id; a thread's replies stay oldest first), each plain comment;
/// a review that said nothing and holds no thread is left out, and
/// threads whose review isn't among them come on their own, at their
/// first comment.
List<CommentItem> commentItems(GitHubPull p) {
  final reviews = p.reviews.isNotEmpty
      ? p.reviews
      : [
          for (final c in p.conversation)
            if (c.review.isNotEmpty) c,
        ];
  final ids = {for (final r in reviews) r.id};
  final under = <String, List<GitHubThread>>{};
  final loose = <GitHubThread>[];
  for (final x in p.threads) {
    final id = x.comments.firstOrNull?.reviewId ?? '';
    if (ids.contains(id)) {
      (under[id] ??= []).add(x);
    } else {
      loose.add(x);
    }
  }
  final out = <CommentItem>[
    for (final r in reviews)
      if (r.body.isNotEmpty || under.containsKey(r.id))
        (comment: r, threads: under[r.id] ?? const [], at: r.createdMs.toInt()),
    for (final c in p.conversation)
      if (c.review.isEmpty)
        (comment: c, threads: const [], at: c.createdMs.toInt()),
    for (final x in loose)
      (
        comment: null,
        threads: [x],
        at: x.comments.firstOrNull?.createdMs.toInt() ?? 0,
      ),
  ];
  // What came at the same moment keeps GitHub's order.
  final order = [for (var n = 0; n < out.length; n++) n]
    ..sort(
      (a, b) => switch (out[b].at.compareTo(out[a].at)) {
        0 => a.compareTo(b),
        final c => c,
      },
    );
  return [for (final n in order) out[n]];
}

/// [items] as [filter] shows them; [me] is who the user is ('' unknown).
List<CommentItem> filtered(
  List<CommentItem> items,
  CommentFilter filter,
  String me,
) {
  bool mine(String who) =>
      me.isNotEmpty && who.toLowerCase() == me.toLowerCase();
  return switch (filter) {
    CommentFilter.all => items,
    CommentFilter.unresolved => [
      for (final i in items)
        if (i.threads.where((x) => !x.resolved).toList() case final open
            when open.isNotEmpty)
          (comment: i.comment, threads: open, at: i.at),
    ],
    CommentFilter.mine => [
      for (final i in items)
        if (i.comment != null && mine(i.comment!.author))
          i
        else if (i.threads.where((x) => x.comments.any((c) => mine(c.author)))
            case final ours when ours.isNotEmpty)
          (comment: i.comment, threads: ours.toList(), at: i.at),
    ],
  };
}

/// The Overview's Comments, as GitHub's page: the heading with its
/// filter (All, Unresolved, Mine), the box for a comment, then each
/// review and comment, the newest first (one just posted lands right
/// under the box, so nothing above it moves), a review's threads in its
/// card ([PullThread], each by its key in [threadKeys]).
class PullComments extends StatelessWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.me,
    required this.filter,
    required this.onFilter,
    required this.onPosted,
    required this.threadKeys,
    required this.reviewKeys,
    super.key,
    this.items = const [],
    this.older = const {},
  });

  final Daemon daemon;
  final GitHubPull pull;

  /// Who the user is on the pull request's host ('' when not known).
  final String me;
  final CommentFilter filter;
  final ValueChanged<CommentFilter> onFilter;
  final Future<void> Function() onPosted;
  final GlobalKey<PullThreadState> Function(String id) threadKeys;
  final GlobalKey Function(String id) reviewKeys;

  /// What blocks the merge: a thread's bots' findings go with it.
  final List<TodoItem> items;

  /// The review bots whose findings come from a review on an older commit
  /// than the head, and that commit.
  final Map<String, String> older;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = pull;
    final also = {
      for (final i in items.whereType<ThreadTodo>()) i.thread.id: i.also,
    };
    final shown = filtered(commentItems(p), filter, me);
    final reacting = (
      daemon: daemon,
      host: p.item.ref.host,
      onChanged: onPosted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Comments',
                style: theme.ui(t.text, size: 20, weight: FontWeight.w600),
              ),
            ),
            Segmented<CommentFilter>(
              value: filter,
              segments: const [
                (CommentFilter.all, 'All'),
                (CommentFilter.unresolved, 'Unresolved'),
                (CommentFilter.mine, 'Mine'),
              ],
              onChanged: onFilter,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CommentBox(
          draft: githubDraft(p.item.ref, 'comment'),
          hint: 'Leave a comment',
          note: me.isEmpty ? 'Markdown' : 'Markdown · posts to GitHub as $me',
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
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(switch (filter) {
              CommentFilter.all => 'No comments',
              CommentFilter.unresolved => 'No unresolved conversations',
              CommentFilter.mine => 'Nothing of yours',
            }, style: theme.ui(t.textMuted, size: 12)),
          ),
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              for (final i in shown)
                _CommentCard(
                  key: i.comment == null ? null : reviewKeys(i.comment!.id),
                  comment: i.comment,
                  reacting: reacting,
                  older: switch (i.comment) {
                    final c? when older[c.author] == c.commit => c.commit,
                    _ => '',
                  },
                  threads: [
                    for (final x in i.threads)
                      PullThread(
                        key: threadKeys(x.id),
                        daemon: daemon,
                        item: p.item,
                        thread: x,
                        also: also[x.id] ?? const [],
                        onChanged: onPosted,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A trailing line of a bot's numbers ("reviewer-xl · $3.48 · 12m 05s"):
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

/// A review's or a comment's card: its author's mark, what they did and
/// when, its state's icon and a ⋯ (Send to agent, Open on GitHub); its
/// text (a long one's start, with Show the whole review; a bot's comment
/// folded to one line, with Show; a bot's numbers muted at its foot)
/// and its reactions; then its [threads].
class _CommentCard extends StatefulWidget {
  const new({
    required this.comment,
    required this.threads,
    required this.reacting,
    super.key,
    this.older = '',
  });

  final Reacting reacting;

  final GitHubComment? comment;
  final List<Widget> threads;

  /// The older commit its bot's findings come from ('' for none).
  final String older;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = widget.comment;
    final threads = [
      for (final x in widget.threads)
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: x),
    ];
    if (c == null) {
      return Container(
        decoration: cardBox(t),
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: threads,
        ),
      );
    }
    final folds = c.bot && c.review.isEmpty && c.body.isNotEmpty;
    final (text, foot) = c.bot ? _splitFoot(c.body) : (c.body, '');
    final long = !folds && longText(text);
    final verb = switch (c.review) {
      'approved' => 'approved',
      'changes_requested' => 'requested changes',
      'dismissed' => 'reviewed (dismissed)',
      '' => 'commented',
      _ => 'reviewed',
    };
    final mark = switch (c.review) {
      'approved' => (Icons.check_circle_outline, t.done, 'Approved'),
      'changes_requested' => (
        Icons.cancel_outlined,
        t.crashed,
        'Requested changes',
      ),
      'dismissed' => (Icons.remove_circle_outline, t.textMuted, 'Dismissed'),
      _ => null,
    };
    final to = SendToAgent.maybeOf(context);
    final what =
        "${possessive('@${c.author}')} "
        "${c.review.isEmpty ? 'comment' : 'review'}";
    final menu = [
      if (to != null && c.body.isNotEmpty)
        MenuEntry(
          'Send to agent',
          icon: Icons.subdirectory_arrow_right,
          onPick: () => to.send(
            c.review == 'changes_requested'
                ? changesRequestedReply(c)
                : commentReply(c),
            what,
          ),
        ),
      if (c.url.isNotEmpty)
        MenuEntry('Open on GitHub', onPick: () => openWeb(context, c.url)),
    ];
    final clamped = long && !_open;
    final short = widget.older.length > 7
        ? widget.older.substring(0, 7)
        : widget.older;
    final body = AgentMarkdown(
      githubText(clamped ? textStart(text) : text),
      images: githubImage,
    );
    return DecoratedBox(
      decoration: cardBox(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              spacing: 8,
              children: [
                PersonMark(c.author),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: c.author,
                          style: theme.ui(t.text, weight: FontWeight.w600),
                        ),
                        if (c.bot) const TextSpan(text: '  bot'),
                        TextSpan(
                          text:
                              ' $verb · ${agoAt(c.createdMs.toInt(), clock())}',
                        ),
                        if (folds && !_open)
                          TextSpan(text: '  ${commentSummary(c.body)}'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.textMuted),
                  ),
                ),
                if (c.outside && !c.bot) const OutsideMark(),
                if (folds)
                  Button(
                    label: _open ? 'Hide' : 'Show',
                    kind: ButtonKind.quiet,
                    onPressed: () => setState(() => _open = !_open),
                  ),
                if (mark case (final icon, final ink, final tip))
                  tooltip(context, tip, Icon(icon, size: 16, color: ink)),
                if (menu.isNotEmpty)
                  MenuIcon(Icons.more_horiz, tooltip: 'More', entries: menu),
              ],
            ),
          ),
          if (widget.older.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 0, 16, 6),
              child: Text(
                'On an older commit ($short): some findings may be done '
                '· comment /review for a fresh one',
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
          if (text.isNotEmpty && (!folds || _open))
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  if (clamped) Clamped(body) else body,
                  if (long)
                    LinkText(
                      _open
                          ? 'Show less'
                          : c.review.isEmpty
                          ? 'Show the whole comment'
                          : 'Show the whole review',
                      size: 12,
                      onTap: () => setState(() => _open = !_open),
                    ),
                  if (foot.isNotEmpty)
                    Text(foot, style: theme.ui(t.textMuted, size: 11.5)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Reactions(
                      c.id,
                      c.reactions,
                      reacting: widget.reacting,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
          ...threads,
        ],
      ),
    );
  }
}
