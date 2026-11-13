import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/link.dart';

import 'fake_daemon.dart';

// The phone's link to a Mac that doesn't answer (ADR 0054): tried again
// after 1 s, then twice as long each time up to 30 s, never while the
// page is hidden (iOS freezes it), and at once when it shows again.

void main() {
  testWidgets('a Mac that doesn’t answer is tried after 1, 2, 4, 8, 16, '
      '30 and 30 s; none while hidden; at once when shown', (tester) async {
    final fake = FakeDaemon([])..down = true;
    final d = Daemon(transport: fake, remote: true);
    var tries = 0;
    final link = Link(d, reset: () async {}, live: () => false);
    link
      ..addListener(() {
        if (link.trying) tries++; // a try starting
      })
      ..start();
    await tester.pump();
    expect(tries, 1);

    /// The next try comes [gap] after the last, not before.
    Future<void> nextAfter(Duration gap) async {
      final was = tries;
      await tester.pump(gap - const Duration(milliseconds: 1));
      expect(tries, was, reason: 'tried before $gap');
      await tester.pump(const Duration(milliseconds: 1));
      expect(tries, was + 1, reason: 'not tried after $gap');
    }

    for (final s in [1, 2, 4, 8, 16, 30, 30]) {
      await nextAfter(Duration(seconds: s));
    }
    expect(link.failures, 8);

    link.visible(shown: false);
    await tester.pump(const Duration(seconds: 60));
    expect(tries, 8);
    link.visible(shown: true);
    await tester.pump();
    expect(tries, 9);
    // Counting again from the first wait: what failed while hidden
    // doesn't count.
    await nextAfter(const Duration(seconds: 1));

    link.dispose();
    d.dispose();
    await tester.pump(const Duration(minutes: 1));
  });
}
