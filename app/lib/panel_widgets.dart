import 'package:flutter/material.dart';
import 'package:nushi/card_list.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The title of a widget to open and scroll into view once it's built (the
/// palette's Artifacts…); cleared once it is.
final ValueNotifier<String?> revealWidget = runValue(null);

/// The details panel's type and room (ADR 0092): a widget's title and its
/// rows at the sidebar's size (the theme's own 13), what's said about a
/// row a step smaller, the side margin, a card's own and the gap a row
/// takes.
abstract final class PanelType {
  static const detail = 12.0;

  /// The panel's text sits this far in from its sides.
  static const side = 16.0;

  /// A widget's card sits this far in from the panel's sides and top, and
  /// from the next card (ADR 0111); its text is the rest of [side] inside
  /// it.
  static const inset = 8.0;

  /// Above and below each row's line.
  static const rowGap = 3.0;
}

/// The details panel's widgets in the order they were dragged into
/// (remembered in [widgetOrder]; widgets it doesn't name go last), one
/// under another in the pane's details column, each a card of its own on
/// the pane's fill with a gap between them (ADR 0111; flat with hairlines
/// until then, ADR 0092). A widget is moved by dragging its title.
class PanelWidgets extends StatelessWidget {
  const new(this.widgets, {super.key});

  final List<PanelWidget> widgets;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widgetOrder,
    builder: (context, saved, _) {
      final byTitle = {for (final w in widgets) w.title: w};
      final titles = [
        ...saved.where(byTitle.containsKey),
        ...byTitle.keys.where((k) => !saved.contains(k)),
      ];
      // The details panel is dense: its controls are compact (ADR 0122).
      return ControlScale.compact(
        child: CardList(
          // Each card brings the gap under it.
          padding: const EdgeInsets.only(top: PanelType.inset),
          // A widget asked for is there to scroll to.
          buildAll: true,
          onReorder: (from, to) =>
              widgetOrder.value = reordered(saved, titles, from, to),
          children: [
            for (final (i, title) in titles.indexed) byTitle[title]!.at(i),
          ],
        ),
      );
    },
  );
}

/// One of the details panel's widgets: a rounded card (ADR 0111), its
/// title in the text color with a small triangle after it that folds it
/// (remembered in [collapsedWidgets]) and [summary] on its right while
/// folded; then rows of a quiet label on the left and a value on the
/// right (a row without a label is a line of its own). With [onTap] the
/// rows are a button; [action] (a small button) sits on the title's right
/// while open. The title drags it among the others: the open hand over
/// it, the closed one while dragged, and the grip on the right under the
/// pointer, in its summary's place.
class PanelWidget extends StatelessWidget {
  const new({
    required this.title,
    required this.rows,
    super.key,
    this.summary,
    this.onTap,
    this.action,
    this.index = 0,
    this.note,
    this.tooltip,
    this.label,
  });

  /// This widget as the [i]th of the list, which its title row drags in.
  PanelWidget at(int i) => PanelWidget(
    key: ValueKey(title),
    title: title,
    rows: rows,
    summary: summary,
    onTap: onTap,
    action: action,
    index: i,
    note: note,
    tooltip: tooltip,
    label: label,
  );

  /// What the title says, when not [title] (which keys the widget's order
  /// and folding): "Pull requests" with two or more.
  final String? label;

  /// The title's tooltip, worded as it's hovered (a time in it is
  /// current).
  final String Function()? tooltip;

  /// What the widget says when it has nothing to offer ("Not a git
  /// repository"): one line, its title and this, nothing to open.
  final String? note;

  final String title;
  final List<(String?, Object)> rows;
  final Widget? summary;
  final VoidCallback? onTap;
  final Widget? action;
  final int index;

