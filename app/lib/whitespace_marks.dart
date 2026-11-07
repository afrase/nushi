import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/theme/theme.dart';
import 'package:re_editor/re_editor.dart';

/// What Show whitespace draws its marks in: the muted text's color, faint.
Color whitespaceColor(Tokens t) => t.textMuted.withValues(alpha: 0.45);

/// Paints the marks of [line]'s spaces and tabs (Show whitespace, ADR
/// 0096): a space a dot at its middle, a tab an arrow across the columns
/// it spans, in [color]. [boxesOf] gives where the character at an offset
/// is drawn, in the canvas's terms; [column] is a column's width. Only
/// marks: the text is never changed, so copying and saving never see them.
void paintWhitespace(
  Canvas canvas,
  String line,
  Iterable<Rect> Function(int at) boxesOf,
  Color color,
  double column,
) {
  final dot = Paint()..color = color;
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final r = max(0.9, column * 0.13);
  for (var i = 0; i < line.length; i++) {
    final c = line.codeUnitAt(i);
    if (c != 0x20 && c != 0x09) continue;
    for (final box in boxesOf(i)) {
      // On a pixel's middle, so a one-pixel line is sharp.
      final y = box.center.dy.floorToDouble() + 0.5;
      if (c == 0x20) {
        canvas.drawCircle(Offset(box.center.dx, y), r, dot);
        continue;
      }
      final from = box.left + column * 0.25;
      final to = box.right - column * 0.25;
      final head = min(column * 0.4, (to - from) / 2);
      canvas.drawPath(
        Path()
          ..moveTo(from, y)
          ..lineTo(to, y)
          ..moveTo(to - head, y - head)
          ..lineTo(to, y)
          ..lineTo(to - head, y + head),
        stroke,
      );
    }
  }
}

/// A line of the preview's read-only source with its whitespace marked
/// over it ([paintWhitespace]) while [show] is on: [line] is the text its
/// child's paragraph (wherever below) draws first, [column] a column's
/// width there.
class WhitespaceMarks extends SingleChildRenderObjectWidget {
  const new({
    required this.line,
    required this.show,
    required this.color,
    required this.column,
    super.key,
    super.child,
  });

  final String line;
  final bool show;
  final Color color;
  final double column;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMarks()
    ..line = line
    ..show = show
    ..color = color
    ..column = column;

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMarks)
        ..line = line
        ..show = show
        ..color = color
        ..column = column;
}

class _RenderMarks extends RenderProxyBox {
  String _line = '';
  bool _show = false;
  Color _color = const Color(0x00000000);
  double _column = 0;

  String get line => _line;
  set line(String v) {
    if (_line == v) return;
    _line = v;
    if (_show) markNeedsPaint();
  }

  bool get show => _show;
  set show(bool v) {
    if (_show == v) return;
    _show = v;
    markNeedsPaint();
  }

  Color get color => _color;
  set color(Color v) {
    if (_color == v) return;
    _color = v;
    if (_show) markNeedsPaint();
  }

  double get column => _column;
  set column(double v) {
    if (_column == v) return;
    _column = v;
    if (_show) markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_show || !_line.contains(_blank)) return;
    final p = paragraphIn(child);
    if (p == null || !p.hasSize) return;
    final at =
        offset +
        MatrixUtils.transformPoint(p.getTransformTo(this), Offset.zero);
    paintWhitespace(
      context.canvas,
      _line,
      (i) => p
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
            boxHeightStyle: ui.BoxHeightStyle.max,
          )
          .map((b) => b.toRect().shift(at)),
      _color,
      _column,
    );
  }
}

final _blank = RegExp('[ \t]');

/// The first paragraph at or below [root]: a line's text.
RenderParagraph? paragraphIn(RenderObject? root) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderParagraph) {
      found = o;
    } else {
      o.visitChildren(visit);
    }
  }

  if (root != null) visit(root);
  return found;
}

/// The lines re_editor has laid out, as it tells its line numbers (the
/// notifier its `indicatorBuilder` is handed), told on as they change:
/// scrolled, edited, wrapped.
class EditorLines extends ChangeNotifier {
  CodeIndicatorValueNotifier? _from;

  /// The lines laid out now, where the editor's text area has them.
  CodeIndicatorValue? get value => _from?.value;

  /// Follows [from], the editor's own.
  void follow(CodeIndicatorValueNotifier from) {
    if (identical(from, _from)) return;
    _from?.removeListener(notifyListeners);
    _from = from..addListener(notifyListeners);
  }

  @override
  void dispose() {
    _from?.removeListener(notifyListeners);
    super.dispose();
  }
}

/// The editor's whitespace marked over it (Show whitespace), where
/// re_editor laid its lines out ([lines]): its text area starts at the
/// right edge of [gutter], the line numbers; the lines' text is
/// [controller]'s. Only drawn: clicks go through to the editor. Laid over
/// the editor, its origin the editor's.
class WhitespaceOverlay extends StatefulWidget {
  const new({
    required this.lines,
    required this.controller,
    required this.gutter,
    required this.column,
    super.key,
  });

  final EditorLines lines;
  final CodeLineEditingController controller;
  final GlobalKey gutter;
  final double column;

  @override
  State<WhitespaceOverlay> createState() => _WhitespaceOverlayState();
}

class _WhitespaceOverlayState extends State<WhitespaceOverlay> {
  final GlobalKey _area = GlobalKey();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      key: _area,
      size: Size.infinite,
      painter: _EditorMarks(
        lines: widget.lines,
        controller: widget.controller,
        gutter: widget.gutter,
        area: _area,
        color: whitespaceColor(NushiTheme.of(context).t),
        column: widget.column,
      ),
    ),
  );
}

class _EditorMarks extends CustomPainter {
  new({
    required this.lines,
    required this.controller,
    required this.gutter,
    required this.area,
    required this.color,
    required this.column,
  }) : super(repaint: Listenable.merge([lines, controller]));

  final EditorLines lines;
  final CodeLineEditingController controller;
  final GlobalKey gutter;
  final GlobalKey area;
  final Color color;
  final double column;

  @override
  void paint(Canvas canvas, Size size) {
    final laidOut = lines.value;
    final g = gutter.currentContext?.findRenderObject();
    final me = area.currentContext?.findRenderObject();
    if (laidOut == null || g is! RenderBox || me is! RenderBox) return;
    if (!g.hasSize) return;
    // The text area's top left: re_editor puts it beside the numbers.
    final origin = MatrixUtils.transformPoint(
      g.getTransformTo(me),
      Offset(g.size.width, 0),
    );
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(origin.dx, origin.dy, size.width, size.height));
    final code = controller.codeLines;
    for (final p in laidOut.paragraphs) {
      if (p.index >= code.length) continue;
      final text = code[p.index].text;
      final at = origin + p.offset;
      paintWhitespace(
        canvas,
        // A line re_editor cut short draws only its start.
        text.length > p.length ? text.substring(0, p.length) : text,
        (i) => p
            .getRangeRects(TextRange(start: i, end: i + 1))
            .map((r) => r.shift(at)),
        color,
        column,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EditorMarks old) =>
      old.color != color ||
      old.column != column ||
      !identical(old.lines, lines) ||
      !identical(old.controller, controller);
}
