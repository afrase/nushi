import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/status.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart' show item, testRepo;
import 'harness.dart';

// Each frame draws the whole window again (Impeller keeps no raster
// cache), so what loops at rest costs a full window's text each time it
// ticks: these count the frames the window asks for, the display asking
// 60 times a second.

var _counting = false;
var _frames = 0;

/// The frames drawn over [span], pumped as a 60 Hz display would.
Future<int> _framesOver(WidgetTester tester, Duration span) async {
  const vsync = Duration(microseconds: Duration.microsecondsPerSecond ~/ 60);
  _frames = 0;
  _counting = true;
  for (var t = Duration.zero; t < span; t += vsync) {
    await tester.pump(vsync);
  }
  _counting = false;
  return _frames;
}

final _link = GitHubLink(
  host: 'github.com',
  repo: testRepo,
  number: 412,
  id: 'PR_412',
  pull: true,
);

/// The whole window on [shown] of [chats], every loop running as in the
/// app (no still frame), the composer unfocused (its caret blinks, as a
/// Mac's does), settled.
Future<Future<void> Function()> _open(
  WidgetTester tester,
  List<Chat> chats, {
  required String shown,
}) async {
  Shine.stopAt = null;
  addTearDown(() => Shine.stopAt = 0);
  viewport(tester, const Size(1700, 1000));
  final fake = FakeDaemon(chats)
    ..answer = (input) => switch (input) {
      GetGitHubStatesRequest() => GetGitHubStatesResponse(
        items: [item(412, 'Speed up CI', checks: 'pending')],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select(shown);
  await tester.pumpWidget(NushiApp(daemon: d));
  // Not pumpAndSettle: a loop never settles. Long enough for the pull
  // request's first look (a second after it's seen) and every slide.
  await tester.pump(const Duration(seconds: 2));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(seconds: 1));
  return () => closeView(tester, d);
}

void main() {
  setUpAll(() async {
    await loadFonts();
    TestWidgetsFlutterBinding.instance.addPersistentFrameCallback((_) {
      if (_counting) _frames++;
    });
  });

  const span = Duration(seconds: 3);
  final pulses = span.inSeconds * pulseRate;

  for (final (state, status, pull, looping)
      in <(String, ChatStatus, bool, Finder)>[
        (
          'working',
          ChatStatus(
            busy: true,
            started: Int64(fixtureNow.millisecondsSinceEpoch),
          ),
          false,
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is StatusMark &&
                (w.painter! as StatusMark).ringing,
          ),
        ),
        (
          'working in the background',
          ChatStatus(background: 1),
          false,
          find.byTooltip(backgroundWords(1)),
        ),
        (
          'its pull request checks running',
          ChatStatus(),
          true,
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is ChecksMark &&
                (w.painter! as ChecksMark).ringing,
          ),
        ),
      ]) {
    testWidgets('a chat $state: the window draws at the pulse rate, not '
        "the display's", (tester) async {
      final looper = chat('l', 'claude', 'Speed up CI', status: status);
      if (pull) looper.pull = _link;
      final close = await _open(tester, [
        looper,
        chat('i', 'codex', 'Tidy the docs', age: 30),
      ], shown: 'i');
      expect(looping, findsWidgets);

      final frames = await _framesOver(tester, span);
      // Each pulse, and at most one a second besides (an elapsed time).
      expect(frames, inInclusiveRange(pulses * 0.9, pulses + span.inSeconds));

      await close();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  testWidgets('every chat idle: the window draws nothing at all', (
    tester,
  ) async {
    final close = await _open(tester, [
      chat('a', 'claude', 'Speed up CI'),
      chat('b', 'codex', 'Tidy the docs', age: 30),
      chat('c', 'claude', 'Old work', status: ChatStatus(asleep: true)),
    ], shown: 'a');

    // Past the status bar's memory reading, every 5 s.
    expect(await _framesOver(tester, const Duration(seconds: 12)), 0);

    await close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
