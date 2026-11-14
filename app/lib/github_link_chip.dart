import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';

/// Where a message's GitHub links become chips (ADR 0117): the daemon to
/// ask, and the chat whose transcript it is (its Link to this chat), if
/// any. Chips show only under one; elsewhere a link stays a link.
class GitHubLinks extends InheritedWidget {
  const new({
    required this.daemon,
    required super.child,
    super.key,
    this.chat,
    this.onShow,
    this.onLink,
    this.onTapChip,
    this.onPull,
  });

  /// Opens the chat's Pull request tab (a live card's click).
  final VoidCallback? onPull;

  final Daemon daemon;
  final ChatState? chat;

  /// Shows the item in the GitHub view.
  final void Function(GitHubAddress a)? onShow;

  /// Links a pull request to the chat (Link to this chat).
  final Future<void> Function(GitHubAddress a, GitHubItem it)? onLink;

  /// What a tap does in the place of opening the address (the phone: the
  /// card as a sheet).
  final void Function(BuildContext context, GitHubAddress a)? onTapChip;

  static GitHubLinks? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GitHubLinks>();

  @override
  bool updateShouldNotify(GitHubLinks old) =>
      daemon != old.daemon || chat != old.chat;
}

/// Whether [text] may hold a link [githubLink] makes a chip of: an
/// address of a pull request or an issue.
bool mayHoldGitHubLinks(String text) =>
    text.contains('/pull/') || text.contains('/issues/');

/// A message's link as a chip or as words with the hover card, when it's
/// a pull request's or an issue's address on a host Nushi knows and a
/// [GitHubLinks] is above; else null (a link as any). [style] is the
/// text's where the link is; [typed] says it's in the user's bubble.
Widget? githubLink(
  BuildContext context,
  String href,
  String text,
  TextStyle style, {
  required bool typed,
  required void Function() onOpen,
}) {
  final scope = GitHubLinks.of(context);
  final a = githubAddress(href);
  if (scope == null || a == null) return null;
  if (!GitHubItems.of(scope.daemon).knows(a.host)) return null;
  return namesItem(text, a, href)
      ? GitHubLinkChip(a, typed: typed, onOpen: onOpen)
      : GitHubLinkWords(a, text: text, style: style, onOpen: onOpen);
}

/// The right-click menu of an item's chip or link: Open on GitHub, Copy
/// link, Show in GitHub view, and Link to this chat for a pull request the
/// chat hasn't.
List<MenuEntry> githubLinkMenu(
  GitHubLinks scope,
  GitHubAddress a,
  GitHubLook look,
  VoidCallback onOpen,
) {
  final chat = scope.chat;
  final it = look.item;
  final linked =
      chat?.pulls.any(
        (p) =>
            p.host == a.host &&
            p.repo.toLowerCase() == a.repo.toLowerCase() &&
            p.number == a.number,
      ) ??
      true;
  return [
    MenuEntry('Open on GitHub', onPick: onOpen),
    MenuEntry(
      'Copy link',
      onPick: () => unawaited(Clipboard.setData(ClipboardData(text: a.url))),
    ),
    if (scope.onShow case final show?)
      MenuEntry('Show in GitHub view', onPick: () => show(a)),
    if (a.pull && !linked && scope.onLink != null)
      MenuEntry(
        'Link to this chat',
        tooltip: it == null ? 'Once GitHub has said what it is' : '',
        onPick: it == null || !it.pull
            ? null
            : () => unawaited(scope.onLink!(a, it)),
      ),
  ];
}

/// A pull request's or an issue's address in a message as a chip: its
/// state's icon, `owner/repo#n` (from the address) and the title; asked
/// for once as it's first built, again on hover past a minute.
class GitHubLinkChip extends StatefulWidget {
  const new(
    this.address, {
    required this.typed,
    required this.onOpen,
    super.key,
  });

  final GitHubAddress address;

  /// In the user's bubble: its own fill.
  final bool typed;
  final VoidCallback onOpen;

  /// The chip's widest.
  static const maxWidth = 420.0;

  @override
  State<GitHubLinkChip> createState() => _GitHubLinkChipState();
}

