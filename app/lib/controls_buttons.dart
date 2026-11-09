part of 'controls.dart';

enum ButtonKind {
  /// The one main action of a dialog or card: accent fill.
  primary,

  /// Every other action: outlined.
  secondary,

  /// One that deletes or loses something: red text, outlined.
  destructive,

  /// The same beside a dialog's own Done, as Claude desktop draws it (its
  /// Allowed sites' Clear all): red text on a faint red fill, no outline.
  danger,
}

/// The ink of a button of [kind].
Color _fg(Tokens t, ButtonKind kind) => switch (kind) {
  ButtonKind.primary => t.onAccent,
  ButtonKind.secondary => t.text,
  ButtonKind.destructive || ButtonKind.danger => t.crashed,
};

/// A button's fill and border, as [look] has it, rounded by [r]: the
/// accent's fill for a primary one, a faint red for a danger one, else
/// outlined.
BoxDecoration _buttonBox(
  Tokens t,
  ButtonKind kind,
  ControlLook look,
  BorderRadius r,
) {
  final primary = kind == ButtonKind.primary;
  if (kind == ButtonKind.danger) {
    return BoxDecoration(
      color: look.hover
          ? Color.alphaBlend(_tint(t, look), t.crashedSoft)
          : t.crashedSoft,
      borderRadius: r,
    );
  }
  return BoxDecoration(
    color: primary
        ? (look.pressed
              ? t.accentPressed
              : look.hover
              ? Color.alphaBlend(t.onAccent.withValues(alpha: 0.12), t.accent)
              : t.accent)
        : (look.hover
              ? Color.alphaBlend(_tint(t, look), t.fieldFill)
              : t.fieldFill),
    border: primary
        ? null
        : Border.all(color: look.hover ? t.fieldBorderHover : t.fieldBorder),
    borderRadius: r,
  );
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
    final fg = _fg(t, kind);
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
          decoration: _buttonBox(
            t,
            kind,
            look,
            BorderRadius.circular(NushiTheme.control),
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

/// A button with a second part beside it, a ▾ that opens a menu of how it
/// goes ("Squash and merge" and the other methods): [label] is the way
/// picked, and pressing it does that.
class SplitButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    required this.entries,
    super.key,
    this.kind = ButtonKind.primary,
    this.tooltip = '',
    this.menuTooltip = '',
  });

  final String label;
  final VoidCallback? onPressed;
  final List<MenuEntry> entries;
  final ButtonKind kind;
  final String tooltip;
  final String menuTooltip;

  /// One part: rounded on its outer side only.
  Widget _part(
    BuildContext context,
    ControlLook look,
    BorderRadius r,
    Widget child,
  ) {
    final t = NushiTheme.of(context).t;
    return _faded(
      look,
      Container(
        height: controlHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: _buttonBox(t, kind, look, r),
        foregroundDecoration: focusRing(t, look, radius: r),
        // As wide as its content, whatever room it's given.
        child: Center(widthFactor: 1, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final primary = kind == ButtonKind.primary;
    final fg = _fg(t, kind);
    const round = Radius.circular(NushiTheme.control);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Pressable(
            onTap: onPressed,
            tooltip: tooltip,
            builder: (context, look) => _part(
              context,
              look,
              const BorderRadius.horizontal(left: round),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(fg, weight: primary ? FontWeight.w500 : null),
              ),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Menu(
          entries: entries,
          builder: (context, open) => Pressable(
            onTap: entries.isEmpty ? null : open,
            tooltip: menuTooltip,
            builder: (context, look) => _part(
              context,
              look,
              const BorderRadius.horizontal(right: round),
              Icon(Icons.keyboard_arrow_down, size: 15, color: fg),
            ),
          ),
        ),
      ],
    );
  }
}

/// Send to agent's button, wherever something goes into the chat's box
/// as a reply card (Send, Fix checks, Address, Send all): its arrow and
/// [label] on the accent's fill, as a primary [Button]. Every one looks
/// alike; a tint read as a disabled button (the owner, 2026-11-09), so
/// only one that can't be pressed is faded.
class SendButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.tooltip = '',
  });

  final String label;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Pressable(
      onTap: onPressed,
      tooltip: tooltip,
      builder: (context, look) => _faded(
        look,
        Container(
          height: controlHeight,
          padding: const EdgeInsets.fromLTRB(7, 0, 9, 0),
          decoration: _buttonBox(
            t,
            ButtonKind.primary,
            look,
            BorderRadius.circular(NushiTheme.control),
          ),
          foregroundDecoration: focusRing(t, look),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.subdirectory_arrow_right, size: 14, color: t.onAccent),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(
                    t.onAccent,
                    size: 12.5,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
