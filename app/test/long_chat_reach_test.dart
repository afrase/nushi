// What reaches past a long chat's recent part (ADR 0026): a pane open on
// an early subagent outlives the chat going back to its recent part.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';
import 'paged_chat.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The window on chat c, [items] paged, with another chat s to switch to.
Future<(Daemon, PagedChat)> _open(
  WidgetTester tester,
  List<Item> items, {
  ChatStatus? status,
  bool details = false,
}) async {
  viewport(tester, const Size(1700, 900));
  showDetails.value = details;
  final c = chat('c', 'claude', 'A long chat', status: status);
  final paged = PagedChat(c, items);
  final other = chat('s', 'claude', 'Short', age: 5);
  final fake = FakeDaemon([c, other])
    ..answer = (input) =>
        paged.answer(input) ??
        (input is GetChatRequest
            ? GetChatResponse(chat: other, items: longChat('s', turns: 1))
            : null);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await _settle(tester);
  return (d, paged);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a pane open on an early subagent stays after switching away '
      'at the bottom and back', (tester) async {
    final (d, _) = await _open(tester, longChat('c', turns: 100));
    final c = d.chats['c']!;
    await d.loadOlder(c, all: true);
    await _settle(tester);
    c.pane.value = 'c-sa3'; // opened from its row
    await _settle(tester);
    // Still at its bottom: away and back, which lets go of what's above.
    d.select('s');
    await _settle(tester);
    d.select('c');
    await _settle(tester);
    expect(c.older, greaterThan(0), reason: 'back to its recent part');
    expect(c.pane.value, 'c-sa3');
    expect(c.items.any((it) => it.id == 'c-sa3'), isTrue);
    expect(find.text('This subagent is no longer in the chat.'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);
}
