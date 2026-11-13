import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_trim.dart';

// What of a tile's own animated image plays (ADR 0112): a trim's frames in
// an image, how it's kept in `projectTiles`, and how its times are written.

const _name = '00112233445566778899aabbccddeeff.gif';

void main() {
  test('a trim in an image: its end no further than the last frame; none '
      'when it keeps them all, or fewer than two', () {
    expect(const TileTrim(2, 5).of(10), const TileTrim(2, 5));
    expect(const TileTrim(2, 50).of(10), const TileTrim(2, 10));
    expect(const TileTrim(0, 10).of(10), isNull);
    expect(const TileTrim(0, 50).of(10), isNull);
    expect(const TileTrim(0, 4).of(10), const TileTrim(0, 4));
    // Past the image's end, or one frame of it: it plays whole.
    expect(const TileTrim(9, 12).of(10), isNull);
    expect(const TileTrim(12, 14).of(10), isNull);
    expect(const TileTrim(0, 2).of(1), isNull);
  });

  test('kept as two frame numbers; one that isn’t a trim reads as none', () {
    expect(const TileTrim(3, 9).toJson(), {'start': 3, 'end': 9});
    expect(TileTrim.read({'start': 3, 'end': 9}), const TileTrim(3, 9));
    expect(TileTrim.read({'start': 0, 'end': 2}), const TileTrim(0, 2));
    for (final bad in [
      null,
      'trim',
      <String, Object>{},
      {'start': 3},
      {'start': 3.5, 'end': 9},
      {'start': '3', 'end': 9},
      {'start': -1, 'end': 9},
      {'start': 4, 'end': 5}, // one frame
      {'start': 9, 'end': 3},
    ]) {
      expect(TileTrim.read(bad), isNull, reason: '$bad');
    }
  });

  test('a look keeps its trim beside its image and crop, and only with an '
      'image', () {
    final saved = {
      'image': _name,
      'crop': {'zoom': 2, 'x': 0.25, 'y': 0.5},
      'trim': {'start': 4, 'end': 30},
    };
    final look = TileLook.read(saved)!;
    expect(look.trim, const TileTrim(4, 30));
    expect(look.crop, const TileCrop(zoom: 2, x: 0.25));
    expect(look.toJson(), saved);
    // From before trimming: every frame.
    expect(TileLook.read({'image': _name})!.trim, isNull);
    expect(
      TileLook.read({
        'mark': 'A',
        'trim': {'start': 4, 'end': 30},
      })!.toJson(),
      {'mark': 'A'},
    );
    expect(TileLook.read({'image': _name, 'trim': 'short'})!.toJson(), {
      'image': _name,
    });
  });

  test('a time is minutes, seconds and tenths', () {
    expect(trimClock(Duration.zero), '0:00.0');
    expect(trimClock(const Duration(milliseconds: 5240)), '0:05.2');
    expect(trimClock(const Duration(milliseconds: 11960)), '0:12.0');
    expect(trimClock(const Duration(seconds: 61, milliseconds: 50)), '1:01.1');
  });
}
