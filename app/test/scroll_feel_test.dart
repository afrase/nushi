import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  Future<ScrollController> list(WidgetTester tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const NativeScroll(),
        builder: (context, child) => MediaQuery(
          data: trackpadSlop(MediaQuery.of(context)),
          child: child!,
        ),
        home: ListView.builder(
          controller: c,
          itemExtent: 40,
          itemCount: 200,
          // Rows that scroll sideways, as a code block does: their drag
          // competes with the list's.
          itemBuilder: (_, i) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text('row $i ' * 40),
          ),
        ),
      ),
    );
    return c;
  }

  testWidgets('a trackpad scroll moves from its first points', (tester) async {
    final c = await list(tester);
    final pan = TestPointer(1, PointerDeviceKind.trackpad);
    final at = tester.getCenter(find.byType(ListView));
    await tester.sendEventToBinding(pan.panZoomStart(at));
    for (var y = -2.0; y >= -8; y -= 2) {
      await tester.sendEventToBinding(pan.panZoomUpdate(at, pan: Offset(0, y)));
    }
    await tester.sendEventToBinding(pan.panZoomEnd());
    await tester.pump();
    // A touch's 18-point slop would have swallowed all 8.
    expect(c.offset, greaterThan(0));
  });

  testWidgets("a flick glides on Apple's curve and stops dead at the end", (
    tester,
  ) async {
    final c = await list(tester);
    const physics = EdgeStopScrollPhysics();
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 8000,
      pixels: 1000,
      viewportDimension: 600,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    final ours = physics.createBallisticSimulation(metrics, 2000)!;
    final apple = const BouncingScrollPhysics().createBallisticSimulation(
      metrics,
      2000,
    )!;
    expect(ours.x(0.5), apple.x(0.5));

    // Flung hard at the end, the list stops there: no rubber band.
    c.jumpTo(c.position.maxScrollExtent - 100);
    await tester.fling(find.byType(ListView), const Offset(0, -600), 4000);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.offset, lessThanOrEqualTo(c.position.maxScrollExtent));
    }
    expect(c.offset, c.position.maxScrollExtent);
  });
}
