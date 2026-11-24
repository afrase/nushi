import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/checks_watch.dart';
import 'package:nushi/cleanup_dialog.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/markdown.dart' show openWeb;
import 'package:nushi/menu.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_merge_dialog.dart';
import 'package:nushi/pull_merge_state.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A pull request's checks as a row's badge counts them (ADR 0117):
/// passed (neutral too) of the total, skipped ones in neither; null with
/// none, or once merged or closed.
({int passed, int total, int failed, int running})? badgeCounts(GitHubItem it) {
  if (it.state != 'open' || !it.hasCheckCounts()) return null;
  final c = it.checkCounts;
  final total = c.passed + c.failed + c.running;
  if (total == 0) return null;
  return (passed: c.passed, total: total, failed: c.failed, running: c.running);
}

/// The badge's dot: red with any failing, amber with any running, else
/// green.
Color badgeColor(
  Tokens t,
  ({int passed, int total, int failed, int running}) n,
) => n.failed > 0
    ? t.crashed
    : n.running > 0
    ? t.needs
    : t.done;

/// The badge's face: its dot, [dot] across, and passed/total in code
/// type of [size] (the phone's sheet draws it a size up).
Widget badgeFace(
  NushiTheme theme,
  ({int passed, int total, int failed, int running}) n, {
  double dot = 7,
  double size = 11.5,
}) => Row(
  mainAxisSize: MainAxisSize.min,
  spacing: 5,
  children: [
    CheckDot(badgeColor(theme.t, n), size: dot),
    Text(
      '${n.passed}/${n.total}',
      style: theme.code(theme.t.textSecondary, size: size),
    ),
  ],
);

/// The checks' state as words: "2 of 3 checks passed", "Checks running",
/// "1 check failing" (the transcript's card).
String checksSentence(({int passed, int total, int failed, int running}) n) {
  if (n.failed > 0) {
    return '${n.failed} check${n.failed == 1 ? '' : 's'} failing';
  }
  if (n.running > 0) return 'Checks running';
  return '${n.passed} of ${n.total} checks passed';
}

/// Whether GitHub says [it] can merge now, as the daemon's clearToMerge
/// reads its merge state (internal/features/github/merge.go): "unstable"
/// is checks not passing that nothing requires, so it's ready too.
bool itemReady(GitHubItem it) =>
    it.state == 'open' &&
    !it.draft &&
    switch (it.mergeState) {
      'clean' || 'has_hooks' || 'unstable' => true,
      _ => false,
    };

/// What keeps open [it] from merging, as a row's Merge… says it while off
/// (ADR 0117): a block of [blockWords], from its draft flag and GitHub's
/// merge state alone, since a row's item has nothing more (which checks
/// are required, the base's rules); null once [itemReady].
String? itemBlock(GitHubItem it) => itemReady(it)
    ? null
    : it.draft
    ? 'draft'
    : switch (it.mergeState) {
        'dirty' => 'conflicts',
        'behind' => 'behind',
        'blocked' => 'rules',
        _ => 'unknown',
      };

/// [block] of [itemBlock] in a word, for Merge…'s detail.
String _blockWord(String block) => switch (block) {
  'rules' => 'blocked',
  'unknown' => 'checking',
  _ => block,
};

/// Whether a merged pull request of [cp]'s offers Clean up… (ADR 0063):
/// no clean-up already started.
bool offersCleanUp(ChatPull cp) => !CleanUpJob.of(cp.chat).started;

