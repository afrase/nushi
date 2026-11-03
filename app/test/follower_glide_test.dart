import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/bottom_follower.dart';

/// A list of rows of 20 px under [f], as many as [count] says.
Widget _rows(BottomFollower f, int Function() count) => MaterialApp(
  home: StatefulBuilder(
    builder: (context, _) {
      f.stick();
      return NotificationListener(
        onNotification: f.onNotification,
        child: SingleChildScrollView(
          controller: f.scroll,
          child: Column(
            children: [
              for (var i = 0; i < count(); i++)
                SizedBox(height: 20, child: Text('$i')),
            ],
          ),
        ),
      );
    },
  ),
);

void main() {
  testWidgets('a glide from far up jumps to a screen above, then glides', (
    tester,
  ) async {
    final f = BottomFollower();
    addTearDown(f.dispose);
    var count = 5000; // 100,000 px: a long chat
    late StateSetter grow;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          grow = setState;
          return _rows(f, () => count);
        },
      ),
    );
    await tester.pumpAndSettle();
    final p = f.scroll.position;
    f.hold(0);
    await tester.pump();
    expect(f.following, isFalse);

    final screen = p.viewportDimension;
    f.follow(glide: true);
    expect(f.gliding, isTrue);
    expect(f.following, isFalse);
    // At once a screen above the bottom, not a trip through the chat.
    expect(p.maxScrollExtent - p.pixels, closeTo(screen, 1));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    final mid = p.maxScrollExtent - p.pixels;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(screen));
    // What the agent writes meanwhile moves the bottom it goes to, and the
    // glide still ends on time.
    grow(() => count += 10);
    await tester.pump(const Duration(milliseconds: 160));
    expect(f.gliding, isFalse);
    expect(f.following, isTrue);
    expect(p.pixels, p.maxScrollExtent);
  });

  testWidgets('a glide from near goes the whole way; a wheel stops it', (
    tester,
  ) async {
    final f = BottomFollower();
    addTearDown(f.dispose);
    await tester.pumpWidget(_rows(f, () => 200));
    await tester.pumpAndSettle();
    final p = f.scroll.position;
    final from = p.maxScrollExtent - p.viewportDimension * 1.5;
    f.hold(from);
    await tester.pump();
    f.follow(glide: true);
    expect(p.pixels, from); // within two screens, no jump
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 40));
    expect(p.pixels, greaterThan(from));
    final at = tester.getCenter(find.byType(SingleChildScrollView));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: at, scrollDelta: const Offset(0, -30)),
    );
    await tester.pump();
    expect(f.gliding, isFalse);
    expect(f.following, isFalse);
    final stopped = p.pixels;
    await tester.pumpAndSettle();
    expect(p.pixels, stopped);
  });
}
