import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The title of a card to open and scroll into view once it's built (the
/// palette's Artifacts…); cleared once it is.
final revealCard = ValueNotifier<String?>(null);

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
        buildAll: true, // a card asked for is there to scroll to
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
    this.buildAll = false,
  });

  final List<Widget> children;

  /// Whether every card is built, not only those near the screen: a list
  /// whose keys move a selection through its rows needs each row there, to
  /// scroll to it and to act on it (⌘⏎). Cards are few, rows a few hundred
  /// at most.
  final bool buildAll;

  /// The card at `from` dropped at `to` (of the list without it).
  final void Function(int from, int to) onReorder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ReorderableListView(
    padding: padding,
    buildDefaultDragHandles: false,
    // The card being dragged keeps its grip and the closed hand.
    proxyDecorator: (child, _, _) => _Dragged(child: child),
    onReorderItem: onReorder,
    scrollCacheExtent: buildAll ? const ScrollCacheExtent.pixels(1e6) : null,
    children: children,
  );
}

/// Marks the card a [CardList] is dragging (the copy under the pointer).
class _Dragged extends InheritedWidget {
  const new({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Dragged>() != null;

  @override
  bool updateShouldNotify(_Dragged old) => false;
}

/// A card's look: rounded, a [title] row that collapses it ([onToggle])
/// and drags it in a [CardList] (as its [index]th), [trailing] on that
/// row's right, then [body] while [open]. Under the pointer the title row
/// shows the open hand and a six-dot grip on its right (in a collapsed
/// card's [trailing] place, its summary); the closed hand while dragged.
class CardShell extends StatefulWidget {
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
  State<CardShell> createState() => _CardShellState();
}

class _CardShellState extends State<CardShell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final dragged = _Dragged.of(context);
    final grip = _hover || dragged;
    final cursor = dragged
        ? SystemMouseCursors.grabbing
        : SystemMouseCursors.grab;
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
            index: widget.index,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: Tap(
                onTap: widget.onToggle,
                cursor: cursor,
                tint: false,
                radius: NushiTheme.card * 1.5,
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                child: Row(
                  children: [
                    widget.title,
                    const SizedBox(width: 2),
                    Chevron(open: widget.open, size: 15),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        // Collapsed, the grip takes the summary's place.
                        child: !widget.open && grip
                            ? const DragGrip()
                            : widget.trailing,
                      ),
                    ),
                    if (widget.open)
                      SizedBox(
                        width: 14,
                        child: grip
                            ? const Align(
                                alignment: Alignment.centerRight,
                                child: DragGrip(),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.open) widget.body,
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

  /// Opens this card (asked by [revealCard]) and, once laid out, scrolls
  /// it into view.
  void _reveal(BuildContext context, {required bool open}) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (revealCard.value != title) return;
        if (!open) {
          collapsedCards.value = {...collapsedCards.value}..remove(title);
          return; // open now: built again, and revealed then
        }
        revealCard.value = null;
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 200),
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    return ListenableBuilder(
      listenable: Listenable.merge([collapsedCards, revealCard]),
      builder: (context, _) {
        final collapsed = collapsedCards.value;
        final open = !collapsed.contains(title);
        if (revealCard.value == title) _reveal(context, open: open);
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
            tint: false,
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
                                      : FlushMenus(child: v as Widget),
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