/// The row's one cue under its title (ADR 0117), the first that applies:
/// merged (with Clean up… while offered), closed without merging, changes
/// requested, open threads, new comments, ready to merge.
({String words, Color color, VoidCallback? cleanUp})? rowCue(
  BuildContext context,
  ChatPull cp,
  GitHubLink link,
  GitHubItem it,
) {
  final t = NushiTheme.of(context).t;
  switch (it.state) {
    case 'merged':
      return (
        words: it.base.isEmpty ? 'Merged' : 'Merged into ${it.base}',
        color: t.textMuted,
        cleanUp: offersCleanUp(cp)
            ? () => cleanUpPull(context, cp, link)
            : null,
      );
    case 'closed':
      return (
        words: 'Closed without merging',
        color: t.textMuted,
        cleanUp: null,
      );
  }
  if (it.review == 'changes_requested') {
    return (words: 'changes requested', color: t.crashed, cleanUp: null);
  }
  if (it.unresolved > 0) {
    final n = it.unresolved;
    return (
      words: '$n thread${n == 1 ? '' : 's'}',
      color: t.needs,
      cleanUp: null,
    );
  }
  final unread = cp.unreadOf(link);
  if (unread > 0) {
    return (
      words: '$unread new comment${unread == 1 ? '' : 's'}',
      color: t.link,
      cleanUp: null,
    );
  }
  if (itemReady(it)) {
    return (words: 'Ready to merge', color: t.done, cleanUp: null);
  }
  return null;
}

/// The chat's branch: its worktree's, else the folder's as found.
String chatBranch(ChatPull cp) =>
    cp.chat.worktree?.branch ?? cp.found?.branch ?? '';

/// The chat's pull requests other than [link] still open on its branch
/// (ADR 0117): while there are any, Clean up… on [link] takes only its
/// branch on GitHub.
List<int> openOnBranch(ChatPull cp, GitHubLink link) {
  final branch = chatBranch(cp);
  if (branch.isEmpty) return const [];
  return [
    for (final l in cp.links)
      if (pullKey(l) != pullKey(link))
        if (cp.itemOf(l) case final it?
            when it.state == 'open' && it.head == branch)
          l.number,
  ];
}

/// Clean up… on [link]: read whole first, for its branch (ADR 0063).
Future<void> cleanUpPull(
  BuildContext context,
  ChatPull cp,
  GitHubLink link,
) async {
  final whole = await cp.whole(context, link);
  if (whole == null || !context.mounted) return;
  await showCleanUp(
    context,
    cp.daemon,
    cp.chat,
    pull: whole,
    openOnBranch: openOnBranch(cp, link),
    branch: chatBranch(cp),
  );
}

/// The ⋯ menu of a pull request's row (and the right-click of the
/// transcript's card): Open on GitHub, Copy link, View changes, Merge…,
/// Send open threads to agent, Ready for review on GitHub, Clean up…,
/// Unlink.
List<MenuEntry> pullRowMenu(
  BuildContext context,
  ChatPull cp,
  GitHubLink link,
  GitHubItem? it, {
  required VoidCallback onShow,
}) {
  final url = it?.url ?? '';
  final block = it == null ? null : itemBlock(it);
  final open = it?.state == 'open';
  final done = it?.state == 'merged' || it?.state == 'closed';
  return [
    if (url.isNotEmpty)
      MenuEntry('Open on GitHub', onPick: () => openWeb(context, url)),
    MenuEntry(
      'Copy link',
      onPick: () => unawaited(
        Clipboard.setData(
          ClipboardData(
            text: url.isNotEmpty
                ? url
                : 'https://${link.host}/${link.repo}/pull/${link.number}',
          ),
        ),
      ),
    ),
    MenuEntry(
      'View changes',
      tooltip: 'Its Pull request tab, at its files',
      onPick: () {
        cp.pick(link, files: true);
        onShow();
      },
    ),
    if (open && it != null)
      MenuEntry(
        'Merge…',
        detail: block == null ? '' : _blockWord(block),
        tooltip: block == null
            ? 'Asks you first'
            : blockSentence([blockWords(block, base: it.base)]),
        onPick: block == null
            ? () => unawaited(_merge(context, cp, link))
            : null,
      ),
    if (open && (it?.unresolved ?? 0) > 0)
      MenuEntry(
        'Send open threads to agent',
        onPick: () => unawaited(_address(context, cp, link, it!)),
      ),
    if (open && (it?.draft ?? false) && url.isNotEmpty)
      MenuEntry(
        'Ready for review on GitHub',
        onPick: () => openWeb(context, url),
      ),
    if (done)
      MenuEntry(
        'Clean up…',
        onPick: CleanUpJob.of(cp.chat).running
            ? null
            : () => unawaited(cleanUpPull(context, cp, link)),
      ),
    MenuEntry(
      'Unlink',
      tooltip: "It isn't found or opened again for this chat",
      onPick: () => tryOrShow(context, () => cp.unlink(link)),
    ),
  ];
}

