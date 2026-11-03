import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The shell's motion (the fluidity review's ideas 7 and 10): panes slide
// in and out, the chat's text glides by a transform with the
// transcript laid out once at its new width, and the terminal slides up
// laid out at its own height.

const _asked = 'Where is the login redirect handled?';

final _items = [
  Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: _asked),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'It is handled in the redirect module.',
  ),
];

/// The app 1700 wide on a chat, the details shown or not, its terminals
/// one shell's.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  bool details = false,
  bool still = false,
}) async {
  viewport(tester, const Size(1700, 700));
  if (still) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  showDetails.value = details;
  paneWidths.value = {};
  final c = chat('c', 'claude', 'Fix the login redirect');
  final fake = FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c, items: _items),
      ListTerminalsRequest(:final chatId) => ListTerminalsResponse(
        terminals: [
          Terminal(id: 't1', chatId: chatId, folder: '/tmp', shell: 'zsh'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) => input is AttachTerminalRequest
        ? (StreamController<AttachTerminalResponse>()
                ..add(AttachTerminalResponse(data: utf8.encode(r'$ '))))
              .stream
        : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Finder get _details => find.byType(DetailsPanel);
Finder get _text => find.text(_asked);

/// The chat's transcript's box, as laid out (a glide only moves its drawing).
Size _transcript(WidgetTester tester) => tester.getSize(
  find.byWidgetPredicate((w) => w is Transcript && w.items == null),
);

double _x(WidgetTester tester, Finder f) => tester.getTopLeft(f).dx;

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  testWidgets('the details slide in from the right edge; the transcript is '
      'laid out at its new width at once and its text glides there', (
    tester,
  ) async {
    final (d, _) = await _app(tester);
    final wide = _transcript(tester).width;
    final from = _x(tester, _text);

    showDetails.value = true;
    await tester.pump();
    const width = DetailsPanel.width;
    expect(_transcript(tester).width, wide - width);
    expect(_x(tester, _details), 1700); // just off the window's edge
    expect(_x(tester, _text), moreOrLessEquals(from, epsilon: 0.5));

    await tester.pump(Motion.enter ~/ 2);
    final midPane = _x(tester, _details);
    final midText = _x(tester, _text);
    expect(midPane, inExclusiveRange(1700 - width, 1700));
    expect(_transcript(tester).width, wide - width); // laid out once
    await tester.pumpAndSettle();
    final to = _x(tester, _text);
    expect(to, lessThan(from));
    expect(midText, inExclusiveRange(to, from));
    expect(_x(tester, _details), 1700 - width);
    d.dispose();
  }, variant: _mac);

  testWidgets('closing, the details keep their place until they are out, '
      'taking no pointer; the transcript takes the room at once', (
    tester,
  ) async {
    final (d, _) = await _app(tester, details: true);
    final narrow = _transcript(tester).width;
    final at = _x(tester, _details);

    showDetails.value = false;
    await tester.pump();
    expect(_transcript(tester).width, narrow + DetailsPanel.width);
    expect(_details, findsOneWidget);
    expect(_x(tester, _details), moreOrLessEquals(at, epsilon: 1));
    final ignoring = tester.widgetList<IgnorePointer>(
      find.ancestor(of: _details, matching: find.byType(IgnorePointer)),
    );
    expect(ignoring.any((w) => w.ignoring), isTrue);

    await tester.pump(Motion.exit ~/ 2);
    expect(_x(tester, _details), inExclusiveRange(at, 1700));
    await tester.pump(Motion.exit);
    await tester.pump();
    expect(_details, findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('a second toggle mid-slide turns it back from where it is', (
    tester,
  ) async {
    final (d, _) = await _app(tester);
    showDetails.value = true;
    await tester.pump();
    await tester.pump(Motion.enter ~/ 3);
    final mid = _x(tester, _details);
    final text = _x(tester, _text);
    expect(mid, inExclusiveRange(1700 - DetailsPanel.width, 1700));

    showDetails.value = false;
    await tester.pump();
    // Where it was, then out again; the text from where it was drawn.
    expect(_x(tester, _details), moreOrLessEquals(mid, epsilon: 2));
    expect(_x(tester, _text), moreOrLessEquals(text, epsilon: 2));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_x(tester, _details), greaterThan(mid));
    await tester.pumpAndSettle();
    expect(_details, findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('the text takes a click mid-glide, where it is drawn', (
    tester,
  ) async {
    final (d, _) = await _app(tester);
    showDetails.value = true;
    await tester.pump();
    await tester.pump(Motion.enter ~/ 4);
    // The hit lands on the text where it's drawn, not where it's laid out.
    final hit = tester.hitTestOnBinding(tester.getCenter(_text));
    final text = tester.renderObject(_text);
    expect(hit.path.any((e) => e.target == text), isTrue);
    await tester.pumpAndSettle();
    d.dispose();
  }, variant: _mac);

  testWidgets('with Reduce Motion the panes and the text are where they go '
      'at once', (tester) async {
    final (d, _) = await _app(tester, still: true);
    showDetails.value = true;
    await tester.pump();
    expect(_x(tester, _details), 1700 - DetailsPanel.width);
    final at = _x(tester, _text);
    await tester.pumpAndSettle();
    expect(_x(tester, _text), at);
    showDetails.value = false;
    await tester.pump();
    expect(_details, findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('the terminal slides up laid out at its own height: its '
      'shell is sized once', (tester) async {
    final (d, fake) = await _app(tester);
    int resizes() => fake.calls.whereType<ResizeTerminalRequest>().length;
    final chatHeight = _transcript(tester).height;

    terminalChats.value = {'c'};
    await tester.pump();
    final panel = find.byType(TerminalPanel);
    final full = tester.getSize(panel).height;
    expect(full, 260);
    await tester.pump();
    final sized = resizes();
    await tester.pump(Motion.enter ~/ 2);
    // Half-way: the slot part open, the panel whole under the clip.
    final top = tester.getTopLeft(panel).dy;
    expect(top, inExclusiveRange(700 - 260 - 22, 700 - 22));
    expect(tester.getSize(panel).height, full);
    expect(
      _transcript(tester).height,
      inExclusiveRange(chatHeight - 260, chatHeight),
    );
    await tester.pumpAndSettle();
    expect(resizes(), sized);
    expect(_transcript(tester).height, chatHeight - 260);

    terminalChats.value = {};
    await tester.pump();
    expect(panel, findsOneWidget); // it goes down whole
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(resizes(), sized);
    expect(_transcript(tester).height, chatHeight);
    await closeView(tester, d);
  }, variant: _mac);
}
