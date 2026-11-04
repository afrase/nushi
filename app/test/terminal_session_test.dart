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

  // Restart shows only on an exited shell, so every other app has been
  // told it exited. Another app restarting it lists it running again:
  // this one attaches to the new shell, not left on the old output.
  testWidgets('a restart in another app attaches here', (tester) async {
    final (terms, streams, _) = _daemon();
    final t = Terminal(id: 't1', chatId: 'c1');
    terms.apply('c1', [t]);
    final session = terms.session(t);
    addTearDown(() {
      session.dispose();
      for (final s in streams) {
        unawaited(s.close());
      }
    });
    session.terminal.resize(80, 24);
    await tester.pump();
    await _exit(tester, terms, streams.first);
    expect(streams, hasLength(1));
    expect(session.exited, isTrue);

    terms.apply('c1', [t]); // restarted elsewhere
    await tester.pump();
    session.terminal.resize(80, 24); // its view laid out again
    await tester.pump();
    expect(streams, hasLength(2), reason: 'never attached to the new shell');
    expect(session.fresh, isFalse); // the app that restarted it answers
  });

  // A restart here whose list event comes before its answer attaches
  // once, when the answer comes, fresh.
  testWidgets('a restart here attaches once', (tester) async {
    final (terms, streams, fake) = _daemon();
    final answered = Completer<RestartTerminalResponse>();
    fake.answer = (input) =>
        input is RestartTerminalRequest ? answered.future : null;
    final t = Terminal(id: 't1', chatId: 'c1');
    terms.apply('c1', [t]);
    final session = terms.session(t);
    addTearDown(() {
      session.dispose();
      for (final s in streams) {
        unawaited(s.close());
      }
    });
    session.terminal.resize(80, 24);
    await tester.pump();
    await _exit(tester, terms, streams.first);

    final restart = terms.restart('t1');
    await tester.pump();
    final old = session.terminal;
    terms.apply('c1', [t]); // its list event, before its answer
    expect(session.terminal, same(old));
    answered.complete(RestartTerminalResponse());
    await restart;
    expect(session.fresh, isTrue);
    session.terminal.resize(80, 24);
    await tester.pump();
    expect(streams, hasLength(2));
  });
}

/// A daemon whose attaches are the streams returned, each starting with a
/// prompt.
(Terminals, List<StreamController<AttachTerminalResponse>>, FakeDaemon)
_daemon() {
  final streams = <StreamController<AttachTerminalResponse>>[];
  final fake = FakeDaemon([])
    ..streams = (input) {
      if (input is! AttachTerminalRequest) return null;
      final s = StreamController<AttachTerminalResponse>()
        ..add(AttachTerminalResponse(data: utf8.encode(r'$ ')));
      streams.add(s);
      return s.stream;
    };
  return (Terminals(NushiServiceClient(fake)), streams, fake);
}

/// The shell exits: the daemon says so, ends the stream, and lists it so.
Future<void> _exit(
  WidgetTester tester,
  Terminals terms,
  StreamController<AttachTerminalResponse> stream,
) async {
  stream.add(AttachTerminalResponse(exited: true, exitCode: 0));
  unawaited(stream.close());
  terms.apply('c1', [Terminal(id: 't1', chatId: 'c1', exited: true)]);
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}
