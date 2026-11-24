part of 'controls.dart';

/// An on/off that can't be misread: a solid track in the accent when on,
/// a solid grey one when off (never a faint dot on a bare track), and a
/// round knob in the theme's on-accent colour (white in most sets, near
/// black where the accent is pastel), the same size either way, so only
/// the knob moves.
/// Clicking it, or Enter or Space with the focus, flips it; without
/// [onChanged] it's disabled (faded, as every control). Settings' rows use
/// it through `SettingsSwitch`.
class Toggle extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// The track's size.
  static const size = Size(36, 20);

  /// The knob's inset from the track's edge.
  static const _inset = 2.0;

  /// The grey of an off track: the muted text's, half strength, which
  /// reads as a solid grey on any surface of every theme.
  static Color offTrack(Tokens t) => t.textMuted.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final change = onChanged;
    final round = BorderRadius.circular(NushiTheme.pill);
    return Semantics(
      toggled: value,
      enabled: change != null,
      child: Pressable(
        onTap: change == null ? null : () => change(!value),
        role: PressRole.none, // a switch, as the Semantics above says
        builder: (context, look) {
          final fill = value ? t.accent : offTrack(t);
          final knob = size.height - 2 * _inset;
          return _faded(
            look,
            AnimatedContainer(
              duration: reduceMotion(context) ? Duration.zero : Motion.quick,
              curve: Motion.settle,
              width: size.width,
              height: size.height,
              padding: const EdgeInsets.all(_inset),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                // Under the pointer a shade over the fill, as a button's.
                color: look.hover
                    ? Color.alphaBlend(_tint(t, look), fill)
                    : fill,
                borderRadius: round,
              ),
              foregroundDecoration: value
                  ? accentFocusRing(t, look, radius: round)
                  : focusRing(t, look, radius: round),
              child: Container(
                width: knob,
                height: knob,
                decoration: BoxDecoration(
                  color: t.onAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: t.shadow,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
