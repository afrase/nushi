import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
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
  showDetails.value = details;
  paneWidths.value = {};
  final c = chat('c', 'claude', 'Fix the login redirect');
  final fake = FakeDaemon([c])..chatItems['c'] = _items;
  final d = await openApp(tester, fake, size: Size(width, 560));
  return d;
}

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

/// The details right of the transcript, then the pane at the chat's
/// pane's right, in from the window's edge (ADR 0123).
void _side(WidgetTester tester) {
  final pane = tester.getRect(_pane);
  final details = tester.getRect(_details);
  final transcript = _transcript(tester);
  expect(details.right, pane.left);
  expect(pane.right, 1400 - NushiTheme.windowPad);
  expect(transcript.right, details.left);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the details open beside an open subagent pane', (tester) async {
    final d = await _app(tester, details: false);
    await _openPane(tester);
    expect(_details, findsNothing);
    await _toggleDetails(tester);
    _side(tester);
    d.dispose();
  }, variant: onMac);

  testWidgets('a subagent pane opens right of the open details', (
    tester,
  ) async {
    final d = await _app(tester);
    expect(_details, findsOneWidget);
    await _openPane(tester);
    _side(tester);
    d.dispose();
  }, variant: onMac);

  testWidgets('each closes on its own', (tester) async {
    final d = await _app(tester);
    await _openPane(tester);
    // The details go; the pane stays, at the right.
    await _toggleDetails(tester);
    expect(_details, findsNothing);
    expect(tester.getRect(_pane).right, 1400 - NushiTheme.windowPad);
    await _toggleDetails(tester);
    _side(tester);
    // The pane's ×: the details stay.
    await tester.tap(
      find.descendant(of: _pane, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(_pane, findsNothing);
    expect(tester.getRect(_details).right, 1400 - NushiTheme.windowPad);
    expect(_transcript(tester).right, tester.getRect(_details).left);
    // The details' ×: the pane is beside the transcript.
    await _openPane(tester);
    await _toggleDetails(tester);
    expect(_transcript(tester).right, tester.getRect(_pane).left);
    d.dispose();
  }, variant: onMac);

  testWidgets('the pane keeps its own width; the details have theirs', (
    tester,
  ) async {
    final d = await _app(tester);
    paneWidths.value = {'subagent': 300, 'details': 240};
    await _openPane(tester);
    expect(tester.getRect(_pane).width, 300);
    expect(tester.getRect(_details).width, DetailsPanel.width); // ADR 0092
    d.dispose();
  }, variant: onMac);

  testWidgets('too narrow for both: the details tuck away and the pane '
      'stays beside the transcript', (tester) async {
    // 892 for the chat's pane: the details (320) fit beside the transcript
    // (484 at least) and so does the pane (264, 360 for the transcript), but
    // not all three (ADR 0123).
    final d = await _app(tester, width: 1160);
    expect(_details, findsOneWidget);
    await _openPane(tester);
    expect(_details, findsNothing);
    expect(find.byType(DetailsPanel, skipOffstage: false), findsOneWidget);
    expect(showDetails.value, true); // still wanted
    final pane = tester.getRect(_pane);
    expect(pane.right, 1160 - NushiTheme.windowPad);
    expect(pane.width, 264);
    expect(_transcript(tester).right, pane.left);
    // Closing the pane brings them back.
    await tester.tap(
      find.descendant(of: _pane, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(_details).right, 1160 - NushiTheme.windowPad);
    expect(_transcript(tester).right, tester.getRect(_details).left);
    d.dispose();
  }, variant: onMac);

  testWidgets('too narrow for the pane beside the transcript: it narrows, '
      'unsaved, then lies over it at its least', (tester) async {
    // 612 for the chat's pane: no details (under 804), and the transcript
    // keeps its 360 beside the pane only with the pane narrowed to 252.
    final d = await _app(tester, width: 880);
    await _openPane(tester);
    var pane = tester.getRect(_pane);
    const edge = 880 - NushiTheme.windowPad;
    expect(pane.right, edge);
    expect(pane.width, 612 - ChatView.leastBesideWide);
    expect(_transcript(tester).right, pane.left);
    expect(paneWidths.value.containsKey('subagent'), isFalse);
    // 552 for the chat: under the pane's least and the transcript's, so
    // it lies over the transcript, at its least.
    viewport(tester, const Size(820, 560));
    await tester.pumpAndSettle();
    pane = tester.getRect(_pane);
    expect(pane.right, 820 - NushiTheme.windowPad);
    expect(pane.width, 220);
    // The transcript keeps its least, under the pane.
    expect(_transcript(tester).width, ChatView.leastBesideWide);
    expect(_transcript(tester).right, greaterThan(pane.left));
    await tester.tap(
      find.descendant(of: _pane, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(_transcript(tester).right, 820 - NushiTheme.windowPad);
    expect(paneWidths.value.containsKey('subagent'), isFalse);
    d.dispose();
  }, variant: onMac);

  testWidgets("the pane drags past 480, to the transcript's least, tucking "
      'the details away, and keeps its width across a relaunch', (
    tester,
  ) async {
    var d = await _app(tester);
    await _openPane(tester);
    expect(
      find.descendant(of: _pane, matching: find.byTooltip('Wider')),
      findsNothing,
    );
    // Its edge, dragged far left: beside the transcript, it stops where the
    // transcript keeps its least (1400 less the sidebar's 260, the window's
    // margin and 360); the details tuck away on the way (ADR 0123).
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
    const most = 1400 - 260 - NushiTheme.windowPad - ChatView.leastBesideWide;
    expect(tester.getRect(_pane).width, most);
    expect(tester.getRect(_pane).right, 1400 - NushiTheme.windowPad);
    expect(_transcript(tester).right, tester.getRect(_pane).left);
    expect(_details, findsNothing);
    expect(showDetails.value, true);
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
  }, variant: onMac);

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
    }, variant: onMac);
  }

  testWidgets('a side chat goes right of the details and left of the pane', (
    tester,
  ) async {
    final d = await _app(tester, width: 1800);
    d.chats['c']!.side.value = ChatState('s', '/Users/me')..title = 'Side';
    await _openPane(tester);
    final side = tester.getRect(find.byType(SideChat));
    final pane = tester.getRect(_pane);
    final details = tester.getRect(_details);
    expect(details.right, side.left);
    expect(side.right, pane.left);
    expect(pane.right, 1800 - NushiTheme.windowPad);
    expect(_transcript(tester).right, details.left);
    d.dispose();
  }, variant: onMac);
}
