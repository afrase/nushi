// What showing and hiding the sidebar rebuilds on a long chat, frame by
// frame: the slide moves what's there and rebuilds next to nothing. A theme
// that compared unequal on every build (e0bad690 to 0.3.1) rebuilt the
// whole transcript on each of the slide's frames, 140–230 ms a frame in a
// profile build. Counts, not times: CI's load makes a time meaningless.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';

/// The most widgets a frame of the slide may rebuild: its own builders,
/// the moving sidebar button, a focus scope or two.
const _mostPerFrame = 20;

/// What each frame rebuilt: every widget, and the transcript's rows.
typedef _Frame = ({int builds, int rows});

/// Runs [change], then pumps 24 frames of 16 ms (past the slide's 240 ms),
/// counting what each frame rebuilds.
Future<List<_Frame>> _frames(WidgetTester tester, VoidCallback change) async {
  var builds = 0;
  var rows = 0;
  debugOnRebuildDirtyWidget = (e, _) {
    builds++;
    if (e.widget is ItemView) rows++;
  };
  final frames = <_Frame>[];
  try {
    change();
    for (var i = 0; i < 24; i++) {
      builds = rows = 0;
      await tester.pump(const Duration(milliseconds: 16));
      frames.add((builds: builds, rows: rows));
    }
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return frames;
}

void _expectQuiet(List<_Frame> frames, String what) {
  for (final (i, f) in frames.indexed.skip(1)) {
    expect(f.rows, 0, reason: '$what: rows rebuilt on frame $i');
    expect(
      f.builds,
      lessThanOrEqualTo(_mostPerFrame),
      reason: '$what: frame $i rebuilt ${f.builds}',
    );
  }
}

void main() {
  setUpAll(loadFonts); // the real fonts, as the app's rows are sized for

  late Chat a;
  late FakeDaemon fake;

  Future<Daemon> app(WidgetTester tester) async {
    viewport(tester, const Size(1700, 1000));
    sidebarHidden.value = false;
    a = chat('a', 'claude', 'A long chat');
    final items = longChat('a');
    fake = FakeDaemon([a, chat('b', 'codex', 'Another', age: 1)])
      ..answer = (input) => input is GetChatRequest && input.chatId == 'a'
          ? GetChatResponse(chat: a, items: items)
          : null;
    final d = await fake.connect(tester);
    d.select('a');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(find.byType(ItemView, skipOffstage: false), findsAtLeast(80));
    return d;
  }

  testWidgets('hiding and showing the sidebar rebuilds no row and next to '
      'nothing while it slides', (tester) async {
    final d = await app(tester);
    _expectQuiet(
      await _frames(tester, () => sidebarHidden.value = true),
      'hide',
    );
    _expectQuiet(
      await _frames(tester, () => sidebarHidden.value = false),
      'show',
    );
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('pinning the open chat rebuilds no row of its transcript', (
    tester,
  ) async {
    final d = await app(tester);
    final frames = await _frames(
      tester,
      () => fake.emit(EventsResponse(chatId: 'a', chat: a..pin = 1)),
    );
    // The sidebar moves the row into Pinned, a section of its own, and
    // rebuilds that section when its move ends: some 50 widgets, once.
    for (final (i, f) in frames.indexed) {
      expect(f.rows, 0, reason: 'rows rebuilt on frame $i');
      if (i > 0) {
        expect(
          f.builds,
          lessThanOrEqualTo(100),
          reason: 'frame $i rebuilt ${f.builds}',
        );
      }
    }
    expect(
      frames.skip(1).where((f) => f.builds > _mostPerFrame),
      hasLength(lessThanOrEqualTo(1)),
    );
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
