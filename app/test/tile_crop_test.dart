import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_look.dart';

// How a tile's own image is framed (ADR 0112): the square a crop shows,
// moving and zooming it, and how it's kept in `projectTiles`.

const _wide = Size(400, 200);
const _name = '00112233445566778899aabbccddeeff.gif';

void main() {
  test('none shows the middle square of the shorter side; a zoom a '
      'smaller one, kept inside the image', () {
    expect(
      const TileCrop().within(400, 200),
      const Rect.fromLTWH(100, 0, 200, 200),
    );
    expect(
      const TileCrop().within(200, 400),
      const Rect.fromLTWH(0, 100, 200, 200),
    );
    expect(
      const TileCrop(zoom: 2).within(400, 200),
      const Rect.fromLTWH(150, 50, 100, 100),
    );
    expect(
      const TileCrop(zoom: 4, x: 0.25, y: 0.75).within(400, 200),
      const Rect.fromLTWH(75, 125, 50, 50),
    );
    // A centre past an edge stops the square at it; a zoom outside its
    // range is taken as its end.
    expect(
      const TileCrop(zoom: 2, x: 0, y: 1).within(400, 200),
      const Rect.fromLTWH(0, 100, 100, 100),
    );
    expect(
      const TileCrop(zoom: 0.5).within(400, 200),
      const Rect.fromLTWH(100, 0, 200, 200),
    );
    expect(const TileCrop(zoom: 100).within(400, 200).width, 200 / 8);
  });

  test('a drag moves the picture with the pointer, and stops at its edge', () {
    // Dragged left by half the square: the square shows further right.
    final right = const TileCrop().panned(const Offset(-0.5, 0), _wide);
    expect(right.within(400, 200), const Rect.fromLTWH(200, 0, 200, 200));
    expect((right.x, right.y), (0.75, 0.5));
    // Further, and down: it stops at the right edge, and at zoom 1 a wide
    // picture has no room to move up or down.
    final edge = right.panned(const Offset(-3, -1), _wide);
    expect((edge.x, edge.y), (0.75, 0.5));
    // Back from the edge it moves at once: the centre kept is the real
    // one, not one past the edge.
    expect(edge.panned(const Offset(0.25, 0), _wide).x, 0.625);

    final zoomed = const TileCrop(zoom: 2).panned(const Offset(0, 0.5), _wide);
    expect(zoomed.within(400, 200), const Rect.fromLTWH(150, 0, 100, 100));
  });

  test('a zoom keeps the bit of the picture under the pointer in place', () {
    const focal = Offset(0.25, 0.75);
    final before = const TileCrop().within(400, 200);
    final after = const TileCrop().zoomed(2, _wide, focal: focal);
    final under = before.topLeft + focal * before.width;
    final now = after.within(400, 200);
    expect(now.width, 100);
    expect(now.topLeft + focal * now.width, under);
    // Out again, about the middle: none, from wherever it was.
    expect(after.zoomed(1, _wide).isWhole, isFalse); // moved to the left
    expect(const TileCrop(zoom: 3).zoomed(1, _wide).isWhole, isTrue);
    // Past its ends: its ends.
    expect(const TileCrop().zoomed(20, _wide).zoom, TileCrop.maxZoom);
    expect(const TileCrop(zoom: 2).zoomed(0.2, _wide).zoom, 1);
  });

  test('kept to four places; one that frames as none does, or isn’t one, '
      'reads as none', () {
    const crop = TileCrop(zoom: 2.123456, x: 0.333333, y: 0.7);
    expect(crop.toJson(), {'zoom': 2.1235, 'x': 0.3333, 'y': 0.7});
    expect(TileCrop.read(crop.toJson()), crop);
    expect(TileCrop.read({'zoom': 1, 'x': 0.5, 'y': 0.5}), isNull);
    for (final bad in [
      null,
      'zoom',
      7,
      <String, Object>{},
      {'zoom': 2, 'x': 0.5},
      {'zoom': '2', 'x': 0.5, 'y': 0.5},
      {'zoom': double.nan, 'x': 0.5, 'y': 0.5},
      {'zoom': 2, 'x': double.infinity, 'y': 0.5},
    ]) {
      expect(TileCrop.read(bad), isNull, reason: '$bad');
    }
    // A hand-edited one out of range is brought into it.
    expect(
      TileCrop.read({'zoom': 50, 'x': -1, 'y': 2}),
      const TileCrop(zoom: TileCrop.maxZoom, x: 0, y: 1),
    );
  });

  test('a look keeps its crop beside its image, and only with one', () {
    final saved = {
      'image': _name,
      'color': 'teal',
      'crop': {'zoom': 2, 'x': 0.25, 'y': 0.5},
    };
    final look = TileLook.read(saved)!;
    expect(look.crop, const TileCrop(zoom: 2, x: 0.25));
    expect(look.toJson(), saved);
    // An app before framing reads `image`, `mark` and `color` alone: the
    // entry still has them as it always did, the crop only added.
    expect(look.toJson()['image'], _name);
    expect(look.toJson().keys, containsAll(['image', 'color']));
    // From before framing: the middle.
    expect(TileLook.read({'image': _name})!.crop, isNull);
    // No image, or one that isn't Nushi's: no crop either.
    expect(
      TileLook.read({
        'mark': 'A',
        'crop': {'zoom': 2, 'x': 0.25, 'y': 0.5},
      })!.toJson(),
      {'mark': 'A'},
    );
    expect(
      TileLook.read({
        'crop': {'zoom': 2, 'x': 0.25, 'y': 0.5},
      }),
      isNull,
    );
    expect(const TileLook(mark: 'A', crop: TileCrop(zoom: 2)).toJson(), {
      'mark': 'A',
    });
    // A bad crop leaves the rest of the look.
    expect(TileLook.read({'image': _name, 'crop': 'close'})!.toJson(), {
      'image': _name,
    });
  });
}
