import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/jira_people.dart' show initials, personColor;
import 'package:nushi/line_icons.dart';
import 'package:nushi/theme/theme.dart';

/// An item's state as GitHub draws it (ADR 0117): its icon and color. A
/// pull request open green (a draft grey), merged violet, closed red; an
/// issue open green, closed as completed violet, as not planned grey.
/// Without [it], [pull]'s open icon, muted.
(LineIcon, Color) itemLook(Tokens t, GitHubItem? it, {required bool pull}) {
  if (it == null) {
    return (pull ? LineIcon.pullOpen : LineIcon.issueOpen, t.textMuted);
  }
  if (it.pull) {
    return switch (it.state) {
      'merged' => (LineIcon.pullMerged, t.subagentAccent),
      'closed' => (LineIcon.pullClosed, t.crashed),
      _ when it.draft => (LineIcon.pullDraft, t.textMuted),
      _ => (LineIcon.pullOpen, t.done),
    };
  }
  return switch (it.state) {
    'closed' when it.stateReason == 'not_planned' => (
      LineIcon.issueNotPlanned,
      t.textMuted,
    ),
    'closed' => (LineIcon.issueDone, t.subagentAccent),
    _ => (LineIcon.issueOpen, t.done),
  };
}

/// An item's state's icon, [size] square.
class ItemIcon extends StatelessWidget {
  const new(this.item, {required this.pull, super.key, this.size = 14});

  final GitHubItem? item;
  final bool pull;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = itemLook(NushiTheme.of(context).t, item, pull: pull);
    return icon.view(size: size, color: color);
  }
}

/// An item's state as a pill's word: Open, Draft, Merged, Closed, Not
/// planned.
String stateWord(GitHubItem it) => switch (it.state) {
  'merged' => 'Merged',
  'closed' when !it.pull && it.stateReason == 'not_planned' => 'Not planned',
  'closed' => 'Closed',
  _ => it.draft ? 'Draft' : 'Open',
};

/// What the hover card, a row and the transcript's card show of a pull
/// request's size: `+adds −dels`.
Widget diffSize(NushiTheme theme, GitHubItem it, {double size = 11.5}) {
  final t = theme.t;
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '+${it.additions}',
          style: theme.code(t.done, size: size),
        ),
        const TextSpan(text: ' '),
        TextSpan(
          text: '−${it.deletions}',
          style: theme.code(t.crashed, size: size),
        ),
      ],
    ),
    maxLines: 1,
  );
}

/// "3 files", "1 file".
String filesWords(int n) => '$n file${n == 1 ? '' : 's'}';

/// A login as Nushi draws people: initials on the person's color.
class LoginAvatar extends StatelessWidget {
  const new(this.login, {super.key, this.size = 16});

  final String login;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: personColor(t, login),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(login).characters.take(1).toString().toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: theme.ui(
          t.monogramText,
          size: size * 0.55,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The hover card of a pull request's or an issue's link (ADR 0117): the
/// state pill, `owner/repo #n`, its age; the title (two lines at most);
/// the author and the size (or an issue's comments). No buttons. With
/// nothing to show it says why: GitHub doesn't show it to the account,
/// sign in, couldn't ask (with the last known and its age), or asking.
class GitHubCard extends StatelessWidget {
  const new(this.address, this.look, {super.key, this.width = 320});

  final GitHubAddress address;
  final GitHubLook look;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: floatBox(t, radius: NushiTheme.card),
      child: GitHubCardBody(address, look),
    );
  }
}

/// [GitHubCard]'s inside, for a card or a sheet.
class GitHubCardBody extends StatelessWidget {
  const new(this.address, this.look, {super.key});

