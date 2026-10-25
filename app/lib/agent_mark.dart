// The marks' path data runs on over adjacent strings, and SVG path
// commands need no space between them.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:flutter/material.dart';
import 'package:svg_path/svg_path.dart';

import 'agents.dart';
import 'theme/theme.dart';

/// An agent's mark, [size] square in [color] (the secondary text's if not
/// given): the agent's own icon where Nushi bundles one, else its initial
/// on a rounded square. One mark per agent wherever a chat's agent shows.
class AgentMark extends StatelessWidget {
  const new(this.agent, {super.key, this.size = 14, this.color});

  final String agent; // as Agent.name, such as "claude"
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final color = this.color ?? t.textSecondary;
    if (_marks[agent] case (final path, final box)) {
      return CustomPaint(
        size: Size.square(size),
        painter: _Mark(path, box, color),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: Text(
        agentTitle(agent)[0],
        style: TextStyle(
          fontFamily: NushiTheme.uiFont,
          fontSize: size * 0.64,
          height: 1,
          fontWeight: FontWeight.w600,
          color: t.monogramText,
        ),
      ),
    );
  }
}

/// [path] drawn in [color], its [box] fitted and centred in the square.
class _Mark extends CustomPainter {
  new(this.path, this.box, this.color);

  final Path path;
  final Rect box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = box.longestSide;
    canvas
      ..scale(size.width / side)
      ..translate(
        (side - box.width) / 2 - box.left,
        (side - box.height) / 2 - box.top,
      )
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Mark old) => old.path != path || old.color != color;
}

/// The agents' own icons, each with the box it's drawn in: Claude's and
/// Codex's from the ACP registry (`cdn.agentclientprotocol.com`, as
/// `claude-acp.svg` and `codex-acp.svg`), Ante's from its docs' logo
/// (`ante.png` in AntigmaLabs/ante), oh-my-pi's from its repository
/// (`assets/icon.svg`), PiG's from its pig sprite, all in one color.
/// NOTES.md, "Agent marks", has their terms.
final Map<String, (Path, Rect)> _marks = {
  'claude': (parseSvgPath(_claude), const Rect.fromLTWH(0, 0, 1200, 1200)),
  'codex': (parseSvgPath(_codex), const Rect.fromLTWH(0, 0, 24, 24)),
  'ante': (_ante(), const Rect.fromLTRB(14, 32, 248, 235)),
  'omp': (_omp(), const Rect.fromLTRB(10, 8, 110, 82)),
  'pig': (_pig(), const Rect.fromLTRB(1, 0, 15, 12)),
};

/// Ante's pixel ghost, its pixels as runs of the 262×266 PNG.
Path _ante() {
  const rows = [
    (32, 49, [(116, 143)]),
    (45, 57, [(60, 74), (187, 200)]),
    (49, 66, [(102, 157)]),
    (66, 83, [(60, 74), (88, 171), (187, 199)]),
    (83, 117, [(46, 213)]),
    (100, 117, [(14, 32), (229, 248)]),
    (117, 133, [(14, 248)]),
    (133, 167, [(32, 81), (102, 158), (180, 227)]),
    (167, 201, [(46, 213)]),
    (201, 218, [(60, 199)]),
    (218, 235, [(74, 102), (159, 185)]),
  ];
  final path = Path();
  for (final (top, bottom, runs) in rows) {
    for (final (left, right) in runs) {
      path.addRect(
        Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          right.toDouble(),
          bottom.toDouble(),
        ),
      );
    }
  }
  return path;
}

/// oh-my-pi's π with a plug on its right leg (the plug's two pins cut
/// out; the bar's two dots, in the bar's place in one color, left out).
Path _omp() {
  RRect r(double x, double y, double w, double h, double radius) =>
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      );
  final pi = Path()
    ..addRRect(r(10, 8, 100, 12, 2))
    ..addRRect(r(25, 20, 12, 62, 2))
    ..addRRect(r(75, 20, 12, 45, 2))
    ..addRRect(r(71, 55, 20, 16, 3));
  final pins = Path()
    ..addRRect(r(76, 59, 3, 8, 1))
    ..addRRect(r(82, 59, 3, 8, 1));
  return Path.combine(PathOperation.difference, pi, pins);
}

/// PiG's pig head: the 16×14 sprite its terminal draws (`pigMascot` in
/// `coding/piglogin/art.go` of MichaelKinsy/PiG, MIT), its empty first and
/// last rows left out, in one color: the eyes and the snout cut out, the
/// nostrils kept.
Path _pig() {
  const rows = [
    '...####..####...',
    '...####..####...',
    '..############..',
    '.##############.',
    '.###..####..###.',
    '.###..####..###.',
    '.#####....#####.',
    '.####.#..#.####.',
    '.#####....#####.',
    '.##############.',
    '..############..',
    '...##########...',
  ];
  final path = Path();
  for (final (y, row) in rows.indexed) {
    for (final run in RegExp('#+').allMatches(row)) {
      path.addRect(
        Rect.fromLTRB(
          run.start.toDouble(),
          y.toDouble(),
          run.end.toDouble(),
          y + 1.0,
        ),
      );
    }
  }
  return path;
}

