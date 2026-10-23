import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/bottom_follower.dart';

void main() {
  testWidgets('a slow scroll up stops following, scrolling down resumes', (
    tester,
  ) async {
    final f = BottomFollower();
    // Items of varying heights, built lazily, as in a transcript.
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
              child: ListView.builder(
                controller: f.scroll,
                itemCount: count,
                itemBuilder: (_, i) =>
                    SizedBox(height: 20.0 + (i % 7) * 40, child: Text('$i')),
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
    final at = tester.getCenter(find.byType(ListView));
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
}
