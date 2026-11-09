import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_daemon.dart' show loadFonts;
import 'session_fixtures.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('the field filters the titles loaded, case aside; the arrows '
      'and Enter go by what shows', (tester) async {
    final (_, d, opened, _) = await pumpSessionList(tester);
    expect(find.text('Rename the relay flags'), findsOne);
    await typeIn(tester, 'FLAKY');
    expect(find.text('Fix the flaky test'), findsOne);
    expect(find.text('Flaky relay reconnect'), findsOne);
    expect(find.text('Rename the relay flags'), findsNothing);
    expect(find.text('More'), findsOne); // the next page isn't filtered yet
    await typeIn(tester, 'relay');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);
    expect(opened.single.sessionId, 's3');
    d.dispose();
  });

  testWidgets('no title loaded matches: it says so, and More looks further', (
    tester,
  ) async {
    final (fake, d, opened, _) = await pumpSessionList(tester);
    await typeIn(tester, 'zebra');
    expect(find.text('No title loaded so far says “zebra”.'), findsOne);
    await press(tester, LogicalKeyboardKey.enter); // right after typing: search
    expect(fake.searched.single.text, 'zebra');
    await press(tester, LogicalKeyboardKey.enter); // More, the only row
    expect(fake.listed.last.cursor, 'p2');
    expect(find.text('Zebra stripes'), findsOne);
    await typeIn(tester, 'zebras');
    expect(find.text('No title says “zebras”.'), findsOne);
    expect(opened, isEmpty);
    d.dispose();
  });

  testWidgets('← goes back only from an empty field; Esc always', (
    tester,
  ) async {
    final (_, d, _, back) = await pumpSessionList(tester);
    await typeIn(tester, 'fix');
    await press(tester, LogicalKeyboardKey.arrowLeft); // the caret moves
    expect(back, isEmpty);
    await press(tester, LogicalKeyboardKey.escape);
    expect(back, hasLength(1));
    await typeIn(tester, '');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(back, hasLength(2));
    d.dispose();
  });
}
