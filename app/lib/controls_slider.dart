part of 'controls.dart';

/// A value along a line, [value] from 0 to 1 (a zoom): a thin track, the
/// part before the thumb in the accent, a round thumb with a tint around
/// it under the pointer; from the keyboard the arrow keys move it. [label]
/// names it to a screen reader.
class LineSlider extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Semantics(
      label: label,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          activeTrackColor: t.accent,
          inactiveTrackColor: t.fieldBorder,
          disabledActiveTrackColor: t.textMuted,
          disabledInactiveTrackColor: t.fieldBorder,
          thumbColor: t.accent,
          disabledThumbColor: t.textMuted,
          overlayColor: t.hover,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 7,
            elevation: 0,
            pressedElevation: 0,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          trackShape: const RoundedRectSliderTrackShape(),
          showValueIndicator: ShowValueIndicator.never,
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: SizedBox(
          height: controlHeight,
          child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
        ),
      ),
    );
  }
}
