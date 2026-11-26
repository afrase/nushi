import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/terminal_session.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

void main() {
  testWidgets('the shell is told its size at once, then at most every '
      '100 ms while it changes, and the last size always', (tester) async {
    final fake = FakeDaemon([chat('c', 'claude', 'Fix it')]);
    FakeShells(
      fake,
      terminals: [
        Terminal(id: 't', chatId: 'c', folder: '/Users/me', shell: 'fish'),
      ],
    );
    final d = await fake.connect(tester);
    final s = TermSession(d.client, 't', 'c');
    List<(int, int)> sent() => [
      for (final r in fake.calls.whereType<ResizeTerminalRequest>())
        (r.cols, r.rows),
    ];
    s.terminal.resize(80, 24);
    await tester.pump();
    expect(sent(), [(80, 24)]);
    // A drag: a new size every frame for half a second.
    for (var i = 1; i <= 30; i++) {
      s.terminal.resize(80 + i, 24);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(TermSession.resizeEvery);
    final sizes = sent();
    expect(sizes.last, (110, 24));
    // 480 ms of changes: the first, about one every 100 ms, and the last.
    expect(sizes.length, inInclusiveRange(5, 7));
    // Still: nothing more is sent.
    await tester.pump(const Duration(seconds: 1));
    expect(sent(), sizes);
    // The same size again isn't a change the emulator reports.
    s.terminal.resize(110, 24);
    await tester.pump(TermSession.resizeEvery);
    expect(sent(), sizes);
    s.dispose();
    await closeView(tester, d);
  });

  testWidgets('a session gone mid-spell sends nothing more', (tester) async {
    final fake = FakeDaemon([chat('c', 'claude', 'Fix it')]);
    FakeShells(fake);
    final d = await fake.connect(tester);
    final s = TermSession(d.client, 't', 'c');
    int sent() => fake.calls.whereType<ResizeTerminalRequest>().length;
    s.terminal.resize(80, 24);
    await tester.pump();
    s.terminal.resize(90, 24);
    s.dispose();
    await tester.pump(TermSession.resizeEvery * 2);
    expect(sent(), 1);
    await closeView(tester, d);
  });
}
