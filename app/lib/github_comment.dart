import 'package:flutter/material.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_text.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/pull_reactions.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

export 'package:nushi/github_text.dart';

/// A comment (an issue's, a thread's, a bot's in a pull request's
/// Comments, whose reviews have their own card): its author (marked when
/// outside the repository, or a bot), when, its text. A bot's comment
/// folds to one line, its first words, with Show; a long text shows its
/// first lines, with Show the whole comment.
///
/// In a chat's tab it can be sent to the agent ([SendToAgent]), unless
/// it's part of a thread ([sendable] false: the thread is sent whole).
/// Given [reacting], its reactions show under it as a pull request's
/// comments' do ([Reactions]; an issue's comments, #88).
class CommentEntry extends StatefulWidget {
  const new(
    this.comment, {
    super.key,
    this.sendable = true,
    this.mark = true,
    this.updated = false,
    this.reacting,
  });

  final GitHubComment comment;

  /// Where its reactions go; null shows none.
  final Reacting? reacting;
  final bool sendable;

  /// Its time is when its issue last changed, not when it was written
  /// (an issue's description from a daemon that sends no opened date):
  /// it reads "updated 1h ago".
  final bool updated;

  /// A bot's mark before its name (none where an avatar shows it).
  final bool mark;

  @override
  State<CommentEntry> createState() => _CommentEntryState();
}

class _CommentEntryState extends State<CommentEntry> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = widget.comment;
    final folds = c.bot && c.body.isNotEmpty;
    final long = !folds && longText(c.body);
    final toggle = LinkText(
      folds
          ? (_open ? 'Hide' : 'Show')
          : _open
          ? 'Show less'
          : 'Show the whole comment',
      // A bot's Show and Hide take the same room, so the link stays put
      // as it's pressed.
      roomFor: folds ? const ['Show', 'Hide'] : const [],
      size: 12,
      onTap: () => setState(() => _open = !_open),
    );
    // Its time sits after the author, folded or open; a folded bot's
    // summary follows it, so nothing in the row moves as Show is pressed.
    final head = Row(
      children: [
        if (c.bot && widget.mark) ...[
          Icon(Icons.smart_toy_outlined, size: 13, color: t.textMuted),
          const SizedBox(width: 5),
        ],
        Text(
          c.author,
          style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
        ),
        if (c.bot) Text('  bot', style: theme.ui(t.textMuted, size: 11.5)),
        if (c.outside && !c.bot) const OutsideMark(),
        Text(
          '  ${widget.updated ? 'updated ' : ''}'
          '${agoAt(c.createdMs.toInt(), clock())}',
          style: theme.ui(t.textMuted, size: 11.5),
        ),
        if (folds && !_open)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                commentSummary(c.body),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          )
        else
          const Spacer(),
        if (folds) ...[const SizedBox(width: 10), toggle],
        if (widget.sendable && c.body.isNotEmpty)
          SendIcon(
            () async => commentReply(c),
            what: "${possessive('@${c.author}')} comment",
          ),
        if (c.url.isNotEmpty)
          IconTap(
            Icons.open_in_new,
            size: 13,
            tooltip: 'Open on GitHub',
            onTap: () => openWeb(context, c.url),
          ),
      ],
    );
    final clamped = long && !_open;
    final body = AgentMarkdown(
      githubText(clamped ? textStart(c.body) : c.body),
      images: githubImage,
    );
    return Padding(
      padding: EdgeInsets.only(top: folds ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          if (c.body.isNotEmpty && (!folds || _open))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: clamped ? Clamped(body) : body,
            ),
          if (long)
            Padding(padding: const EdgeInsets.only(top: 4), child: toggle),
          if (widget.reacting case final r? when !folds || _open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Reactions(c.id, c.reactions, reacting: r),
            ),
        ],
      ),
    );
  }
}

/// "outside" after an author who isn't the repository's owner, a member
/// or a collaborator: what they wrote may be anyone's.
class OutsideMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return tooltip(
      context,
      "Not the repository's owner, a member or a collaborator",
      Text('  outside', style: theme.ui(theme.t.needs, size: 11.5)),
    );
  }
}

/// [child]'s first three lines or so, fading out at the foot.
class Clamped extends StatelessWidget {
  const new(this.child, {super.key});

  final Widget child;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.55, 1],
      // design: a fade's mask, of which only the alpha counts.
      colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    ).createShader(r),
    child: ClipRect(
      child: SizedBox(
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    ),
  );
}