const _claude =
    'M234 800.2L468.6 668.5L472.6 657.1L468.6 650.7L457.2 650.7L418 648.3'
    'L283.9 644.7L167.6 639.9L54.9 633.8L26.6 627.8L0 592.8L2.7 575.3'
    'L26.6 559.2L60.7 562.2L136.2 567.4L249.4 575.2L331.6 580L453.3 592.7'
    'L472.6 592.7L475.3 584.9L468.7 580L463.6 575.2L346.4 495.8L219.5 411.9'
    'L153.1 363.5L117.2 339.1L99.1 316.1L91.2 266L123.9 230.1L167.7 233.1'
    'L178.9 236.1L223.2 270.2L318 343.6L441.8 434.7L459.9 449.8L467.2 444.6'
    'L468.1 441L459.9 427.4L392.6 305.7L320.8 181.9L288.8 130.6L280.3 99.9'
    'C277.4 87.2 275.2 76.6 275.2 63.6L312.3 13.2L332.9 6.6L382.4 13.2'
    'L403.2 31.3L434 101.7L483.9 212.5L561.2 363.2L583.8 407.9L595.9 449.3'
    'L600.4 462L608.2 462L608.2 454.7L614.6 369.8L626.3 265.6L637.8 131.5'
    'L641.7 93.7L660.4 48.5L697.5 24L726.5 37.9L750.4 72L747.1 94.1'
    'L732.9 186.2L705.1 330.5L687 427.2L697.5 427.2L709.6 415.1L758.5 350.2'
    'L840.6 247.5L876.9 206.7L919.2 161.7L946.3 140.3L997.6 140.3'
    'L1035.4 196.4L1018.5 254.4L965.6 321.4L921.8 378.2L859 462.8'
    'L819.8 530.4L823.4 535.8L832.8 534.9L974.7 504.7L1051.3 490.9'
    'L1142.8 475.2L1184.2 494.5L1188.7 514.1L1172.5 554.3L1074.6 578.5'
    'L959.8 601.4L788.9 641.9L786.8 643.4L789.3 646.4L866.3 653.6'
    'L899.2 655.4L979.8 655.4L1129.9 666.6L1169.2 692.5L1192.7 724.3'
    'L1188.7 748.4L1128.3 779.2L1046.8 759.9L856.6 714.6L791.4 698.3'
    'L782.3 698.3L782.3 703.7L836.7 756.9L936.3 846.8L1061.1 962.8'
    'L1067.4 991.5L1051.4 1014.1L1034.5 1011.7L924.9 929.2L882.6 892.1'
    'L786.8 811.5L780.5 811.5L780.5 819.9L802.6 852.2L919.1 1027.4'
    'L925.1 1081.1L916.7 1098.6L886.5 1109.2L853.3 1103.1L785.1 1007.4'
    'L714.7 899.5L657.9 802.9L651 806.8L617.5 1167.7L601.8 1186.1'
    'L565.5 1200L535.3 1177L519.3 1139.9L535.3 1066.6L554.7 970.8'
    'L570.4 894.7L584.5 800.1L593 768.7L592.4 766.6L585.5 767.5L514.2 865.4'
    'L405.8 1011.9L320.1 1103.7L299.5 1111.8L263.9 1093.4L267.2 1060.4'
    'L287.1 1031.1L405.8 880.1L477.4 786.5L523.7 732.5L523.3 724.7'
    'L520.6 724.7L205.3 929.4L149.2 936.6L125 914L128 876.9L139.4 864.8'
    'L234.2 799.6L233.9 799.9Z';

const _codex =
    'M22.282 9.821a5.985 5.985 0 0 0-.516-4.91 6.046 6.046 0 0 '
    '0-6.51-2.9A6.065 6.065 0 0 0 4.981 4.18a5.985 5.985 0 0 0-3.998 2.9 '
    '6.046 6.046 0 0 0 .743 7.097 5.98 5.98 0 0 0 .51 4.911 6.051 6.051 0 0 '
    '0 6.515 2.9A5.985 5.985 0 0 0 13.26 24a6.056 6.056 0 0 0 5.772-4.206 '
    '5.99 5.99 0 0 0 3.997-2.9 6.056 6.056 0 0 0-.747-7.073zM13.26 '
    '22.43a4.476 4.476 0 0 1-2.876-1.04l.141-.081 4.779-2.758a.795.795 0 0 '
    '0 .392-.681v-6.737l2.02 1.168a.071.071 0 0 1 .038.052v5.583a4.504 '
    '4.504 0 0 1-4.494 4.494zM3.6 18.304a4.47 4.47 0 0 '
    '1-.535-3.014l.142.085 4.783 2.759a.771.771 0 0 0 .78 '
    '0l5.843-3.369v2.332a.08.08 0 0 1-.033.062L9.74 19.95a4.5 4.5 0 0 '
    '1-6.14-1.646zM2.34 7.896a4.485 4.485 0 0 1 2.366-1.973V11.6a.766.766 0 '
    '0 0 .388.676l5.815 3.355-2.02 1.168a.076.076 0 0 1-.071 '
    '0l-4.83-2.786A4.504 4.504 0 0 1 2.34 7.872zm16.597 '
    '3.855l-5.833-3.387L15.119 7.2a.076.076 0 0 1 .071 0l4.83 2.791a4.494 '
    '4.494 0 0 1-.676 8.105v-5.678a.79.79 0 0 '
    '0-.407-.667zm2.01-3.023l-.141-.085-4.774-2.782a.776.776 0 0 0-.785 '
    '0L9.409 9.23V6.897a.066.066 0 0 1 .028-.061l4.83-2.787a4.5 4.5 0 0 1 '
    '6.68 4.66zm-12.64 4.135l-2.02-1.164a.08.08 0 0 1-.038-.057V6.075a4.5 '
    '4.5 0 0 1 7.375-3.453l-.142.08L8.704 5.46a.795.795 0 0 '
    '0-.393.681zm1.097-2.365l2.602-1.5 2.607 1.5v2.999l-2.597 '
    '1.5-2.607-1.5z';