/// Merge…: the pull request read whole, then ADR 0069's dialog for the
/// method picked last.
Future<void> _merge(BuildContext context, ChatPull cp, GitHubLink link) async {
  final p = await cp.whole(context, link);
  if (p == null || !context.mounted) return;
  final view = mergeView(p);
  if (view == null || view.step != MergeStep.merge) {
    showError(
      context,
      "It can't merge now${view == null ? '' : ': ${view.heading}'}",
    );
    return;
  }
  await confirmMerge(
    context,
    cp.daemon,
    p,
    MergeAct.merge,
    method: pickedMethod(p),
    onDone: cp.again,
  );
}

/// Send open threads to agent (Address): the threads as reply cards in
/// the chat's box.
Future<void> _address(
  BuildContext context,
  ChatPull cp,
  GitHubLink link,
  GitHubItem it,
) async {
  final p = await cp.whole(context, link);
  if (p == null || !context.mounted) return;
  await toAgent(
    context,
    cp.daemon,
    it,
    chat: cp.chat,
    replies: () async => threadReplies(p),
  );
}

/// A pull request's CI badge: a dot (red with any failing, amber with any
/// running, else green) and passed/total; its click opens the checks'
/// popover: In progress, Passed, Failed, then Fix checks, Show checks and
/// Open on GitHub.
class ChecksBadge extends StatelessWidget {
  const new(this.cp, this.link, this.item, {required this.onShow, super.key});

  final ChatPull cp;
  final GitHubLink link;
  final GitHubItem item;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = badgeCounts(item);
    if (n == null) return const SizedBox.shrink();
    final skipped = item.checkCounts.skipped;
    Widget count(String label, int v, Color c) => Row(
      children: [
        CheckDot(c),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.ui(t.text, size: 12))),
        Text('$v', style: theme.code(t.textSecondary, size: 12)),
      ],
    );
    return Menu(
      filter: false,
      entries: [
        MenuEntry.heading(
          'Checks · ${n.total + skipped}'
          '${skipped > 0 ? ' ($skipped skipped)' : ''}',
        ),
        MenuEntry.row((_) => count('In progress', n.running, t.needs)),
        MenuEntry.row((_) => count('Passed', n.passed, t.done)),
        MenuEntry.row((_) => count('Failed', n.failed, t.crashed)),
        if (n.failed > 0)
          MenuEntry(
            'Fix checks',
            tooltip: "Each failed check as a reply card in the chat's box",
            onPick: () => unawaited(_fix(context)),
          ),
        MenuEntry(
          'Show checks',
          onPick: () {
            cp.pick(link, checks: true);
            onShow();
          },
        ),
        if (item.url.isNotEmpty)
          MenuEntry(
            'Open on GitHub',
            onPick: () => openWeb(context, '${item.url}/checks'),
          ),
      ],
      builder: (context, open) => Tap(
        onTap: open,
        tooltip: 'Checks: ${checksSentence(n)}',
        radius: NushiTheme.tag,
        padding: _badgePadding,
        child: badgeFace(theme, n),
      ),
    );
  }

  Future<void> _fix(BuildContext context) async {
    final p = await cp.whole(context, link);
    if (p == null || !context.mounted) return;
    await toAgent(
      context,
      cp.daemon,
      item,
      chat: cp.chat,
      replies: () => checkReplies(cp.daemon, item.ref, p),
    );
    // Acted on: the chat no longer needs you for it (ADR 0138).
    ChecksWatch.of(cp.daemon).seen(cp.chat);
  }
}

/// The badge's padding, round its face.
const _badgePadding = EdgeInsets.symmetric(horizontal: 5, vertical: 2);

/// A checks' dot of [color], [size] across.
class CheckDot extends StatelessWidget {
  const new(this.color, {super.key, this.size = 7});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// One of a chat's pull requests as a row of the PR widget (ADR 0117),
/// 44 tall: the state's icon, the title, the CI badge; under the title
/// `#n`, `+adds −dels` and one cue. Its ⋯ shows under the pointer or
/// focus (its room kept, so nothing moves). A click opens the Pull request
/// tab on it ([onShow]). Without [menu] (the header chip's hover) it has
/// no ⋯ and no badge's popover.
class PullRow extends StatefulWidget {
  const new(
    this.cp,
    this.link, {
    required this.onShow,
    super.key,
    this.menu = true,
  });

