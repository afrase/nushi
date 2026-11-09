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

Int64 _ago(Duration d) => Int64(fixtureNow.subtract(d).millisecondsSinceEpoch);

/// Claude's sessions: three on the first page, one on the next.
ListAgentSessionsResponse _pages(ListAgentSessionsRequest r) =>
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
Future<(FakeDaemon, Daemon, List<FoundSession>, List<bool>)> _list(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
  String folder = '/Users/me/nushi',
}) async {
  final fake = FakeDaemon(const [])..sessions = _pages;
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

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the field filters the titles loaded, case aside; the arrows '
      'and Enter go by what shows', (tester) async {
    final (_, d, opened, _) = await _list(tester);
    expect(find.text('Rename the relay flags'), findsOne);
    await _type(tester, 'FLAKY');
    expect(find.text('Fix the flaky test'), findsOne);
    expect(find.text('Flaky relay reconnect'), findsOne);
    expect(find.text('Rename the relay flags'), findsNothing);
    expect(find.text('More'), findsOne); // the next page isn't filtered yet
    await _type(tester, 'relay');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(opened.single.sessionId, 's3');
    d.dispose();
  });

  testWidgets('no title loaded matches: it says so, and More looks further', (
    tester,
  ) async {
    final (fake, d, opened, _) = await _list(tester);
    await _type(tester, 'zebra');
    expect(find.text('No title loaded so far says “zebra”.'), findsOne);
    await _key(tester, LogicalKeyboardKey.enter); // More, the only row
    expect(fake.listed.last.cursor, 'p2');
    expect(find.text('Zebra stripes'), findsOne);
    await _type(tester, 'zebras');
    expect(find.text('No title says “zebras”.'), findsOne);
    expect(opened, isEmpty);
    d.dispose();
  });

  testWidgets('← goes back only from an empty field; Esc always', (
    tester,
  ) async {
    final (_, d, _, back) = await _list(tester);
    await _type(tester, 'fix');
    await _key(tester, LogicalKeyboardKey.arrowLeft); // the caret moves
    expect(back, isEmpty);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(back, hasLength(1));
    await _type(tester, '');
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(back, hasLength(2));
    d.dispose();
  });
}
