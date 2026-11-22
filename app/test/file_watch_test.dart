import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/preview.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A file's watch that lost the daemon watches again after 2 s, and one
// disposed meanwhile leaves no timer behind.

void main() {
  testWidgets('a watch disposed while it waits to watch again leaves no '
      'timer', (tester) async {
    final watches = <StreamController<WatchChatFileResponse>>[];
    final fake = FakeDaemon([chat('c', 'claude', 'Fix')])
      ..streams = (input) {
        if (input is! WatchChatFileRequest) return null;
        // Closed by the test (lose).
        final s = StreamController<WatchChatFileResponse>();
        watches.add(s);
        return s.stream;
      };
    final d = await fake.connect(tester);
    final watch = FileWatch(d, 'c', 'a.go');
    await tester.pump();
    expect(watches, hasLength(1));

    // The daemon went away: it watches again 2 s later.
    Future<void> lose() async {
      watches.last.add(WatchChatFileResponse(path: '/x/a.go'));
      await tester.pump();
      unawaited(watches.last.close());
      await tester.pump();
    }

    await lose();
    expect(watch.live, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(watches, hasLength(2));

    await lose();
    // Waiting again: its timer goes with it, so none is left pending when
    // the test ends (the test fails on one that is).
    watch.dispose();
    await closeView(tester, d);
    expect(watches, hasLength(2));
  });
}
