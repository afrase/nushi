import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

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
  viewport(tester, Size(width, 560));
  showDetails.value = details;
  paneWidths.value = {};
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

  testWidgets('the pane keeps its own width; the details have theirs', (
    tester,
  ) async {
    final d = await _app(tester);
    paneWidths.value = {'subagent': 300, 'details': 240};
    await _openPane(tester);
    expect(tester.getRect(_pane).width, 300);
    expect(tester.getRect(_details).width, DetailsPanel.width); // ADR 0092
    d.dispose();
  }, variant: _mac);

  testWidgets('too narrow for both: the pane lies over the transcript', (
    tester,
  ) async {
    // 900 for the chat: the details (320) fit beside the transcript
    // (556), the pane too, but not with the transcript at its least
    // beside the pane (360).
    final d = await _app(tester, width: 1160);
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

  testWidgets('the pane drags past 480, to a strip of the transcript, and '
      'keeps its width across a relaunch', (tester) async {
    var d = await _app(tester);
    await _openPane(tester);
    expect(
      find.descendant(of: _pane, matching: find.byTooltip('Wider')),
      findsNothing,
    );
    // Its edge, dragged far left: the pane goes over the transcript until
    // 48 of it is left (1400 less the sidebar's 260 and the details' 320).
    final drag = await tester.startGesture(
      tester.getTopLeft(_pane) + const Offset(2, 200),
    );
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-300, 0));
    await tester.pump();
    expect(tester.getRect(_pane).width, greaterThan(480)); // the old cap
    await drag.moveBy(const Offset(-2000, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    const most = 1400 - 260 - DetailsPanel.width - 48;
    expect(tester.getRect(_pane).width, most);
    expect(tester.getRect(_pane).right, tester.getRect(_details).left);
    expect((readSaved()['panes']! as Map)['subagent'], most);
    d.dispose();

    // Relaunched, the widths read from app.json: the pane opens at the
    // width it was left at.
    await tester.pumpWidget(const SizedBox());
    final saved = readSaved()['panes']! as Map<String, Object?>;
    d = await _app(tester);
    paneWidths.value = {
      for (final MapEntry(:key, :value) in saved.entries)
        key: (value! as num).toDouble(),
    };
    await _openPane(tester);
    expect(tester.getRect(_pane).width, most);
    d.dispose();
  }, variant: _mac);

  // Dragged wide, beside the transcript, and as far as it goes, over it.
  for (final (name, width, by) in [
    ('wide_beside', 1700.0, -500.0),
    ('wide_most', 1700.0, -2000.0),
    ('narrow_most', 720.0, -2000.0),
  ]) {
    testWidgets('dragged wide: $name (dark)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final d = await _app(tester, width: width);
      await _openPane(tester);
      final drag = await tester.startGesture(
        tester.getTopLeft(_pane) + const Offset(2, 200),
      );
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      await drag.moveBy(Offset(by, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expectTextInside(tester, width);
      await render(tester, find.byType(NushiApp), 'pane_drag_$name');
      d.dispose();
    }, variant: _mac);
  }

  testWidgets('a side chat goes left of the pane and the details', (
    tester,
  ) async {
    final d = await _app(tester, width: 1800);
    d.chats['c']!.side.value = ChatState('s', '/Users/me')..title = 'Side';
    await _openPane(tester);
    final side = tester.getRect(find.byType(SideChat));
    final pane = tester.getRect(_pane);
    expect(side.right, pane.left);
    expect(pane.right, tester.getRect(_details).left);
    expect(_transcript(tester).right, lessThanOrEqualTo(side.left));
    d.dispose();
  }, variant: _mac);
}
