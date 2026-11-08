import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/window_drag_linux.dart';
import 'package:re_editor/re_editor.dart';
import 'package:xterm2/xterm.dart' hide Terminal;

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// The app's keys on Linux (ADR 0102): held with Control where the Mac's
// take ⌘, written Ctrl+Shift+E, with GNOME Terminal's keys in a terminal
// and Quit, which no menu bar has, in the palette. Tests pair Linux's
// conventions and window with its platform, as a Linux machine runs them.

final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

void _onLinux() => native
  ..conventions = linuxConventions
  ..window = const LinuxWindow();

/// Presses [key] with [holding] held down, and settles unless [settle] is
/// false (a turn's clock runs).
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, [
  List<LogicalKeyboardKey> holding = const [LogicalKeyboardKey.controlLeft],
  bool settle = true,
]) async {
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

const _ctrl = <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft];
const _shift = <LogicalKeyboardKey>[
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.shiftLeft,
];

/// The app on Linux on three chats, [select] shown, [width] wide; chat a's
/// terminal is [shells]' shell.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  String select = 'a',
  double width = 1200,
  FakeShells Function(FakeDaemon)? shells,
}) async {
  _onLinux();
  viewport(tester, Size(width, 760));
  showDetails.value = false;
  final fake = FakeDaemon([
    chat('a', 'claude', 'Fix the login redirect', age: 2),
    chat('b', 'codex', 'Bump the API version', age: 1),
    chat('c', 'claude', 'Release notes', folder: '/Users/me/site', age: 3),
  ]);
  shells?.call(fake);
  final d = await fake.connect(tester);
  d.select(select);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

/// What the shell got of Ctrl+C, D, R, K and \\ (SIGQUIT's).
const _shellGot = '\x03\x04\x12\x0b\x1c';

Finder get _paletteField =>
    find.descendant(of: find.byType(Palette), matching: find.byType(TextField));

void main() {
  setUpAll(loadFonts);

  testWidgets('Ctrl+K opens the palette and ⌘K doesn’t; Ctrl+1 and '
      'Ctrl+Page Down switch chats', (tester) async {
    final (d, _) = await _app(tester);
    await _press(tester, LogicalKeyboardKey.keyK, [
      LogicalKeyboardKey.metaLeft,
    ]);
    expect(find.byType(Palette), findsNothing);
    await _press(tester, LogicalKeyboardKey.keyK);
    expect(find.byType(Palette), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final order = [for (final c in chatOrder(d)) c.id];
    await _press(tester, LogicalKeyboardKey.digit1);
    expect(d.selectedId, order[0]);
    await _press(tester, LogicalKeyboardKey.pageDown);
    expect(d.selectedId, order[1]);
    await _press(tester, LogicalKeyboardKey.pageUp);
    expect(d.selectedId, order[0]);
    await _press(tester, LogicalKeyboardKey.digit3);
    expect(d.selectedId, order[2]);
    // ⌘ and a digit is nothing of the app's here.
    await _press(tester, LogicalKeyboardKey.digit1, [
      LogicalKeyboardKey.metaLeft,
    ]);
    expect(d.selectedId, order[2]);
    await closeView(tester, d);
  }, variant: _linux);

  testWidgets('the keys’ words say Ctrl: the New chat button, the numbers '
      'held Ctrl shows, and the header’s tooltips', (tester) async {
    for (final width in [1700.0, 720.0]) {
      sidebarHidden.value = false;
      final (d, _) = await _app(tester, width: width);
      expect(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.text('Ctrl+N', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Show terminal  Ctrl+`'), findsOneWidget);
      if (width > 1000) {
        expect(
          find.byTooltip(
            'Ctrl+Alt+2   Ctrl+Tab the next tab, Ctrl+Shift+Tab the one before',
          ),
          findsOneWidget,
        );
      }
      // Control held alone numbers the chats, as ⌘ does on the Mac.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      for (final n in ['Ctrl+1', 'Ctrl+2', 'Ctrl+3']) {
        expect(find.text(n, findRichText: true), findsOneWidget);
      }
      expect(find.textContaining('⌘'), findsNothing);
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(NushiApp),
        'keys_linux_held_${width.toInt()}',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Ctrl+1', findRichText: true), findsNothing);

      await _press(tester, LogicalKeyboardKey.keyK);
      expect(find.text('Ctrl+K', findRichText: true), findsOneWidget);
      await tester.enterText(_paletteField, 'show');
      await tester.pumpAndSettle();
      expect(find.text('Ctrl+Shift+E', findRichText: true), findsOneWidget);
      await render(
        tester,
        find.byType(NushiApp),
        'keys_linux_palette_${width.toInt()}',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await closeView(tester, d);
    }
  }, variant: _linux);

  testWidgets('Ctrl+Enter stops the turn and sends; Control starts no line '
      'here, Shift still does', (tester) async {
    final (d, fake) = await _app(tester);
    final a = d.chats['a']!
      ..busy = true
      ..started = clock()
      ..notifyListeners();
    await tester.pump();
    expect(
      find.textContaining('Enter queues it, Ctrl+Enter stops'),
      findsOneWidget,
    );
    final field = find.descendant(
      of: find.byType(Composer),
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pump();
    final c = tester.widget<TextField>(field).controller!
      ..value = const TextEditingValue(
        text: 'abcd',
        selection: TextSelection.collapsed(offset: 2),
      );
    await _press(tester, LogicalKeyboardKey.enter, [
      LogicalKeyboardKey.shiftLeft,
    ], false);
    expect(c.text, 'ab\ncd');
    c.text = 'abcd';
    await _press(tester, LogicalKeyboardKey.enter, _ctrl, false);
    await tester.pump(const Duration(milliseconds: 100));
    final sent = fake.calls.whereType<SendPromptRequest>();
    expect(sent.single.text, 'abcd');
    expect(sent.single.now, isTrue);
    expect(c.text, isEmpty);
    a.busy = false;
    await closeView(tester, d);
  }, variant: _linux);

  testWidgets(r'in a terminal Ctrl and a letter is the shell’s, Ctrl+\ '
      'too; Ctrl+Shift+C copies, Ctrl+Shift+P opens the palette, Ctrl+Alt+2 '
      'shows Changes', (tester) async {
    terminalChats.value = {'a'};
    late FakeShells shells;
    final (d, _) = await _app(
      tester,
      shells: (fake) => shells = FakeShells(
        fake,
        terminals: [
          Terminal(id: 't1', chatId: 'a', folder: '/tmp', shell: 'zsh'),
        ],
      )..replay['t1'] = 'old output\r\n> ',
    );
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final view = find.byType(TerminalView);
    await tester.tap(view);
    await tester.pumpAndSettle();
    final pinned = d.chats['a']!.pin;
    for (final k in [
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.backslash,
    ]) {
      await _press(tester, k);
    }
    expect(shells.typedAll.join(), _shellGot);
    expect(sidebarHidden.value, isFalse);
    expect(d.chats['a']!.pin, pinned);
    expect(find.byType(Palette), findsNothing);

    final terminal = tester.widget<TerminalView>(view);
    final buffer = terminal.terminal.buffer;
    terminal.controller!.setSelection(
      buffer.createAnchor(0, 0),
      buffer.createAnchor(3, 0),
    );
    await _press(tester, LogicalKeyboardKey.keyC, _shift);
    expect(copied, [
      {'text': 'old'},
    ]);
    expect(shells.typedAll.join(), _shellGot);

    await _press(tester, LogicalKeyboardKey.digit2, [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.altLeft,
    ]);
    expect(d.chats['a']!.shownTab, ChatTab.changes);
    d.chats['a']!.tab.value = ChatTab.chat;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.keyP, _shift);
    expect(find.byType(Palette), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeView(tester, d);
  }, variant: _linux);

  testWidgets('without a menu bar, Quit and Previous and Next chat are '
      'palette rows', (tester) async {
    final (d, _) = await _app(tester);
    await _press(tester, LogicalKeyboardKey.keyK);
    await tester.enterText(_paletteField, 'quit');
    await tester.pumpAndSettle();
    expect(find.text('Quit Nushi'), findsOneWidget);
    expect(find.text('Ctrl+Q', findRichText: true), findsOneWidget);
    await tester.enterText(_paletteField, 'chat');
    await tester.pumpAndSettle();
    expect(find.text('Previous chat'), findsOneWidget);
    expect(find.text('Ctrl+Page Up', findRichText: true), findsOneWidget);
    expect(find.text('Next chat'), findsOneWidget);
    final order = [for (final c in chatOrder(d)) c.id];
    await tester.tap(find.text('Previous chat'));
    await tester.pumpAndSettle();
    expect(find.byType(Palette), findsNothing);
    expect(d.selectedId, order[(order.indexOf('a') - 1) % order.length]);
    await closeView(tester, d);
  }, variant: _linux);

  testWidgets('Ctrl+Q asks before it quits, as the window’s close does: '
      'edits that can’t be saved ask, and Cancel stays', (tester) async {
    _onLinux();
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 3,
      offset: 1,
    );
    await typeIn(tester, e, 'x');
    fake.putFile('main.go', utf8.encode(goSource.replaceAll('println', 'p')));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.keyQ);
    expect(find.text('Quit without your changes to main.go?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Quit without your changes to main.go?'), findsNothing);
    expect(chatC(d).edits['main.go'], same(e));
    await endEditor(tester, d);
  }, variant: _linux);

  testWidgets('on the Mac, Quit is its menu’s: ⌘Q is no key of the app’s '
      'and the palette has no Quit row', (tester) async {
    viewport(tester, const Size(1200, 760));
    final d = await FakeDaemon([chat('a', 'claude', 'Keys')]).connect(tester);
    d.select('a');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(actKeys.keys, isNot(contains(quitKey)));
    await _press(tester, LogicalKeyboardKey.keyK, [
      LogicalKeyboardKey.metaLeft,
    ]);
    await tester.enterText(_paletteField, 'quit');
    await tester.pumpAndSettle();
    expect(find.text('Quit Nushi'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
