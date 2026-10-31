import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The Preview and Source tabs over a file that renders, the phone's still
/// the pill (ADR 0071).
class SourceSwitch extends StatelessWidget {
  const new({required this.source, required this.onChanged, super.key});

  final bool source;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = [(false, 'Preview'), (true, 'Source')];
    return TouchTargets.of(context)
        ? Segmented(value: source, segments: tabs, onChanged: onChanged)
        : PlainTabs(
            value: source,
            tabs: tabs,
            onChanged: onChanged,
            fill: true,
          );
  }
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
