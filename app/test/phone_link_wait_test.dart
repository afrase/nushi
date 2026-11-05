// The phone's Link when a ping's answer is late (link.dart): behind a large
// upload on a slow uplink the channel still moves bytes, and isn't dropped;
// a silent one is, after Link.answer.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/link.dart';

import 'fake_daemon.dart';

/// A Link on a live channel whose pings [answer] answers, its bytes moved
/// read from [moved], counting its resets.
(Link, Daemon, List<int>) _link(
  Completer<PingResponse> answer,
  int Function() moved,
) {
  final fake = FakeDaemon([])
    ..answer = (input) => input is PingRequest ? answer.future : null;
  final d = Daemon(transport: fake, remote: true);
  final resets = <int>[];
  final link = Link(
    d,
    reset: () async => resets.add(1),
    live: () => true,
    moved: moved,
  );
  return (link, d, resets);
}

void main() {
  testWidgets('a ping late behind an upload keeps a channel that moves', (
    tester,
  ) async {
    final answer = Completer<PingResponse>();
    var moved = 0;
    final (link, d, resets) = _link(answer, () => moved);
    var ok = false;
    unawaited(link.check().then((v) => ok = v));
    // 20 s at about 64 KB/s going out (0.5 Mbit/s), the ping behind it.
    for (var s = 0; s < 20; s++) {
      moved += 64000;
      await tester.pump(const Duration(seconds: 1));
    }
    expect(resets, isEmpty);
    answer.complete(PingResponse(apiVersion: apiVersion));
    await tester.pump();
    await tester.pump();
    expect(ok, isTrue);
    expect(d.connected, isTrue);
    link.dispose();
    d.dispose();
  });

  testWidgets('a silent channel is dropped after Link.answer', (tester) async {
    final answer = Completer<PingResponse>();
    final (link, d, resets) = _link(answer, () => 5);
    bool? ok;
    unawaited(link.check().then((v) => ok = v));
    await tester.pump(Link.answer - const Duration(seconds: 1));
    expect(resets, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(resets, isNotEmpty);
    // The reset ends the ping on a real channel; here its answer fails.
    answer.completeError(StateError('connection lost'));
    await tester.pump();
    await tester.pump();
    expect(ok, isFalse);
    expect(link.failures, 1);
    link.dispose();
    d.dispose();
  });
}
