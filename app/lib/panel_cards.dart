import 'package:flutter/material.dart';

import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The cards in the order they were dragged into (remembered in
/// [cardOrder]; cards it doesn't name go last).
class PanelCards extends StatelessWidget {
  const new(this.cards, {super.key});

  final List<PanelCard> cards;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: cardOrder,
    builder: (context, saved, _) {
      final byTitle = {for (final c in cards) c.title: c};
      final titles = [
        ...saved.where(byTitle.containsKey),
        ...byTitle.keys.where((k) => !saved.contains(k)),
      ];
      return CardList(
        onReorder: (from, to) =>
            cardOrder.value = reordered(saved, titles, from, to),
        children: [
          for (final (i, title) in titles.indexed) byTitle[title]!.at(i),
        ],
      );
    },
  );
}

/// Cards ([CardShell]s, each keyed and told its index) in a list, each
/// moved by dragging its title row, without a lifted look.
class CardList extends StatelessWidget {
  const new({
    required this.children,
    required this.onReorder,
    super.key,
    this.padding = const EdgeInsets.all(12),
  });

  final List<Widget> children;

  /// The card at `from` dropped at `to` (of the list without it).
  final void Function(int from, int to) onReorder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ReorderableListView(
    padding: padding,
    buildDefaultDragHandles: false,
    proxyDecorator: (child, _, _) => child,
    onReorderItem: onReorder,
    children: children,
  );
}

/// A card's look: rounded, a [title] row that collapses it ([onToggle])
/// and drags it in a [CardList] (as its [index]th), [trailing] on that
/// row's right, then [body] while [open].
class CardShell extends StatelessWidget {
  const new({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.body,
    super.key,
    this.trailing,
    this.index = 0,
  });

  final Widget title;
  final bool open;
  final VoidCallback onToggle;
  final Widget body;
  final Widget? trailing;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: box(
        t.borderSubtle,
        fill: t.raised,
        radius: NushiTheme.card * 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tap(
              onTap: onToggle,
              radius: NushiTheme.card * 1.5,
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
              child: Row(
                children: [
                  title,
                  const SizedBox(width: 2),
                  Chevron(open: open, size: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open) body,
        ],
      ),
    );
  }
}

/// A rounded card: a title that collapses it (remembered in
/// [collapsedCards]), with [summary] on its right while collapsed; then rows
/// of a quiet label on the left and a value on the right (a row without a
/// label is a line of its own). With [onTap] the rows are a button; [action]
/// (a small button) sits on the title's right while open.
class PanelCard extends StatelessWidget {
  const new({
    required this.title,
    required this.rows,
    super.key,
    this.summary,
    this.onTap,
    this.action,
    this.index = 0,
  });

  /// This card as the [i]th of the list, which its title row drags in.
  PanelCard at(int i) => PanelCard(
    key: ValueKey(title),
    title: title,
    rows: rows,
    summary: summary,
    onTap: onTap,
    action: action,
    index: i,
  );

  final String title;
  final List<(String?, Object)> rows;
  final Widget? summary;
  final VoidCallback? onTap;
  final Widget? action;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    return ValueListenableBuilder(
      valueListenable: collapsedCards,
      builder: (context, collapsed, _) {
        final open = !collapsed.contains(title);
        return CardShell(
          index: index,
          open: open,
          onToggle: () => collapsedCards.value = open
              ? {...collapsed, title}
              : ({...collapsed}..remove(title)),
          title: Text(
            title,
            style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
          ),
          trailing: open ? action : summary,
          body: Tap(
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, v) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: label == null
                        ? (v is String ? Text(v, style: muted) : v as Widget)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: theme.ui(t.textMuted, size: 12),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: v is String
                                      ? Text(
                                          v,
                                          style: theme.ui(t.text, size: 12),
                                        )
                                      : v as Widget,
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The saved card order once the card [from] of those [shown] moved to
/// [to]: cards not shown here keep their places among the rest.
List<String> reordered(
  List<String> saved,
  List<String> shown,
  int from,
  int to,
) {
  final moved = [...shown];
  moved.insert(to, moved.removeAt(from));
  var k = 0;
  return [
    for (final s in saved)
      if (shown.contains(s)) moved[k++] else s,
    ...moved.skip(k),
  ];
}
