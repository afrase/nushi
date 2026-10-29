import 'package:flutter/material.dart';

import 'package:nushi/card_list.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The title of a widget to open and scroll into view once it's built (the
/// palette's Artifacts…); cleared once it is.
final revealWidget = ValueNotifier<String?>(null);

/// The details panel's widgets in the order they were dragged into
/// (remembered in [widgetOrder]; widgets it doesn't name go last).
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
        buildAll: true, // a widget asked for is there to scroll to
        onReorder: (from, to) =>
            widgetOrder.value = reordered(saved, titles, from, to),
        children: [
          for (final (i, title) in titles.indexed) byTitle[title]!.at(i),
        ],
      );
    },
  );
}

/// One of the details panel's widgets: rounded, a title that collapses it
/// (remembered in [collapsedWidgets]), with [summary] on its right while
/// collapsed; then rows of a quiet label on the left and a value on the
/// right (a row without a label is a line of its own). With [onTap] the
/// rows are a button; [action] (a small button) sits on the title's right
/// while open.
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
    final muted = theme.ui(t.textMuted, size: 12);
    Widget titleText = Text(
      title,
      style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
    );
    if (tooltip case final words?) titleText = _HoverTip(words, titleText);
    if (note case final n?) {
      return CardShell(
        index: index,
        open: false,
        chevron: false,
        onToggle: () {},
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
        return CardShell(
          index: index,
          open: open,
          onToggle: () => collapsedWidgets.value = open
              ? {...collapsed, title}
              : ({...collapsed}..remove(title)),
          title: titleText,
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
