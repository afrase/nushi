import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// ⌃Tab and ⌃⇧Tab, the chat's tabs, wherever the focus is (`chat_keys.dart`),
// pressed as the Mac sends them: Control, then Shift, then Tab (its
// character a backtab with Shift), and up in reverse.

/// b has a pull request: three tabs.
final _pull = GitHubLink(
  host: 'github.com',
  repo: 'afrase/nushi',
  number: 12,
  id: 'PR_12',
  pull: true,
);

Future<Daemon> _app(WidgetTester tester) async {
  viewport(tester, const Size(1200, 700));
  final fake =
      FakeDaemon([
          chat('a', 'claude', 'Fix the login redirect', age: 2),
          chat('b', 'codex', 'Bump the API version', age: 1)..pull = _pull,
        ])
        ..answer = (input) => input is FindChatPullRequest
            ? FindChatPullResponse(pull: input.chatId == 'b' ? _pull : null)
            : null;
  final d = await fake.connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  d.select('b');
  await tester.pumpAndSettle();
  return d;
}

/// ⌃Tab, or with [back] ⌃⇧Tab, as macOS sends it.
Future<void> _tab(WidgetTester tester, {bool back = false}) async {
  const mac = 'macos';
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft, platform: mac);
  if (back) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft, platform: mac);
  }
  await tester.sendKeyDownEvent(
    LogicalKeyboardKey.tab,
    platform: mac,
    character: back ? '\u0019' : '\t',
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.tab, platform: mac);
  if (back) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: mac);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft, platform: mac);
  await tester.pumpAndSettle();
}

/// ⇧⌘] or ⇧⌘[, reported as [key] (the bracket, or the
/// brace ⇧ makes of it).
Future<void> _bracket(WidgetTester tester, LogicalKeyboardKey key) async {
  const mac = 'macos';
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft, platform: mac);
  final right =
      key == LogicalKeyboardKey.bracketRight ||
      key == LogicalKeyboardKey.braceRight;
  await tester.sendKeyEvent(
    key,
    platform: mac,
    physicalKey: right
        ? PhysicalKeyboardKey.bracketRight
        : PhysicalKeyboardKey.bracketLeft,
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: mac);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);
  await tester.pumpAndSettle();
}

Finder get _box => find.descendant(
  of: find.byType(Composer),
  matching: find.byType(EditableText),
);

Finder _segment(String label) => find.descendant(
  of: find.byType(Segmented<ChatTab>),
  matching: find.text(label),
);

