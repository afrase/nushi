import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_beside.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The sidebar peeks while it's hidden (ADR 0118): the pointer on the
// sidebar's button, or resting on the window's left edge, slides it in over
// the chat, which doesn't move; it goes once the pointer has been off it
// for a moment, never while its menu is open.

const _show = 'Show the sidebar\u2002⌘\\';

Future<Daemon> _window(
  WidgetTester tester, {
  double width = 1200,
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, Size(width, 700), brightness: brightness);
  sidebarHidden.value = true;
  final d = await FakeDaemon([
    chat('a', 'claude', 'Fix the login redirect after it expires'),
    chat('b', 'codex', 'Bump the API version', age: 1),
    chat('c', 'claude', 'Write the release notes', age: 2),
  ]).connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(600, 400));
  addTearDown(mouse.removePointer);
  return mouse;
}

/// Where the button that shows the sidebar is.
Offset _button(WidgetTester tester) => tester.getCenter(find.byTooltip(_show));

void main() {
  setUpAll(loadFonts);

  testWidgets('the pointer on the button peeks at the sidebar, over the chat, '
      'which stays; it goes once the pointer has been off it', (tester) async {
    final d = await _window(tester);
    final header = tester.getRect(find.byType(ChatHeader));
    final button = tester.getRect(find.byTooltip(_show));
    expect(find.byType(Sidebar), findsNothing);
    final mouse = await _mouse(tester);

    await mouse.moveTo(button.center);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget);
    expect(sidebarHidden.value, isTrue, reason: 'still hidden: a peek');
    // A card in from the window's edges, over the chat, which hasn't moved,
    // nor has the button.
    final card = tester.getRect(find.byType(Sidebar));
    expect(card.left, NushiTheme.windowPad);
    expect(card.top, NushiTheme.windowPad);
    expect(card.bottom, 700 - NushiTheme.windowPad);
    expect(tester.getRect(find.byType(ChatHeader)), header);
    expect(tester.getRect(find.byTooltip(_show)), button);
    // New chat where it is with the sidebar shown.
    expect(tester.getRect(find.text('New chat')).top, greaterThan(64));

    // Onto it, and a pick there: it stays.
    await mouse.moveTo(card.center);
    await tester.pump(SidebarBeside.grace * 2);
    expect(find.byType(Sidebar), findsOneWidget);
    await tester.tap(find.text('Bump the API version'));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'b');
    expect(find.byType(Sidebar), findsOneWidget);

    // Off it, and back within the grace: it stays.
    await mouse.moveTo(Offset(card.right + 200, 400));
    await tester.pump(SidebarBeside.grace ~/ 2);
    await mouse.moveTo(card.center);
    await tester.pump(SidebarBeside.grace * 2);
    expect(find.byType(Sidebar), findsOneWidget);

    // Off it for longer: it slides away.
    await mouse.moveTo(Offset(card.right + 200, 400));
    await tester.pump(SidebarBeside.grace);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsNothing);
    expect(tester.getRect(find.byType(ChatHeader)), header);
    d.dispose();
  }, variant: onMac);

  testWidgets('a menu of it open keeps it, the pointer on the menu', (
    tester,
  ) async {
    final d = await _window(tester);
    final mouse = await _mouse(tester);
    await mouse.moveTo(_button(tester));
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(Sidebar));
    // A row's right-click menu.
    final row = tester.getCenter(find.text('Write the release notes'));
    await mouse.moveTo(row);
    await tester.pump();
    final right = await tester.startGesture(
      row,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await right.up();
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    // Out past the card, as onto the menu or past it.
    await mouse.moveTo(Offset(card.right + 300, 600));
    await tester.pump(SidebarBeside.grace * 3);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget);
    // The menu shut by a click off it, the pointer still off the
    // sidebar: it goes.
    await mouse.down(Offset(card.right + 300, 600));
    await mouse.up();
    await tester.pumpAndSettle();
    await tester.pump(SidebarBeside.grace);
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(find.byType(Sidebar), findsNothing);
    d.dispose();
  }, variant: onMac);

  testWidgets('its edge dragged past it keeps it until let go', (tester) async {
    // Dragged wider than its most, the pointer leaves the card: the peek
    // stays while the press is held, so the drag isn't cut off with it.
    final d = await _window(tester);
    final mouse = await _mouse(tester);
    await mouse.moveTo(_button(tester));
    await tester.pumpAndSettle();
    final edge = find.byWidgetPredicate(
      (w) => w is Resizable && w.name == 'sidebar',
    );
    final at = tester.getRect(edge).centerRight - const Offset(2, 0);
    await mouse.moveTo(at);
    await tester.pump();
    await mouse.down(at);
    await mouse.moveTo(at + const Offset(20, 0));
    await tester.pump();
    await mouse.moveTo(at + const Offset(600, 0));
    await tester.pump(SidebarBeside.grace * 3);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget);
    await mouse.up();
    await tester.pump(SidebarBeside.grace * 2);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsNothing);
    expect(paneWidths.value['sidebar'], sidebarMost(1200));
    d.dispose();
  }, variant: onMac);

  testWidgets('the button pressed while it peeks shows it for good, at once '
      'where it was', (tester) async {
    final d = await _window(tester);
    final mouse = await _mouse(tester);
    await mouse.moveTo(_button(tester));
    await tester.pumpAndSettle();
    final floating = tester.getRect(find.text('New chat'));
    await tester.tap(find.byTooltip(_show));
    await tester.pump();
    expect(sidebarHidden.value, isFalse);
    // No slide in: one frame on, it's where it rests.
    final shown = tester.getRect(find.text('New chat'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('New chat')), shown);
    expect(find.byType(Sidebar), findsOneWidget);
    expect(shown.top, floating.top, reason: 'at the height it floated at');
    d.dispose();
  }, variant: onMac);

  testWidgets('hidden by its button, it doesn’t peek until the pointer has '
      'left the button and come back', (tester) async {
    viewport(tester, const Size(1200, 700));
    final d = await FakeDaemon([chat('a', 'claude', 'One')]).connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final mouse = await _mouse(tester);
    final hide = tester.getCenter(find.byTooltip('Hide the sidebar\u2002⌘\\'));
    await mouse.moveTo(hide);
    await tester.pump();
    await tester.tap(find.byTooltip('Hide the sidebar\u2002⌘\\'));
    await tester.pumpAndSettle();
    expect(sidebarHidden.value, isTrue);
    expect(find.byType(Sidebar), findsNothing);
    await mouse.moveTo(const Offset(600, 400));
    await tester.pumpAndSettle();
    await mouse.moveTo(hide);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('the pointer resting on the window’s left edge peeks; one '
      'passing doesn’t', (tester) async {
    final d = await _window(tester);
    final mouse = await _mouse(tester);
    await mouse.moveTo(const Offset(3, 400));
    await tester.pump(SidebarBeside.dwell ~/ 2);
    await mouse.moveTo(const Offset(600, 400));
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsNothing);

    await mouse.moveTo(const Offset(3, 400));
    await tester.pump(SidebarBeside.dwell);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget);
    // On to it on a slant, through the margin under it: it stays.
    await mouse.moveTo(const Offset(60, 300));
    await tester.pump(SidebarBeside.grace * 2);
    expect(find.byType(Sidebar), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('under Reduce Motion it comes and goes at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final d = await _window(tester);
    final mouse = await _mouse(tester);
    await mouse.moveTo(_button(tester));
    await tester.pump();
    expect(tester.getRect(find.byType(Sidebar)).left, NushiTheme.windowPad);
    d.dispose();
  }, variant: onMac);

  testWidgets('on Linux too, under its title bar', (tester) async {
    native
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
    final d = await _window(tester, width: 720);
    final mouse = await _mouse(tester);
    await mouse.moveTo(
      tester.getCenter(find.byTooltip('Show the sidebar\u2002Ctrl+\\')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget);
    expectTextInside(tester, 720);
    await render(tester, find.byType(NushiApp), 'linux_peek_720');
    d.dispose();
  }, variant: onLinux);

  group('renders', () {
    for (final width in [1700.0, 720.0]) {
      for (final b in renderThemes) {
        testWidgets('peeking, $width wide, ${b.name}', (tester) async {
          final d = await _window(tester, width: width, brightness: b);
          final mouse = await _mouse(tester);
          await mouse.moveTo(_button(tester));
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'sidebar_peek_${width.toInt()}_${b.name}',
          );
          d.dispose();
        }, variant: onMac);
      }
    }
  });
}
