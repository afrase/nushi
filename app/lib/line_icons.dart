import 'package:flutter/material.dart';

/// The few icons drawn as light strokes, where Material's glyphs are too heavy
/// beside the chat header's words (ADR 0072). Each is geometry on a 24 box, so
/// it's sharp at any size and needs no font. Everywhere else stays Material.
enum LineIcon {
  /// The terminal's panel: a prompt in the box.
  terminal,

  /// The details panel: the box, its right side marked off.
  details,

  /// Show in Finder.
  folderOpen,

  /// Close.
  close;

  /// The stroke on the 24 box; it scales with the size.
  static const _stroke = 1.6;

  static final _box = RRect.fromRectXY(const Rect.fromLTWH(3, 3, 18, 18), 3, 3);

  Path get _path => switch (this) {
    terminal =>
      Path()
        ..addRRect(_box)
        ..moveTo(7, 15)
        ..lineTo(10, 12)
        ..lineTo(7, 9)
        ..moveTo(13, 15)
        ..lineTo(17, 15),
    details =>
      Path()
        ..addRRect(_box)
        ..moveTo(15, 3)
        ..lineTo(15, 21),
    folderOpen =>
      Path()
        ..moveTo(3, 19)
        ..lineTo(3, 6)
        ..quadraticBezierTo(3, 4, 5, 4)
        ..lineTo(9, 4)
        ..lineTo(11.5, 6.5)
        ..lineTo(17, 6.5)
        ..quadraticBezierTo(19, 6.5, 19, 8.5)
        ..lineTo(19, 10.5)
        ..moveTo(3, 19)
        ..lineTo(6, 11.8)
        ..quadraticBezierTo(6.5, 10.5, 8, 10.5)
        ..lineTo(20.5, 10.5)
        ..quadraticBezierTo(22, 10.5, 21.5, 12)
        ..lineTo(19.3, 17.8)
        ..quadraticBezierTo(18.9, 19, 17.5, 19)
        ..lineTo(3, 19),
    close =>
      Path()
        ..moveTo(6, 6)
        ..lineTo(18, 18)
        ..moveTo(18, 6)
        ..lineTo(6, 18),
  };

  /// The icon, [size] square, in the room an [Icon] of that size takes.
  Widget view({required double size, required Color color}) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LinePainter(this, color)),
  );
}

class _LinePainter extends CustomPainter {
  new(this.icon, this.color);

  final LineIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.shortestSide / 24)
      ..drawPath(
        icon._path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = LineIcon._stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.icon != icon || old.color != color;
}
