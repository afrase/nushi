import 'package:flutter/material.dart';
import 'package:nushi/chat.dart' show clock;
import 'package:nushi/cleanup_dialog.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/pull_header.dart';
import 'package:nushi/pull_link.dart';
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
                githubAgo(it.updatedMs.toInt(), clock()),
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
            _Legend(p),
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
    final t = NushiTheme.of(context).t;
    final it = p.item;
    final open = p.threads.where((x) => !x.resolved).length;
    final comments = commentTimes(p).length;
    final block = mergeBlockers(p);
    return [
      if (it.draft && p.reviewers.isEmpty)
        _Row(
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
        _Row(
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
          'clean' || 'has_hooks' when p.mergeable != 'conflicting' => _Row(
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
          'unknown' || '' when p.mergeable != 'conflicting' => _Row(
            icon: Icon(Icons.schedule, size: 14, color: t.textMuted),
            label: 'Checking whether it can merge…',
            muted: true,
          ),
          _ => _Row(
            icon: Icon(Icons.lock_outline, size: 14, color: t.needs),
            label: 'Merge blocked',
            color: t.needs,
            keepLabel: true,
            value: block.isEmpty ? mergeWords(t, p).$1 : block.join(', '),
          ),
        },
      _Row(
        icon: Icon(Icons.chat_bubble_outline, size: 13, color: t.textMuted),
        label: comments == 0
            ? 'No comments'
            : '$comments comment${comments == 1 ? '' : 's'}',
        trailing: unread > 0 ? _New(unread) : null,
      ),
    ];
  }

  Widget _reviewer(BuildContext context, GitHubReviewer r) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final name = r.team ? '@${r.login}' : r.login;
    if (r.state == 'requested') {
      return _Row(
        icon: _Ring(t.textMuted),
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
    return _Row(
      icon: Avatar(name: r.login, id: r.login, size: 17),
      label: name,
      value: words,
      valueColor: color,
    );
  }
}

/// What keeps an open pull request from merging, in a word each: its
/// checks, its review, its threads, conflicts, being behind its base.
List<String> mergeBlockers(GitHubPull p) => [
  if (p.checks.any((c) => c.failed) ||
      p.checks.any((c) => c.state == 'pending'))
    'checks',
  if (p.item.review == 'changes_requested' ||
      p.item.review == 'review_required' ||
      p.reviewers.any((r) => r.state == 'requested'))
    'review',
  if (p.threads.any((x) => !x.resolved)) 'threads',
  if (p.mergeable == 'conflicting' || p.mergeState == 'dirty') 'conflicts',
  if (p.mergeState == 'behind') 'behind ${p.base}',
];

/// A pull request's checks as one bar: failing red, running amber, passed
/// green, the rest grey, each as wide as its count.
class ChecksBar extends StatelessWidget {
  const new(this.pull, {super.key, this.height = 6});

  final GitHubPull pull;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final n = countChecks(pull);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 1,
          children: [
            for (final (count, color) in [
              (n.failing, t.crashed),
              (n.running, t.needs),
              (n.passed, t.done),
              (n.other, t.borderStrong),
            ])
              if (count > 0)
                Expanded(
                  flex: count,
                  child: ColoredBox(color: color),
                ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const new(this.pull);

  final GitHubPull pull;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = countChecks(pull);
    if (n.failing + n.running + n.other == 0) {
      return Text(
        n.passed == 1 ? 'The check passed' : 'All ${n.passed} checks passed',
        style: theme.ui(t.done, size: 12),
      );
    }
    Widget part(int count, String words, Color color, {bool dot = true}) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        if (dot)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        Text(
          '$count $words',
          style: theme.ui(
            words == 'failed' ? t.crashed : t.textSecondary,
            size: 12,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        if (n.failing > 0) part(n.failing, 'failed', t.crashed),
        if (n.running > 0) part(n.running, 'running', t.needs),
        if (n.passed > 0) part(n.passed, 'passed', t.done),
        if (n.other > 0) part(n.other, 'skipped', t.textMuted, dot: false),
      ],
    );
  }
}

/// One of the widget's rows: an icon (or avatar), what, and a value or a
/// button at its right.
class _Row extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.trailing,
    this.color,
    this.muted = false,
    this.bold = false,
    this.tip = '',
    this.keepLabel = false,
  });

  final String tip;

  /// The label whole, the value cut instead.
  final bool keepLabel;
  final Widget icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final Color? color;
  final bool muted;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.ui(
        color ?? (muted ? t.textSecondary : t.text),
        size: 12.5,
        weight: bold ? FontWeight.w600 : null,
      ),
    );
    // A value at most 130 wide, else the label's room ([keepLabel]).
    Widget valueText(String v) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: keepLabel ? double.infinity : 130),
      child: Tooltip(
        message: tip,
        child: Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.ui(valueColor ?? t.textMuted, size: 12),
        ),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 26),
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: icon)),
          const SizedBox(width: 8),
          if (keepLabel) labelText else Expanded(child: labelText),
          if (value case final v?) ...[
            const SizedBox(width: 8),
            if (keepLabel) Expanded(child: valueText(v)) else valueText(v),
          ],
          ?trailing,
        ],
      ),
    );
  }
}

/// A dashed-looking ring: someone asked, not yet answered.
class _Ring extends StatelessWidget {
  const new(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.3),
    ),
  );
}

/// "2 new": comments since the tab last showed them.
class _New extends StatelessWidget {
  const new(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$n new', style: theme.ui(t.accentInk, size: 11.5)),
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
