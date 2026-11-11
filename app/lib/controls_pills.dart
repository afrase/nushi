part of 'controls.dart';

/// A pill-shaped button on a card (ADR 0111): [label], an optional leading
/// [icon], on the card's lifted fill, no outline. In the composer's row
/// (Queue, Stop and send); [small], in a tool call's row (Preview, Open),
/// where [on] fills it with the accent's soft tint while what it opens is
/// the one open.
class PillButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.tooltip = '',
    this.small = false,
    this.on = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String tooltip;
  final bool small;
  final bool on;

  /// The composer's row's height: its pills, pickers and round buttons.
  static const height = 32.0;

  /// A [small] pill's height.
  static const smallHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final fg = on ? t.accentInk : t.text;
    final fill = on ? t.accentSoft : t.lifted;
    final round = BorderRadius.circular(NushiTheme.pill);
    return Pressable(
      onTap: onPressed,
      tooltip: tooltip,
      builder: (context, look) => _faded(
        look,
        Container(
          height: small ? smallHeight : height,
          padding: EdgeInsets.symmetric(horizontal: small ? 10 : 12),
          decoration: BoxDecoration(
            color: look.hover ? Color.alphaBlend(_tint(t, look), fill) : fill,
            borderRadius: round,
          ),
          foregroundDecoration: focusRing(t, look, radius: round),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: small ? 5 : 6,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: small ? 13 : 15,
                  color: on ? fg : t.textSecondary,
                ),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(
                    fg,
                    size: small ? 12 : 12.5,
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

/// What a [RoundButton] is for, which says its fill.
enum RoundKind {
  /// One more thing to do (the composer's +, a pill's action without its
  /// words): the card's lifted fill.
  plain,

  /// The one main action (Send): the accent's fill.
  primary,

  /// Stop: solid red, so it is never mistaken ([Tokens.stop]).
  stop,
}

/// A round icon button on a card (ADR 0111), [PillButton.height] across:
/// [glyph] draws its mark in the color its [kind] gives.
class RoundButton extends StatelessWidget {
  const new({
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    super.key,
    this.kind = RoundKind.plain,
  });

  final Widget Function(Color color) glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final RoundKind kind;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final (fill, fg) = switch (kind) {
      RoundKind.plain => (t.lifted, t.text),
      RoundKind.primary => (t.accent, t.onAccent),
      RoundKind.stop => (t.stop, t.onStop),
    };
    final round = BorderRadius.circular(NushiTheme.pill);
    return Pressable(
      onTap: onPressed,
      tooltip: tooltip,
      builder: (context, look) => _faded(
        look,
        Container(
          width: PillButton.height,
          height: PillButton.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: look.pressed && kind == RoundKind.primary
                ? t.accentPressed
                : look.hover
                ? Color.alphaBlend(_tint(t, look), fill)
                : fill,
            borderRadius: round,
          ),
          foregroundDecoration: focusRing(t, look, radius: round),
          child: glyph(fg),
        ),
      ),
    );
  }
}
