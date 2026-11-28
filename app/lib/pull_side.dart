import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A person's mark on the pull request's page: the first letter of their
/// login on its colour, never an image from GitHub (ADR 0137).
class PersonMark extends StatelessWidget {
  const new(this.login, {super.key, this.size = 20});

  final String login;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Avatar(name: login, id: login, size: size, letters: 1, tip: false);
}

/// A reviewer's state as its mark, ink and words: approved (a tick),
/// changes requested, awaited (a dot), commented, dismissed.
(IconData, Color, String) reviewerLook(Tokens t, GitHubReviewer r) =>
    switch (r.state) {
      'approved' => (Icons.check, t.done, 'Approved'),
      'changes_requested' => (
        Icons.feedback_outlined,
        t.crashed,
        'Requested changes',
      ),
      'commented' => (Icons.chat_bubble_outline, t.textMuted, 'Commented'),
      'dismissed' => (Icons.remove_circle_outline, t.textMuted, 'Dismissed'),
      _ => (Icons.circle, t.needs, 'Awaiting review'),
    };

/// A reviewer's name as GitHub writes it: a team's with its @.
String reviewerName(GitHubReviewer r) => r.team ? '@${r.login}' : r.login;

/// A label's colour as GitHub gives it (six hex digits), or null.
Color? labelColor(String hex) {
  final v = int.tryParse(hex, radix: 16);
  if (v == null || hex.length != 6) return null;
  // design: a GitHub label's own colour, drawn only as its small dot.
  return Color.fromARGB(255, v >> 16 & 255, v >> 8 & 255, v & 255);
}

/// Everyone who took part: the author, then whoever commented, reviewed
/// or wrote in a thread, in order of first word.
List<String> participants(GitHubPull p) {
  final seen = <String>{p.item.author};
  for (final c in [
    ...p.conversation,
    ...p.reviews,
    for (final x in p.threads) ...x.comments,
  ]) {
    if (c.author.isNotEmpty) seen.add(c.author);
  }
  return seen.where((s) => s.isNotEmpty).toList();
}

/// The page's side column (under the main column when narrow): Activity
/// (its commits, a click opens the Commits tab), Reviewers with their
/// states, Assignees, Labels and who took part. Read-only: changing them
/// is GitHub's.
class PullSide extends StatelessWidget {
  const new({required this.pull, required this.onCommits, super.key, this.top});

  final GitHubPull pull;
  final VoidCallback onCommits;

  /// What goes first (the GitHub view's chats on the item).
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = pull;
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        s,
        style: theme.ui(t.textMuted, size: 12, weight: FontWeight.w600),
      ),
    );
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 1, color: t.line),
    );
    Widget row(Widget lead, String words, {Widget? end}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        spacing: 8,
        children: [
          lead,
          Expanded(
            child: Text(
              words,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text),
            ),
          ),
          ?end,
        ],
      ),
    );
    Widget none(String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(s, style: theme.ui(t.textMuted, size: 12)),
    );
    final who = participants(p);
    return Column(
      key: const ValueKey('pull-side'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (top case final w?) ...[w, line],
        heading('Activity'),
        Tap(
          onTap: onCommits,
          tooltip: 'Show the commits',
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: row(
            Icon(Icons.commit, size: 16, color: t.textMuted),
            'Commits',
            end: Text('${p.commits}', style: theme.ui(t.textMuted, size: 12)),
          ),
        ),
        line,
        heading('Reviewers'),
        if (p.reviewers.isEmpty) none('No reviews'),
        for (final r in p.reviewers)
          if (reviewerLook(t, r) case (final icon, final ink, final words))
            row(
              PersonMark(r.login),
              reviewerName(r),
              end: tooltip(
                context,
                r.codeOwner ? '$words, code owner' : words,
                Icon(icon, size: icon == Icons.circle ? 8 : 16, color: ink),
              ),
            ),
        line,
        heading('Assignees'),
        if (p.assignees.isEmpty) none('No one'),
        for (final a in p.assignees) row(PersonMark(a), a),
        line,
        heading('Labels'),
        if (p.labels.isEmpty)
          none('None')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final l in p.labels) LabelPill(l)],
          ),
        line,
        heading('${who.length} participant${who.length == 1 ? '' : 's'}'),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [for (final w in who) tooltip(context, w, PersonMark(w))],
        ),
      ],
    );
  }
}

/// A label: its name on Nushi's pill, GitHub's colour only as a dot.
class LabelPill extends StatelessWidget {
  const new(this.label, {super.key});

  final GitHubLabel label;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final dot = labelColor(label.color);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 9, 2),
      decoration: BoxDecoration(
        color: t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (dot != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          Text(
            label.name,
            style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
