import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/status.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_picture.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart' show item, testRepo;
import 'harness.dart';
import 'project_tile_fixture.dart';

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

  testWidgets('a project’s animated tile: nothing is drawn while it '
      'rests, frames only while the pointer is on it', (tester) async {
    if (tileImagesDir.existsSync()) tileImagesDir.deleteSync(recursive: true);
    final image = keepTileImage((bytes: animatedGif(), kind: 'gif'));
    addTearDown(() => dropTileImage(image));
    projectTiles.value = {'/Users/me/nushi': TileLook(image: image)};
    final close = await _open(tester, [
      chat('a', 'claude', 'Speed up CI'),
      chat('b', 'codex', 'Tidy the docs', age: 30),
    ], shown: 'a');
    final tile = find.byType(TilePictureView);
    expect(tile, findsOneWidget);
    final state = tester.state<TilePictureViewState>(tile);
    await untilReal(tester, () => state.animated);
    await tester.pump(const Duration(seconds: 1));

    // At rest: its first frame, and no frame asked for.
    expect(await _framesOver(tester, const Duration(seconds: 12)), 0);
    expect(state.busy, isFalse);

    // Under the pointer it plays, a frame of the window for each of its
    // own (a tenth of a second each): the engine decodes on the real
    // clock, so real time passes between the display's.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(900, 500));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(tile));
    await tester.pump();
    await untilReal(tester, () => state.played >= 1);
    const vsync = Duration(microseconds: Duration.microsecondsPerSecond ~/ 60);
    final from = state.played;
    _frames = 0;
    _counting = true;
    for (var t = Duration.zero; t < const Duration(seconds: 1); t += vsync) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(vsync);
    }
    _counting = false;
    final shown = state.played - from;
    expect(shown, inInclusiveRange(5, 11));
    // No more of the window's frames than the image's own, and a few for
    // the pointer's tint on the header.
    expect(_frames, inInclusiveRange(shown, shown + 6));

    // Off it: the first frame again, and nothing drawn.
    await mouse.moveTo(const Offset(900, 500));
    await tester.pump(const Duration(seconds: 1));
    expect(state.busy, isFalse);
    expect(await _framesOver(tester, const Duration(seconds: 12)), 0);

    await close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

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
