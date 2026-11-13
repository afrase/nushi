import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'project_tile_fixture.dart';
import 'sidebar_fixture.dart';

// A project rail tile's tooltip goes to the tile's right, level with it,
// not below it over the next tile (`besideTile`); every other tooltip is
// where it was.

/// Moves [mouse] over [tooltip]'s rail tile until its tooltip shows, and
/// gives the tile's box and the tooltip text's.
Future<(Rect, Rect)> _hover(
  WidgetTester tester,
  TestGesture mouse,
  String tooltip,
) async {
  final tile = find.byWidgetPredicate(
    (w) => w is RailTile && w.tooltip == tooltip,
  );
  await mouse.moveTo(tester.getCenter(tile));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return (tester.getRect(tile), tester.getRect(find.text(tooltip).last));
}

void main() {
  setUpAll(loadFonts);
  setUp(() => projectRail.value = true);

  testWidgets('a tile’s tooltip is at its right, level with it', (
    tester,
  ) async {
    final (d, _) = await arrangedSidebar(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    for (final tip in ['garden\n$garden', 'All projects', 'Add project…']) {
      final (tile, text) = await _hover(tester, mouse, tip);
      expect(text.left, greaterThan(tile.right), reason: tip);
      expect(text.center.dy, moreOrLessEquals(tile.center.dy, epsilon: 1));
      // Moved away, it goes.
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text(tip), findsNothing);
    }
    d.dispose();
  });

  group('besideTile', () {
    const tile = Size.square(38);
    const tip = Size(120, 40);
    const window = Size(800, 600);
    Offset at(Offset target, {Size room = window}) => besideTile(
      TooltipPositionContext(
        target: target,
        targetSize: tile,
        tooltipSize: tip,
        verticalOffset: 0,
        overlaySize: room,
      ),
    );

    test('right of the tile, its middle level with the tile’s', () {
      expect(at(const Offset(32, 200)), const Offset(32 + 19 + 8, 180));
    });

    test('kept inside the window top to bottom', () {
      expect(at(const Offset(32, 10)).dy, 0);
      expect(at(const Offset(32, 595)).dy, 600 - 40);
    });

    test('left of it with no room on the right; below with none either '
        'side', () {
      expect(at(const Offset(760, 200)), const Offset(760 - 19 - 8 - 120, 180));
      final below = at(const Offset(70, 200), room: const Size(140, 600));
      expect(below.dy, greaterThan(200 + 19));
    });
  });
}
