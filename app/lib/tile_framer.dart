import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_picture.dart';

/// Framing a tile's own image, in Change tile… (ADR 0112): the square the
/// tile will show, larger, to drag the picture in and zoom (a scroll, a
/// pinch or the Zoom slider), and Reset framing for the middle square
/// again. It shows [picture]'s first frame, decoded once at a few times
/// its own size so zooming in stays sharp a while, never the picture's
/// own size; [crop] is what's set (null for the middle), and each change
/// goes to [onChanged], the middle as null.
class TileFramer extends StatefulWidget {
  const new({
    required this.picture,
    required this.crop,
    required this.onChanged,
    required this.fill,
    super.key,
  });

  /// The framing square's side.
  static const size = 112.0;

  /// How many times the square's pixels the picture is decoded at.
  static const _detail = 3;

  final TilePicture picture;
  final TileCrop? crop;
  final ValueChanged<TileCrop?> onChanged;

  /// Behind the picture where it's see-through, as the tile has it.
  final Color fill;

  @override
  State<TileFramer> createState() => TileFramerState();
}

/// The state of a [TileFramer]; a test waits on its picture.
class TileFramerState extends State<TileFramer> {
  ui.Image? _image;
  int _decodes = 0; // which decode is the current one
  TileCrop _from = const TileCrop(); // the crop a gesture started from
  Offset _start = Offset.zero; // where it started, in the square
  bool _dragging = false;

  /// Whether its picture is decoded and shown.
  @visibleForTesting
  bool get decoded => _image != null;

  TileCrop get _crop => widget.crop ?? const TileCrop();

  Size get _size => Size(_image!.width.toDouble(), _image!.height.toDouble());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decodes == 0) unawaited(_decode());
  }

  @override
  void didUpdateWidget(TileFramer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.picture.key == widget.picture.key) return;
    // The last picture's shape would frame this one wrong: none until
    // it's decoded.
    final before = _image;
    _image = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => before?.dispose());
    unawaited(_decode());
  }

  @override
  void dispose() {
    _decodes++;
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final run = ++_decodes;
    final side =
        (TileFramer.size *
                MediaQuery.devicePixelRatioOf(context) *
                TileFramer._detail)
            .ceil();
    ui.Image? image;
    try {
      final codec = await tileImageCodec(await widget.picture.read(), side);
      try {
        image = await tileFrame((await codec.getNextFrame()).image, side);
      } finally {
        codec.dispose();
      }
    } on Object {
      image = null; // not an image after all: the square stays empty
    }
    if (run != _decodes || !mounted) return image?.dispose();
    final before = _image;
    setState(() => _image = image);
    WidgetsBinding.instance.addPostFrameCallback((_) => before?.dispose());
  }

  void _set(TileCrop crop) => widget.onChanged(crop.isWhole ? null : crop);

  void _begin(ScaleStartDetails d) {
    _from = _crop;
    _start = d.localFocalPoint;
    setState(() => _dragging = true);
  }

  /// A drag moves the picture with the pointer; a pinch zooms about where
  /// it started, then follows it.
  void _update(ScaleUpdateDetails d) {
    if (_image == null) return;
    const side = TileFramer.size;
    _set(
      _from
          .zoomed(_from.zoom * d.scale, _size, focal: _start / side)
          .panned((d.localFocalPoint - _start) / side, _size),
    );
  }

  void _end(ScaleEndDetails _) => setState(() => _dragging = false);

  /// A wheel's scroll zooms about the pointer.
  void _scroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _image == null) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      _set(
        _crop.zoomed(
          _crop.zoom * exp(-scroll.scrollDelta.dy / 200),
          _size,
          focal: scroll.localPosition / TileFramer.size,
        ),
      );
    });
  }

  static final double _top = log(TileCrop.maxZoom);

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final image = _image;
    final crop = _crop;
    final view = MouseRegion(
      cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: Listener(
        onPointerSignal: _scroll,
        child: GestureDetector(
          // A trackpad's two-finger scroll zooms, as a wheel's does; a
          // drag with the button down moves.
          trackpadScrollCausesScale: true,
          onScaleStart: _begin,
          onScaleUpdate: _update,
          onScaleEnd: _end,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(NushiTheme.control),
            child: SizedBox.square(
              dimension: TileFramer.size,
              child: ColoredBox(
                color: widget.fill,
                child: CustomPaint(painter: _Framed(image, crop)),
              ),
            ),
          ),
        ),
      ),
    );
    final muted = theme.ui(t.textMuted, size: 12);
    return Row(
      spacing: 14,
      children: [
        Semantics(
          label: 'Framing',
          child: KeyedSubtree(key: const Key('tile framing'), child: view),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                spacing: 4,
                children: [
                  Text('Zoom', style: theme.ui(t.textSecondary, size: 12)),
                  Expanded(
                    child: LineSlider(
                      label: 'Zoom',
                      value: log(crop.zoom) / _top,
                      onChanged: image == null
                          ? null
                          : (v) => _set(
                              crop.zoomed(
                                pow(TileCrop.maxZoom, v).toDouble(),
                                _size,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              Text('Drag to move it; scroll or pinch to zoom.', style: muted),
              Button(
                label: 'Reset framing',
                kind: ButtonKind.quiet,
                onPressed: widget.crop == null
                    ? null
                    : () => widget.onChanged(null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The square [crop] frames of [image], filling the canvas.
class _Framed extends CustomPainter {
  const new(this.image, this.crop);

  final ui.Image? image;
  final TileCrop crop;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    canvas.drawImageRect(
      image,
      crop.within(image.width, image.height),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_Framed old) => old.image != image || old.crop != crop;
}
