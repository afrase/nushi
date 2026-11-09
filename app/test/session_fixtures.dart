import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/open_session.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// SessionList on its own, for its tests.

Int64 _ago(Duration d) => Int64(fixtureNow.subtract(d).millisecondsSinceEpoch);

/// Claude's sessions: three on the first page, one on the next.
ListAgentSessionsResponse sessionPages(ListAgentSessionsRequest r) =>
    switch (r.cursor) {
      '' => ListAgentSessionsResponse(
        canList: true,
        seesOpen: true,
        nextCursor: 'p2',
        sessions: [
          FoundSession(
            sessionId: 's1',
            title: 'Fix the flaky test',
            folder: '/Users/me/nushi',
            updatedUnixMs: _ago(const Duration(minutes: 5)),
            messages: 12,
          ),
          FoundSession(
            sessionId: 's2',
            title: 'Rename the relay flags',
            folder: '/Users/me/nushi',
            updatedUnixMs: _ago(const Duration(hours: 3)),
          ),
          FoundSession(
            sessionId: 's3',
            title: 'Flaky relay reconnect',
            folder: '/Users/me/nushi',
            updatedUnixMs: _ago(const Duration(days: 2)),
          ),
        ],
      ),
      _ => ListAgentSessionsResponse(
        canList: true,
        sessions: [FoundSession(sessionId: 's4', title: 'Zebra stripes')],
      ),
    };

/// SessionList for Claude in a dialog of its own, on a fake daemon; what
/// it opens and whether it went back.
Future<(FakeDaemon, Daemon, List<FoundSession>, List<bool>)> pumpSessionList(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
  String folder = '/Users/me/nushi',
}) async {
  final fake = FakeDaemon(const [])..sessions = sessionPages;
  final d = await fake.connect(tester);
  final opened = <FoundSession>[];
  final back = <bool>[];
  await tester.pumpWidget(
    themed(
      tokens: tokens,
      Center(
        child: Dialog(
          child: SizedBox(
            width: 440,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SessionList(
                daemon: d,
                agent: 'claude',
                folder: folder,
                onOpen: opened.add,
                onBack: () => back.add(true),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d, opened, back);
}

Future<void> typeIn(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// What a search of Claude's sessions finds: two, the second open in a
/// terminal.
SearchAgentSessionsResponse sessionHits(SearchAgentSessionsRequest r) =>
    SearchAgentSessionsResponse(
      canSearch: true,
      seesOpen: true,
      hits: [
        SessionHit(
          session: FoundSession(
            sessionId: 's9',
            title: 'Old relay work',
            folder: '/Users/me/nushi',
            updatedUnixMs: _ago(const Duration(days: 6)),
          ),
          before: '…so why does the ',
          match: r.text,
          after:
              ' test fail only on CI? It passes here every time, and the '
              'logs say nothing useful about the relay at all…',
          count: 3,
        ),
        SessionHit(
          session: FoundSession(
            sessionId: 's8',
            title: 'Clock skew',
            folder: '/Users/me/nushi',
            updatedUnixMs: _ago(const Duration(days: 9)),
            openIn: 'a terminal',
          ),
          before: 'The ',
          match: r.text,
          after: ' one races the clock.',
          count: 1,
        ),
      ],
    );
