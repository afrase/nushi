part of 'controls.dart';

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
/// where the icon alone says what it does. [held] keeps the tint while what
/// it toggles is on (a pinned message's pin).
class IconTap extends StatelessWidget {
  const new(
    IconData this.icon, {
    required this.tooltip,
    required this.onTap,
    super.key,
    this.size = 16,
    this.color,
    this.padding = 5,
    this.held = false,
  }) : line = null,
       glyph = null,
       _working = false;

  /// The same button with a drawn [LineIcon].
  const new line(
    LineIcon this.line, {
    required this.tooltip,
    required this.onTap,
    super.key,
    this.size = 16,
    this.color,
    this.padding = 5,
  }) : icon = null,
       glyph = null,
       _working = false,
       held = false;

  /// The same button with [glyph] drawn in the icon's place, at the
  /// icon's size and in its color (a chevron that turns).
  const new drawn(
    Widget Function(double size, Color color) this.glyph, {
    required this.tooltip,
    required this.onTap,
    super.key,
    this.size = 16,
    this.color,
    this.padding = 5,
  }) : icon = null,
       line = null,
       _working = false,
       held = false;

  /// A button for something that runs: held down (tinted) with [glyph]
  /// (a spinner) at rest, and [icon] (✕, to stop it) under the pointer.
  const new working(
    Widget Function(double size, Color color) this.glyph,
    IconData this.icon, {
    required this.tooltip,
    required this.onTap,
    super.key,
    this.size = 16,
    this.color,
    this.padding = 5,
  }) : line = null,
       _working = true,
       held = false;

  final IconData? icon;
  final LineIcon? line;
  final Widget Function(double size, Color color)? glyph;
  final bool _working;
  final bool held;
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
      builder: (context, look) {
        final tint = look.enabled ? color ?? t.textSecondary : t.textMuted;
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: look.hover
                ? _tint(t, look)
                : _working || held
                ? t.hover
                : null,
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          foregroundDecoration: focusRing(t, look),
          child:
              (_working && look.hover ? null : glyph?.call(size, tint)) ??
              line?.view(size: size, color: tint) ??
              Icon(icon, size: size, color: tint),
        );
      },
    );
  }
}

/// A round color to pick: [color], or with none a hollow ring, the one
/// picked ([selected]) ringed. [tooltip] names it; the ring and the name are
/// there without a pointer, and Tab, Enter and Space work it like any
/// control.
class Swatch extends StatelessWidget {
  const new({
    required this.color,
    required this.tooltip,
    required this.onTap,
    super.key,
    this.selected = false,
  });

  /// How much room it takes, and the color's own size in it.
  static const size = 18.0;
  static const _dot = 12.0;

  final Color? color;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        tooltip: tooltip,
        builder: (context, look) => _faded(
          look,
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: look.focus
                  ? Border.all(color: t.focus, width: 2)
                  : selected
                  ? Border.all(color: t.text, width: 1.5)
                  : look.hover
                  ? Border.all(color: t.fieldBorderHover, width: 1.5)
                  : null,
            ),
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: color == null
                    ? Border.all(color: t.textSecondary, width: 1.5)
                    : null,
              ),
            ),
          ),
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
  return keyText(keys, theme.code(color ?? theme.t.textMuted, size: 11));
}

/// A shortcut's [keys] in [style], `⌘` a size up: the code font's stands on
/// the baseline, shorter than a capital, and at this size it comes level
/// with the letter beside it. The line stays as high as [style]'s.
Widget keyText(String keys, TextStyle style) => Text.rich(
  TextSpan(
    children: [
      for (final m in RegExp('⌘|[^⌘]+').allMatches(keys))
        TextSpan(
          text: m[0],
          style: m[0] == '⌘'
              ? TextStyle(fontSize: style.fontSize! * 1.3)
              : null,
        ),
    ],
  ),
  style: style,
  strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
);
