import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  testWidgets('restarting the daemon asks first while a turn runs', (
    tester,
  ) async {
    final fake = FakeDaemon([
      Chat(
        id: 'c',
        agent: 'claude',
        folder: '/x',
        status: ChatStatus(busy: true),
      ),
    ]);
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => restartDaemonAsking(context, d),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Restart the daemon?'), findsOneWidget);
    expect(find.textContaining('stops 1 running turn'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Restart the daemon?'), findsNothing);
    await closeView(tester, d);
  });

  // A terminal running a command ends with the daemon, though its chat is
  // asleep, so the restart asks, saying what runs.
  testWidgets('it asks too while a terminal runs a command, with every '
      'chat asleep', (tester) async {
    final fake =
        FakeDaemon([
            Chat(
              id: 'c',
              agent: 'claude',
              folder: '/x',
              status: ChatStatus(asleep: true),
            ),
          ])
          ..answer = (i) => i is ListTerminalsRequest && i.chatId == 'c'
              ? ListTerminalsResponse(
                  terminals: [
                    Terminal(id: 't1', chatId: 'c', shell: 'zsh'),
                    Terminal(id: 't2', chatId: 'c', program: 'npm run dev'),
                  ],
                )
              : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => restartDaemonAsking(context, d),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Restart the daemon?'), findsOneWidget);
    expect(find.textContaining('“npm run dev”'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Restart the daemon?'), findsNothing);
    await closeView(tester, d);
  });
}
