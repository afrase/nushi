import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the memory: each chat, then the app and the daemon apart '
        '($name)', (tester) async {
      viewport(tester, const Size(720, 360));
      const mb = 1 << 20;
      final fake =
          FakeDaemon([
              chat(
                'a',
                'claude',
                'Wire the ledger',
                folder: '/Users/me/ledger',
              ),
            ])
            ..answer = (input) => switch (input) {
              GetMemoryRequest() => GetMemoryResponse(
                daemon: Int64(24 * mb),
                app: Int64(410 * mb),
                chats: {'a': Int64(230 * mb)}.entries,
              ),
              _ => null,
            };
      final d = await fake.connect(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: StatusBar(d)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('664 MB'));
      await tester.pumpAndSettle();
      expect(find.text('Wire the ledger', findRichText: true), findsOne);
      expect(find.text('Nushi app', findRichText: true), findsOne);
      expect(find.text('410 MB'), findsOne);
      expect(find.text('Nushi daemon', findRichText: true), findsOne);
      expect(find.text('24 MB'), findsOne);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/status_memory_$name.png'),
      );
      await closeView(tester, d);
    });
  }

  testWidgets('read every 5 s while the window shows, never while hidden, '
      'at once as it shows again; a reading that shows the same draws '
      'nothing', (tester) async {
    const mb = 1 << 20;
    var daemonBytes = 24 * mb;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        GetMemoryRequest() => GetMemoryResponse(daemon: Int64(daemonBytes)),
        _ => null,
      };
    final d = await fake.connect(tester);
    await tester.pumpWidget(themed(StatusBar(d)));
    await tester.pump();
    int reads() => fake.calls.whereType<GetMemoryRequest>().length;
    expect(reads(), 1);
    expect(find.text('24 MB'), findsOne);

    // A few bytes more: the same "24 MB", no frame.
    var frames = 0;
    var counting = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (counting) frames++;
    });
    daemonBytes += 1000;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    counting = false;
    expect(reads(), 2);
    expect(frames, 0);

    daemonBytes = 30 * mb;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(reads(), 3);
    expect(find.text('30 MB'), findsOne);

    // The app's state, one step at a time as the engine changes it.
    void become(List<AppLifecycleState> states) =>
        states.forEach(tester.binding.handleAppLifecycleStateChanged);

    // Hidden (main.dart says so to macView as the app's state changes).
    become([.inactive, .hidden]);
    d.macView.window = false;
    await tester.pump(const Duration(seconds: 15));
    expect(reads(), 3);
    // Shown again, it reads at once, then every 5 s.
    daemonBytes = 40 * mb;
    d.macView.window = true;
    become([.inactive, .resumed]);
    await tester.pump();
    expect(reads(), 4);
    expect(find.text('40 MB'), findsOne);
    await tester.pump(const Duration(seconds: 5));
    expect(reads(), 5);

    await closeView(tester, d);
  });
}
