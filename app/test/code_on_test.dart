import 'dart:math';

// The diff package's own copy of the rule, which it doesn't export: read
// from its src here only, to hold the app's copy to it.
import 'package:diff_view/src/render/text_contrast.dart' show readableOn;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart' show Capture;
import 'package:nushi/theme/tokyo_night.dart';
import 'package:nushi/transcript_find.dart';

// codeOn: ADR 0086's amendment for the fills Nushi paints under code
// itself (issue 117), on the cases the ADR names.

const double _floor = codeOnTintContrast;

Color _code(Color c, Color fill, Color background) =>
    codeOn(c, fill, background: background, floor: _floor);

/// [c] with its HSL lightness [l].
Color _lit(Color c, double l) => Color(
  HSLColor.fromColor(c).withLightness(l.clamp(0, 1)).toColor().toARGB32(),
);

void main() {
  const t = tokyoNightDark;
  final comment = t.syntax[Capture.comment]!.color;
  final hit = Color.alphaBlend(findColors(t).hit, t.base);

  test("a comment on a find's hit reads as the theme's comments do, by the "
      'least change of lightness, its hue kept', () {
    final own = contrast(comment, t.base);
    expect(own, lessThan(_floor), reason: "Tokyo Night's comments, 2.8:1");
    expect(contrast(comment, hit), lessThan(own - 0.5));
    final c = _code(comment, hit, t.base);
    expect(contrast(c, hit), greaterThanOrEqualTo(own));
    final (was, now) = (HSLColor.fromColor(comment), HSLColor.fromColor(c));
    expect((now.hue - was.hue).abs(), lessThan(1.5));
    expect((now.saturation - was.saturation).abs(), lessThan(0.02));
    // On its own side: lighter than the fill, as it was, and lighter still.
    expect(c.computeLuminance(), greaterThan(comment.computeLuminance()));
    // The least: a step less doesn't reach it.
    expect(contrast(_lit(c, now.lightness - 1 / 255), hit), lessThan(own));
  });

  test('a colour that already reads on the fill is left alone', () {
    final keyword = t.syntax[Capture.keyword]!.color;
    expect(contrast(keyword, hit), greaterThan(_floor));
    expect(_code(keyword, hit, t.base), keyword);
    // Nor one that reads its own contrast there, under the floor.
    expect(_code(comment, t.base, t.base), comment);
  });

  test('a colour over the floor on the background is taken to the floor, '
      'not to its own contrast', () {
    const fill = Color(0xFF4A4F66);
    const bg = Color(0xFF1A1B26);
    const ink = Color(0xFF8A90B0);
    expect(contrast(ink, bg), greaterThan(4.5));
    expect(contrast(ink, fill), lessThan(_floor));
    final c = _code(ink, fill, bg);
    expect(contrast(c, fill), inInclusiveRange(_floor, _floor + 0.1));
  });

  test("the other side when its own can't reach it", () {
    // Lighter than the fill, but white on it reads under 3:1: darker.
    const fill = Color(0xFFD8D8D8);
    const ink = Color(0xFFE4E4E4);
    const bg = Color(0xFF000000);
    expect(contrast(const Color(0xFFFFFFFF), fill), lessThan(_floor));
    final c = _code(ink, fill, bg);
    expect(c.computeLuminance(), lessThan(fill.computeLuminance()));
    expect(contrast(c, fill), greaterThanOrEqualTo(_floor));
    // The least step on that side, not the end it falls back to.
    expect(c, isNot(const Color(0xFF000000)));
    final l = HSLColor.fromColor(c).lightness;
    expect(contrast(_lit(c, l + 1 / 255), fill), lessThan(_floor));
  });

  test("the diff package's rule and this one answer alike, translucent "
      'colours too', () {
    final r = Random(117);
    Color any({bool opaque = false}) => Color.fromARGB(
      opaque || r.nextBool() ? 255 : 40 + r.nextInt(216),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
    );
    var translucent = 0;
    for (var i = 0; i < 4000; i++) {
      final color = any();
      final fill = any(opaque: true);
      final background = any(opaque: true);
      final floor = [1.5, _floor, 4.5][r.nextInt(3)];
      if (color.a < 1) translucent++;
      expect(
        codeOn(color, fill, background: background, floor: floor),
        readableOn(color, fill, background: background, minContrast: floor),
        reason: '$color on $fill, background $background, floor $floor',
      );
    }
    expect(translucent, greaterThan(1000));
  });

  test('where nothing reaches it, the best of the colour and the ends: '
      'never worse', () {
    const fill = Color(0xFF808080);
    const ink = Color(0xFF8A8A8A);
    // 6.1:1 on black, its own; neither end reaches that on mid grey.
    final c = codeOn(ink, fill, background: const Color(0xFF000000), floor: 21);
    expect(contrast(c, fill), greaterThan(contrast(ink, fill)));
    expect(c, anyOf(const Color(0xFFFFFFFF), const Color(0xFF000000)));
  });
}
