import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nushi/run_state.dart';

/// The fonts an emoji in a mark is set in, by name, so it's the same font
/// wherever the system's own fallback would look: the Mac's, then Linux's.
const emojiFonts = ['Apple Color Emoji', 'Noto Color Emoji'];

/// Whether a mark is put where its ink is in the middle ([TileMark]). A
/// test's goldens are taken without (`flutter_test_config.dart`): the
/// measuring waits on the engine, which a test's clock doesn't.
bool centreMarksByInk = true;

/// How far each mark measured so far has to move, by what it is.
final Map<String, Offset> _nudges = runMap();
final Map<String, Future<Offset>> _measuring = runMap();

/// Whether a mark is being measured now (a test waits for it).
@visibleForTesting
bool get measuringMarks => _measuring.isNotEmpty;

/// A tile's mark (its initials, or the emoji or characters the user set)
/// with its ink in the middle of the tile.
///
/// A line of text is centred by its line box, which is as high as the
/// text's font says and has that font's baseline: capitals sit a little
/// low in it, and an emoji, drawn from another font with other measures,
/// sat visibly off the middle (the owner saw one low and left in its
/// tile). No font's measures say where a glyph's ink is, so the mark is
/// drawn once off screen, the box of what it painted is found, and the
/// text is moved by the difference; what it found is kept by text and
/// size, so each mark is measured once. Until then it's centred by its
/// line.
class TileMark extends StatefulWidget {
  const new(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  State<TileMark> createState() => _TileMarkState();
}

class _TileMarkState extends State<TileMark> {
  /// The screen's pixels to a point: the mark is measured as it's drawn.
  double _scale = 1;

  /// The style the text is drawn in: the one given over the one around
  /// it, as [Text] has it. What's around says how a line's height is
  /// shared out over and under its glyphs, which moves them.
  late TextStyle _style;

  String get _key {
    final s = _style;
    return '${widget.text}\n${s.fontSize}\n${s.fontWeight?.value}\n'
        '${s.letterSpacing}\n${s.fontFamily}\n${s.height}\n'
        '${s.leadingDistribution}\n$_scale';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scale = MediaQuery.devicePixelRatioOf(context);
    _style = DefaultTextStyle.of(context).style.merge(widget.style);
    _measure();
  }

  @override
  void didUpdateWidget(TileMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _style = DefaultTextStyle.of(context).style.merge(widget.style);
    _measure();
  }

  void _measure() {
    final key = _key;
    if (!centreMarksByInk || _nudges.containsKey(key)) return;
    final measured = _measuring[key] ??= _nudge(widget.text, _style, _scale);
    unawaited(
      measured.then((nudge) {
        _nudges[key] = nudge;
        unawaited(_measuring.remove(key));
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: (centreMarksByInk ? _nudges[_key] : null) ?? Offset.zero,
    child: Text(
      widget.text,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      // The mark's own size, not the theme's text scale.
      textScaler: TextScaler.noScaling,
      style: widget.style,
    ),
  );
}

/// How far [text] in [style], centred by its line box, has to move for
/// what it paints to be centred: drawn on a clear canvas at [scale], the
/// screen's own (an emoji is a picture for each size, each placed a
/// little differently: measured at another scale it came out a point or
/// two off), with room around it for a glyph that reaches past its line.
/// Nothing for a mark that paints nothing, or if the engine can't draw it.
Future<Offset> _nudge(String text, TextStyle style, double scale) async {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final line = Offset.zero & painter.size;
  final pad = (style.fontSize ?? 14).ceilToDouble();
  final width = ((line.width + 2 * pad) * scale).ceil();
  final height = ((line.height + 2 * pad) * scale).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  painter
    ..paint(canvas, Offset(pad, pad))
    ..dispose();
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData();
    image.dispose();
    if (data == null) return Offset.zero;
    var (left, top, right, bottom) = (width, height, -1, -1);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // More than a trace of ink: an edge's faintest pixels aren't
        // what the eye centres.
        if (data.getUint8((y * width + x) * 4 + 3) < 48) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < left) return Offset.zero;
    final ink = Rect.fromLTRB(
      left / scale - pad,
      top / scale - pad,
      (right + 1) / scale - pad,
      (bottom + 1) / scale - pad,
    );
    return line.center - ink.center;
  } on Object {
    return Offset.zero;
  } finally {
    picture.dispose();
  }
}
