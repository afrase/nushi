import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart' show withKey;
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_button.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'panes_app.dart';

// The sidebar in a narrow window (ADR 0123's amendment of 2026-11-17):
// shown, it tucks itself away where the main area beside it would be
// narrower than a chat's least, never saved, and is back once the window
// has room; tucked, its button and ⌘\ float it over the view.

const PanesOpen _filesOnly = (
  side: false,
  files: true,
  subagent: false,
  command: false,
  previews: 1,
  browser: 0,
);

/// The sidebar laid out beside the view (not floating over it).
bool _docked(WidgetTester tester) => find
    .byWidgetPredicate((w) => w is Sidebar && !w.floating)
    .evaluate()
    .isNotEmpty;

void main() {
  setUpAll(loadFonts);

  test('it tucks where the main area beside it would be under a '
      "chat's least", () {
    final least = sidebarWidthIn(600);
    // The window's margin is at the main area's right.
    final line = least + 8 + ChatView.leastBesideWide;
    expect(sidebarTucksIn(line - 1), isTrue);
    expect(sidebarTucksIn(line), isFalse);
    expect(sidebarTucksIn(720), isFalse);
    expect(sidebarTucksIn(400), isTrue);
  });

  testWidgets('shown, in a 560 window it tucks away, not saved; the chat '
      'keeps the room; at 720 it is back', (tester) async {
    final (d, _) = await panesApp(tester, width: 560, sidebar: true);
    expect(_docked(tester), isFalse);
    expect(sidebarTucked.value, isTrue);
    expect(sidebarShut, isTrue);
    expect(sidebarHidden.value, isFalse, reason: "the user's choice");
    expect(readSaved()['sidebarHidden'], isNot(isTrue));
    expect(
      tester.getSize(find.byType(ChatView)).width,
      greaterThanOrEqualTo(ChatView.leastBesideWide),
    );
    await render(tester, find.byType(NushiApp), 'sidebar_tucked_560');

    viewport(tester, const Size(720, 900));
    await tester.pumpAndSettle();
    expect(_docked(tester), isTrue);
    expect(sidebarTucked.value, isFalse);
    expect(
      tester.getSize(find.byType(ChatView)).width,
      greaterThanOrEqualTo(ChatView.leastBesideWide),
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('tucked, its button says Show and floats it over the view, '
      r'and ⌘\ puts the float away; the choice is never changed', (
    tester,
  ) async {
    final (d, _) = await panesApp(tester, width: 480, sidebar: true);
    final button = find.byType(SidebarButton);
    expect(find.byTooltip(withKey('Show the sidebar', r'⌘\')), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is Sidebar && w.floating),
      findsOneWidget,
    );
    expect(sidebarHidden.value, isFalse);
    await render(tester, find.byType(NushiApp), 'sidebar_tucked_peek_480');

    await press(tester, LogicalKeyboardKey.backslash, cmd: true);
    expect(find.byType(Sidebar), findsNothing);
    expect(sidebarHidden.value, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  for (final width in <double>[400, 480, 520, 560, 600]) {
    testWidgets('a ${width.round()} window with the sidebar shown and Files '
        'open: the chat keeps its least, its box at the window left', (
      tester,
    ) async {
      final (d, _) = await panesApp(
        tester,
        width: width,
        sidebar: true,
        open: _filesOnly,
      );
      expect(_docked(tester), isFalse);
      // It lies under the pane from the window's left, as with the
      // sidebar hidden; before, it was 157 wide in a 400 window, the
      // sidebar at its left.
      expect(
        tester.getSize(find.byType(ChatView)).width,
        greaterThanOrEqualTo(ChatView.leastBesideWide),
      );
      expect(tester.getRect(find.byType(Composer)).left, lessThan(20));
      await closeView(tester, d);
    }, variant: onMac);
  }
}
