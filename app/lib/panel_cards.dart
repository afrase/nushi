import 'package:flutter/material.dart';

import 'settings.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The cards in the order they were dragged into (remembered in
/// [cardOrder]; cards it doesn't name go last), each moved by dragging its
/// title row, without a lifted look.
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
      return ReorderableListView(
        padding: const EdgeInsets.all(12),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, _, _) => child,
        onReorderItem: (from, to) =>
            cardOrder.value = reordered(saved, titles, from, to),
        children: [
          for (final (i, title) in titles.indexed) byTitle[title]!.at(i),
        ],
      );
    },
  );
}

/// A rounded card: a title that collapses it (remembered in
/// [collapsedCards]), with [summary] on its right while collapsed; then rows
/// of a quiet label on the left and a value on the right (a row without a
/// label is a line of its own). With [onTap] the rows are a button.
class PanelCard extends StatelessWidget {
  const new({
    required this.title,
    required this.rows,
    super.key,
    this.summary,
    this.onTap,
    this.index = 0,
  });

  /// This card as the [i]th of the list, which its title row drags in.
  PanelCard at(int i) => PanelCard(
    key: ValueKey(title),
    title: title,
    rows: rows,
    summary: summary,
    onTap: onTap,
    index: i,
  );

  final String title;
  final List<(String?, Object)> rows;
  final Widget? summary;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    return ValueListenableBuilder(
      valueListenable: collapsedCards,
      builder: (context, collapsed, _) {
        final open = !collapsed.contains(title);
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
                  onTap: () => collapsedCards.value = open
                      ? {...collapsed, title}
                      : ({...collapsed}..remove(title)),
                  radius: NushiTheme.card * 1.5,
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: theme.ui(
                          t.textSecondary,
                          size: 12,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Chevron(open: open, size: 15),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: open ? null : summary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (open)
                Tap(
                  onTap: onTap,
                  padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (label, v) in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: label == null
                              ? (v is String
                                    ? Text(v, style: muted)
                                    : v as Widget)
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
                                                style: theme.ui(
                                                  t.text,
                                                  size: 12,
                                                ),
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
            ],
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