  final ChatPull cp;
  final GitHubLink link;
  final VoidCallback onShow;
  final bool menu;

  /// A row's height.
  static const height = 44.0;

  @override
  State<PullRow> createState() => _PullRowState();
}

class _PullRowState extends State<PullRow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final cp = widget.cp;
    final l = widget.link;
    final it = cp.itemOf(l);
    final muted = theme.ui(t.textMuted, size: 11.5);
    final cue = it == null ? null : rowCue(context, cp, l, it);
    final menu = it == null
        ? const <MenuEntry>[]
        : pullRowMenu(context, cp, l, it, onShow: widget.onShow);
    final sub = <InlineSpan>[
      TextSpan(text: '#${l.number}', style: theme.code(t.textMuted, size: 11)),
      if (it != null && (it.additions > 0 || it.deletions > 0)) ...[
        const TextSpan(text: ' '),
        TextSpan(text: '+${it.additions}', style: theme.code(t.done, size: 11)),
        const TextSpan(text: ' '),
        TextSpan(
          text: '−${it.deletions}',
          style: theme.code(t.crashed, size: 11),
        ),
      ],
      if (cue != null) ...[
        TextSpan(text: ' · ', style: muted),
        TextSpan(text: cue.words, style: theme.ui(cue.color, size: 11.5)),
      ],
    ];
    final row = SizedBox(
      height: PullRow.height,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ItemIcon(it, pull: true, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  it?.title ?? '${l.repo}#${l.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(children: sub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (cue?.cleanUp case final clean?) ...[
                      Text(' · ', style: muted),
                      LinkText('Clean up…', size: 11.5, onTap: clean),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (it != null && badgeCounts(it) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 4),
              child: widget.menu
                  ? ChecksBadge(cp, l, it, onShow: widget.onShow)
                  // The badge without its popover (the header chip's hover).
                  : Padding(
                      padding: _badgePadding,
                      child: badgeFace(theme, badgeCounts(it)!),
                    ),
            ),
          if (widget.menu)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Visibility.maintain(
                visible: _hover || _focus,
                child: MenuIcon.line(
                  LineIcon.more,
                  size: 14,
                  padding: 3,
                  tooltip: 'Pull request',
                  entries: menu,
                ),
              ),
            ),
        ],
      ),
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focus = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Menu(
          filter: false,
          entries: menu,
          builder: (context, open) => Tap(
            onTap: () {
              cp.pick(l);
              widget.onShow();
            },
            onSecondaryTapUp: widget.menu && menu.isNotEmpty
                ? (d) => open(d.localPosition)
                : null,
            tooltip: it == null ? '' : '${l.repo}#${l.number}',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// A chat's pull requests folded into one line, as the widget's summary
/// says several: "3 open, 1 merged" and the worst checks.
Widget pullsFolded(NushiTheme theme, List<GitHubItem?> items) {
  final t = theme.t;
  final counts = <String, int>{};
  for (final it in items) {
    final s = it?.state ?? 'open'; // a draft is open
    counts[s] = (counts[s] ?? 0) + 1;
  }
  final words = [
    for (final s in ['open', 'merged', 'closed'])
      if (counts[s] case final n?) '$n $s',
  ].join(', ');
  var failed = 0;
  var running = 0;
  var passed = false;
  for (final it in items) {
    if (it == null) continue;
    final n = badgeCounts(it);
    if (n == null) continue;
    failed += n.failed;
    running += n.running;
    passed = true;
  }
  final worst = failed > 0
      ? ('$failed failing', t.crashed)
      : running > 0
      ? ('$running running', t.needs)
      : passed
      ? ('passing', t.done)
      : null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      Flexible(
        child: Text(
          words,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(t.textMuted, size: 12),
        ),
      ),
      if (worst case (final w, final c)) ...[
        CheckDot(c),
        Text(w, style: theme.code(t.textSecondary, size: 11.5)),
      ],
    ],
  );
}
