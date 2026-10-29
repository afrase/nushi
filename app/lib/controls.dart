import 'package:flutter/material.dart';

import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';

// The app's controls: one look for each kind of thing that can be
// pressed, so what's clickable looks it. [Button] for an action,
// [MenuField] for a value picked from a list, [LinkText] for going
// somewhere from within text, [IconTap] where an icon alone is clear,
// [DragGrip] where something can be moved. Plain text is never clickable;
// all of these show the pointing hand.

/// A button's and a field's height.
const controlHeight = 26.0;

/// How a control is, to draw it: under the pointer, focused from the
/// keyboard, pressable at all.
typedef ControlLook = ({bool hover, bool focus, bool enabled});

/// Says the controls below are for a finger (the phone): each gets a
/// target of at least [TouchTargets.size] points, as iOS asks.
class TouchTargets extends InheritedWidget {
  const new({required super.child, super.key});

  static const size = 44.0;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TouchTargets>() != null;

  @override
  bool updateShouldNotify(TouchTargets oldWidget) => false;
}

/// [child] centred in a target of at least 44 points under [TouchTargets],
/// else as it is.
Widget touchTarget(BuildContext context, Widget child) =>
    TouchTargets.of(context)
    ? ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: TouchTargets.size,
          minHeight: TouchTargets.size,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      )
    : child;

