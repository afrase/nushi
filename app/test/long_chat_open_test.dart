// How long a 2,000-item chat takes to open on the Mac: its first frame and
// all of what it loads laid out, and the snapshot's decoding (what the
// socket would carry). A measure, printed, with loose bounds: a debug
// widget test is several times slower than a release build. Before the
// recent part (ADR 0026) it laid out all 2,007 items over 39 frames.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';
import 'paged_chat.dart';

int _items() => find.byType(ItemView, skipOffstage: false).evaluate().length;

void main() {
  setUpAll(loadFonts);

  testWidgets('a 2,000-item chat opens', (tester) async {
    viewport(tester, const Size(1700, 1000));
    showDetails.value = false;
    final items = longChat('l', turns: 188);
    expect(items.length, greaterThanOrEqualTo(2000));
    final long = PagedChat(chat('l', 'claude', 'Long chat'), items);
    final short = chat('s', 'claude', 'Short chat', age: 5);
    final fake = FakeDaemon([long.chat, short])
      ..answer = (input) =>
          long.answer(input) ??
          (input is GetChatRequest
              ? GetChatResponse(chat: short, items: longChat('s', turns: 1))
              : null);
    final d = await fake.connect(tester);
    d.select('s');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();

    final watch = Stopwatch()..start();
    d.select('l');
    await tester.pump(); // the snapshot's answer
    await tester.pump(); // its first frame
    final first = watch.elapsedMilliseconds;
    var frames = 2;
    var was = -1;
    while (_items() != was) {
      was = _items();
      await tester.pump();
      frames++;
    }
    final total = watch.elapsedMilliseconds;
    final asked = long.asked.whereType<GetChatRequest>().last;
    final response = GetChatResponse(
      items: items.sublist(
        items.length - (asked.recent > 0 ? asked.recent : items.length),
      ),
    );
    final bytes = response.writeToBuffer();
    final decode = Stopwatch()..start();
    GetChatResponse.fromBuffer(bytes);
    // The measure, for whoever runs it (ADR 0026 has the numbers).
    // ignore: avoid_print
    print(
      'open ${items.length} items (recent ${asked.recent}): first frame '
      '$first ms, all of it laid out in $total ms over $frames frames, '
      '$was messages and steps; snapshot ${bytes.length ~/ 1024} KiB, '
      'decoded in ${decode.elapsedMilliseconds} ms',
    );
    expect(asked.recent, Daemon.macRecentItems);
    expect(frames, lessThan(12), reason: 'the recent part, a few frames');
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
