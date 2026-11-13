import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_frames.dart';
import 'package:nushi/tile_trim.dart';

/// Trimming a tile's own animated image, in Change tile… (ADR 0112), as
/// the iPhone's Photos trims a video: a strip of [frames]' thumbnails, a
/// handle at each end of the part kept (its outline in the accent, the
/// rest dimmed), a playhead to drag through it, and Play, which plays the
/// part kept in the framing square, looping. While a handle or the
/// playhead moves, the times show under the strip. Only for an image of
/// more than one frame; [onChanged] after each change of the trim.
class TileTrimmer extends StatefulWidget {
  const new({required this.frames, required this.onChanged, super.key});

  /// The strip's height.
  static const height = 40.0;

  /// A handle's width, outside the part kept.
  static const handle = 12.0;

  final TileFrames frames;
  final VoidCallback onChanged;

  @override
  State<TileTrimmer> createState() => _TileTrimmerState();
}

/// What a drag on the strip moves.
enum _Moving { nothing, start, end, playhead }

class _TileTrimmerState extends State<TileTrimmer> {
  _Moving _moving = _Moving.nothing;

  TileFrames get _frames => widget.frames;

  /// Where [time] is across a strip [width] wide: between the handles'
  /// room at each end.
  double _x(Duration time, double width) {
    final length = _frames.length.inMicroseconds;
    final inner = width - 2 * TileTrimmer.handle;
    return TileTrimmer.handle +
        (length == 0 ? 0 : inner * time.inMicroseconds / length);
  }

  Duration _time(double x, double width) {
    final inner = max(1, width - 2 * TileTrimmer.handle);
    final part = ((x - TileTrimmer.handle) / inner).clamp(0.0, 1.0);
    return _frames.length * part;
  }

  void _begin(Offset at, double width) {
    final f = _frames;
    final left = _x(f.startOf(f.start), width);
    final right = _x(f.startOf(f.end), width);
    const reach = TileTrimmer.handle + 4;
    // The nearer handle, if the pointer is on or just past one.
    final toLeft = (at.dx - (left - TileTrimmer.handle / 2)).abs();
    final toRight = (at.dx - (right + TileTrimmer.handle / 2)).abs();
    _moving = toLeft <= toRight && toLeft <= reach
        ? _Moving.start
        : toRight <= reach
        ? _Moving.end
        : _Moving.playhead;
    setState(() {});
    _move(at, width);
  }

  void _move(Offset at, double width) {
    final f = _frames;
    final time = _time(at.dx, width);
    switch (_moving) {
      case _Moving.start:
        f.moveStart(f.boundaryAt(time));
        widget.onChanged();
      case _Moving.end:
        f.moveEnd(f.boundaryAt(time));
        widget.onChanged();
      case _Moving.playhead:
        f.scrub(f.frameAt(time));
      case _Moving.nothing:
        break;
    }
  }

