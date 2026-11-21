import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/window_drag_linux.dart';
import 'package:xterm2/xterm.dart' hide Terminal;

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

// Keys chosen in Settings › Keyboard shortcuts (ADR 0146), as the app
// binds and shows them: the root's keys, Settings' stop, the menu bar, the
// tooltips and labels behind Settings, the palette, a terminal and a text
// field.

/// The app on three chats, chat a shown, the sidebar showing; [shells]
/// gives chat a its terminal.
Future<Daemon> _app(
  WidgetTester tester, {
  FakeShells Function(FakeDaemon)? shells,
}) async {
  viewport(tester, const Size(1200, 760));
  showDetails.value = false;
  final fake = FakeDaemon([
    chat('a', 'claude', 'Fix the login redirect', age: 2),
    chat('b', 'codex', 'Bump the API version', age: 1),
    chat('c', 'claude', 'Release notes', age: 3),
  ]);
  shells?.call(fake);
  final d = await fake.connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

void _onLinux() => native
  ..conventions = linuxConventions
  ..window = const LinuxWindow();

/// [key] pressed with [holding] held, then settled.
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key,
  List<LogicalKeyboardKey> holding,
) async {
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pumpAndSettle();
}

const List<LogicalKeyboardKey> _altCmd = [
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.altLeft,
];
const List<LogicalKeyboardKey> _cmd = [LogicalKeyboardKey.metaLeft];
const List<LogicalKeyboardKey> _ctrl = [LogicalKeyboardKey.controlLeft];

/// The choices set as Settings would, and the frame after.
Future<void> _choose(WidgetTester tester, Map<String, String> keys) async {
  shortcutKeys.value = keys;
  await tester.pumpAndSettle();
}

/// The menu bar's item [label] in the menu [menu], submenus' items too.
PlatformMenuItem _menuItem(WidgetTester tester, String menu, String label) {
  final top = tester
      .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
      .menus
      .whereType<PlatformMenu>()
      .firstWhere((m) => m.label == menu);
  Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
    PlatformMenuItemGroup(:final members) => members.expand(items),
    PlatformMenu(:final menus) => [m, ...menus.expand(items)],
    _ => [m],
  };
  return top.menus.expand(items).firstWhere((m) => m.label == label);
}

