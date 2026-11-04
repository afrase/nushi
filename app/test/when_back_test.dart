import 'package:connectrpc/connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  testWidgets('whenBack calls once the daemon is connected again, or another '
      'build answers; once, and not after a cancel', (tester) async {
    var down = false;
    var build = 'one';
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        PingRequest() when down => throw ConnectException(
          Code.unavailable,
          'daemon unavailable: dial failed',
        ),
        PingRequest() => PingResponse(apiVersion: apiVersion, build: build),
        _ => null,
      };
    final d = await fake.connect(tester);
    var back = 0;
    d.whenBack(() => back++);
    await tester.pump(const Duration(seconds: 2)); // the same daemon
    expect(back, 0);

    down = true;
    await tester.pump(const Duration(seconds: 2));
    expect(back, 0);
    down = false;
    await tester.pump(const Duration(seconds: 2));
    expect(back, 1);
    await tester.pump(const Duration(seconds: 2));
    down = true;
    await tester.pump(const Duration(seconds: 2));
    down = false;
    await tester.pump(const Duration(seconds: 2));
    expect(back, 1); // once

    // A restart between two pings: only the build says so.
    d.whenBack(() => back++);
    build = 'two';
    await tester.pump(const Duration(seconds: 2));
    expect(back, 2);

    d.whenBack(() => back++)();
    build = 'three';
    await tester.pump(const Duration(seconds: 2));
    expect(back, 2); // cancelled
    await closeView(tester, d);
  });

  test('daemonGone: only a call the daemon was unavailable for', () {
    expect(daemonGone(ConnectException(Code.unavailable, 'gone')), isTrue);
    expect(daemonGone(ConnectException(Code.internal, 'no')), isFalse);
    expect(daemonGone(StateError('no')), isFalse);
  });
}
