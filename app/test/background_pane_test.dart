import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_commands.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A background command's pane beside the chat: the command, its state,
// its output as far as the daemon read it; Stop while it runs, × closes.

Item _command(String state, {String output = ''}) => Item(
  id: 'call-1',
  title: 'npm run dev',
  backgroundCommand: BackgroundCommand(
    state: state,
    started: Int64(
      fixtureNow.subtract(const Duration(seconds: 12)).millisecondsSinceEpoch,
    ),
    output: output,
  ),
);

/// The pane on chat c, which holds [items]; the list is a 1 per ×.
Future<(FakeDaemon, Daemon, ChatState, List<int>)> _pane(
  WidgetTester tester,
  List<Item> items,
) async {
  final fake = FakeDaemon([]);
  final d = await fake.connect(tester);
  final chat = ChatState('c', '/Users/me/nushi')..items.addAll(items);
  final closed = <int>[];
  await tester.pumpWidget(
    themed(
      SizedBox(
        width: 480,
        height: 600,
        child: BackgroundCommandPane(
          chat: chat,
          daemon: d,
          id: 'call-1',
          onClose: () => closed.add(1),
        ),
      ),
    ),
  );
  return (fake, d, chat, closed);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('running: its output so far, its time, Stop stops it; × '
      'closes', (tester) async {
    final (fake, d, _, closed) = await _pane(tester, [
      _command('running', output: 'ready on :5173'),
    ]);
    expect(find.text('npm run dev'), findsOne);
    expect(find.text(r'$ npm run dev'), findsOne);
    expect(find.text('running · 12s'), findsOne);
    expect(find.text('Output so far'), findsOne);
    expect(find.text('ready on :5173'), findsOne);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    final stop = fake.calls.whereType<StopTaskRequest>().single;
    expect((stop.chatId, stop.callId), ('c', 'call-1'));
    await tester.tap(find.byTooltip('Close'));
    expect(closed, [1]);
    await closeView(tester, d);
  });

  testWidgets('ended: no Stop, its output, or that there was none', (
    tester,
  ) async {
    final (_, d, chat, _) = await _pane(tester, [_command('done')]);
    expect(find.byTooltip('Stop'), findsNothing);
    expect(find.text('Output'), findsOne);
    expect(find.text('None'), findsOne);
    // Its agent stopped first: it may still run.
    chat
      ..items.first = _command('started')
      ..notifyListeners();
    await tester.pump();
    expect(find.text('It may still run: its agent stopped first.'), findsOne);
    await closeView(tester, d);
  });

  testWidgets('gone from the chat (rewound, or the chat reloaded): it says '
      'so', (tester) async {
    final (_, d, _, _) = await _pane(tester, [Item(id: 'other')]);
    expect(find.text('This command is no longer in the chat.'), findsOne);
    expect(find.byTooltip('Close'), findsOne);
    await closeView(tester, d);
  });
}
