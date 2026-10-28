import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_filters.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// An inbox's section: its id (as the daemon's `wide` names it), title,
/// items, how many GitHub found, and how many more it has without the
/// date.
typedef Section = ({
  String id,
  String title,
  List<GitHubItem> items,
  int total,
  int older,
});

/// [inbox]'s sections in the order their cards were dragged into (one
/// not dragged yet goes last).
List<Section> sectionsOf(ListGitHubInboxResponse? inbox) {
  final i = inbox;
  if (i == null) return const [];
  final all = <Section>[
    (
      id: 'review',
      title: 'Review requested',
      items: i.review,
      total: i.reviewTotal,
      older: i.reviewOlder,
    ),
    (
      id: 'mine',
      title: 'My pull requests',
      items: i.mine,
      total: i.mineTotal,
      older: i.mineOlder,
    ),
    (
      id: 'assigned',
      title: 'Assigned issues',
      items: i.assigned,
      total: i.assignedTotal,
      older: i.assignedOlder,
    ),
  ];
  final saved = githubCardOrder.value;
  final ids = [for (final s in all) s.id];
  return [
    for (final id in [
      ...saved.where(ids.contains),
      ...ids.where((id) => !saved.contains(id)),
    ])
      all.firstWhere((s) => s.id == id),
  ];
}

/// The items the keys move through: the open cards', in their order.
List<GitHubItem> visibleItems(List<Section> sections) => [
  for (final s in sections)
    if (!githubCollapsed.value.contains(s.id)) ...s.items,
];

/// The inbox as cards, as the Jira view's statuses: one a section, each
/// collapsing by its title and dragged by its title row into another
/// order (both remembered). Review requested's card has [whose] on its
/// title row. A card the date leaves items out of says how many, with
/// Show ([onOlder]).
class InboxCards extends StatelessWidget {
  const new({
    required this.daemon,
    required this.sections,
    required this.picked,
    required this.now,
    required this.days,
    required this.whose,
    required this.onOpen,
    required this.onOlder,
    required this.onHide,
    required this.startMenu,
    this.selectedRow,
    super.key,
  });

  final Daemon daemon;
  final List<Section> sections;
  final GitHubRef? picked;
  final DateTime now;

  /// The date filter's days (0: any time).
  final int days;
  final Widget whose;
  final ValueChanged<GitHubItem> onOpen;

  /// Shows the section's older items too.
  final ValueChanged<String> onOlder;

  /// Hides a repository (owner/name).
  final ValueChanged<String> onHide;

  /// The selected row's key, to scroll it into view.
  final GlobalKey? selectedRow;