/// [item]'s key as the menu bar is given it: its key and whether ⌘, ⌥
/// and ⇧ are held; null for none.
(LogicalKeyboardKey?, bool?, bool?, bool?)? _menuKey(PlatformMenuItem item) {
  final s = item.shortcut?.serializeForMenu();
  return s == null ? null : (s.trigger, s.meta, s.alt, s.shift);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a chosen key runs its action at the root and the old one '
      'no longer does; Settings stops it as the default', (tester) async {
    final d = await _app(tester);
    expect(sidebarHidden.value, isFalse);
    // Changed after the window's keys were built and first used.
    await _press(tester, LogicalKeyboardKey.backslash, _cmd);
    expect(sidebarHidden.value, isTrue);
    await _choose(tester, {'sidebar': 'Alt+Cmd+S'});
    await _press(tester, LogicalKeyboardKey.backslash, _cmd);
    expect(sidebarHidden.value, isTrue);
    await _press(tester, LogicalKeyboardKey.keyS, _altCmd);
    expect(sidebarHidden.value, isFalse);
    d.openSettings();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.keyS, _altCmd);
    expect(sidebarHidden.value, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('the menu bar shows the chosen key and follows a change; a '
      'cleared key leaves its item without one, and it still runs', (
    tester,
  ) async {
    final d = await _app(tester);
    final reload = _menuItem(tester, 'View', 'Reload Page');
    expect(_menuKey(reload), (LogicalKeyboardKey.keyR, true, false, false));
    await _choose(tester, {'reloadPage': 'Alt+Cmd+R', 'address': 'Cmd+G'});
    expect(_menuKey(_menuItem(tester, 'View', 'Reload Page')), (
      LogicalKeyboardKey.keyR,
      true,
      true,
      false,
    ));
    expect(_menuKey(_menuItem(tester, 'File', 'Open Location…')), (
      LogicalKeyboardKey.keyG,
      true,
      false,
      false,
    ));
    await _choose(tester, {'sidebar': ''});
    final sidebar = _menuItem(tester, 'View', 'Hide Sidebar');
    expect(sidebar.shortcut, isNull);
    expect(_menuKey(_menuItem(tester, 'View', 'Reload Page'))?.$1, isNotNull);
    sidebar.onSelected!();
    await tester.pumpAndSettle();
    expect(sidebarHidden.value, isTrue);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a chosen ⌘K takes the palette's: its item has no key, and "
      '⌘K hides the sidebar', (tester) async {
    final d = await _app(tester);
    await _choose(tester, {'sidebar': 'Cmd+K'});
    expect(_menuItem(tester, 'View', 'Command Palette…').shortcut, isNull);
    await _press(tester, LogicalKeyboardKey.keyK, _cmd);
    expect(sidebarHidden.value, isTrue);
    expect(find.byType(Palette), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('the menu bar has no keys while Settings takes one', (
    tester,
  ) async {
    final d = await _app(tester);
    shortcutRecording.value = true;
    await tester.pump();
    expect(_menuItem(tester, 'View', 'Reload Page').shortcut, isNull);
    expect(_menuItem(tester, 'View', 'Chat 1 in the Sidebar').shortcut, isNull);
    shortcutRecording.value = false;
    await tester.pump();
    expect(_menuItem(tester, 'View', 'Reload Page').shortcut, isNotNull);
    expect(
      _menuItem(tester, 'View', 'Chat 1 in the Sidebar').shortcut,
      isNotNull,
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a chosen ⇧⌘} is given to the menu bar as ⇧ makes it', (
    tester,
  ) async {
    final d = await _app(tester);
    await _choose(tester, {'pin': 'Shift+Cmd+]'});
    expect(_menuKey(_menuItem(tester, 'Chat', 'Pin Chat')), (
      LogicalKeyboardKey.braceRight,
      true,
      false,
      true,
    ));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the palette's Keyboard shortcuts row opens Settings there", (
    tester,
  ) async {
    final d = await _app(tester);
    await _press(tester, LogicalKeyboardKey.keyK, _cmd);
    await tester.enterText(
      find.descendant(
        of: find.byType(Palette),
        matching: find.byType(TextField),
      ),
      'keyboard',
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(d.settingsOpen?.section, SettingsSection.shortcuts);
    expect(find.text('Keyboard shortcuts'), findsWidgets);
    await closeView(tester, d);
  }, variant: onMac);

  group('Next tab', () {
    /// ⇧⌘], reported as [key] (the bracket, or the brace ⇧ makes of it).
    Future<void> bracket(WidgetTester tester, LogicalKeyboardKey key) async {
      const mac = 'macos';
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.shiftLeft,
        platform: mac,
      );
      await tester.sendKeyEvent(
        key,
        platform: mac,
        physicalKey: PhysicalKeyboardKey.bracketRight,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: mac);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      await tester.pumpAndSettle();
    }

    testWidgets("its second keys, ⇧⌘] and ⇧⌘}, step only while it's on "
        '⌃Tab; chosen as ⇧⌘], both reported keys step', (tester) async {
      final d = await _app(tester);
      final a = d.chats['a']!;
      await bracket(tester, LogicalKeyboardKey.bracketRight);
      expect(a.shownTab, ChatTab.changes);
      await bracket(tester, LogicalKeyboardKey.braceRight);
      expect(a.shownTab, ChatTab.chat);

      await _choose(tester, {'nextTab': 'Alt+Cmd+T'});
      await bracket(tester, LogicalKeyboardKey.bracketRight);
      await bracket(tester, LogicalKeyboardKey.braceRight);
      expect(a.shownTab, ChatTab.chat);
      await _press(tester, LogicalKeyboardKey.keyT, _altCmd);
      expect(a.shownTab, ChatTab.changes);

      await _choose(tester, {'nextTab': 'Shift+Cmd+]'});
      await bracket(tester, LogicalKeyboardKey.bracketRight);
      expect(a.shownTab, ChatTab.chat);
      await bracket(tester, LogicalKeyboardKey.braceRight);
      expect(a.shownTab, ChatTab.changes);
      await closeView(tester, d);
    }, variant: onMac);
  });

  testWidgets('a tooltip behind Settings names the chosen key at once; a '
      'cleared New chat key leaves its button no key cap', (tester) async {
    final d = await _app(tester);
    expect(find.byTooltip(r'Hide the sidebar ⌘\'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Sidebar), matching: find.text('⌘N')),
      findsOneWidget,
    );
    d.openSettings();
    await tester.pumpAndSettle();
    await _choose(tester, {'sidebar': 'Alt+Cmd+S', 'newChat': ''});
    expect(find.byTooltip('Hide the sidebar ⌥⌘S'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Sidebar), matching: find.text('⌘N')),
      findsNothing,
    );
    final button = tester.widget<WideButton>(
      find.ancestor(
        of: find.text('New chat'),
        matching: find.byType(WideButton),
      ),
    );
    expect(button.hint, isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a cleared Open file key leaves the empty Files pane's "
      'sentence whole', (tester) async {
    viewport(tester, const Size(1700, 900));
    shortcutKeys.value = {'openFile': ''};
    final fake = FakeDaemon([chat('c', 'claude', 'Fix it')])
      ..answer = (input) =>
          input is PingRequest ? PingResponse(apiVersion: filesApi - 1) : null;
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      themed(
        Center(
          child: SizedBox(
            width: 820,
            height: 700,
            child: FilesPane(chat: d.chats['c']!, daemon: d, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Click a file path in the conversation'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the palette's rows and its field's hint show the chosen "
      'key; a cleared palette key shows none', (tester) async {
    final d = await _app(tester);
    final palette = find.byType(Palette);
    Finder inPalette(String text) =>
        find.descendant(of: palette, matching: find.text(text));

    await _choose(tester, {'sidebar': 'Alt+Cmd+S', 'palette': 'Cmd+G'});
    await _press(tester, LogicalKeyboardKey.keyG, _cmd);
    expect(palette, findsOneWidget);
    expect(inPalette('⌥⌘S'), findsOneWidget);
    expect(inPalette('⌘G'), findsOneWidget); // the hint
    expect(find.byTooltip('The palette: ⌘G'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _choose(tester, {'palette': ''});
    _menuItem(tester, 'View', 'Command Palette…').onSelected!();
    await tester.pumpAndSettle();
    expect(palette, findsOneWidget);
    expect(find.byTooltip(RegExp('^The palette')), findsNothing);
    expect(inPalette('⌘K'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeView(tester, d);
  }, variant: onMac);

  group('a terminal', () {
    test('on the Mac a chosen ⌘ key passes and a ⌃ one is the shell’s; '
        'its own keys stay its own', () {
      shortcutKeys.value = {'find': 'Cmd+G', 'sidebar': 'Cmd+K'};
      expect(terminalPasses(findKey), isTrue);
      expect(terminalPasses(sidebarKey), isFalse); // ⌘K clears it
      shortcutKeys.value = {'terminal': 'Ctrl+R'};
      expect(terminalPasses(toggleTerminalKey), isFalse);
      shortcutKeys.value = {'palette': 'Shift+Cmd+O'};
      expect(terminalPasses(paletteKey), isTrue);
      shortcutKeys.value = {};
      // The defaults as before: ⌘F and ⌘W are the terminal's, ⌘K too.
      expect(terminalPasses(findKey), isFalse);
      expect(terminalPasses(closeTabKey), isFalse);
      expect(terminalPasses(paletteKey), isFalse);
      expect(terminalPasses(nextTabKey), isTrue);
      expect(terminalPasses(toggleTerminalKey), isTrue);
    });

    test('on Linux a chosen Ctrl and letter is the shell’s, a Ctrl+Shift '
        'one passes; the defaults pass as listed', () {
      native.conventions = linuxConventions;
      final before = {
        for (final k in [...actKeys.keys, paletteKey, ...chatKeys.keys])
          k: terminalPasses(k),
      };
      shortcutKeys.value = {'pin': 'Cmd+R'};
      expect(terminalPasses(pinKey), isFalse);
      shortcutKeys.value = {'pin': 'Alt+Cmd+R'};
      expect(terminalPasses(pinKey), isFalse);
      shortcutKeys.value = {'pin': 'Shift+Cmd+O'};
      expect(terminalPasses(pinKey), isTrue);
      shortcutKeys.value = {'terminal': 'Cmd+R'};
      expect(terminalPasses(toggleTerminalKey), isFalse);
      shortcutKeys.value = {};
      expect({for (final k in before.keys) k: terminalPasses(k)}, before);
      expect(terminalPasses(toggleTerminalKey), isTrue);
      expect(terminalPasses(paletteKeyToo), isTrue);
      expect(terminalPasses(paletteKey), isFalse);
      expect(terminalPasses(pinKey), isFalse);
    });

    testWidgets('on Linux a chosen Ctrl+R for Terminal goes to the shell, '
        'and a chosen Ctrl+Shift+O for Pin and Ctrl+Shift+G for the palette '
        'pass', (tester) async {
      _onLinux();
      terminalChats.value = {'a'};
      shortcutKeys.value = {
        'terminal': 'Cmd+R',
        'pin': 'Shift+Cmd+O',
        'palette': 'Shift+Cmd+G',
      };
      late FakeShells shells;
      final d = await _app(
        tester,
        shells: (fake) => shells = FakeShells(
          fake,
          terminals: [
            Terminal(id: 't1', chatId: 'a', folder: '/tmp', shell: 'zsh'),
          ],
        ),
      );
      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.keyR, _ctrl);
      expect(shells.typedAll.join(), '\x12');
      expect(terminalChats.value, {'a'});
      final pinned = d.chats['a']!.pin;
      await _press(tester, LogicalKeyboardKey.keyO, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      ]);
      expect(d.chats['a']!.pin, isNot(pinned));
      expect(shells.typedAll.join(), '\x12');
      // The palette is no key the terminal binds by default: it passes
      // only because the terminal offers the palette's key too.
      expect(find.byType(Palette), findsNothing);
      await _press(tester, LogicalKeyboardKey.keyG, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      ]);
      expect(find.byType(Palette), findsOne);
      expect(shells.typedAll.join(), '\x12');
      await closeView(tester, d);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  Finder box() => find.descendant(
    of: find.byType(Composer),
    matching: find.byType(EditableText),
  );

  testWidgets('on Linux a Back chosen in place of Alt+Left works in a text '
      'field; the default stays the field’s', (tester) async {
    _onLinux();
    final d = await _app(tester);
    d.select('b');
    await tester.pumpAndSettle();
    await tester.tap(box());
    await tester.pumpAndSettle();
    const alt = [LogicalKeyboardKey.altLeft];
    await _press(tester, LogicalKeyboardKey.arrowLeft, alt);
    expect(d.selectedId, 'b');
    await _choose(tester, {'back': 'Shift+Cmd+O'});
    await tester.tap(box());
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.keyO, [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.shiftLeft,
    ]);
    expect(d.selectedId, 'a');
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('⌥⌘↑ in an empty box reaches Previous chat; Up alone still '
      'is the box’s', (tester) async {
    final d = await _app(tester);
    // The sidebar's order: b (newest), a, c.
    await tester.tap(box());
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowUp, const []);
    expect(d.selectedId, 'a');
    await _press(tester, LogicalKeyboardKey.arrowUp, _altCmd);
    expect(d.selectedId, 'b');
    await closeView(tester, d);
  }, variant: onMac);
}