  final GitHubAddress address;
  final GitHubLook look;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final a = address;
    final muted = theme.ui(t.textMuted, size: 12);
    final it = look.item;
    final head = '${a.repo} #${a.number}';
    if (it == null) {
      final why = look.unseen
          ? "${a.host} doesn't show this to your account: a private "
                'repository, or none by that name.'
          : look.signIn
          ? 'Sign in to GitHub to see it: Settings › GitHub.'
          : look.error != null
          ? "Couldn't ask GitHub: ${look.error}"
          : 'Asking GitHub…';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Row(
            spacing: 6,
            children: [
              ItemIcon(null, pull: a.pull),
              Flexible(
                child: Text(
                  head,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.code(t.textSecondary, size: 12),
                ),
              ),
            ],
          ),
          Text(why, style: muted),
        ],
      );
    }
    final now = clock();
    final when = it.createdMs > 0 ? it.createdMs : it.updatedMs;
    final at = look.at;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          spacing: 8,
          children: [
            ItemStatePill(it),
            Expanded(
              child: Text(
                head,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.code(t.textSecondary, size: 12),
              ),
            ),
            if (when > 0)
              Text(
                agoShort(
                  now.difference(
                    DateTime.fromMillisecondsSinceEpoch(when.toInt()),
                  ),
                ),
                style: muted,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          it.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(t.text, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 6,
          children: [
            LoginAvatar(it.author),
            Expanded(
              child: Text(
                it.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
            if (it.pull) ...[
              diffSize(theme, it),
              const SizedBox(width: 2),
              Text(filesWords(it.changedFiles), style: muted),
            ] else
              Text(
                '${it.comments} comment${it.comments == 1 ? '' : 's'}',
                style: muted,
              ),
          ],
        ),
        if (look.error != null && at != null) ...[
          const SizedBox(height: 8),
          Text(
            "Couldn't ask GitHub. As it was ${ago(now.difference(at), at)}.",
            style: muted,
          ),
        ],
      ],
    );
  }
}

/// An item's state as a pill: GitHub's icon and word on the state's soft
/// fill (ADR 0117: the hover card, the transcript's card).
class ItemStatePill extends StatelessWidget {
  const new(this.item, {super.key});

  final GitHubItem item;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (icon, fg) = itemLook(t, item, pull: item.pull);
    final bg = fg == t.done
        ? t.doneSoft
        : fg == t.crashed
        ? t.crashedSoft
        : fg == t.subagentAccent
        ? t.subagentTint
        : t.selected;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 1, 8, 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          icon.view(size: 13, color: fg),
          Text(
            stateWord(item),
            style: theme.ui(fg, size: 12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Shows [card] floating under [child] after the pointer has been on it
/// for 400 ms ([onShow] runs then), held while the pointer is on either.
class HoverCard extends StatefulWidget {
  const new({
    required this.child,
    required this.card,
    super.key,
    this.onShow,
    // design: a hover card's wait, as a tooltip's
    this.delay = const Duration(milliseconds: 400),
  });

  final Widget child;
  final WidgetBuilder card;
  final VoidCallback? onShow;
  final Duration delay;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  Timer? _wait;
  Timer? _leave;

  void _enter() {
    _leave?.cancel();
    if (_portal.isShowing) return;
    _wait ??= Timer(widget.delay, () {
      _wait = null;
      if (!mounted) return;
      widget.onShow?.call();
      _portal.show();
    });
  }

  // A moment's grace, so the pointer can cross the gap to the card.
  void _exit() {
    _wait?.cancel();
    _wait = null;
    _leave?.cancel();
    // design: a hover card's linger, as a tooltip's
    _leave = Timer(const Duration(milliseconds: 150), () {
      if (mounted && _portal.isShowing) _portal.hide();
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _leave?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, 4),
        child: Align(
          alignment: Alignment.topLeft,
          child: MouseRegion(
            onEnter: (_) => _enter(),
            onExit: (_) => _exit(),
            child: widget.card(context),
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => _enter(),
        onExit: (_) => _exit(),
        child: widget.child,
      ),
    ),
  );
}
