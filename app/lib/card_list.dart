import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'package:nushi/disclosure.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Cards ([CardShell]s, or the details panel's widgets, each keyed and
/// told its index) in a list, each moved by dragging its title row,
/// without a lifted look; the one dragged is under a [DraggedCard].
///
/// Every card is built, not only those near the screen: a list whose keys
/// move a selection through its rows needs each row there, to scroll to it
/// and to act on it (⌘⏎). Cards are few, rows a few hundred at most.
class CardList extends StatelessWidget {
  const new({
    required this.children,
    required this.onReorder,
    super.key,
    this.padding = const EdgeInsets.all(12),
    this.keepScrollAs,
  });

  /// A name, unique among the window's lists, to keep its scroll by while
  /// the app runs: the list comes back where it was (the inbox, after an
  /// item's details took its place).
  final String? keepScrollAs;

  final List<Widget> children;

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
    scrollCacheExtent: const ScrollCacheExtent.pixels(1e6),
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
/// and drags it in a [CardList] (as its [index]th; [DragTitle]),
/// [trailing] on that row's right, then [body] while [open]
/// ([Disclosure]). With the pointer anywhere on it, the six-dot grip shows
/// on the title row's right (in a collapsed card's [trailing] place, its
/// summary).
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
    return Padding(
      // The gap under it isn't its, nor the pointer's.
      padding: const EdgeInsets.only(bottom: 10),
      child: DragTitle(
        index: index,
        onTap: onToggle,
        radius: NushiTheme.inner(NushiTheme.card, 1),
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        card: (context, row) => Container(
          // The point its outline took, so its rows are where they were.
          padding: const EdgeInsets.all(1),
          decoration: cardBox(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row,
              Disclosure(open: open, child: body),
            ],
          ),
        ),
        title: (context, {required grip}) => Row(
          children: [
            title,
            const SizedBox(width: 2),
            TurnChevron(open: open, size: 15),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                // Collapsed, the grip takes the summary's place.
                child: !open && grip ? const DragGrip() : trailing,
              ),
            ),
            if (open)
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
    );
  }
}

/// What a card in a [CardList] does as it's dragged, for both cards
/// ([CardShell], the details panel's widgets), each keeping its own
/// layout ([card], around its title row): the pointer anywhere on the
/// card shows the [DragGrip] (the `grip` [title] is told, as while
/// dragged or [held]; ADR 0092's amendment), and its title row drags it
/// (as its [index]th) and [onTap]s, the open hand over it and the closed
/// one while dragged.
class DragTitle extends StatefulWidget {
  const new({
    required this.index,
    required this.onTap,
    required this.padding,
    required this.radius,
    required this.title,
    required this.card,
    super.key,
    this.held = false,
  });

  final int index;
  final VoidCallback? onTap;

  /// The title row's padding and the corners of its pressed fill.
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Something else keeps the grip shown (a menu the title's button
  /// opened, which the pointer is on).
  final bool held;

  /// The title row's content, told whether the grip shows.
  final Widget Function(BuildContext context, {required bool grip}) title;

  /// The card around the title row.
  final Widget Function(BuildContext context, Widget title) card;

  @override
  State<DragTitle> createState() => _DragTitleState();
}

class _DragTitleState extends State<DragTitle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dragged = DraggedCard.of(context);
    final grip = _hover || widget.held || dragged;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.card(
        context,
        ReorderableDragStartListener(
          index: widget.index,
          child: Tap(
            onTap: widget.onTap,
            cursor: dragged
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab,
            tint: false,
            radius: widget.radius,
            padding: widget.padding,
            child: widget.title(context, grip: grip),
          ),
        ),
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