/// Hover, keyboard focus and press for a control that [builder] draws:
/// the pointing hand, a click or Enter or Space press it. Without [onTap]
/// it's disabled: no hand, no focus.
class Pressable extends StatefulWidget {
  const new({
    required this.onTap,
    required this.builder,
    super.key,
    this.tooltip = '',
    this.autofocus = false,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, ControlLook look) builder;
  final String tooltip;
  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _focus = false;

  void _set(bool hover, bool focus) {
    if (mounted && (hover != _hover || focus != _focus)) {
      setState(() {
        _hover = hover;
        _focus = focus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    final control = FocusableActionDetector(
      enabled: on,
      autofocus: widget.autofocus,
      mouseCursor: on ? SystemMouseCursors.click : MouseCursor.defer,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap?.call(),
        ),
      },
      onShowHoverHighlight: (v) => _set(v, _focus),
      onShowFocusHighlight: (v) => _set(_hover, v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: touchTarget(
          context,
          widget.builder(context, (
            hover: _hover && on,
            focus: _focus && on,
            enabled: on,
          )),
        ),
      ),
    );
    return widget.tooltip.isEmpty
        ? control
        : Tooltip(message: widget.tooltip, child: control);
  }
}

/// The ring a focused control wears, over its border.
BoxDecoration? focusRing(Tokens t, ControlLook look) => look.focus
    ? BoxDecoration(
        border: Border.all(color: t.focus, width: 2),
        borderRadius: BorderRadius.circular(NushiTheme.control),
      )
    : null;

/// [child] faded while [look] is disabled.
Widget _faded(ControlLook look, Widget child) =>
    look.enabled ? child : Opacity(opacity: 0.45, child: child);

enum ButtonKind {
  /// The one main action of a dialog or card: accent fill.
  primary,

  /// Every other action: outlined.
  secondary,

  /// One that deletes or loses something: red text, outlined.
  destructive,
}

/// A button: [label], an optional leading [icon], a shortcut [hint] after
/// the label (not on a phone). Every button has the same height and
/// padding; stretched wider than its content, the content is centred.
/// [wrap]: on a phone, a long label wraps to three lines, the button
/// growing, rather than being cut (a permission's option says what it
/// allows).
class Button extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.kind = ButtonKind.secondary,
    this.icon,
    this.hint,
    this.autofocus = false,
    this.tooltip = '',
    this.menu = false,
    this.wrap = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool wrap;
  final ButtonKind kind;
  final IconData? icon;
  final String? hint;
  final bool autofocus;
  final String tooltip;

  /// Whether it opens a menu: a ▾ after the label.
  final bool menu;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final primary = kind == ButtonKind.primary;
    final fg = switch (kind) {
      ButtonKind.primary => t.onAccent,
      ButtonKind.secondary => t.text,
      ButtonKind.destructive => t.crashed,
    };
    final style = theme.ui(fg, weight: primary ? FontWeight.w500 : null);
    final touch = TouchTargets.of(context);
    final lines = wrap && touch ? 3 : 1;
    return Pressable(
      onTap: onPressed,
      autofocus: autofocus,
      tooltip: tooltip,
      builder: (context, look) => _faded(
        look,
        Container(
          height: lines > 1 ? null : controlHeight,
          constraints: lines > 1
              ? const BoxConstraints(minHeight: controlHeight)
              : null,
          padding: lines > 1
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
              : const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: primary
                ? (look.hover
                      ? Color.alphaBlend(
                          t.onAccent.withValues(alpha: 0.12),
                          t.accent,
                        )
                      : t.accent)
                : (look.hover
                      ? Color.alphaBlend(t.hover, t.fieldFill)
                      : t.fieldFill),
            border: primary
                ? null
                : Border.all(
                    color: look.hover ? t.fieldBorderHover : t.fieldBorder,
                  ),
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          foregroundDecoration: focusRing(t, look),
          // Centred when its parent stretches it (the sidebar's New chat);
          // a value picker is a MenuField, which keeps its value at the left.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: style,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: lines > 1 ? TextAlign.center : null,
                ),
              ),
              if (hint != null && !touch) ...[
                const SizedBox(width: 6),
                keyHint(
                  context,
                  hint!,
                  color: primary ? t.onAccent : t.textMuted,
                ),
              ],
              if (menu) ...[
                const SizedBox(width: 3),
                Icon(Icons.keyboard_arrow_down, size: 15, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Send to agent's button, wherever something goes into the chat's box
/// as a reply card (Send, Fix checks, Address): its arrow and [label] in
/// the accent's ink on its tint; [primary], the accent's fill (Send all).
class SendButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.tooltip = '',
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final fg = primary ? t.onAccent : t.accentInk;
    final fill = primary ? t.accent : t.accentSoft;
    return Pressable(
      onTap: onPressed,
      tooltip: tooltip,
      builder: (context, look) => _faded(
        look,
        Container(
          height: controlHeight,
          padding: const EdgeInsets.fromLTRB(7, 0, 9, 0),
          decoration: BoxDecoration(
            color: look.hover
                ? Color.alphaBlend(fg.withValues(alpha: 0.12), fill)
                : fill,
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          foregroundDecoration: focusRing(t, look),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.subdirectory_arrow_right, size: 14, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(fg, size: 12.5, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says the compact [MenuField]s below end flush with their room: a
/// panel widget's values, so a menu's ▾ lines up with the text values'
/// right edge.
class FlushMenus extends InheritedWidget {
  const new({required super.child, super.key});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlushMenus>() != null;

  @override
  bool updateShouldNotify(FlushMenus oldWidget) => false;
}

/// A value picked from a list ([entries]) that looks it: [label] and a ▾
/// in a bordered box, the whole box the target. [compact], for a picker in
/// a header or a row ("Only me ▾"), drops the box but keeps the ▾ and a
/// tint under the pointer. With no [entries] it's disabled.
class MenuField extends StatelessWidget {
  const new({
    required this.label,
    required this.entries,
    super.key,
    this.compact = false,
    this.tooltip = '',
    this.digits = false,
    this.onOpen,
    this.onClose,
  });

  /// The value, usually a [Text]; styled as a field's unless it says.
  final Widget label;
  final List<MenuEntry> entries;
  final bool compact;
  final String tooltip;
  final bool digits;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final flush = compact && FlushMenus.of(context);
    final caret = Icon(
      Icons.keyboard_arrow_down,
      size: compact ? 14 : 15,
      color: t.textSecondary,
    );
    return Menu(
      entries: entries,
      digits: digits,
      onOpen: onOpen,
      onClose: onClose,
      builder: (context, open) => Pressable(
        onTap: entries.isEmpty ? null : open,
        tooltip: tooltip,
        builder: (context, look) {
          final face = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: DefaultTextStyle(
                  style: compact
                      ? theme.ui(t.textSecondary, size: 12)
                      : theme.ui(t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: label,
                ),
              ),
              SizedBox(width: compact ? 1 : 6),
              // Flush, the glyph's own margin goes past the edge too.
              if (flush)
                Transform.translate(offset: const Offset(2, 0), child: caret)
              else
                caret,
            ],
          );
          return _faded(
            look,
            Container(
              height: compact ? null : controlHeight,
              padding: compact
                  ? EdgeInsets.fromLTRB(5, 1, flush ? 0 : 3, 1)
                  : const EdgeInsets.fromLTRB(8, 0, 5, 0),
              decoration: BoxDecoration(
                color: compact
                    ? (look.hover ? t.hover : null)
                    : (look.hover
                          ? Color.alphaBlend(t.hover, t.fieldFill)
                          : t.fieldFill),
                border: compact
                    ? null
                    : Border.all(
                        color: look.hover ? t.fieldBorderHover : t.fieldBorder,
                      ),
                borderRadius: BorderRadius.circular(NushiTheme.control),
              ),
              foregroundDecoration: focusRing(t, look),
              child: face,
            ),
          );
        },
      ),
    );
  }
}

/// A button that opens a menu of what it can do ("Start work ▾");
/// [onOpener] takes the menu's opener (for a shortcut that opens it too).
class MenuButton extends StatelessWidget {
  const new({
    required this.label,
    required this.entries,
    super.key,
    this.kind = ButtonKind.secondary,
    this.icon,
    this.tooltip = '',
    this.onOpener,
  });

  final String label;
  final List<MenuEntry> entries;
  final ButtonKind kind;
  final IconData? icon;
  final String tooltip;

  /// Given the menu's opener on each build.
  final void Function(OpenMenu open)? onOpener;

  @override
  Widget build(BuildContext context) => Menu(
    entries: entries,
    builder: (context, open) {
      onOpener?.call(open);
      return Button(
        label: label,
        kind: kind,
        icon: icon,
        tooltip: tooltip,
        menu: true,
        onPressed: entries.isEmpty ? null : open,
      );
    },
  );
}

/// An icon that opens a menu ("More": ⋯).
class MenuIcon extends StatelessWidget {
  const new(
    this.icon, {
    required this.tooltip,
    required this.entries,
    super.key,
    this.size = 16,
    this.onClose,
  });

  final IconData icon;
  final String tooltip;
  final List<MenuEntry> entries;
  final double size;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Menu(
    entries: entries,
    onClose: onClose,
    builder: (context, open) => IconTap(
      icon,
      tooltip: tooltip,
      size: size,
      onTap: entries.isEmpty ? null : open,
    ),
  );
}

/// A link inside text or beside it, to go somewhere ("Settings ›
/// Agents"): the link color, underlined under the pointer or when focused.
class LinkText extends StatelessWidget {
  const new(
    this.text, {
    required this.onTap,
    super.key,
    this.size = 13,
    this.mono = false,
    this.tooltip = '',
  });

  final String text;
  final VoidCallback? onTap;
  final double size;
  final bool mono;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Pressable(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, look) {
        final color = look.enabled ? t.link : t.textMuted;
        final style = mono
            ? theme.code(color, size: size)
            : theme.ui(color, size: size);
        return Text(
          text,
          style: style.copyWith(
            decoration: look.hover || look.focus
                ? TextDecoration.underline
                : null,
            decorationColor: color,
          ),
        );
      },
    );
  }
}

/// A small icon button: a tint under the pointer and its [tooltip]. Only
/// where the icon alone says what it does.
class IconTap extends StatelessWidget {
  const new(
    this.icon, {
    required this.tooltip,
    required this.onTap,
    super.key,
    this.size = 16,
    this.color,
    this.padding = 5,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  /// The room around the icon, on each side (5; 3 in a menu's row).
  final double padding;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Pressable(
      onTap: onTap,
      tooltip: tooltip,
      builder: (context, look) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: look.hover ? t.hover : null,
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        foregroundDecoration: focusRing(t, look),
        child: Icon(
          icon,
          size: size,
          color: look.enabled ? color ?? t.textSecondary : t.textMuted,
        ),
      ),
    );
  }
}

/// Six dots in two columns of three: what can be dragged by here.
class DragGrip extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(8, 12),
    painter: _Dots(NushiTheme.of(context).t.grip),
  );
}

class _Dots extends CustomPainter {
  new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final x in [2.0, 6.0]) {
      for (final y in [2.0, 6.0, 10.0]) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.color != color;
}

/// A shortcut in small monospace (`⏎`); nothing on a phone, which has no
/// keys ([TouchTargets]).
Widget keyHint(BuildContext context, String keys, {Color? color}) {
  if (TouchTargets.of(context)) return const SizedBox.shrink();
  final theme = NushiTheme.of(context);
  return Text(keys, style: theme.code(color ?? theme.t.textMuted, size: 11));
}
