import 'package:flutter/widgets.dart';

import 'package:nushi/theme/theme.dart';

/// A theme's key colors in a strip, for its picker (Settings › General's
/// Theme, the phone's Settings): its base and raised surfaces, the accent,
/// a tool call's, a subagent's and the findings' accents, and a failed
/// chat's red, outlined in [outline] so a set as light as the page still
/// shows its edge.
class ThemeStrip extends StatelessWidget {
  const new(this.tokens, {required this.outline, super.key, this.height = 14});

  final Tokens tokens;
  final Color outline;
  final double height;

  /// The colors it shows, in its order.
  static List<Color> colorsOf(Tokens t) => [
    t.base,
    t.raised,
    t.accent,
    t.toolAccent,
    t.subagentAccent,
    t.findingsAccent,
    t.crashed,
  ];

  @override
  Widget build(BuildContext context) => framed(
    border: outline,
    radius: 3,
    height: height,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in colorsOf(tokens)) Expanded(child: ColoredBox(color: c)),
      ],
    ),
  );
}
