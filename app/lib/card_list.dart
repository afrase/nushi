import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'package:nushi/disclosure.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Cards ([CardShell]s, or the details panel's widgets, each keyed and
/// told its index) in a list, each moved by dragging its title row,
/// without a lifted look; the one dragged is under a [DraggedCard].
class CardList extends StatelessWidget {
  const new({
    required this.children,
    required this.onReorder,
    super.key,
    this.padding = const EdgeInsets.all(12),
    this.buildAll = false,
    this.keepScrollAs,
  });

  /// A name, unique among the window's lists, to keep its scroll by while
  /// the app runs: the list comes back where it was (the inbox, after an
  /// item's details took its place).
  final String? keepScrollAs;

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
    key: keepScrollAs == null ? null : PageStorageKey(keepScrollAs),
    padding: padding,
    buildDefaultDragHandles: false,
    // The card being dragged keeps its grip and the closed hand.
    proxyDecorator: (child, _, _) => DraggedCard(child: child),
    onReorderItem: onReorder,
    scrollCacheExtent: buildAll ? const ScrollCacheExtent.pixels(1e6) : null,
    children: children,
  );
}

/// Marks the card a [CardList] is dragging (the copy under the pointer).
class DraggedCard extends InheritedWidget {
  const new({required super.child, super.key});

  /// Whether [context] is in the card being dragged.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DraggedCard>() != null;

  @override
  bool updateShouldNotify(DraggedCard old) => false;
}

/// A card's look: rounded, a [title] row that collapses it ([onToggle])
/// and drags it in a [CardList] (as its [index]th), [trailing] on that
/// row's right, then [body] while [open] ([Disclosure]). Under the
/// pointer the title row shows the open hand and a six-dot grip on its
/// right (in a collapsed card's [trailing] place, its summary); the closed
/// hand while dragged.
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
    final dragged = DraggedCard.of(context);
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
                    TurnChevron(open: widget.open, size: 15),
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
          Disclosure(open: widget.open, child: widget.body),
        ],
      ),
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