  /// Opens this widget (asked by [revealWidget]) and, once laid out, scrolls
  /// it into view.
  void _reveal(BuildContext context, {required bool open}) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (revealWidget.value != title) return;
        if (!open) {
          collapsedWidgets.value = {...collapsedWidgets.value}..remove(title);
          return; // open now: built again, and revealed then
        }
        revealWidget.value = null;
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
    final muted = theme.ui(t.textMuted);
    Widget titleText = Text(
      label ?? title,
      style: theme.ui(t.text, weight: FontWeight.w500),
    );
    if (tooltip case final words?) titleText = _HoverTip(words, titleText);
    if (note case final n?) {
      return _Section(
        index: index,
        open: false,
        folds: false,
        onToggle: null,
        title: titleText,
        trailing: Tooltip(
          message: n,
          child: Text(
            n,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
        body: const SizedBox.shrink(),
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([collapsedWidgets, revealWidget]),
      builder: (context, _) {
        final collapsed = collapsedWidgets.value;
        final open = !collapsed.contains(title);
        if (revealWidget.value == title) _reveal(context, open: open);
        return _Section(
          index: index,
          open: open,
          onToggle: () => collapsedWidgets.toggle(title),
          title: titleText,
          trailing: open ? action : summary,
          acts: open && action != null,
          body: Tap(
            onTap: onTap,
            tint: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, v) in rows)
                  Padding(
                    // A row's own key: its state (a list it opened) stays
                    // as rows come and go above it.
                    key: v is Widget && v.key is LocalKey ? v.key : null,
                    padding: const EdgeInsets.symmetric(
                      vertical: PanelType.rowGap,
                    ),
                    child: label == null
                        ? (v is String ? Text(v, style: muted) : v as Widget)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: theme.ui(t.textSecondary)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: v is String
                                      ? Text(v, style: theme.ui(t.text))
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

/// A widget's look ([PanelWidget]): a card on the pane's fill, a card's
/// fill and corners and no outline (ADR 0111), [PanelType.inset] in from
/// the panel's sides with that gap under it; a [title] row that folds it
/// ([onToggle]; a triangle after the title while it [folds]) and drags
/// it, [trailing] on that row's right, then [body] while [open]; folded,
/// it's a short card, its title in its middle. Under the pointer, or while
/// dragged, the [DragGrip] takes [trailing]'s place on the right (ADR
/// 0092's amendment): the card is plain at rest, and the grip says the
/// title drags. A [trailing] that [acts] (a button) stays, the grip left
/// of it, so it can still be clicked, and a menu it opens keeps the grip
/// there while the pointer is on the menu.
class _Section extends StatefulWidget {
  const new({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.body,
    required this.index,
    this.trailing,
    this.acts = false,
    this.folds = true,
  });

  final Widget title;
  final bool open;
  final bool folds;
  final VoidCallback? onToggle;
  final Widget body;
  final Widget? trailing;
  final bool acts;
  final int index;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _hovered = false;

  /// A menu of the action's is open: the pointer on it has left the widget,
  /// but the title row keeps its hovered look.
  bool _menuOpen = false;

  @override
  void didUpdateWidget(_Section old) {
    super.didUpdateWidget(old);
    // A menu gone with its button (the widget folded) says nothing as it
    // closes.
    if (!widget.acts) _menuOpen = false;
  }

  /// The button that [_Section.acts], the grip left of it while [grip]. It
  /// stays the same element as the pointer comes and goes (a menu it opened
  /// would close with it), and its menus open under it, ending at its edge.
  Widget _action({required bool grip}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (grip) ...[const DragGrip(), const SizedBox(width: 10)],
      NotificationListener<MenuOpened>(
        key: const ValueKey('action'),
        onNotification: (n) {
          setState(() => _menuOpen = n.open);
          return false;
        },
        child: TrailingMenus(child: widget.trailing!),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final dragged = DraggedCard.of(context);
    final w = widget;
    final grip = _hovered || _menuOpen || dragged;
    // A card, dragged too; the gap under it isn't its, nor the pointer's.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PanelType.inset,
        0,
        PanelType.inset,
        PanelType.inset,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          decoration: cardBox(t),
          padding: const EdgeInsets.symmetric(
            horizontal: PanelType.side - PanelType.inset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReorderableDragStartListener(
                index: w.index,
                child: Tap(
                  onTap: w.onToggle,
                  cursor: dragged
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab,
                  tint: false,
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Row(
                    children: [
                      w.title,
                      if (w.folds) ...[
                        const SizedBox(width: 2),
                        _Triangle(open: w.open),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: w.acts && w.trailing != null
                              ? _action(grip: grip)
                              : grip
                              ? const DragGrip()
                              : w.trailing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The rows end 10 from the card's foot; folded, the title
              // has as much under it as over it.
              Disclosure(
                open: w.open,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: w.body,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small filled triangle after a folding widget's title, as Claude
/// Code's rail has it: right while folded, down while open, turning
/// between (at once with Reduce Motion).
class _Triangle extends StatelessWidget {
  const new({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.25 : 0,
    duration: reduceMotion(context) ? Duration.zero : Motion.standard,
    curve: Motion.size,
    child: Icon(
      Icons.arrow_right,
      size: 18,
      color: NushiTheme.of(context).t.textMuted,
    ),
  );
}

/// A tooltip worded again each time the pointer comes in.
class _HoverTip extends StatefulWidget {
  const new(this.words, this.child);

  final String Function() words;
  final Widget child;

  @override
  State<_HoverTip> createState() => _HoverTipState();
}

class _HoverTipState extends State<_HoverTip> {
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() {}),
    child: Tooltip(message: widget.words(), child: widget.child),
  );
}