class _GitHubLinkChipState extends State<GitHubLinkChip> {
  GitHubItems? _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GitHubLinks.of(context);
    if (scope == null) return;
    final items = GitHubItems.of(scope.daemon);
    if (items != _items) {
      _items = items;
      items.want(widget.address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final scope = GitHubLinks.of(context)!;
    final items = GitHubItems.of(scope.daemon);
    final a = widget.address;
    return ListenableBuilder(
      listenable: items,
      builder: (context, _) {
        final look = items.look(a);
        final it = look.item;
        final ink = widget.typed ? t.userBandText : t.text;
        final chip = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: GitHubLinkChip.maxWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemIcon(it, pull: a.pull, size: 13),
              const SizedBox(width: 5),
              Text(
                a.short,
                maxLines: 1,
                style: theme.code(
                  widget.typed ? t.userBandMuted : t.textSecondary,
                  size: 11.5,
                ),
              ),
              if (it != null && it.title.isNotEmpty) ...[
                Text(' · ', style: theme.ui(t.textMuted, size: 12.5)),
                Flexible(
                  child: Text(
                    it.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(ink, size: 12.5, weight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        );
        return Menu(
          filter: false,
          entries: githubLinkMenu(scope, a, look, widget.onOpen),
          builder: (context, open) => HoverCard(
            onShow: () =>
                items.want(a, quiet: false, fresh: const Duration(minutes: 1)),
            card: (_) => ListenableBuilder(
              listenable: items,
              builder: (_, _) => GitHubCard(a, items.look(a)),
            ),
            child: _ChipTap(
              onTap: scope.onTapChip == null
                  ? widget.onOpen
                  : () => scope.onTapChip!(context, a),
              onSecondaryTapUp: (d) => open(d.localPosition),
              fill: widget.typed ? t.userBandCodeBlock : t.raised,
              child: chip,
            ),
          ),
        );
      },
    );
  }
}

/// A link to a pull request or an issue with words of its own: the words
/// as a link, with the item's hover card.
class GitHubLinkWords extends StatefulWidget {
  const new(
    this.address, {
    required this.text,
    required this.style,
    required this.onOpen,
    super.key,
  });

  final GitHubAddress address;
  final String text;
  final TextStyle style;
  final VoidCallback onOpen;

  @override
  State<GitHubLinkWords> createState() => _GitHubLinkWordsState();
}

class _GitHubLinkWordsState extends State<GitHubLinkWords> {
  @override
  Widget build(BuildContext context) {
    final scope = GitHubLinks.of(context)!;
    final items = GitHubItems.of(scope.daemon);
    final a = widget.address;
    return Menu(
      filter: false,
      entries: githubLinkMenu(scope, a, items.look(a), widget.onOpen),
      builder: (context, open) => HoverCard(
        onShow: () =>
            items.want(a, quiet: false, fresh: const Duration(minutes: 1)),
        card: (_) => ListenableBuilder(
          listenable: items,
          builder: (_, _) => GitHubCard(a, items.look(a)),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: scope.onTapChip == null
                ? widget.onOpen
                : () => scope.onTapChip!(context, a),
            onSecondaryTapUp: (d) => open(d.localPosition),
            child: Text(widget.text, style: widget.style),
          ),
        ),
      ),
    );
  }
}

/// A chip's press: its fill, the hover tint over it under the pointer.
/// Not a [Tap]: a chip sits in a line of text, so it takes no touch
/// target's height, and a tap on the phone is its own.
class _ChipTap extends StatefulWidget {
  const new({
    required this.onTap,
    required this.onSecondaryTapUp,
    required this.fill,
    required this.child,
  });

  final VoidCallback onTap;
  final GestureTapUpCallback onSecondaryTapUp;
  final Color fill;
  final Widget child;

  @override
  State<_ChipTap> createState() => _ChipTapState();
}

class _ChipTapState extends State<_ChipTap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 1, 6, 1),
          decoration: BoxDecoration(
            color: _hover
                ? Color.alphaBlend(t.hover, widget.fill)
                : widget.fill,
            borderRadius: BorderRadius.circular(NushiTheme.tag),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
