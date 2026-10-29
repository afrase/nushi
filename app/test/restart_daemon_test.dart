import 'dart:async';

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

  // Ten seconds of tries, on the test's clock rather than waited out.
  testWidgets('a daemon that never stops is said, not waited on quietly', (
    tester,
  ) async {
    final fake = FakeDaemon([])
      ..answer = (input) => input is PingRequest
          ? PingResponse(apiVersion: apiVersion, build: 'old')
          : null;
    final d = Daemon(transport: fake);
    await tester.pump(const Duration(milliseconds: 50));
    expect(d.connected, isTrue);
    Object? error;
    var done = false;
    unawaited(
      d.restartDaemon().then(
        (_) => done = true,
        onError: (Object e) => error = e,
      ),
    );
    await tester.pump(const Duration(seconds: 9));
    expect((done, error), (false, null)); // still trying
    await tester.pump(const Duration(seconds: 2));
    expect(error, isA<StateError>());
    d.dispose();
  });

  test(
    'one restart at a time: a second asked meanwhile is the same one',
    () async {
      var phase = 'old';
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
      Future<void>.delayed(
        const Duration(milliseconds: 100),
        () => phase = 'gone',
      );
      Future<void>.delayed(
        const Duration(milliseconds: 900),
        () => phase = 'new',
      );
      final first = d.restartDaemon();
      expect(d.restarting, isTrue);
      // A second stop would stop the daemon the first one started.
      expect(d.restartDaemon(), same(first));
      await first;
      expect((d.restarting, d.connected, phase), (false, true, 'new'));
    },
  );

  test(
    'one ping at a time: a ping asked while one is out gets its answer',
    () async {
      final answer = Completer<PingResponse>();
      final fake = FakeDaemon([])
        ..answer = (input) => input is PingRequest ? answer.future : null;
      final d = Daemon(transport: fake); // its first ping is out
      addTearDown(d.dispose);
      final again = d.ping();
      answer.complete(PingResponse(apiVersion: apiVersion));
      expect(await again, isTrue);
      expect(fake.calls.whereType<PingRequest>(), hasLength(1));
    },
  );
}
