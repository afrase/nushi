import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon_settings.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';

void main() {
  testWidgets('asks once made; a change sends every setting', (tester) async {
    final fake = FakeDaemon([])
      ..settings = Settings(sleepAfterMinutes: 60, debugLog: false);
    final d = await fake.connect(tester);
    final s = DaemonSettings(d);
    addTearDown(s.dispose);
    await tester.pump();
    expect(s.value?.sleepAfterMinutes, 60);
    await s.change((s) => s.debugLog = true);
    expect(s.value?.debugLog, isTrue);
    final sent = fake.setSettings.single;
    expect((sent.sleepAfterMinutes, sent.debugLog), (60, true));
    d.dispose();
  });

  testWidgets('closed before the answer or mid-change, nothing throws, and '
      'a change queued behind starts from what the last one set', (
    tester,
  ) async {
    final asked = Completer<GetSettingsResponse>();
    final held = Completer<SetSettingsResponse>();
    final fake = FakeDaemon([])
      ..on(
        (input) => switch (input) {
          GetSettingsRequest() => asked.future,
          SetSettingsRequest() when !held.isCompleted => held.future,
          _ => null,
        },
      );
    final d = await fake.connect(tester);
    final early = DaemonSettings(d)..dispose();
    asked.complete(GetSettingsResponse(settings: Settings(debugLog: false)));
    await tester.pump();
    expect(early.value, isNull);

    final s = DaemonSettings(d);
    await tester.pump();
    final first = s.change((s) => s.sleepAfterMinutes = 15);
    final second = s.change((s) => s.debugLog = true);
    await tester.pump();
    s.dispose(); // Settings closed while the first is out
    held.complete(SetSettingsResponse());
    await tester.pump();
    await Future.wait([first, second]);
    final last = fake.setSettings.last;
    expect((last.sleepAfterMinutes, last.debugLog), (15, true));
    d.dispose();
  });
}
