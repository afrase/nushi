import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcripts_section.dart';

import 'fake_daemon.dart';

/// Copies of six chats' transcripts, each last written some hours ago (under
/// 30 days: "3d ago" whenever the test runs).
List<TranscriptCopy> _copies() {
  final now = DateTime.now();
  TranscriptCopy copy(String id, String title, int bytes, int hours) =>
      TranscriptCopy(
        chatId: id,
        title: title,
        agent: 'claude',
        bytes: Int64(bytes),
        lastWrittenMs: Int64(
          now.subtract(Duration(hours: hours)).millisecondsSinceEpoch,
        ),
      );
  return [
    copy('a', 'Refactor the session store into its own package', 48 << 20, 2),
    copy('b', 'Fix the login redirect', 9 << 20, 75),
    copy('c', '', 3 << 20, 290),
    copy('d', 'Review the diff view', 840 << 10, 20),
    copy('e', 'Why does the build fail on CI?', 120 << 10, 5),
    copy('f', 'Rename the flag', 16 << 10, 1),
  ];
}

/// The calls the section made of the daemon, of [T].
List<T> _calls<T>(FakeDaemon fake) => fake.calls.whereType<T>().toList();

Future<(FakeDaemon, Daemon)> _show(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
  List<TranscriptCopy>? copies,
}) async {
  final fake = FakeDaemon([]);
  final list = copies ?? _copies();
  fake.answer = (input) => switch (input) {
    ListTranscriptsRequest() => ListTranscriptsResponse(
      copies: list,
      totalBytes: Int64(list.fold(0, (n, c) => n + c.bytes.toInt())),
    ),
    _ => null,
  };
  final d = await fake.connect(tester);
  var settings = Settings(
    sleepAfterMinutes: 30,
    keepTranscripts: true,
    transcriptDays: 90,
  );
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(520, 400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) => TranscriptsSection(
              client: d.client,
              settings: settings,
              onChange: (change) async {
                final next = settings.deepCopy();
                change(next);
                await d.client.setSettings(SetSettingsRequest(settings: next));
                setState(() => settings = next);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the copies, largest first, and what clears them ($name)', (
      tester,
    ) async {
      final (_, d) = await _show(tester, tokens: tokens);
      expect(find.text('61.0 MB in 6 chats'), findsOneWidget);
      expect(find.text('A deleted chat'), findsOneWidget);
      expect(find.text('Show all 6'), findsOneWidget);
      expect(find.text('Rename the flag'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/transcripts_$name.png'),
      );
      d.dispose();
    });
  }

  testWidgets('turning copies off asks; Delete copies clears them all', (
    tester,
  ) async {
    final (fake, d) = await _show(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Stop keeping transcripts?'), findsOneWidget);
    await tester.tap(find.text('Delete copies'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.keepTranscripts, isFalse);
    expect(_calls<ClearTranscriptsRequest>(fake).single.all, isTrue);
    d.dispose();
  });

  testWidgets('Keep copies turns copying off and clears nothing', (
    tester,
  ) async {
    final (fake, d) = await _show(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep copies'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.single.keepTranscripts, isFalse);
    expect(_calls<ClearTranscriptsRequest>(fake), isEmpty);

    // On again: nothing to ask.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.keepTranscripts, isTrue);
    d.dispose();
  });

  testWidgets('a chat’s copy, those older than some days, or on their own', (
    tester,
  ) async {
    final (fake, d) = await _show(tester);
    await tester.tap(find.text('Clear').first); // the largest chat's
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '14');
    await tester.tap(find.text('Clear').last);
    await tester.pumpAndSettle();
    final cleared = _calls<ClearTranscriptsRequest>(fake);
    expect(cleared.first.chatIds, ['a']);
    expect(cleared.last.olderThanDays, 14);

    await tester.tap(find.text('90 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('365 days'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.transcriptDays, 365);
    expect(fake.setSettings.last.keepTranscripts, isTrue);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('Clear every copy?'), findsOneWidget);
    await tester.tap(find.text('Clear all').last);
    await tester.pumpAndSettle();
    expect(_calls<ClearTranscriptsRequest>(fake).last.all, isTrue);
    d.dispose();
  });
}
