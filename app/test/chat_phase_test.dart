// A chat's state in a word: worked out once (ChatState.phase), so the
// Mac's header and the phone's row say the same.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// A chat in each state, by the word both say.
final Map<String, Chat> _chats = {
  'working': chat('w', 'claude', 'W', status: ChatStatus(busy: true)),
  'needs you': chat(
    'n',
    'codex',
    'N',
    status: ChatStatus(busy: true, waiting: true),
  ),
  'done': chat('u', 'claude', 'U')..unseen = true,
  // A turn's end while subagents or commands run on: not "idle", nor
  // "done" while unseen.
  'in background': chat('b', 'claude', 'B', status: ChatStatus(background: 2))
    ..unseen = true,
  'idle': chat('i', 'ante', 'I')..unseen = false,
  'asleep': chat('s', 'omp', 'S', status: ChatStatus(asleep: true)),
  "couldn't start": chat(
    'c',
    'pig',
    'C',
    status: ChatStatus(reopenFailed: true),
  ),
  // Its agent deleted the session: the daemon says the reopen failed too.
  'expired': chat(
    'e',
    'claude',
    'E',
    status: ChatStatus(reopenFailed: true, sessionGone: true),
  )..unseen = true,
};

void main() {
  testWidgets('the Mac and the phone say the same word for each state', (
    tester,
  ) async {
    final d = await FakeDaemon(_chats.values.toList()).connect(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ListView(
              children: [
                for (final c in _chats.values) ...[
                  ChatRow(d.chats[c.id]!, onTap: () {}),
                  ChatStatusWord(
                    d.chats[c.id]!,
                    key: Key('mac ${c.id}'),
                    style: const TextStyle(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (final MapEntry(key: word, value: c) in _chats.entries) {
      final phone = find.descendant(
        of: find.ancestor(
          of: find.text(c.title),
          matching: find.byType(ChatRow),
        ),
        matching: find.text(word),
      );
      expect(phone, findsOne, reason: 'the phone, ${c.title}');
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(Key('mac ${c.id}')),
                matching: find.byType(Text),
              ),
            )
            .data,
        word,
        reason: 'the Mac, ${c.title}',
      );
    }
    expect(d.chats['e']!.phase, ChatPhase.expired);
    d.dispose();
  });

  test('a collapsed group: working in the background is under working, '
      'over an unseen end', () {
    ChatState of(ChatStatus s, {bool unseen = false}) => ChatState('x', '/f')
      ..status(s)
      ..unseen = unseen;
    final background = of(ChatStatus(background: 1));
    final unseen = of(ChatStatus(), unseen: true);
    final working = of(ChatStatus(busy: true));
    expect(groupPhase([unseen, background]), ChatPhase.background);
    expect(groupPhase([background, working]), ChatPhase.working);
    expect(background.phase, ChatPhase.background);
    expect(of(ChatStatus(busy: true, background: 1)).phase, ChatPhase.working);
  });
}
