import 'package:flutter/material.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/controls.dart';

import 'package:nushi/theme/theme.dart';

export 'package:nushi/controls.dart';

/// Shows [message] in a snack bar.
void showError(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$message')));

/// Runs a call, showing its error, if any, in a snack bar: the app's, also
/// once the widget that asked is gone (a trust card replaced it).
Future<void> tryOrShow(
  BuildContext context,
  Future<void> Function() call,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await call();
  } on Object catch (e) {
    if (context.mounted) {
      showError(context, e);
    } else {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// A quiet pressable area: a light tint under the pointer (unless not
/// [tint]: a card's title, which shows its grip instead) or when
/// [selected], no ripple.
class Tap extends StatefulWidget {
  const new({
    required this.onTap,
    required this.child,
    super.key,
    this.onSecondaryTapUp,
    this.selected = false,
    this.padding = EdgeInsets.zero,
    this.radius = NushiTheme.control,
    this.tooltip = '',
    this.cursor,
    this.tint = true,
  });

  final VoidCallback? onTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final Widget child;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String tooltip;

  /// The pointer over it, when not the pointing hand (a drag's open hand).
  final MouseCursor? cursor;

  /// Whether the pointer over it tints it.
  final bool tint;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final on = widget.onTap != null;
    final tap = MouseRegion(
      cursor:
          widget.cursor ?? (on ? SystemMouseCursors.click : MouseCursor.defer),
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.selected
                ? t.selected
                : _hover && on && widget.tint
                ? t.hover
                : null,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: widget.child,
        ),
      ),
    );
    return widget.tooltip.isEmpty
        ? tap
        : Tooltip(message: widget.tooltip, child: tap);
  }
}

/// A dialog: [title], [content] 460 wide, and its [actions].
Widget nushiDialog(String title, Widget content, List<Widget> actions) =>
    AlertDialog(
      title: Text(title),
      content: SizedBox(width: 460, child: content),
      actions: actions,
    );

/// Asks [title] with [text] in a dialog; true once [action] is pressed
/// ([destructive]: it deletes or loses something, so it's in red).
Future<bool> confirm(
  BuildContext context,
  String title,
  String text,
  String action, {
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => nushiDialog(title, Text(text), [
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
        Button(
          label: action,
          kind: destructive ? ButtonKind.destructive : ButtonKind.primary,
          autofocus: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ]),
    ) ??
    false;

/// One choice of a few (`Chat | Changes`).
class Segmented<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.segments,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: box(t.borderSubtle, fill: t.base, radius: NushiTheme.control),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, text) in segments)
            Tap(
              onTap: () => onChanged(v),
              selected: v == value,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              child: Text(
                text,
                style: theme.ui(
                  v == value ? t.text : t.textSecondary,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The chevron of something that opens: down while [open].
class Chevron extends StatelessWidget {
  const new({required this.open, super.key, this.size = 14, this.color});

  final bool open;
  final double size;
  final Color? color; // the muted text color if not given

  @override
  Widget build(BuildContext context) => Icon(
    open ? Icons.expand_more : Icons.chevron_right,
    size: size,
    color: color ?? NushiTheme.of(context).t.textMuted,
  );
}

/// A tool call's title (a command) whole, wrapped, in monospace.
class FullTitle extends StatelessWidget {
  const new(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Text(
        title,
        style: theme.code(t.text, size: 12).copyWith(height: 1.35),
      ),
    );
  }
}

/// [child] dimmed, and not to be clicked, while [on]: what it shows is
/// being replaced.
class Dimmed extends StatelessWidget {
  const new({required this.on, required this.child, super.key});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: on,
    child: AnimatedOpacity(
      opacity: on ? 0.4 : 1,
      duration: const Duration(milliseconds: 120),
      child: child,
    ),
  );
}

/// A list's rows while the first answer is on its way: bars where a row's
/// key, title and details will be, never a blank view.
class RowsLoading extends StatelessWidget {
  const new({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.borderSubtle,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  bar(72, 9),
                  // Titles of a few widths, as a list's are.
                  FractionallySizedBox(
                    widthFactor: const [0.8, 0.55, 0.7][i % 3],
                    child: bar(double.infinity, 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What the bar says of what shows: "Updated 3m ago · refreshing" for
/// what was kept from last time while it's asked again, "Updated 3m ago"
/// once asking failed, "Loading…" with nothing kept.
String? updatedLine(DateTime? updated, {required bool loading, DateTime? now}) {
  if (updated == null) return loading ? 'Loading…' : null;
  final when = ago((now ?? DateTime.now()).difference(updated), updated);
  return 'Updated $when${loading ? ' · refreshing' : ''}';
}

/// A line above the list: a problem, or what shows is old.
class Notice extends StatelessWidget {
  const new(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(10),
      decoration: box(t.needs, fill: t.needsSoft),
      child: Row(
        children: [
          Expanded(child: Text(text, style: theme.ui(t.needs, size: 12))),
          if (action case final a?) ...[
            const SizedBox(width: 8),
            Button(label: a, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
