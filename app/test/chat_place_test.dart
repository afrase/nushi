import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/bottom_follower.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';

// Jump to latest's glide and its chip, and a chat opening where it was
// left: on a chat thousands of lines long (longChat), as the owner's are.

/// The app with chats a and b, each [turns] long; [waiting] chats wait on
/// the user.
Future<Daemon> _app(
  WidgetTester tester, {
  int turns = 150,
  Set<String> waiting = const {},
}) async {
  viewport(tester, const Size(1400, 900));
  showDetails.value = false;
  final chats = [
    for (final id in ['a', 'b'])
      chat(
        id,
        'claude',
        'Chat $id',
        status: ChatStatus(waiting: waiting.contains(id)),
      ),
  ];
  final fake = FakeDaemon(chats)
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(
            chat: chats.firstWhere((c) => c.id == input.chatId),
            items: longChat(input.chatId, turns: turns),
            status: ChatStatus(waiting: waiting.contains(input.chatId)),
          )
        : null;
  final d = await fake.connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

ScrollPosition _list(WidgetTester tester) =>
    tester.widget<SingleChildScrollView>(_scroll).controller!.position;

final Finder _scroll = find
    .descendant(
      of: find.byType(Transcript),
      matching: find.byType(SingleChildScrollView),
    )
    .first;

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(of: find.byType(JumpChip), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  testWidgets('Jump to latest glides from far up in a long chat, briefly; '
      'its chip fades in and out', (tester) async {
    final d = await _app(tester);
    final p = _list(tester);
    expect(p.maxScrollExtent, greaterThan(100 * p.viewportDimension));
    expect(find.byType(JumpChip), findsNothing);

    // Far up: the chip fades in.
    p.jumpTo(p.maxScrollExtent * 0.2);
    await tester.drag(_scroll, const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(JumpChip), findsOneWidget);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);

    // Its tap: a screen above the bottom at once, then a glide; the chip
    // fades as it goes, and takes no click meanwhile.
    final screen = p.viewportDimension;
    await tester.tap(find.text('Jump to latest'));
    await tester.pump();
    expect(p.maxScrollExtent - p.pixels, lessThanOrEqualTo(screen + 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(p.maxScrollExtent - p.pixels, inExclusiveRange(0, screen));
    expect(_opacity(tester), lessThan(1));
    // Over within the glide's length (and a frame), however long the chat.
    await tester.pump(BottomFollower.glideFor);
    expect(p.pixels, p.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(JumpChip), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('with Reduce Motion Jump to latest jumps and the chip just '
      'goes', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final d = await _app(tester, turns: 30);
    final p = _list(tester);
    await tester.drag(_scroll, const Offset(0, 900));
    await tester.pump();
    expect(_opacity(tester), 1); // there at once
    await tester.tap(find.text('Jump to latest'));
    await tester.pump();
    expect(p.pixels, p.maxScrollExtent);
    expect(find.byType(JumpChip), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a chat left scrolled up opens there again, the chip showing; '
      'one left at its bottom opens at its bottom', (tester) async {
    final d = await _app(tester, turns: 60);
    var p = _list(tester);
    p.jumpTo(p.maxScrollExtent * 0.5);
    await tester.drag(_scroll, const Offset(0, 40));
    await tester.pumpAndSettle();
    final left = p.extentAfter;

    d.select('b');
    await tester.pumpAndSettle();
    p = _list(tester);
    expect(p.pixels, p.maxScrollExtent); // b, never scrolled: its bottom
    d.select('a');
    // Unseen while it fills in up to the place, a few frames, then there.
    double shown() => tester
        .widget<Opacity>(
          find.ancestor(of: _scroll, matching: find.byType(Opacity)).first,
        )
        .opacity;
    var frames = 0;
    do {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    } while (shown() == 0 && frames < 60);
    expect(frames, lessThan(10));
    p = _list(tester);
    expect(p.extentAfter, closeTo(left, 1));
    await tester.pumpAndSettle();
    expect(p.extentAfter, closeTo(left, 1));
    expect(find.text('Jump to latest'), findsOneWidget);

    // Back to the bottom, then away and back: at its bottom.
    await tester.tap(find.text('Jump to latest'));
    await tester.pumpAndSettle();
    d.select('b');
    await tester.pumpAndSettle();
    d.select('a');
    await tester.pumpAndSettle();
    p = _list(tester);
    expect(p.pixels, p.maxScrollExtent);
    expect(find.byType(JumpChip), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a chat that needs you opens at its bottom', (tester) async {
    final d = await _app(tester, turns: 40, waiting: {'a'});
    var p = _list(tester);
    p.jumpTo(p.maxScrollExtent * 0.5);
    await tester.drag(_scroll, const Offset(0, 40));
    await tester.pumpAndSettle();
    d.select('b');
    await tester.pumpAndSettle();
    d.select('a');
    await tester.pumpAndSettle();
    p = _list(tester);
    expect(p.pixels, p.maxScrollExtent);
    await closeView(tester, d);
  }, variant: _mac);
}
