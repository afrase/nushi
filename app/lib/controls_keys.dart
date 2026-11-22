part of 'controls.dart';

// A shortcut's keys: in small code beside what they do, on a small cap,
// and as the cap that is the control changing them (Settings › Keyboard
// shortcuts).

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
  _keySpan(keys, style),
  style: style,
  strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
);

/// [keys] as [keyText] draws them, `⌘` a size up.
TextSpan _keySpan(String keys, TextStyle style) => TextSpan(
  children: [
    for (final m in RegExp('⌘|[^⌘]+').allMatches(keys))
      TextSpan(
        text: m[0],
        style: m[0] == '⌘' ? TextStyle(fontSize: style.fontSize! * 1.3) : null,
      ),
  ],
);

/// The width [keys] take in [style] as [keyText] draws them, at the
/// text's scale in [context].
double keyTextWidth(BuildContext context, String keys, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(style: style, children: [_keySpan(keys, style)]),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    maxLines: 1,
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

/// A shortcut as a key's cap ([keyText] on a small raised chip): beside
/// the action it does (the sidebar's New chat) and on a chat's row while ⌘
/// is held. Nothing on a phone, which has no keys.
class KeyCap extends StatelessWidget {
  const new(this.keys, {super.key});

  final String keys;

  @override
  Widget build(BuildContext context) {
    // No key (one the user cleared), no cap.
    if (keys.isEmpty || TouchTargets.of(context)) {
      return const SizedBox.shrink();
    }
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.tag),
      ),
      child: keyText(keys, theme.code(t.textSecondary, size: 11)),
    );
  }
}

/// What a [KeyCapButton] holds.
enum KeyCapLook {
  /// A key, on `lifted`.
  key,

  /// A key the user chose: the accent's soft fill and its ink.
  chosen,

  /// No key: "None" in `textMuted` on a `fieldBorder` outline, no fill.
  none,

  /// Listening for keys: "Press keys…" on the accent's soft fill.
  listening,
}

/// A key's cap that is the control changing it (Settings › Keyboard
/// shortcuts): [keys] in code type 12, [look] saying what it holds,
/// [height] high, hugging its key and at least
/// [minWidth] wide so a short key isn't a crumb. [ring] draws the 2-point
/// focus ring (the keyboard's focus, or listening); [lit], the row it
/// sits on is under the pointer, puts the row's tint on it too, so the
/// cap keeps its edge there. Without [onTap] it's a key that can't change
/// (a fixed one): `textSecondary`, no hover, hand or focus.
class KeyCapButton extends StatelessWidget {
  const new(
    this.keys, {
    super.key,
    this.onTap,
    this.focusNode,
    this.look = KeyCapLook.key,
    this.ring = false,
    this.lit = false,
    this.tooltip = '',
  });

  final String keys;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final KeyCapLook look;
  final bool ring;
  final bool lit;
  final String tooltip;

  /// Its height at the text's own size.
  static const height = 24.0;

  /// Its least width.
  static const minWidth = 46.0;

  /// Its corners.
  static const double radius = NushiTheme.control;

  static const _pad = 8.0;

  /// The width of a cap holding [keys] in [context] ([minWidth] for none).
  static double widthOf(BuildContext context, String keys) {
    final theme = NushiTheme.of(context);
    final w = keyTextWidth(context, keys, theme.code(theme.t.text, size: 12));
    return max(minWidth, (w + 2 * _pad).ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final on = onTap != null;
    final words = switch (look) {
      KeyCapLook.listening => Text(
        'Press keys…',
        maxLines: 1,
        style: theme.ui(t.accentInk, size: 12, weight: FontWeight.w600),
      ),
      KeyCapLook.none => Text(
        'None',
        maxLines: 1,
        style: theme.ui(t.textMuted, size: 12),
      ),
      KeyCapLook.chosen => keyText(keys, theme.code(t.accentInk, size: 12)),
      KeyCapLook.key => keyText(
        keys,
        theme.code(on ? t.text : t.textSecondary, size: 12),
      ),
    };
    final base = switch (look) {
      KeyCapLook.listening || KeyCapLook.chosen => t.accentSoft,
      KeyCapLook.none => null,
      KeyCapLook.key => t.lifted,
    };
    final fill = lit && base != null ? Color.alphaBlend(t.hover, base) : base;
    final ringed = ring || (on && (ShowLook.of(context)?.focus ?? false));
    final border = ringed
        ? Border.all(color: t.focus, width: 2)
        : look == KeyCapLook.none
        ? Border.all(color: t.fieldBorder)
        : null;
    final box = Container(
      height: height,
      constraints: const BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: _pad),
      foregroundDecoration: border == null
          ? null
          : BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(radius),
            ),
      // Hugging its words, wherever it's put.
      child: Center(widthFactor: 1, child: words),
    );
    if (!on) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: box,
      );
    }
    return Tap(
      focusNode: focusNode,
      onTap: onTap,
      tooltip: tooltip,
      fill: fill,
      child: box,
    );
  }
}
