import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/bottom_follower.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('a slow scroll up stops following, scrolling down resumes', (
    tester,
  ) async {
    final f = BottomFollower();
    // Items of varying heights, all laid out, as in a transcript.
    var count = 80;
    late StateSetter grow;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            grow = setState;
            f.stick();
            return NotificationListener(
              onNotification: f.onNotification,
              child: SingleChildScrollView(
                controller: f.scroll,
                child: Column(
                  children: [
                    for (var i = 0; i < count; i++)
                      SizedBox(height: 20.0 + (i % 7) * 40, child: Text('$i')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p = f.scroll.position;
    expect(p.pixels, p.maxScrollExtent);

    // A trackpad-like scroll up in small steps, each well under a line.
    final at = tester.getCenter(find.byType(SingleChildScrollView));
    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(position: at, scrollDelta: const Offset(0, -3)),
      );
      await tester.pump();
    }
    expect(f.following, isFalse);
    final held = p.pixels;
    expect(held, lessThan(p.maxScrollExtent));

    // The agent writes on: the list grows, and stays where the user is.
    grow(() => count += 5);
    await tester.pumpAndSettle();
    expect(p.pixels, held);

    // Scrolled back down to the bottom, it follows again.
    await tester.sendEventToBinding(
      PointerScrollEvent(position: at, scrollDelta: const Offset(0, 100000)),
    );
    await tester.pumpAndSettle();
    expect(f.following, isTrue);
    grow(() => count += 5);
    await tester.pumpAndSettle();
    expect(p.pixels, p.maxScrollExtent);
  });

  testWidgets("the app's scrolling stops at the ends; following holds", (
    tester,
  ) async {
    final f = BottomFollower();
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const NativeScroll(),
        home: NotificationListener(
          onNotification: f.onNotification,
          child: SingleChildScrollView(
            controller: f.scroll,
            child: Column(
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 40, child: Text('$i')),
              ],
            ),
          ),
        ),
      ),
    );
    f.stick();
    await tester.pumpAndSettle();
    final p = f.scroll.position;
    final list = find.byType(SingleChildScrollView);
    expect(p.physics, isA<EdgeStopScrollPhysics>());

    // At the bottom, a fling down never goes past it: still following.
    final seen = <double>[];
    void track() => seen.add(p.pixels);
    p.addListener(track);
    await tester.fling(list, const Offset(0, -300), 3000);
    await tester.pumpAndSettle();
    p.removeListener(track);
    expect(seen.every((px) => px <= p.maxScrollExtent), isTrue);
    expect(p.pixels, p.maxScrollExtent);
    expect(f.following, isTrue);

    // Dragged up a little, it stops following; a fling into the bottom
    // edge follows again once it lands there.
    await tester.drag(list, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(f.following, isFalse);
    await tester.fling(list, const Offset(0, -150), 4000);
    await tester.pumpAndSettle();
    expect(p.pixels, p.maxScrollExtent);
    expect(f.following, isTrue);

    // Flung to the top, it stops there; Jump to latest (follow) goes back
    // down and follows.
    await tester.fling(list, const Offset(0, 3000), 8000);
    await tester.pumpAndSettle();
    expect(p.pixels, 0);
    expect(f.following, isFalse);
    f.follow();
    tester.binding.scheduleFrame(); // the button going away rebuilds
    await tester.pumpAndSettle();
    expect(p.pixels, p.maxScrollExtent);
    expect(f.following, isTrue);
  });
}
