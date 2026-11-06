import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The few icons drawn as light strokes, where Material's glyphs are too heavy
/// beside the chat header's words (ADR 0072) and in the composer's + menu,
/// whose rows Claude's app draws the same way. Each is geometry on a 24 box,
/// so it's sharp at any size and needs no font. Everywhere else stays
/// Material.
enum LineIcon {
  /// The terminal's panel: a prompt in the box.
  terminal,

  /// The details panel: the box, its right side marked off.
  details,

  /// The sidebar: the box, its left side marked off.
  sidebar,

  /// The Files pane: a folder, shut.
  folder,

  /// Show in Finder.
  folderOpen,

  /// Close.
  close,

  /// More: three dots, as heavy as the others' strokes.
  more,

  /// Arrange (the sidebar's grouping and sort): three lines, each shorter.
  arrange,

  /// Add: the composer's +.
  plus,

  /// Add files or photos: a paper clip, leaning right.
  paperclip,

  /// Mention a file: an @.
  at,

  /// Slash commands: a slash in the box.
  slashBox,

  /// A browser tab (ADR 0094): a globe, its meridian a lens and its
  /// equator a line.
  globe,

  /// A browser tab's Back: an arrow to the left.
  back,

  /// A browser tab's Forward: an arrow to the right.
  forward,

  /// A browser tab's Reload: a circle's arrow turning clockwise, its head
  /// at the top right.
  reload,

  /// Open outside (a page in the default browser): an arrow out of a box's
  /// top right corner.
  openOutside,

  /// Expand (the browser over the chat): two arrows out to the corners.
  expand,

  /// Collapse: the same arrows in from the corners.
  collapse;

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
    sidebar =>
      Path()
        ..addRRect(_box)
        ..moveTo(9, 3)
        ..lineTo(9, 21),
    // The open folder's back, its tab and corners, closed up into the box's
    // width and height.
    folder =>
      Path()
        ..moveTo(3, 7)
        ..quadraticBezierTo(3, 5, 5, 5)
        ..lineTo(9, 5)
        ..lineTo(11.5, 7.5)
        ..lineTo(19, 7.5)
        ..quadraticBezierTo(21, 7.5, 21, 9.5)
        ..lineTo(21, 17)
        ..quadraticBezierTo(21, 19, 19, 19)
        ..lineTo(5, 19)
        ..quadraticBezierTo(3, 19, 3, 17)
        ..close(),
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
    arrange =>
      Path()
        ..moveTo(4, 7)
        ..lineTo(20, 7)
        ..moveTo(7, 12)
        ..lineTo(17, 12)
        ..moveTo(10, 17)
        ..lineTo(14, 17),
    more =>
      Path()
        ..addOval(_dot(6))
        ..addOval(_dot(12))
        ..addOval(_dot(18)),
    plus =>
      Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(5, 12)
        ..lineTo(19, 12),
    // Upright, three bends in one wire, then turned 45° about the middle.
    paperclip =>
      (Path()
            ..moveTo(13.5, 8.5)
            ..lineTo(13.5, 16)
            ..arcToPoint(const Offset(10.5, 16), radius: _r(1.5))
            ..lineTo(10.5, 6)
            ..arcToPoint(const Offset(15.5, 6), radius: _r(2.5))
            ..lineTo(15.5, 17)
            ..arcToPoint(const Offset(8.5, 17), radius: _r(3.5))
            ..lineTo(8.5, 9))
          // Grown to fill the box on its diagonal, as the @ and the slash
          // box do, its wires apart at 16 on a 1x screen.
          .transform(_turn(pi / 4, scale: 1.25)),
    at =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3.5))
        ..moveTo(15.5, 8.5)
        ..lineTo(15.5, 13.5)
        ..arcToPoint(
          const Offset(20.5, 13.5),
          radius: _r(2.5),
          clockwise: false,
        )
        ..lineTo(20.5, 12)
        ..arcToPoint(
          Offset(12 + 8.5 * cos(0.7), 12 + 8.5 * sin(0.7)),
          radius: _r(8.5),
          largeArc: true,
          clockwise: false,
        ),
    slashBox =>
      Path()
        ..addRRect(_box)
        ..moveTo(14.5, 7.5)
        ..lineTo(9.5, 16.5),
    globe =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9))
        ..moveTo(12, 3)
        ..arcToPoint(const Offset(12, 21), radius: _r(13))
        ..arcToPoint(const Offset(12, 3), radius: _r(13))
        ..moveTo(3, 12)
        ..lineTo(21, 12),
    back =>
      Path()
        ..moveTo(19, 12)
        ..lineTo(5, 12)
        ..moveTo(11, 6)
        ..lineTo(5, 12)
        ..lineTo(11, 18),
    forward =>
      Path()
        ..moveTo(5, 12)
        ..lineTo(19, 12)
        ..moveTo(13, 6)
        ..lineTo(19, 12)
        ..lineTo(13, 18),
    // From the right, clockwise round to the top, on to the head.
    reload =>
      Path()
        ..moveTo(20, 12)
        ..arcToPoint(const Offset(12, 4), radius: _r(8), largeArc: true)
        ..quadraticBezierTo(16.5, 4, 19.5, 7.5)
        ..moveTo(20, 3.5)
        ..lineTo(20, 8)
        ..lineTo(15.5, 8),
    openOutside =>
      Path()
        ..moveTo(18, 13.5)
        ..lineTo(18, 18)
        ..quadraticBezierTo(18, 20, 16, 20)
        ..lineTo(6, 20)
        ..quadraticBezierTo(4, 20, 4, 18)
        ..lineTo(4, 8)
        ..quadraticBezierTo(4, 6, 6, 6)
        ..lineTo(10.5, 6)
        ..moveTo(14.5, 4)
        ..lineTo(20, 4)
        ..lineTo(20, 9.5)
        ..moveTo(20, 4)
        ..lineTo(11, 13),
    expand =>
      Path()
        ..moveTo(14, 4)
        ..lineTo(20, 4)
        ..lineTo(20, 10)
        ..moveTo(20, 4)
        ..lineTo(14, 10)
        ..moveTo(10, 20)
        ..lineTo(4, 20)
        ..lineTo(4, 14)
        ..moveTo(4, 20)
        ..lineTo(10, 14),
    collapse =>
      Path()
        ..moveTo(14, 4)
        ..lineTo(14, 10)
        ..lineTo(20, 10)
        ..moveTo(14, 10)
        ..lineTo(20, 4)
        ..moveTo(10, 20)
        ..lineTo(10, 14)
        ..lineTo(4, 14)
        ..moveTo(10, 14)
        ..lineTo(4, 20),
  };

  static Radius _r(double r) => Radius.circular(r);

  /// A turn of [angle] clockwise about the box's middle.
  static Float64List _turn(double angle, {double scale = 1}) =>
      (Matrix4.identity()
            ..translateByDouble(12, 12, 0, 1)
            ..rotateZ(angle)
            ..scaleByDouble(scale, scale, 1, 1)
            ..translateByDouble(-12, -12, 0, 1))
          .storage;

  /// A dot at [x], closed up by the stroke.
  static Rect _dot(double x) =>
      Rect.fromCircle(center: Offset(x, 12), radius: 0.4);

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