  void _end() {
    // A handle let go: the square shows the start again, as the tile
    // will at rest.
    if (_moving case _Moving.start || _Moving.end) _frames.rest();
    setState(() => _moving = _Moving.nothing);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.frames,
    builder: (context, _) {
      final f = _frames;
      if (!f.loaded || f.count < 2) return const SizedBox.shrink();
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final label = switch (_moving) {
        _Moving.start || _Moving.end =>
          '${trimClock(f.startOf(f.start))} – ${trimClock(f.startOf(f.end))}',
        _Moving.playhead => trimClock(f.startOf(f.playhead)),
        _Moving.nothing => '',
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 6,
            children: [
              IconTap.line(
                f.playing ? LineIcon.pause : LineIcon.play,
                tooltip: f.playing ? 'Pause' : 'Play',
                size: 18,
                color: t.text,
                onTap: f.toggle,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final width = box.maxWidth;
                    return GestureDetector(
                      key: const Key('tile trim strip'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragDown: (d) =>
                          _begin(d.localPosition, width),
                      onHorizontalDragUpdate: (d) =>
                          _move(d.localPosition, width),
                      onHorizontalDragEnd: (_) => _end(),
                      onHorizontalDragCancel: _end,
                      child: CustomPaint(
                        size: Size(width, TileTrimmer.height),
                        painter: _Strip(
                          thumbs: f.thumbs,
                          left: _x(f.startOf(f.start), width),
                          right: _x(f.startOf(f.end), width),
                          playhead: _x(f.startOf(f.playhead), width),
                          tokens: t,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Under the strip's middle; its line is there while it's empty,
          // so nothing moves when the times come.
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: SizedBox(
              height: 16,
              width: double.infinity,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The strip: [thumbs] across between the handles' room, dimmed outside
/// [left] to [right], those framed in the accent with a handle at each
/// end, and the playhead's line at [playhead].
class _Strip extends CustomPainter {
  const new({
    required this.thumbs,
    required this.left,
    required this.right,
    required this.playhead,
    required this.tokens,
  });

  final List<ui.Image> thumbs;
  final double left;
  final double right;
  final double playhead;
  final Tokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    const h = TileTrimmer.handle;
    const bar = 3.0; // the outline's top and bottom
    final t = tokens;
    final inner = Rect.fromLTRB(h, bar, size.width - h, size.height - bar);
    final cell = inner.width / max(1, thumbs.length);
    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(inner, const Radius.circular(NushiTheme.tag)),
      );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final (i, image) in thumbs.indexed) {
      final to = Rect.fromLTWH(
        inner.left + i * cell,
        inner.top,
        cell,
        inner.height,
      );
      canvas.drawImageRect(image, _cover(image, to.size), to, paint);
    }
    // Outside the part kept, dimmed.
    final dim = Paint()..color = t.scrim.withValues(alpha: 0.55);
    canvas
      ..drawRect(Rect.fromLTRB(inner.left, inner.top, left, inner.bottom), dim)
      ..drawRect(
        Rect.fromLTRB(right, inner.top, inner.right, inner.bottom),
        dim,
      )
      ..restore();
    // The part kept, framed: a bar along its top and bottom, a handle at
    // each end.
    final frame = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromLTRBR(
          left - h,
          0,
          right + h,
          size.height,
          const Radius.circular(NushiTheme.control),
        ),
      )
      ..addRect(Rect.fromLTRB(left, bar, right, size.height - bar));
    canvas.drawPath(frame, Paint()..color = t.accent);
    final chevron = Paint()
      ..color = t.onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final mid = size.height / 2;
    canvas
      ..drawPath(
        Path()
          ..moveTo(left - h / 2 + 2, mid - 5)
          ..lineTo(left - h / 2 - 2, mid)
          ..lineTo(left - h / 2 + 2, mid + 5),
        chevron,
      )
      ..drawPath(
        Path()
          ..moveTo(right + h / 2 - 2, mid - 5)
          ..lineTo(right + h / 2 + 2, mid)
          ..lineTo(right + h / 2 - 2, mid + 5),
        chevron,
      );
    // The playhead: a thin line, edged so it reads on any picture.
    final x = playhead.clamp(left + 1.5, right - 1.5);
    final line = Rect.fromLTRB(x - 1.5, 1, x + 1.5, size.height - 1);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          line.inflate(0.5),
          const Radius.circular(NushiTheme.tag),
        ),
        Paint()..color = t.shadow,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(line, const Radius.circular(NushiTheme.tag)),
        Paint()..color = t.onAccent,
      );
  }

  /// The middle of [image] of the shape of [cell], as a cell shows it.
  static Rect _cover(ui.Image image, Size cell) {
    final (w, h) = (image.width.toDouble(), image.height.toDouble());
    final scale = max(cell.width / w, cell.height / h);
    final (sw, sh) = (cell.width / scale, cell.height / scale);
    return Rect.fromLTWH((w - sw) / 2, (h - sh) / 2, sw, sh);
  }

  @override
  bool shouldRepaint(_Strip old) =>
      old.thumbs != thumbs ||
      old.left != left ||
      old.right != right ||
      old.playhead != playhead ||
      old.tokens != tokens;
}
