// Settings as a modal over the window (ADR 0087): its size and place, the
// app behind it in sight and repainted by a theme picked, the ways it
// shuts (Esc, Close, ⌘, and a click on the dim) leaving the window as it
// was and the focus where it was, the focus and the keys kept inside, and
// what starts work elsewhere shutting it first; renders at full size.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings_modal.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

final Finder _modal = find.byKey(const ValueKey('settings-modal'));

/// The composer's field of the chat that shows.
Finder get _box => find.descendant(
  of: find.byType(Composer),
  matching: find.byType(EditableText),
);

/// Whether the focus is inside Settings: on the modal's scope or below it.
bool _focusInside(WidgetTester tester) {
  final at = FocusManager.instance.primaryFocus;
  final scope = FocusScope.of(tester.element(_modal));
  return at != null && (at == scope || scope.descendants.contains(at));
}

void main() {
  setUpAll(loadFonts);

  // It grows with the window, 40 in from each edge, to 1120 wide at most
  // and with no height limit: a taller window shows more of a page.
  for (final (size, want) in [
    (const Size(1700, 1000), const Size(1120, 920)),
    (const Size(2400, 1400), const Size(1120, 1320)),
    (const Size(720, 900), const Size(640, 820)),
    (const Size(900, 600), const Size(820, 520)),
  ]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()}: '
        '${want.width.toInt()}×${want.height.toInt()}, centered, the app '
        'in sight behind it', (tester) async {
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.general,
        size: size,
      );
      final box = tester.getRect(_modal);
      expect(box.size, want);
      expect(box.center, Offset(size.width / 2, size.height / 2));
      expect(box.left, greaterThanOrEqualTo(SettingsModal.inset));
      // The window is as it was: the sidebar and the chat, behind.
      expect(find.byType(Sidebar), findsOne);
      expect(find.byType(Composer), findsOne);
      expect(d.place, const ChatPlace());
      d.dispose();
    }, variant: onMac);
  }

  // A title's actions end a clear gap before Close, at any width.
  for (final width in [1700.0, 900.0]) {
    for (final (section, last) in [
      (SettingsSection.mcp, 'Add server'),
      (SettingsSection.skills, 'New skill…'),
    ]) {
      testWidgets('${width.toInt()}: ${section.name}’s $last stays 12 '
          'clear of Close', (tester) async {
        final d = await pumpSettingsApp(
          tester,
          settingsFake(),
          section,
          size: Size(width, 900),
        );
        final close = tester.getRect(
          find.descendant(of: _modal, matching: find.byTooltip('Close Esc')),
        );
        final action = tester.getRect(
          find
              .ancestor(of: find.text(last), matching: find.byType(Pressable))
              .first,
        );
        expect(action.top < close.bottom, isTrue, reason: 'on its line');
        expect(close.left - action.right, greaterThanOrEqualTo(12));
        d.dispose();
      }, variant: onMac);
    }
  }

  testWidgets('a theme picked repaints the app behind at once', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.appearance,
    );
    final nord = find.text('Nord');
    await tester.ensureVisible(nord);
    await tester.pumpAndSettle();
    await tester.tap(nord);
    await tester.pumpAndSettle();
    expect(
      NushiTheme.of(tester.element(find.byType(Sidebar))).t,
      same(builtInTheme('nord')!.dark),
    );
    expect(d.settingsOpen, isNotNull, reason: 'a pick keeps Settings open');
    d.dispose();
  }, variant: onMac);

  testWidgets('Esc, Close, ⌘, and a click on the dim each shut it, the '
      'window as it was and the focus back in the chat’s box', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    d.closeSettings();
    await tester.pumpAndSettle();
    final shut = <String, Future<void> Function()>{
      'Esc': () async {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      },
      'Close': () async {
        await tester.tap(
          find.descendant(
            of: _modal,
            matching: find.byTooltip('Close\u2002Esc'),
          ),
        );
        await tester.pumpAndSettle();
      },
      '⌘,': () => press(tester, LogicalKeyboardKey.comma, cmd: true),
      'the dim': () async {
        await tester.tapAt(const Offset(20, 500));
        await tester.pumpAndSettle();
      },
    };
    for (final MapEntry(key: how, value: close) in shut.entries) {
      await tester.tap(_box);
      await tester.pumpAndSettle();
      final box = FocusManager.instance.primaryFocus;
      await press(tester, LogicalKeyboardKey.comma, cmd: true);
      expect(d.settingsOpen, isNotNull, reason: how);
      expect(_focusInside(tester), isTrue, reason: how);
      await close();
      expect(d.settingsOpen, isNull, reason: how);
      expect(find.byType(SettingsView), findsNothing, reason: how);
      expect((d.place, d.selectedId), (const ChatPlace(), 'a'), reason: how);
      expect(FocusManager.instance.primaryFocus, same(box), reason: how);
    }
    d.dispose();
  }, variant: onMac);

  testWidgets('the focus and the keys stay inside: Tab goes round '
      'Settings, typing never reaches the chat, ⌘N, ⌘K and ⌘1 do nothing', (
    tester,
  ) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    expect(_focusInside(tester), isTrue);
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusInside(tester), isTrue, reason: 'tab $i');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pumpAndSettle();
    expect(d.chats['a']!.draft.text.text, isEmpty);
    await press(tester, LogicalKeyboardKey.keyN, cmd: true);
    expect(find.byType(Dialog), findsNothing, reason: 'no New chat');
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(find.byType(Palette), findsNothing);
    await press(tester, LogicalKeyboardKey.digit2, cmd: true);
    expect(d.selectedId, 'a');
    expect(d.settingsOpen, isNotNull);
    d.dispose();
  }, variant: onMac);

  testWidgets('a menu bar item shuts it first, then runs: New Chat…', (
    tester,
  ) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    // As the menu bar's item does.
    runAct(tester.element(find.byType(Sidebar)), d, Act.newChat);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(find.byType(Dialog), findsOne, reason: 'New chat');
    d.dispose();
  }, variant: onMac);

  testWidgets('opening a chat from Chat history shuts it and shows the chat', (
    tester,
  ) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.history,
    );
    await tester.tap(find.byTooltip('Open the chat').last);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(d.selectedId, 'b');
    d.dispose();
  }, variant: onMac);

  testWidgets('a trust card asking shuts it: the card is in the window', (
    tester,
  ) async {
    final fake = settingsFake();
    final inner = fake.answer!;
    fake.answer = (input) => input is CheckFolderRequest
        ? CheckFolderResponse(
            key: 'k',
            runs: [FolderRun(file: '/x/.mcp.json', what: 'x')],
          )
        : inner(input);
    final d = await pumpSettingsApp(tester, fake, SettingsSection.skills);
    final started = d.startChat('/x', 'claude');
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(find.byType(TrustCard), findsOne);
    d.trustAsk!.decide(start: false);
    expect(await started, isNull);
    d.dispose();
  }, variant: onMac);
}
