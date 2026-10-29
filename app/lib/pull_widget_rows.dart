import 'package:flutter/material.dart';
import 'package:nushi/cleanup_dialog.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/pull_header.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_widget_parts.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The PR widget open: the state pill, number and age, the title; for an
/// open or draft pull request the checks as a bar with its legend (and
/// Fix checks while some fail), then a row per reviewer (one asked and
/// waiting, or how each reviewed: a missing code owner shows), the review
/// threads not resolved (Address), whether it can merge and what blocks
/// it, the comments; a draft says its reviewers aren't asked yet, with
/// Ready for review; merged or closed, what that means for its branch.
class PullRows extends StatelessWidget {
  const new(this.cp, {super.key});

  final ChatPull cp;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = cp.pull!;
    final it = p.item;
    final done = it.state == 'merged' || it.state == 'closed';
    final unread = unreadComments(cp.chat.id, p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StatePill(it),
            const SizedBox(width: 6),
            Text(
              '#${it.ref.number}',
              style: theme.code(t.textSecondary, size: 12),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                agoAt(it.updatedMs.toInt(), clock()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.ui(t.textMuted, size: 11.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          it.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(
            done ? t.textSecondary : t.text,
            size: 12.5,
            weight: FontWeight.w600,
          ),
        ),
        if (done)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                CleanUpJob.of(cp.chat),
                cleanUpLater,
              ]),
              builder: (context, _) => CleanUpJob.of(cp.chat).started
                  ? CleanUpProgress(CleanUpJob.of(cp.chat))
                  : _Done(cp),
            ),
          )
        else ...[
          if (p.checks.isNotEmpty) ...[
            const SizedBox(height: 9),
            ChecksBar(p),
            const SizedBox(height: 5),
            ChecksLegend(p),
            if (p.checks.any((c) => c.failed))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SendButton(
                    label: 'Fix checks',
                    tooltip:
                        "Each failed check as a reply card in the chat's box, "
                        'to send',
                    onPressed: () => toAgent(
                      context,
                      cp.daemon,
                      it,
                      chat: cp.chat,
                      replies: () => checkReplies(cp.daemon, it.ref, p),
                    ),
                  ),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Divider(height: 1, color: t.borderSubtle),
          ),
          const SizedBox(height: 6),
          ..._rows(context, p, unread),
          if (it.draft && it.url.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Button(
                  label: 'Ready for review',
                  icon: Icons.open_in_new,
                  tooltip: 'Mark it ready for review on GitHub',
                  onPressed: () => openWeb(it.url),
                ),
              ),
            ),
        ],
        if (cp.error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Not current: $e',
              style: theme.ui(t.textMuted, size: 12),
            ),
          ),
      ],
    );
  }

  List<Widget> _rows(BuildContext context, GitHubPull p, int unread) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = p.item;
    final open = p.threads.where((x) => !x.resolved).length;
    final comments = commentTimes(p).length;
    final block = mergeBlockers(p);
    // Unstable with nothing else in the way, as the header has it: it can
    // merge (the checks that don't pass aren't required).
    final unstable = p.mergeState == 'unstable' && block.isEmpty;
    final ready =
        !hasConflicts(p) &&
        (p.mergeState == 'clean' || p.mergeState == 'has_hooks' || unstable);
    return [
      if (it.draft && p.reviewers.isEmpty)
        WidgetRow(
          icon: Icon(Icons.edit_outlined, size: 14, color: t.textMuted),
          label: "Reviewers aren't asked yet",
          muted: true,
        ),
      // The reviewers that count: those asked, and who approved or asked
      // for changes (not a bot that only commented).
      for (final r in p.reviewers)
        if (r.state != 'commented' && r.state != 'dismissed')
          _reviewer(context, r),
      if (open > 0)
        WidgetRow(
          icon: Icon(Icons.forum_outlined, size: 14, color: t.needs),
          label: '$open open thread${open == 1 ? '' : 's'}',
          trailing: SendButton(
            label: 'Address',
            tooltip: "Each thread as a reply card in the chat's box, to send",
            onPressed: () => toAgent(
              context,
              cp.daemon,
              it,
              chat: cp.chat,
              replies: () async => threadReplies(p),
            ),
          ),
        ),
      if (!it.draft)
        switch (p.mergeState) {
          _ when ready => WidgetRow(
            icon: Icon(Icons.merge_type, size: 14, color: t.done),
            label: 'Ready to merge',
            color: t.done,
            bold: true,
            trailing: it.url.isEmpty
                ? null
                : LinkText(
                    'Open on GitHub',
                    size: 12,
                    onTap: () {
                      markPullSeen(cp.chat.id, p);
                      openWeb(it.url);
                    },
                  ),
          ),
          'unknown' || '' when !hasConflicts(p) => WidgetRow(
            icon: Icon(Icons.schedule, size: 14, color: t.textMuted),
            label: 'Checking whether it can merge…',
            muted: true,
          ),
          _ => WidgetRow(
            icon: Icon(Icons.lock_outline, size: 14, color: t.needs),
            label: 'Merge blocked',
            color: t.needs,
            keepLabel: true,
            // Nothing named: a rule of its base's (GitHub's "blocked").
            value: block.isEmpty ? "a rule of ${p.base}'s" : block.join(', '),
          ),
        },
      // Under Ready to merge, whole (it may wrap).
      if (!it.draft && ready && unstable)
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 4),
          child: Text(unstableWords, style: theme.ui(t.textMuted, size: 12)),
        ),
      WidgetRow(
        icon: Icon(Icons.chat_bubble_outline, size: 13, color: t.textMuted),
        label: comments == 0
            ? 'No comments'
            : '$comments comment${comments == 1 ? '' : 's'}',
        trailing: unread > 0 ? NewCount(unread) : null,
      ),
    ];
  }

  Widget _reviewer(BuildContext context, GitHubReviewer r) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final name = r.team ? '@${r.login}' : r.login;
    if (r.state == 'requested') {
      return WidgetRow(
        icon: AskedRing(t.textMuted),
        label: name,
        value: 'waiting',
        tip: r.codeOwner ? 'Asked as a code owner' : 'Asked to review',
      );
    }
    final (words, color) = switch (r.state) {
      'approved' => ('Approved', t.done),
      'changes_requested' => ('Changes requested', t.crashed),
      'dismissed' => ('Dismissed', t.textMuted),
      _ => ('Commented', t.textMuted),
    };
    return WidgetRow(
      icon: Avatar(name: r.login, id: r.login, size: 17),
      label: name,
      value: words,
      valueColor: color,
    );
  }
}