void main() {
  setUpAll(loadFonts);

  testWidgets("⇧⌘] and ⇧⌘[ step the tabs too, as Chrome's, with the "
      'box focused, and ⌘[ alone stays Back', (tester) async {
    final d = await _app(tester);
    final b = d.chats['b']!;
    await tester.tap(_box);
    await tester.pumpAndSettle();
    expect(b.shownTab, ChatTab.chat);
    await _bracket(tester, LogicalKeyboardKey.bracketRight);
    expect(b.shownTab, ChatTab.changes);
    await _bracket(tester, LogicalKeyboardKey.braceRight);
    expect(b.shownTab, ChatTab.pull);
    await _bracket(tester, LogicalKeyboardKey.bracketLeft);
    expect(b.shownTab, ChatTab.changes);
    await _bracket(tester, LogicalKeyboardKey.braceLeft);
    expect(b.shownTab, ChatTab.chat);
    expect((actKeys[backKey]! as RunActIntent).act, Act.back);
    d.dispose();
  }, variant: onMac);

  testWidgets('after a click outside the box (a header tab), ⌃⇧Tab and '
      '⌃Tab still step', (tester) async {
    final d = await _app(tester);
    final b = d.chats['b']!;
    await tester.tap(_box);
    await tester.pumpAndSettle();
    // The click lets go of the box (the framework's unfocus on the
    // desktop): the focus stays under the window's keys.
    await tester.tap(_segment('Changes'));
    await tester.pumpAndSettle();
    expect(b.shownTab, ChatTab.changes);
    await _tab(tester, back: true);
    expect(b.shownTab, ChatTab.chat);
    await _tab(tester, back: true);
    expect(b.shownTab, ChatTab.pull); // round
    await _tab(tester);
    expect(b.shownTab, ChatTab.chat);
    // And a character typed then goes into the box (ADR 0121).
    await tester.tap(_box);
    await tester.pumpAndSettle();
    await tester.tap(_segment('Chat'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX, platform: 'macos');
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(_box).controller.text, 'x');
    d.dispose();
  }, variant: onMac);

  testWidgets('⌃Tab from the box, then ⌃⇧Tab back: the box goes with the '
      'Chat tab, and the focus stays under the window’s keys', (tester) async {
    final d = await _app(tester);
    final b = d.chats['b']!;
    // A click outside the box first, as anyone does before typing again.
    await tester.tap(_box);
    await tester.pumpAndSettle();
    await tester.tap(_segment('Changes'));
    await tester.pumpAndSettle();
    await tester.tap(_segment('Chat'));
    await tester.pumpAndSettle();
    await tester.tap(_box);
    await tester.pumpAndSettle();
    await _tab(tester);
    expect(b.shownTab, ChatTab.changes); // the box is gone with Chat
    await _tab(tester, back: true);
    expect(b.shownTab, ChatTab.chat);
    d.dispose();
  }, variant: onMac);

  testWidgets('with the box’s choices showing, ⌃Tab and ⌃⇧Tab step the tabs '
      'and pick none', (tester) async {
    final d = await _app(tester);
    final b = d.chats['b']!;
    await tester.tap(_box);
    await tester.enterText(_box, '/co');
    await tester.pumpAndSettle();
    expect(find.textContaining('/copy', findRichText: true), findsWidgets);
    await _tab(tester);
    expect(b.shownTab, ChatTab.changes);
    await _tab(tester, back: true);
    expect(b.shownTab, ChatTab.chat);
    expect(tester.widget<EditableText>(_box).controller.text, '/co');
    d.dispose();
  }, variant: onMac);

  testWidgets('a header tab’s tooltip names its own key, the folded tabs’ '
      'the next tab’s', (tester) async {
    final d = await _app(tester);
    for (final (label, key) in [
      ('Chat', '⌃⌘1'),
      ('Changes', '⌃⌘2'),
      ('Pull request', '⌃⌘3'),
    ]) {
      expect(find.byTooltip('$label\u2002$key'), findsOneWidget);
    }
    expect(find.byTooltip(RegExp('one before')), findsNothing);

    // Folded into a menu field where the header has no room.
    await tester.pumpWidget(
      themed(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 460,
            child: ChatHeader(
              d.chats['b']!,
              d,
              tab: ChatTab.chat,
              onTab: (_) {},
              panel: false,
              onPanel: null,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(MenuField), findsOneWidget);
    expect(find.byTooltip('Next tab\u2002⌃⇥'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('View › Previous Tab and Next Tab, and the palette’s rows, '
      'show the keys and step', (tester) async {
    final d = await _app(tester);
    final b = d.chats['b']!;
    final view = tester
        .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
        .menus
        .whereType<PlatformMenu>()
        .firstWhere((m) => m.label == 'View');
    Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
      PlatformMenuItemGroup(:final members) => members.expand(items),
      _ => [m],
    };
    PlatformMenuItem item(String label) =>
        view.menus.expand(items).firstWhere((m) => m.label == label);
    expect(item('Next Tab').shortcut, nextTabKey);
    expect(item('Previous Tab').shortcut, previousTabKey);
    item('Previous Tab').onSelected!();
    await tester.pumpAndSettle();
    expect(b.shownTab, ChatTab.pull);
    item('Next Tab').onSelected!();
    await tester.pumpAndSettle();
    expect(b.shownTab, ChatTab.chat);

    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    await tester.enterText(
      find.descendant(
        of: find.byType(Palette),
        matching: find.byType(TextField),
      ),
      'tab',
    );
    await tester.pump();
    Finder inPalette(String text) => find.descendant(
      of: find.byType(Palette),
      matching: find.text(text, findRichText: true),
    );
    for (final text in ['Next tab', '⌃⇥', 'Previous tab', '⌃⇧⇥']) {
      expect(inPalette(text), findsOneWidget, reason: text);
    }
    d.dispose();
  }, variant: onMac);
}
