part of 'controls.dart';

enum ButtonKind {
  /// The one main action of a dialog, a card or a bar: the accent's fill.
  primary,

  /// Every other action: the lifted fill, no outline (ADR 0111).
  secondary,

  /// An action beside a filled one that should stand back (an inline
  /// box's Cancel): no fill until the pointer is on it.
  quiet,

  /// One that deletes or loses something: red text on the lifted fill.
  destructive,

  /// The same beside a dialog's own Done, as Claude desktop draws it (its
  /// Allowed sites' Clear all): red text on a faint red fill.
  danger,
}

/// The ink of a button of [kind].
Color _fg(Tokens t, ButtonKind kind) => switch (kind) {
  ButtonKind.primary => t.onAccent,
  ButtonKind.secondary || ButtonKind.quiet => t.text,
  ButtonKind.destructive || ButtonKind.danger => t.crashed,
};

/// A button's fill, as [look] has it, rounded by [r]: the accent's for a
/// primary one, a shade lighter under the pointer and darker pressed; a
/// faint red for a danger one, and for a destructive one under the
/// pointer; none for a quiet one; else the lifted fill. The pointer's tint
/// goes over each. No kind has an outline: a
/// button is told from what it sits on by its fill (ADR 0111).
BoxDecoration _buttonBox(
  Tokens t,
  ButtonKind kind,
  ControlLook look,
  BorderRadius r,
) {
  if (kind == ButtonKind.primary) {
    return BoxDecoration(
      color: look.pressed
          ? t.accentPressed
          : look.hover
          ? Color.alphaBlend(t.onAccent.withValues(alpha: 0.12), t.accent)
          : t.accent,
      borderRadius: r,
    );
  }
  if (kind == ButtonKind.quiet) {
    return BoxDecoration(
      color: look.hover ? _tint(t, look) : null,
      borderRadius: r,
    );
  }
  if (kind == ButtonKind.destructive && look.hover) {
    // Its red is under AA on the lifted fill once the pointer's tint is
    // over that, and reads on the red's own soft fill (`tokens_test`).
    return BoxDecoration(
      color: look.pressed
          ? Color.alphaBlend(t.pressed, t.crashedSoft)
          : t.crashedSoft,
      borderRadius: r,
    );
  }
  final fill = kind == ButtonKind.danger ? t.crashedSoft : t.lifted;
  return BoxDecoration(
    color: look.hover ? Color.alphaBlend(_tint(t, look), fill) : fill,
    borderRadius: r,
  );
}

/// The focus ring of a button of [kind]: on the accent's fill, the one
/// that stands off it.
Decoration? _ring(
  Tokens t,
  ButtonKind kind,
  ControlLook look,
  BorderRadius r,
) => kind == ButtonKind.primary
    ? accentFocusRing(t, look, radius: r)
    : focusRing(t, look, radius: r);

/// A button: [label], an optional leading [icon], a shortcut [hint] after
/// the label (not on a phone). Its height, padding, type and corners are
/// its place's [ControlSize]; stretched wider than its content, the
/// content is centred.
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
    final size = ControlSize.of(context);
    final style = theme.ui(fg, size: size.text, weight: FontWeight.w500);
    final touch = TouchTargets.of(context);
    final lines = wrap && touch ? 3 : 1;
    final corners = BorderRadius.circular(size.radius);
    return Pressable(
      onTap: onPressed,
      autofocus: autofocus,
      tooltip: tooltip,
      builder: (context, look) => _faded(
        look,
        Container(
          height: lines > 1 ? null : size.height,
          constraints: BoxConstraints(
            minHeight: lines > 1 ? size.height : 0,
            minWidth: size.minWidth,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: size.pad,
            vertical: lines > 1 ? 5 : 0,
          ),
          decoration: _buttonBox(t, kind, look, corners),
          foregroundDecoration: _ring(t, kind, look, corners),
          // Centred when its parent stretches it (the sidebar's New chat);
          // a value picker is a MenuField, which keeps its value at the left.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size.icon, color: fg),
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

/// A row-wide action on the window's background or a pane (the sidebar's
/// New chat, ADR 0111): a card's fill and no outline, taller than a
/// [Button], [icon] and [label] at its start and its shortcut [hint] as a
/// key's cap at its end.
class WideButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.hint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? hint;

  static const height = 38.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    // Its corners are its height's share, as every control's (ADR 0122).
    final corners = BorderRadius.circular(ControlSize.radiusFor(height));
    return Pressable(
      onTap: onPressed,
      builder: (context, look) => _faded(
        look,
        Container(
          height: height,
          padding: const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
            color: look.hover
                ? Color.alphaBlend(_tint(t, look), t.raised)
                : t.raised,
            borderRadius: corners,
          ),
          foregroundDecoration: focusRing(t, look, radius: corners),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: t.text),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, weight: FontWeight.w500),
                ),
              ),
              if (hint case final hint?) KeyCap(hint),
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
    final size = ControlSize.of(context);
    return _faded(
      look,
      Container(
        height: size.height,
        padding: EdgeInsets.symmetric(horizontal: size.pad - 2),
        decoration: _buttonBox(t, kind, look, r),
        foregroundDecoration: _ring(t, kind, look, r),
        // As wide as its content, whatever room it's given.
        child: Center(widthFactor: 1, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final fg = _fg(t, kind);
    final size = ControlSize.of(context);
    final round = Radius.circular(size.radius);
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
              BorderRadius.horizontal(left: round),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(fg, size: size.text, weight: FontWeight.w500),
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
              BorderRadius.horizontal(right: round),
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
    final size = ControlSize.of(context);
    final corners = BorderRadius.circular(size.radius);
    return Pressable(
      onTap: onPressed,
      tooltip: tooltip,
      builder: (context, look) => _faded(
        look,
        Container(
          height: size.height,
          padding: EdgeInsets.fromLTRB(size.pad - 3, 0, size.pad - 1, 0),
          decoration: _buttonBox(t, ButtonKind.primary, look, corners),
          foregroundDecoration: accentFocusRing(t, look, radius: corners),
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
                    size: size.text,
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
