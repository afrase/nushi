import 'package:flutter/material.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A quiet button: its words, a tint under the pointer.
class GhostButton extends StatelessWidget {
  const new(
    this.label, {
    required this.onTap,
    super.key,
    this.icon,
    this.tooltip = '',
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Pressable(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, look) => Container(
        height: controlHeight,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: look.hover ? t.hover : null,
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        foregroundDecoration: focusRing(t, look),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              label,
              style: theme.ui(
                look.enabled ? t.textSecondary : t.textMuted,
                size: 12.5,
              ),
            ),
            if (icon != null) Icon(icon, size: 13, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

/// One item: its box to pick it, its icon, what and where, its line of
/// detail and whose it is; Log (a check's failing part), Reply and
/// Resolve (a thread's), Send.
class TodoRow extends StatefulWidget {
  const new({
    required this.item,
    required this.daemon,
    required this.pull,
    required this.now,
    required this.picked,
    required this.onPick,
    required this.onSend,
    required this.onChanged,
    super.key,
    this.inBox = false,
  });

  final TodoItem item;
  final Daemon daemon;
  final GitHubPull pull;
  final DateTime now;
  final bool picked;
  final ValueChanged<bool> onPick;

  /// Its card waits in the chat's box: Send is "In the box ✓", off, until
  /// the card is taken out or sent.
  final bool inBox;
  final VoidCallback onSend;
  final Future<void> Function() onChanged;

  @override
  State<TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends State<TodoRow> {
  bool _log = false;
  String? _tail;
  String? _error;
  bool _busy = false;

  /// The reply box shows: opened, or a reply written there not posted yet.
  late bool _replying = switch (widget.item) {
    ThreadTodo(:final thread) => commentDraft(_draft(thread)).isNotEmpty,
    _ => false,
  };

  /// The key of thread [x]'s reply box: the Files tab's too.
  String _draft(GitHubThread x) =>
      githubDraft(widget.pull.item.ref, 'thread ${x.id}');

  Future<void> _toggleLog(GitHubCheck c) async {
    setState(() => _log = !_log);
    if (!_log || _tail != null || c.id == 0) return;
    try {
      final r = await widget.daemon.client.getGitHubJobLog(
        GetGitHubJobLogRequest(ref: widget.pull.item.ref, job: c.id),
      );
      if (mounted) setState(() => _tail = failingPart(r.tail));
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  Future<void> _resolve(GitHubThread x) async {
    setState(() => _busy = true);
    await tryOrShow(context, () async {
      await widget.daemon.client.resolveGitHubThread(
        ResolveGitHubThreadRequest(
          host: widget.pull.item.ref.host,
          thread: x.id,
          resolve: true,
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
    final i = widget.item;
    final small = theme.ui(t.textMuted, size: 11.5);
    Text? where(String place) => place.isEmpty
        ? null
        : Text(
            place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.text, size: 12),
          );
    final (
      IconData icon,
      Color color,
      Text? title,
      _Tag? tag,
      String detail,
    ) = switch (i) {
      CheckTodo(check: final c) => (
        Icons.cancel_outlined,
        t.crashed,
        Text.rich(
          TextSpan(
            children: [
              if (c.workflow.isNotEmpty)
                TextSpan(
                  text: '${c.workflow} / ',
                  style: theme.ui(t.textMuted),
                ),
              TextSpan(text: c.name),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(t.text, weight: FontWeight.w500),
        ),
        c.required ? _Tag('Required', t.textSecondary) : null,
        _checkDetail(c),
      ),
      ReviewTodo(review: final r) => (
        Icons.rate_review_outlined,
        t.crashed,
        Text(
          '@${r.author}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(t.text, weight: FontWeight.w500),
        ),
        _Tag('Changes requested', t.crashed, soft: true),
        r.body.isEmpty
            ? 'No text: their review threads say what'
            : _firstLine(plainText(r.body)),
      ),
      ThreadTodo(thread: final x) => (
        Icons.forum_outlined,
        t.needs,
        where(threadPlace(x)),
        _Tag(x.outdated ? 'Outdated' : 'Unresolved', t.needs, soft: true),
        plainText(x.comments.isEmpty ? '' : x.comments.first.body),
      ),
      FindingTodo(finding: final f) => (
        Icons.warning_amber_rounded,
        t.findingsAccent,
        where(findingPlace(f)),
        _Tag('Must address', t.findingsAccent, soft: true),
        plainText(f.text),
      ),
    };
    final who = _whose(i, widget.now);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 24,
                child: Checkbox(
                  value: widget.picked,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => widget.onPick(v ?? false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 7),
                child: Icon(icon, size: 15, color: color),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          if (title != null) ...[
                            Flexible(child: title),
                            if (tag != null) const SizedBox(width: 8),
                          ],
                          ?tag,
                        ],
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(t.textSecondary, size: 12.5),
                        ),
                      ),
                    if (who.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(who, style: small),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  if (i case CheckTodo(check: final c)
                      when c.id != 0 || c.url.isNotEmpty)
                    GhostButton(
                      _log ? 'Hide log' : 'Log',
                      tooltip: c.id == 0
                          ? 'Open its page on GitHub'
                          : 'The failing part of its log',
                      onTap: c.id == 0
                          ? () => openWeb(c.url)
                          : () => _toggleLog(c),
                    ),
                  if (i case ThreadTodo(thread: final x) when x.canReply)
                    GhostButton(
                      'Reply',
                      onTap: () => setState(() => _replying = true),
                    ),
                  if (i case ThreadTodo(thread: final x) when x.canResolve)
                    GhostButton(
                      'Resolve',
                      onTap: _busy ? null : () => _resolve(x),
                    ),
                  const SizedBox(width: 4),
                  SendButton(
                    label: widget.inBox ? 'In the box ✓' : 'Send',
                    tooltip: widget.inBox
                        ? "Its card waits in the chat's box"
                        : "Its reply card in the chat's box, to send with "
                              'your message',
                    onPressed: widget.inBox ? null : widget.onSend,
                  ),
                ],
              ),
            ],
          ),
          if (_log)
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 6, 0, 0),
              child: _error != null
                  ? Text(_error!, style: theme.ui(t.crashed, size: 12))
                  : _tail == null
                  ? Text('Loading the log…', style: small)
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      padding: const EdgeInsets.all(8),
                      decoration: box(t.borderSubtle, fill: t.codeBlock),
                      child: SingleChildScrollView(
                        reverse: true, // the end is what matters
                        child: SelectableText(
                          _tail!.isEmpty ? '(an empty log)' : _tail!,
                          style: theme.code(t.text, size: 11.5),
                        ),
                      ),
                    ),
            ),
          if (_replying && i is ThreadTodo)
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 6, 0, 0),
              child: CommentBox(
                draft: _draft(i.thread),
                hint: 'Reply (Markdown; ⌘⏎ posts it)',
                label: 'Reply',
                autofocus: true,
                onCancel: () => setState(() => _replying = false),
                onPost: (text) async {
                  await widget.daemon.client.replyGitHubThread(
                    ReplyGitHubThreadRequest(
                      host: widget.pull.item.ref.host,
                      thread: i.thread.id,
                      body: text,
                    ),
                  );
                  if (mounted) setState(() => _replying = false);
                  await widget.onChanged();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// What a failed check says: its failures counted and the first, as
/// `file:line message`; else its title.
String _checkDetail(GitHubCheck c) {
  final failures = [
    for (final a in c.annotations)
      if (a.level == 'failure') a,
  ];
  final first = failures.isEmpty ? null : failures.first;
  if (first != null) {
    final where = '${first.path.split('/').last}:${first.line}';
    final n = failures.length;
    return '${n > 1 ? '$n failures · ' : ''}$where ${first.message}';
  }
  if (c.title.isNotEmpty) return c.title;
  return c.state == 'timed_out' ? 'Timed out' : 'Failed';
}

/// [text]'s first line (a review's summary, in one line).
String _firstLine(String text) => text.trim().split('\n').first.trim();

/// Whose an item is: a thread's authors (and a bot's review when its
/// finding is on the same lines), a finding's review; and when. A check
/// is no one's.
String _whose(TodoItem i, DateTime now) {
  switch (i) {
    case ThreadTodo(thread: final x, :final also):
      final people = {for (final c in x.comments) c.author}.join(', ');
      final last = x.comments.lastOrNull;
      final bots = {
        for (final f in also) '${possessive(f.from.author)} review',
      };
      return [
        if (bots.isEmpty) people else '$people, and ${bots.join(', ')}',
        if (last != null) agoAt(last.createdMs.toInt(), now),
      ].join(' · ');
    case ReviewTodo(review: final r):
      return [
        'their latest review',
        if (r.createdMs != 0) agoAt(r.createdMs.toInt(), now),
      ].join(' · ');
    case FindingTodo(finding: final f):
      return '${possessive(f.from.author)} review · '
          '${agoAt(f.from.createdMs.toInt(), now)}';
    case CheckTodo():
      return '';
  }
}

class _Tag extends StatelessWidget {
  const new(this.text, this.color, {this.soft = false});

  final String text;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: soft ? color.withValues(alpha: 0.14) : null,
        border: soft ? null : Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Text(
        text,
        style: theme.ui(color, size: 11.5, weight: FontWeight.w500),
      ),
    );
  }
}
