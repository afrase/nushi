import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;

/// How a tile's own image is framed in its square (ADR 0112): [zoom] times
/// closer than the square of the image's shorter side, which is what a
/// tile shows with none, centred at [x] and [y], fractions of the image's
/// width and height. It's kept beside the image's name in `projectTiles`,
/// never by changing the file: a GIF still plays, and framing it again
/// starts from the whole picture. Null for a tile is the square from the
/// image's middle, as a tile without one has always shown.
@immutable
class TileCrop {
  const new({this.zoom = 1, this.x = 0.5, this.y = 0.5});

  /// [saved] as `app.json` has it; null when it isn't one, or frames as
  /// none does.
  static TileCrop? read(Object? saved) {
    if (saved is! Map) return null;
    double? number(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    final (zoom, x, y) = (
      number(saved['zoom']),
      number(saved['x']),
      number(saved['y']),
    );
    if (zoom == null || x == null || y == null) return null;
    final crop = TileCrop(
      zoom: zoom.clamp(1, maxZoom),
      x: x.clamp(0, 1),
      y: y.clamp(0, 1),
    );
    return crop.isWhole ? null : crop;
  }

  /// The closest it goes: a subject an eighth of the picture's shorter
  /// side fills the tile.
  static const maxZoom = 8.0;

  final double zoom;
  final double x;
  final double y;

  /// Whether it shows what no crop does: the middle square, unzoomed.
  bool get isWhole => key == const TileCrop().key;

  /// The square it shows of an image [width] by [height], in that image's
  /// pixels: a side of the shorter one over [zoom], kept inside the image.
  Rect within(num width, num height) {
    final (w, h) = (width.toDouble(), height.toDouble());
    final side = min(w, h) / zoom.clamp(1, maxZoom);
    final left = (x * w - side / 2).clamp(0.0, w - side);
    final top = (y * h - side / 2).clamp(0.0, h - side);
    return Rect.fromLTWH(left, top, side, side);
  }

  /// It as an image of [size] shows it: the centre its square really has,
  /// so a drag past an edge stops there rather than storing a centre
  /// beyond it.
  TileCrop fitted(Size size) {
    final shown = within(size.width, size.height);
    return TileCrop(
      zoom: zoom.clamp(1, maxZoom),
      x: shown.center.dx / size.width,
      y: shown.center.dy / size.height,
    );
  }

  /// Moved by [by], in the square's own widths (a drag across the whole
  /// square is 1), the picture following the pointer.
  TileCrop panned(Offset by, Size size) {
    final side = within(size.width, size.height).width;
    return TileCrop(
      zoom: zoom,
      x: x - by.dx * side / size.width,
      y: y - by.dy * side / size.height,
    ).fitted(size);
  }

  /// Zoomed to [to] about [focal] (where in the square, 0 to 1 across and
  /// down): the bit of the picture there stays put.
  TileCrop zoomed(
    double to,
    Size size, {
    Offset focal = const Offset(0.5, 0.5),
  }) {
    final shown = within(size.width, size.height);
    final point = shown.topLeft + Offset(focal.dx, focal.dy) * shown.width;
    final zoom = to.clamp(1.0, maxZoom);
    final side = min(size.width, size.height) / zoom;
    final centre = point + Offset(0.5 - focal.dx, 0.5 - focal.dy) * side;
    return TileCrop(
      zoom: zoom,
      x: centre.dx / size.width,
      y: centre.dy / size.height,
    ).fitted(size);
  }

  /// What tells one framing from another, to four places: a cache's key.
  String get key =>
      '${zoom.toStringAsFixed(4)},${x.toStringAsFixed(4)},'
      '${y.toStringAsFixed(4)}';

  /// As `app.json` keeps it, to four places.
  Map<String, Object> toJson() => {
    'zoom': _round(zoom),
    'x': _round(x),
    'y': _round(y),
  };

  static double _round(double v) => (v * 10000).round() / 10000;

  @override
  bool operator ==(Object other) => other is TileCrop && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'TileCrop($key)';
}
