import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_segments.dart' show quietSend;
import 'package:nushi/pull_side.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The Comments segment's list: each review thread not resolved on a line
/// (its place, its first words, Outdated), a click shows it in Comments
/// ([onThread]); then a review bot's findings left (each with Send to
/// agent; a click shows its review, [onReview]).
class CommentsList extends StatelessWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.findings,
    required this.onThread,
    required this.onReview,
    required this.narrow,
    super.key,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final List<ReviewFinding> findings;
  final ValueChanged<GitHubThread> onThread;
  final ValueChanged<String> onReview;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final open = [
      for (final x in pull.threads)
        if (!x.resolved) x,
    ];
    if (open.isEmpty && findings.isEmpty) {
      return const NoneLine('No unresolved conversations');
    }
    Widget row({
      required IconData icon,
      required Color ink,
      required String place,
      required String words,
      required VoidCallback onTap,
      Widget? end,
    }) => Tap(
      onTap: onTap,
      radius: 0,
      tooltip: 'Show it in Comments',
      padding: const EdgeInsets.fromLTRB(14, 5, 8, 5),
      child: SizedBox(
        height: 28,
        child: Row(
          spacing: 10,
          children: [
            Icon(icon, size: 16, color: ink),
            if (place.isNotEmpty)
              Flexible(
                child: Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.code(t.text, size: 12),
                ),
              ),
            Expanded(
              flex: 2,
              child: Text(
                words,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
            ?end,
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final x in open)
          row(
            icon: Icons.chat_bubble_outline,
            ink: t.needs,
            place: x.onFile ? x.path : threadPlace(x),
            words: x.comments.isEmpty
                ? ''
                : '${x.comments.first.author}: '
                      '${plainText(x.comments.first.body)}',
            onTap: () => onThread(x),
            end: x.outdated ? const NotePill('Outdated') : null,
          ),
        for (final f in findings)
          row(
            icon: Icons.warning_amber_rounded,
            ink: t.findingsAccent,
            place: findingPlace(f),
            words: '${f.from.author}: ${plainText(f.text)}',
            onTap: () => onReview(f.from.id),
            end: ControlScale.compact(
              child: quietSend(
                context,
                narrow: narrow,
                onPressed: () => toAgent(
                  context,
                  daemon,
                  pull.item,
                  what: switch (findingPlace(f)) {
                    '' => 'a finding',
                    final w => 'a finding on $w',
                  },
                  replies: () async => [findingReply(f)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The Approvals segment's list: each reviewer, their state, and who's
/// still awaited, with Ping on GitHub.
class ApprovalsList extends StatelessWidget {
  const new({required this.pull, super.key});

  final GitHubPull pull;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = pull;
    if (p.reviewers.isEmpty) return const NoneLine('No reviewers asked');
    final waiting = waitingOn(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in p.reviewers)
          if (reviewerLook(t, r) case (final icon, final ink, final words))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: Row(
                spacing: 10,
                children: [
                  PersonMark(r.login),
                  Text(
                    reviewerName(r),
                    style: theme.ui(t.text, weight: FontWeight.w500),
                  ),
                  Expanded(
                    child: Text(
                      r.codeOwner ? '$words, code owner' : words,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(
                        r.state == 'changes_requested'
                            ? t.crashed
                            : t.textMuted,
                        size: 12,
                      ),
                    ),
                  ),
                  Icon(icon, size: icon == Icons.circle ? 8 : 16, color: ink),
                ],
              ),
            ),
        if (waiting.isNotEmpty && p.item.url.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LinkText(
                'Ping on GitHub',
                size: 12,
                tooltip: 'Open the pull request on GitHub, to ask them',
                onTap: () => openWeb(context, p.item.url),
              ),
            ),
          ),
      ],
    );
  }
}

/// A segment's list with nothing in it.
class NoneLine extends StatelessWidget {
  const new(this.words, {super.key});

  final String words;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Text(words, style: theme.ui(theme.t.textMuted, size: 12)),
    );
  }
}
