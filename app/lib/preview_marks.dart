import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

/// ⌥Z (Alt+Z on Linux), while the preview has the focus and shows a
/// file's source: its lines wrap, or run on (VS Code's key for Word Wrap).
/// Not the app's: elsewhere ⌥Z types Ω.
const wrapKey = SingleActivator(LogicalKeyboardKey.keyZ, alt: true);

/// Wraps the lines of every preview's source, or stops wrapping them.
void toggleWrap() => wrapLines.value = !wrapLines.value;

/// What wrapping's button and palette row say: what they'll do.
String wrapLabel({required bool wrap}) =>
    wrap ? 'Don’t wrap lines' : 'Wrap lines';

/// The button over a file's source in the Mac's preview that wraps its
/// lines or not ([wrapLines]), held while they wrap, [wrapKey] in its
/// tooltip.
class WrapButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: wrapLines,
    builder: (context, wrap, _) => IconTap(
      Icons.wrap_text,
      tooltip: '${wrapLabel(wrap: wrap)}  ${keyLabel(wrapKey)}',
      size: 15,
      held: wrap,
      onTap: toggleWrap,
    ),
  );
}

/// The Preview and Source tabs over a file that renders.
class SourceSwitch extends StatelessWidget {
  const new({required this.source, required this.onChanged, super.key});

  final bool source;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => PlainTabs(
    value: source,
    tabs: const [(false, 'Preview'), (true, 'Source')],
    onChanged: onChanged,
    fill: true,
  );
}

/// The green mark of a preview the daemon keeps current; its dot pulses
/// once each time [version] (the file as last sent) changes.
class LiveMark extends StatefulWidget {
  const new({super.key, this.size = 12, this.version});

  final double size;
  final Object? version;

  @override
  State<LiveMark> createState() => _LiveMarkState();
}

class _LiveMarkState extends State<LiveMark>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );
  late final Animation<double> _grow = _scale.animate(_pulse);

  // Up to 1.8 times its size and back, each way easing out.
  static final Animatable<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.8,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.8,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 70,
    ),
  ]);

  @override
  void didUpdateWidget(LiveMark old) {
    super.didUpdateWidget(old);
    if (old.version != null &&
        !identical(old.version, widget.version) &&
        !reduceMotion(context)) {
      _pulse.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Tooltip(
      message: 'Updates as the file changes',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          ScaleTransition(
            scale: _grow,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: t.done, shape: BoxShape.circle),
            ),
          ),
          Text('Live', style: theme.ui(t.done, size: widget.size)),
        ],
      ),
    );
  }
}
