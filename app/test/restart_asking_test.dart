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
}
