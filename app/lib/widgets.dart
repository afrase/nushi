import 'package:flutter/material.dart';
import 'package:nushi/commits.dart';

import 'package:nushi/theme/theme.dart';

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

/// A quiet pressable area: a light tint under the pointer or when
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
  });

  final VoidCallback? onTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final Widget child;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String tooltip;

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
      cursor: on ? SystemMouseCursors.click : MouseCursor.defer,
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
                : _hover && on
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

/// A small icon button.
class IconTap extends StatelessWidget {
  const new(
    this.icon, {
    required this.tooltip,
    required this.onTap,
    super.key,
    this.size = 16,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Tap(
      tooltip: tooltip,
      onTap: onTap,
      padding: const EdgeInsets.all(5),
      child: Icon(
        icon,
        size: size,
        color: onTap == null ? t.textMuted : color ?? t.textSecondary,
      ),
    );
  }
}

enum ButtonKind {
  /// The one main action: accent fill.
  primary,

  /// Outlined.
  secondary,

  /// A quiet toolbar action: no chrome.
  ghost,

  /// Stop or delete: in red.
  danger,
}

/// A compact button with an optional leading [icon] and a shortcut [hint]
/// after the label.
class Button extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.kind = ButtonKind.secondary,
    this.icon,
    this.hint,
    this.height = 26,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final IconData? icon;
  final String? hint;
  final double height;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final enabled = onPressed != null;
    final (Color? bg, Color fg, Color? border) = switch (kind) {
      ButtonKind.primary => (t.accent, t.onAccent, null),
      ButtonKind.secondary => (null, t.text, t.borderStrong),
      ButtonKind.ghost => (null, t.textSecondary, null),
      ButtonKind.danger => (null, t.crashed, t.crashed),
    };
    final color = enabled ? fg : t.textMuted;
    final style = theme.ui(
      color,
      weight: kind == ButtonKind.primary ? FontWeight.w500 : null,
    );
    return TextButton(
      onPressed: onPressed,
      autofocus: autofocus,
      style:
          TextButton.styleFrom(
            minimumSize: Size(0, height),
            fixedSize: Size.fromHeight(height),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: enabled ? bg : (bg == null ? null : t.selected),
            foregroundColor: color,
            textStyle: style,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NushiTheme.control),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: t.focus, width: 2)
                  : border == null
                  ? null
                  : BorderSide(color: enabled ? border : t.borderSubtle),
            ),
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(width: 6),
            keyHint(
              context,
              hint!,
              color: enabled && kind == ButtonKind.primary
                  ? t.onAccent
                  : t.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

/// A dialog: [title], [content] 460 wide, and its [actions].
Widget nushiDialog(String title, Widget content, List<Widget> actions) =>
    AlertDialog(
      title: Text(title),
      content: SizedBox(width: 460, child: content),
      actions: actions,
    );

/// Asks [title] with [text] in a dialog; true once [action] is pressed.
Future<bool> confirm(
  BuildContext context,
  String title,
  String text,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => nushiDialog(title, Text(text), [
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context, false),
        ),
        Button(
          label: action,
          kind: ButtonKind.primary,
          autofocus: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ]),
    ) ??
    false;

/// A shortcut in small monospace (`⏎`).
Widget keyHint(BuildContext context, String keys, {Color? color}) {
  final theme = NushiTheme.of(context);
  return Text(keys, style: theme.code(color ?? theme.t.textMuted, size: 11));
}

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