/// A merged or closed pull request: what that means for its branch, and
/// Clean up… (Not now hides the offer for this chat; the menu keeps it).
class _Done extends StatelessWidget {
  const new(this.cp);

  final ChatPull cp;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = cp.pull!;
    final merged = p.item.state == 'merged';
    final code = theme.code(t.text, size: 11.5);
    final offer =
        cp.daemon.daemonApi >= cleanUpApi &&
        !cleanUpLater.value.contains(cp.chat.id);
    final wt = cp.chat.worktree != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: box(
        merged ? t.subagentBorder : t.borderSubtle,
        fill: merged ? t.subagentTint : t.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text.rich(
            TextSpan(
              children: merged
                  ? [
                      const TextSpan(text: 'Merged into '),
                      TextSpan(text: p.base, style: code),
                      TextSpan(
                        text: offer && wt
                            ? ". This chat's worktree and branch aren't "
                                  'needed any more.'
                            : '.',
                      ),
                    ]
                  : [
                      const TextSpan(text: 'Closed without merging.'),
                      if (p.commits > 0) ...[
                        TextSpan(
                          text:
                              ' Its ${p.commits} '
                              'commit${p.commits == 1 ? '' : 's'} '
                              '${p.commits == 1 ? 'stays' : 'stay'} on ',
                        ),
                        TextSpan(text: p.head, style: code),
                        const TextSpan(text: '.'),
                      ],
                    ],
            ),
            style: theme.ui(t.text, size: 12.5),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (offer)
                Button(
                  label: 'Clean up…',
                  kind: merged ? ButtonKind.primary : ButtonKind.secondary,
                  onPressed: () =>
                      showCleanUp(context, cp.daemon, cp.chat, pull: p),
                ),
              if (offer && merged)
                LinkText(
                  'Not now',
                  size: 12,
                  tooltip: "The widget's menu keeps Clean up…",
                  onTap: () =>
                      cleanUpLater.value = {...cleanUpLater.value, cp.chat.id},
                ),
              if (!merged && p.item.url.isNotEmpty)
                LinkText(
                  'Reopen on GitHub',
                  size: 12,
                  onTap: () => openWeb(p.item.url),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
