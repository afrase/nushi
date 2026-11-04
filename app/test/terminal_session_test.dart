import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/terminals.dart';

import 'fake_daemon.dart';

void main() {
  // A restart here: the old shell's stream ends (as the daemon ends it,
  // just before the restart's answer), then the session attaches anew.
  // The old stream's retry mustn't attach once more and replay the
  // screen twice.
  testWidgets('a restart attaches once', (tester) async {
    final streams = <StreamController<AttachTerminalResponse>>[];
    final fake = FakeDaemon([])
      ..streams = (input) {
        if (input is! AttachTerminalRequest) return null;
        final s = StreamController<AttachTerminalResponse>()
          ..add(AttachTerminalResponse(data: utf8.encode(r'$ ')));
        streams.add(s);
        return s.stream;
      };
    final session = TermSession(NushiServiceClient(fake), 't1', 'c1');
    addTearDown(() {
      session.dispose();
      for (final s in streams) {
        unawaited(s.close());
      }
    });
    session.terminal.resize(80, 24); // its view laid out: it attaches
    await tester.pump();
    expect(streams, hasLength(1));

    unawaited(streams.first.close()); // the old shell gone
    await tester.pump();
    session
      ..fresh = true
      ..attach();
    final restarted = session.terminal..resize(80, 24);
    await tester.pump();
    expect(streams, hasLength(2));
    await tester.pump(const Duration(seconds: 2)); // past the retry's wait
    expect(
      session.terminal,
      same(restarted),
      reason: 'attached again: the screen replays twice',
    );

    // The daemon going away still brings it back.
    unawaited(streams.last.close());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(session.terminal, isNot(same(restarted)));
    session.terminal.resize(80, 24);
    await tester.pump();
    expect(streams, hasLength(3));
  });
}
