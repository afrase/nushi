import 'package:flutter/material.dart';
import 'package:nushi/card_list.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The title of a widget to open and scroll into view once it's built (the
/// palette's Artifacts…); cleared once it is.
final revealWidget = ValueNotifier<String?>(null);

/// The details panel's type and room (ADR 0092): a widget's title and its
/// rows at the sidebar's size (the theme's own 13), what's said about a
/// row a step smaller, the side margin and the gap a row takes.
abstract final class PanelType {
  static const detail = 12.0;

  /// The panel's text sits this far in from its sides.
  static const side = 16.0;

  /// Above and below each row's line.
  static const rowGap = 3.0;
}

/// The details panel's widgets in the order they were dragged into
/// (remembered in [widgetOrder]; widgets it doesn't name go last), one
/// under another on the panel's own background, a hairline between them
/// (ADR 0092). A widget is moved by dragging its title.
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
      return CardList(
        padding: const EdgeInsets.symmetric(vertical: 4),
        // A widget asked for is there to scroll to.
        buildAll: true,
        onReorder: (from, to) =>
            widgetOrder.value = reordered(saved, titles, from, to),
        children: [
          for (final (i, title) in titles.indexed) byTitle[title]!.at(i),
        ],
      );
    },
  );
}

/// One of the details panel's widgets, as Claude Code's right rail draws a
/// section: no box, a hairline over it unless it's the first, its title in
/// the text color with a small triangle after it that folds it
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
  );

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
      title,
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

/// A widget's look ([PanelWidget]): a hairline over it unless it's the
/// first ([index] 0), a [title] row that folds it ([onToggle]; a triangle
/// after the title while it [folds]) and drags it, [trailing] on that
/// row's right, then [body] while [open]. Under the pointer, or while
/// dragged, the [DragGrip] takes [trailing]'s place on the right (ADR
/// 0092's amendment): the rail stays flat at rest, and the grip says the
/// title drags. A [trailing] that [acts] (a button) stays, the grip left
/// of it, so it can still be clicked.
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

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final dragged = DraggedCard.of(context);
    final w = widget;
    // On the panel's background, dragged too.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: t.base,
        padding: const EdgeInsets.symmetric(horizontal: PanelType.side),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (w.index > 0 && !dragged)
              SizedBox(height: 1, child: ColoredBox(color: t.borderSubtle)),
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
                        child: !(_hovered || dragged)
                            ? w.trailing
                            : w.acts && w.trailing != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const DragGrip(),
                                  const SizedBox(width: 10),
                                  w.trailing!,
                                ],
                              )
                            : const DragGrip(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Disclosure(open: w.open, child: w.body),
            const SizedBox(height: 10),
          ],
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
