import 'package:flutter/widgets.dart';

import 'package:nushi/clock.dart';

/// [text] on one line in [style], again every second while [live]: a
/// running time ("12s", a subagent's "Thinking, 40s"), in tabular figures
/// so it doesn't jitter as it ticks.
class LiveText extends StatefulWidget {
  const new(this.text, {required this.live, required this.style, super.key});

  final String Function() text;
  final bool live;
  final TextStyle style;

  @override
  State<LiveText> createState() => _LiveTextState();
}

class _LiveTextState extends State<LiveText> {
  // It ticks on the one secondClock, and only while live: every row of
  // the transcript stays built (ADR 0026). Not while its tickers are off
  // either: built but not drawn (the details rail tucked away, ADR 0123),
  // it has no one to show the time to. A tick finds it scrolled out of
  // its view, it waits for the next.
  bool _listens = false;
  bool _ticks = true;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ticks = TickerMode.valuesOf(context).enabled;
    if (ticks == _ticks) return;
    _ticks = ticks;
    _sync();
  }

  @override
  void didUpdateWidget(LiveText old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    if (_listens) secondClock.removeListener(_tick);
    super.dispose();
  }

  void _sync() {
    final listen = widget.live && _ticks;
    if (listen == _listens) return;
    _listens = listen;
    if (listen) {
      secondClock.addListener(_tick);
    } else {
      secondClock.removeListener(_tick);
    }
  }

  void _tick() {
    if (_shown()) setState(() {});
  }

  /// Whether any of it is inside its scrolling view (the transcript's), or
  /// it has none.
  bool _shown() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final view = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (view is! RenderBox || !view.hasSize) return true;
    final at = box.localToGlobal(Offset.zero) & box.size;
    return at.overlaps(view.localToGlobal(Offset.zero) & view.size);
  }

  @override
  Widget build(BuildContext context) => Text(
    widget.text(),
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
    style: widget.style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
