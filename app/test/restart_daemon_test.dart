import 'package:connectrpc/connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';

void main() {
  test('a restart returns once the new daemon answers', () async {
    var phase = 'old'; // then 'gone', then 'new'
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        PingRequest() when phase == 'gone' => throw ConnectException(
          Code.unavailable,
          'no daemon',
        ),
        PingRequest() => PingResponse(apiVersion: apiVersion, build: phase),
        _ => null,
      };
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(d.connected, isTrue);

    // It goes, then the new one comes a moment later.
    Future<void>.delayed(
      const Duration(milliseconds: 100),
      () => phase = 'gone',
    );
    Future<void>.delayed(
      const Duration(milliseconds: 900),
      () => phase = 'new',
    );
    await d.restartDaemon();
    expect((d.connected, phase), (true, 'new'));
  });

  test('a daemon that never stops is said, not waited on quietly', () async {
    final fake = FakeDaemon([])
      ..answer = (input) => input is PingRequest
          ? PingResponse(apiVersion: apiVersion, build: 'old')
          : null;
    final d = Daemon(transport: fake);
    addTearDown(d.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await expectLater(d.restartDaemon(), throwsA(isA<StateError>()));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
