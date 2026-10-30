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
}
