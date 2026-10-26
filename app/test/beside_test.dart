import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_panel.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';

/// A chat whose agent started a subagent, which read a file.
final _items = [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Where is the login redirect handled?',
  ),
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    title: 'Find the redirect',
    status: 'completed',
    subagent: Subagent(state: 'done', result: 'In `auth/redirect.go`.'),
  ),
  Item(
    id: 'r',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'a',
    title: 'Read auth/redirect.go',
    status: 'completed',
  ),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'It is handled in `auth/redirect.go`.',
  ),
];

/// The app at [width] (the sidebar takes 260 of it) on a chat with a
/// subagent, the details panel shown or not.
Future<Daemon> _app(
  WidgetTester tester, {
  double width = 1400,
  bool details = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 560);
  addTearDown(tester.view.reset);
  showDetails.value = details;
  paneWidths.value = {};
  subagentWide.value = false;
  final c = chat('c', 'claude', 'Fix the login redirect');
  final fake = FakeDaemon([c])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: _items)
        : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Finder get _pane => find.byType(SubagentPane);
Finder get _details => find.byType(DetailsPanel);

/// The chat's own transcript, not the subagent pane's.
Rect _transcript(WidgetTester tester) => tester.getRect(
  find.byWidgetPredicate((w) => w is Transcript && w.items == null).first,
);

Future<void> _openPane(WidgetTester tester) async {
  await tester.tap(find.byType(SubagentLine));
  await tester.pumpAndSettle();
}

Future<void> _toggleDetails(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is Tooltip && (w.message ?? '').endsWith(' details'),
    ),
  );
  await tester.pumpAndSettle();
}

/// The pane, then the details at its right, both beside the transcript.
void _side(WidgetTester tester) {
  final pane = tester.getRect(_pane);
  final details = tester.getRect(_details);
  final transcript = _transcript(tester);
  expect(pane.right, details.left);
  expect(details.right, 1400);
  expect(transcript.right, lessThanOrEqualTo(pane.left));
}

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  testWidgets('the details open beside an open subagent pane', (tester) async {
    final d = await _app(tester, details: false);
    await _openPane(tester);
    expect(_details, findsNothing);
    await _toggleDetails(tester);
    _side(tester);
    d.dispose();
  }, variant: _mac);

  testWidgets('a subagent pane opens left of the open details', (tester) async {
    final d = await _app(tester);
    expect(_details, findsOneWidget);
    await _openPane(tester);
    _side(tester);
    d.dispose();
  }, variant: _mac);

  testWidgets('each closes on its own', (tester) async {
    final d = await _app(tester);
    await _openPane(tester);
    // The details go; the pane stays, at the right.
    await _toggleDetails(tester);
    expect(_details, findsNothing);
    expect(tester.getRect(_pane).right, 1400);
    await _toggleDetails(tester);
    _side(tester);
    // The pane's ×: the details stay.
    await tester.tap(
      find.descendant(of: _pane, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(_pane, findsNothing);
    expect(tester.getRect(_details).right, 1400);
    expect(_transcript(tester).right, tester.getRect(_details).left);
    d.dispose();
  }, variant: _mac);

  testWidgets('each keeps its own width', (tester) async {
    final d = await _app(tester);
    paneWidths.value = {'pane': 300, 'details': 240};
    await _openPane(tester);
    expect(tester.getRect(_pane).width, 300);
    expect(tester.getRect(_details).width, 240);
    d.dispose();
  }, variant: _mac);

  testWidgets('too narrow for both: the pane lies over the transcript', (
    tester,
  ) async {
    // 950 for the chat: the details (264) fit beside the transcript
    // (556), the pane too, but not all three.
    final d = await _app(tester, width: 1210);
    await _openPane(tester);
    final pane = tester.getRect(_pane);
    final details = tester.getRect(_details);
    expect(pane.right, details.left);
    expect(pane.width, 264);
    // The transcript keeps its width, under the pane.
    expect(_transcript(tester).right, details.left);
    // Closing the pane uncovers it.
    await tester.tap(
      find.descendant(of: _pane, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(_transcript(tester).right, details.left);
    d.dispose();
  }, variant: _mac);

  testWidgets('a side question goes left of the pane and the details', (
    tester,
  ) async {
    final d = await _app(tester, width: 1800);
    d.chats['c']!.side = ChatState('s', '/Users/me')..title = 'Side';
    await _openPane(tester);
    final side = tester.getRect(find.byType(SidePanel));
    final pane = tester.getRect(_pane);
    expect(side.right, pane.left);
    expect(pane.right, tester.getRect(_details).left);
    expect(_transcript(tester).right, lessThanOrEqualTo(side.left));
    d.dispose();
  }, variant: _mac);

  for (final (name, mode) in [('dark', 'Dark'), ('light', 'Light')]) {
    for (final (what, width) in [('beside', 1400.0), ('over', 1210.0)]) {
      testWidgets('the pane and the details, $what ($name)', (tester) async {
        final d = await _app(tester, width: width);
        tester.platformDispatcher.platformBrightnessTestValue = mode == 'Dark'
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _openPane(tester);
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/beside_${what}_$name.png'),
        );
        d.dispose();
      }, variant: _mac);
    }
  }
}
