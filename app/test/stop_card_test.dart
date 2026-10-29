import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/queue.dart';
import 'package:nushi/stop_label.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A made-up background command of several lines, and one whose first line
/// runs long.
const _loop = 'until test -f /tmp/made-up/ready; do\n  sleep 60\ndone';
const _long =
    r'for f in build/out/*.log; do grep -c "made-up error pattern" "$f"; done';

/// A chat running both in the background: a stop of the first was sent
/// (Claude stopped it), a stop of the second waits in the queue.
ChatState _chat() => ChatState('c', '/Users/me/made-up')
  ..agent = 'claude'
  ..loaded = true
  ..items.addAll([
    for (final (id, task, command) in [
      ('s1', 'bloop0001', _loop),
      ('s2', 'blong0002', _long),
    ])
      Item(
        id: id,
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        tool: 'Bash',
        title: command,
        toolKind: 'execute',
        status: 'completed',
        shell: Shell(id: task, state: 'running'),
      ),
  ])
  ..queue = [
    QueuedMessage(id: 'q1', relayTo: _long, toSubagent: 's2', relayStop: true),
  ];

final _sent = Item(
  id: 'u1',
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  relayTo: _loop,
  relayCall: 's1',
  relayState: 'relayed',
  relayStop: true,
);

Future<void> _pump(
  WidgetTester tester,
  Daemon d,
  ChatState chat,
  Tokens tokens,
  double width,
) async {
  viewport(tester, Size(width, 240));
  await tester.pumpWidget(
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        backgroundColor: tokens.base,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemView(_sent, chat, d, live: false, still: false),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: QueuePills(chat, onEdit: (_) {}, onRemove: (_) {}),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  test('a stop names a command by its first line, cut to about 60', () {
    expect(stopCommand(_loop), 'until test -f /tmp/made-up/ready; do …');
    expect(stopCommand('sleep 600'), 'sleep 600');
    final cut = stopCommand(_long);
    expect(cut.runes.length, stopCommandLength);
    expect(cut, endsWith('…'));
    expect(_long, startsWith(cut.substring(0, cut.length - 1)));
  });

  testWidgets('a stop is one line, queued and sent', (tester) async {
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    final chat = _chat();
    d.chats['c'] = chat;
    await _pump(tester, d, chat, Tokens.dark, 720);
    final sent = find.textContaining(
      'Stop: until test -f /tmp/made-up/ready; do …',
      findRichText: true,
    );
    final queued = find.textContaining(
      'Stop: ${stopCommand(_long)}',
      findRichText: true,
    );
    expect(sent, findsOneWidget);
    expect(queued, findsOneWidget);
    expect(find.textContaining('sleep 60', findRichText: true), findsNothing);
    expect(find.textContaining(r'"$f"', findRichText: true), findsNothing);
    for (final line in [sent, queued]) {
      final text = tester.widget<RichText>(line);
      expect(text.maxLines, 1);
      // One line high: the text's own height, not wrapped.
      expect(tester.getSize(line).height, lessThan(22));
    }
    expect(find.textContaining('stopped', findRichText: true), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final (size, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
      testWidgets('stops, $size ($name)', (tester) async {
        final fake = FakeDaemon([]);
        final d = await fake.connect(tester);
        final chat = _chat();
        d.chats['c'] = chat;
        await _pump(tester, d, chat, tokens, width);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/stop_card_${size}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
