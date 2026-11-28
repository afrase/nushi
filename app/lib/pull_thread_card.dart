import 'package:flutter/material.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_thread.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/pull_reactions.dart';
import 'package:nushi/pull_side.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A line of a thread's diff hunk: its kind (' ', '+' or '-'), its
/// number on the side it shows (0 for a removed line) and its text.
typedef HunkLine = (String kind, int number, String text);

/// The last [last] lines of [hunk] (a unified diff hunk, as GitHub keeps
/// a thread's), numbered from its `@@` header: a removed line by the old
/// side, which shows no number, the rest by the new side.
List<HunkLine> hunkLines(String hunk, {int last = 5}) {
  final out = <HunkLine>[];
  if (hunk.isEmpty) return out;
  var neu = 0;
  final header = RegExp(r'^@@ -\d+(?:,\d+)? \+(\d+)');
  for (final line in hunk.split('\n')) {
    if (header.firstMatch(line) case final m?) {
      neu = int.parse(m[1]!);
      continue;
    }
    if (line.startsWith(r'\')) continue; // "\ No newline at end of file"
    final kind = line.isEmpty ? ' ' : line[0];
    final text = line.isEmpty ? '' : line.substring(1);
    switch (kind) {
      case '-':
        out.add(('-', 0, text));
      case '+':
        out.add(('+', neu++, text));
      default:
        out.add((' ', neu++, text));
    }
  }
  return out.length <= last ? out : out.sublist(out.length - last);
}

/// A review thread on the Overview, inside its review's card: its file's
/// path, the last lines of its hunk, its comments, a reply field,
/// Resolve conversation and Send to agent. A resolved or outdated one
/// folds to its path and a pill, with Show. [also] are a review bot's
/// findings on its lines, which go to the agent with it.
class PullThread extends StatefulWidget {
  const new({
    required this.daemon,
    required this.item,
    required this.thread,
    required this.onChanged,
    super.key,
    this.also = const [],
  });

  final Daemon daemon;

  /// The pull request it's on.
  final GitHubItem item;
  final GitHubThread thread;
  final List<ReviewFinding> also;
  final Future<void> Function() onChanged;

  @override
  State<PullThread> createState() => PullThreadState();
}

/// [PullThread]'s state; [show] opens it (a click on its row in the merge
/// status card).
class PullThreadState extends State<PullThread> {
  /// The reply box shows: opened, or a reply written there not posted yet.
  late bool _replying = commentDraft(
    threadDraft(widget.item.ref, widget.thread),
  ).isNotEmpty;
  late bool _open =
      !(widget.thread.resolved || widget.thread.outdated) || _replying;
  bool _busy = false;

  /// Opens it, folded or not.
  void show() {
    if (!_open) setState(() => _open = true);
  }

  Future<void> _resolve(bool resolve) async {
    setState(() => _busy = true);
    await tryOrShow(context, () async {
      await widget.daemon.client.resolveGitHubThread(
        ResolveGitHubThreadRequest(
          host: widget.item.ref.host,
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
    final folds = x.resolved || x.outdated;
    final head = Row(
      children: [
        Expanded(
          child: Text(
            x.onFile ? x.path : threadPlace(x),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.textSecondary, size: 12),
          ),
        ),
        if (x.outdated) ...[
          const NotePill('Outdated'),
          const SizedBox(width: 8),
        ],
        if (x.resolved) ...[
          const NotePill('Resolved', tone: NoteTone.done),
          const SizedBox(width: 8),
        ],
        if (folds)
          Button(
            label: _open ? 'Hide' : 'Show',
            // The same width either way, so it and the pills before it
            // stay put as it's pressed.
            roomFor: const ['Show', 'Hide'],
            kind: ButtonKind.quiet,
            onPressed: () => setState(() => _open = !_open),
          ),
      ],
    );
    final lines = hunkLines(x.diffHunk);
    return Container(
      key: ValueKey('thread ${x.id}'),
      decoration: BoxDecoration(
        color: t.base,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      // Its head's row is as high from the top folded or open, so Show,
      // turning into Hide, stays where it was pressed.
      padding: EdgeInsets.fromLTRB(12, 3, 8, _open ? 10 : 3),
      child: !_open
          ? SizedBox(height: ControlSize.regular.height, child: head)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                SizedBox(height: ControlSize.regular.height, child: head),
                if (lines.isNotEmpty) HunkLines(lines),
                for (final c in x.comments)
                  ThreadComment(
                    c,
                    reacting: (
                      daemon: widget.daemon,
                      host: widget.item.ref.host,
                      onChanged: widget.onChanged,
                    ),
                  ),
                if (_replying)
                  ThreadReplyBox(
                    daemon: widget.daemon,
                    ref: widget.item.ref,
                    thread: x,
                    onClose: () => setState(() => _replying = false),
                    onChanged: widget.onChanged,
                  )
                else if (x.canReply)
                  _ReplyField(onTap: () => setState(() => _replying = true)),
                ControlScale.compact(
                  child: Row(
                    spacing: 6,
                    children: [
                      if (x.canResolve && !x.resolved)
                        Button(
                          label: 'Resolve conversation',
                          onPressed: _busy ? null : () => _resolve(true),
                        ),
                      if (x.canUnresolve && x.resolved)
                        Button(
                          label: 'Unresolve conversation',
                          onPressed: _busy ? null : () => _resolve(false),
                        ),
                      const Spacer(),
                      Button(
                        label: 'Send to agent',
                        kind: ButtonKind.quiet,
                        icon: Icons.subdirectory_arrow_right,
                        tooltip:
                            "A reply card in the chat's box, to send with "
                            'your message',
                        onPressed: () => toAgent(
                          context,
                          widget.daemon,
                          widget.item,
                          what: 'the thread on ${threadPlace(x)}',
                          replies: () async => [
                            threadReply(x, also: widget.also),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Reply…", a field's look: a click opens the thread's reply box.
class _ReplyField extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Pressable(
      onTap: onTap,
      tooltip: 'Reply on GitHub',
      builder: (context, look) => Container(
        height: ControlSize.regular.height + 2,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: t.fieldFill,
          border: Border.all(
            color: look.hover ? t.fieldBorderHover : t.fieldBorder,
          ),
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        foregroundDecoration: focusRing(t, look),
        child: Text('Reply…', style: theme.ui(t.hintOn(t.fieldFill))),
      ),
    );
  }
}

/// A thread's comment: its author's mark, name and age, its text; with
/// [reacting], its reactions under it.
class ThreadComment extends StatelessWidget {
  const new(this.comment, {super.key, this.reacting});

  final GitHubComment comment;
  final Reacting? reacting;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = comment;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        PersonMark(c.author),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    c.author,
                    style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
                  ),
                  if (c.outside && !c.bot) const OutsideMark(),
                  Text(
                    '  ${agoAt(c.createdMs.toInt(), clock())}',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ],
              ),
              AgentMarkdown(githubText(c.body), images: githubImage),
              if (reacting case final r?)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Reactions(c.id, c.reactions, reacting: r),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A hunk's lines as the diff draws them: the new side's numbers, a
/// mark, the text on its line's fill.
class HunkLines extends StatelessWidget {
  const new(this.lines, {super.key});

  final List<HunkLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final d = theme.t.diff;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NushiTheme.control),
      child: ColoredBox(
        color: d.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (kind, n, text) in lines)
                ColoredBox(
                  color: switch (kind) {
                    '+' => d.insertedLine,
                    '-' => d.deletedLine,
                    _ => d.background,
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            n == 0 ? '' : '$n',
                            textAlign: TextAlign.right,
                            style: theme.code(d.gutterText, size: 12),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            kind,
                            textAlign: TextAlign.center,
                            style: theme.code(d.gutterText, size: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            text.replaceAll('\t', '    '),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: theme.code(d.text, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
