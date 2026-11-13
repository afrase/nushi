import 'dart:typed_data';

// How far a golden drawn on CI may be from the one drawn here: GitHub's
// macOS image rasterises text a few pixels differently, so a few pixels
// always pass, and otherwise up to 1% of the golden's pixels but no more
// than [goldenMostPixels]: on a whole window 1% is 15,000 pixels, room
// for a missing icon or a line of text to pass unseen. On 2026-11-13, 389
// of the 401 goldens differed on CI by text alone: half by 344 pixels or
// fewer, the most 4,183 (the theme picker, 0.73%); a 5,500-pixel banner
// by 57 (1.03%). CI prints each one's numbers.

/// Pixels any golden may differ in, however small.
const goldenFewPixels = 150;

/// Pixels no golden may differ in more than, however large.
const goldenMostPixels = 6000;

/// Whether [diff] pixels changed of a golden's [total] are within what CI
/// allows.
bool goldenWithin(int diff, int total) =>
    diff <= goldenFewPixels ||
    (diff <= total * 0.01 && diff <= goldenMostPixels);

/// A PNG's pixels (its width times its height, from its header); 0 when
/// [png] isn't one.
int pngPixels(Uint8List png) {
  if (png.length < 24) return 0;
  final b = ByteData.sublistView(png);
  return b.getUint32(16) * b.getUint32(20);
}