  /// Takes the selected row's Start work menu (and its item), for ⌘⏎.
  final void Function(GitHubRef ref, OpenMenu open) startMenu;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final ids = [for (final s in sections) s.id];
    // The one row [selectedRow] keys (an item may be in two cards).
    final first = [
      for (final s in sections)
        for (final it in s.items)
          if (sameRef(it.ref, picked)) it,
    ].firstOrNull;
    final collapsed = githubCollapsed.value;
    return CardList(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      buildAll: true,
      onReorder: (from, to) => githubCardOrder.value = reordered(
        githubCardOrder.value,
        ids,
        from,
        to,
      ),
      children: [
        for (final (i, s) in sections.indexed)
          CardShell(
            key: ValueKey(s.id),
            index: i,
            open: !collapsed.contains(s.id),
            onToggle: () => githubCollapsed.value = collapsed.contains(s.id)
                ? ({...collapsed}..remove(s.id))
                : {...collapsed, s.id},
            title: Text(
              '${s.title}  '
              '${s.total > s.items.length ? '${s.items.length} of ' : ''}'
              '${s.total > s.items.length ? s.total : s.items.length}',
              style: theme.ui(
                t.textSecondary,
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
            trailing: s.id == 'review' ? whose : null,
            body: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final it in s.items)
                    ItemRow(
                      key:
                          (identical(it, first) ? selectedRow : null) ??
                          ValueKey('${s.id} ${it.id}'),
                      daemon: daemon,
                      item: it,
                      selected: sameRef(it.ref, picked),
                      now: now,
                      onOpen: () => onOpen(it),
                      onHide: () => onHide(it.ref.repo),
                      startMenu: (open) => startMenu(it.ref, open),
                    ),
                  if (s.items.isEmpty && s.older == 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                      child: Text(
                        'None',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    ),
                  if (s.older > 0 && days > 0)
                    OlderLine(
                      count: s.older,
                      days: days,
                      onShow: () => onOlder(s.id),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Whether [a] and [b] are the same item.
bool sameRef(GitHubRef a, GitHubRef? b) =>
    b != null && a.host == b.host && a.repo == b.repo && a.number == b.number;

/// A row of the inbox: the kind's icon in its state's color, the title,
/// and under it `owner/repo#123` muted (each cut on its own line, so
/// neither hides the other), the item's chats, and on the right in
/// columns of their own: the review decision, the checks, threads not
/// resolved (else comments), when it changed. Start work shows on hover
/// and on the selected row (⌘⏎ too); a right-click has it, the browser,
/// and Hide this repository.
class ItemRow extends StatefulWidget {
  const new({
    required this.daemon,
    required this.item,
    required this.selected,
    required this.now,
    required this.onOpen,
    required this.onHide,
    required this.startMenu,
    super.key,
  });

  final Daemon daemon;
  final GitHubItem item;
  final bool selected;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback onHide;

  /// Takes the row's Start work menu, for ⌘⏎ (when it's selected).
  final void Function(OpenMenu open) startMenu;

  @override
  State<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<ItemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = widget.item;
    final chats = chatsOnItem(widget.daemon, it.ref);
    final review = switch (it.review) {
      'approved' || 'changes_requested' => reviewWords(t, it.review),
      _ => null,
    };
    final checks = checksIcon(t, it.checks);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Menu(
        entries: [
          MenuEntry(
            'Start work',
            submenu: startEntries(context, widget.daemon, it),
          ),
          MenuEntry('Open in the browser', onPick: () => openWeb(it.url)),
          MenuEntry.divider,
          MenuEntry(
            'Hide this repository',
            detail: it.ref.repo,
            onPick: widget.onHide,
          ),
        ],
        builder: (context, open) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Tap(
            selected: widget.selected,
            onTap: widget.onOpen,
            onSecondaryTapUp: (d) => open(d.localPosition),
            padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
            child: Row(
              children: [
                Tooltip(
                  message: itemState(it),
                  child: Icon(
                    it.pull ? Icons.merge_type : Icons.adjust,
                    size: 14,
                    color: itemColor(t, it),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.text),
                      ),
                      Text(
                        '${it.ref.repo}#${it.ref.number}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.textMuted, size: 11.5),
                      ),
                    ],
                  ),
                ),
                if (chats.isNotEmpty) ChatMarks(widget.daemon, chats),
                _column(
                  20,
                  review == null
                      ? null
                      : Tooltip(
                          message: review.$1,
                          child: Icon(
                            Icons.rate_review_outlined,
                            size: 13,
                            color: review.$2,
                          ),
                        ),
                ),
                _column(
                  20,
                  checks == null
                      ? null
                      : Tooltip(
                          message: checks.$3,
                          child: Icon(checks.$1, size: 14, color: checks.$2),
                        ),
                ),
                _column(40, _talk(theme, it)),
                const SizedBox(width: 6),
                ItemAge(it.updatedMs.toInt(), now: widget.now),
                SizedBox(
                  width: 30,
                  child: _hover || widget.selected
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: _start(context),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _start(BuildContext context) => Menu(
    digits: true,
    entries: startEntries(context, widget.daemon, widget.item),
    builder: (context, open) {
      if (widget.selected) widget.startMenu(open);
      return IconTap(
        Icons.play_arrow_outlined,
        size: 15,
        tooltip: widget.selected ? 'Start work (⌘⏎)' : 'Start work',
        onTap: open,
      );
    },
  );

  static Widget _column(double width, Widget? child) => SizedBox(
    width: width,
    child: child == null
        ? null
        : Align(alignment: Alignment.centerRight, child: child),
  );

  /// Threads not resolved (in the warning color), else comments.
  static Widget? _talk(NushiTheme theme, GitHubItem it) {
    final t = theme.t;
    final (n, icon, color, words) = it.unresolved > 0
        ? (
            it.unresolved,
            Icons.forum_outlined,
            t.needs,
            unresolvedWords(it.unresolved),
          )
        : (
            it.comments,
            Icons.chat_bubble_outline,
            t.textMuted,
            '${it.comments} comment${it.comments == 1 ? '' : 's'}',
          );
    if (n == 0) return null;
    return Tooltip(
      message: words,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 3),
          Text('$n', style: theme.ui(color, size: 11.5)),
        ],
      ),
    );
  }
}
