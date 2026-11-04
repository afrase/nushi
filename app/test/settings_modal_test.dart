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
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings_modal.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

final Finder _modal = find.byKey(const ValueKey('settings-modal'));

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool meta = false,
}) async {
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// The composer's field of the chat that shows.
Finder get _box => find.descendant(
  of: find.byType(Composer),
  matching: find.byType(EditableText),
);

/// Whether the focus is inside Settings.
bool _focusInside(WidgetTester tester) {
  final at = FocusManager.instance.primaryFocus?.context;
  if (at == null) return false;
  var inside = false;
  at.visitAncestorElements((e) {
    if (e.widget is SettingsView) inside = true;
    return !inside;
  });
  return inside;
}

void main() {
  setUpAll(loadFonts);

  for (final (size, want) in [
    (const Size(1700, 1000), SettingsModal.maxSize),
    (const Size(720, 900), const Size(640, 720)),
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
    }, variant: _mac);
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
  }, variant: _mac);

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
      'Esc': () => _key(tester, LogicalKeyboardKey.escape),
      'Close': () async {
        await tester.tap(
          find.descendant(of: _modal, matching: find.byTooltip('Close (esc)')),
        );
        await tester.pumpAndSettle();
      },
      '⌘,': () => _key(tester, LogicalKeyboardKey.comma, meta: true),
      'the dim': () async {
        await tester.tapAt(const Offset(20, 500));
        await tester.pumpAndSettle();
      },
    };
    for (final MapEntry(key: how, value: close) in shut.entries) {
      await tester.tap(_box);
      await tester.pumpAndSettle();
      final box = FocusManager.instance.primaryFocus;
      await _key(tester, LogicalKeyboardKey.comma, meta: true);
      expect(d.settingsOpen, isNotNull, reason: how);
      expect(_focusInside(tester), isTrue, reason: how);
      await close();
      expect(d.settingsOpen, isNull, reason: how);
      expect(find.byType(SettingsView), findsNothing, reason: how);
      expect((d.place, d.selectedId), (const ChatPlace(), 'a'), reason: how);
      expect(FocusManager.instance.primaryFocus, same(box), reason: how);
    }
    d.dispose();
  }, variant: _mac);

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
    await _key(tester, LogicalKeyboardKey.keyN, meta: true);
    expect(find.byType(Dialog), findsNothing, reason: 'no New chat');
    await _key(tester, LogicalKeyboardKey.keyK, meta: true);
    expect(find.byType(Palette), findsNothing);
    await _key(tester, LogicalKeyboardKey.digit2, meta: true);
    expect(d.selectedId, 'a');
    expect(d.settingsOpen, isNotNull);
    d.dispose();
  }, variant: _mac);

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
  }, variant: _mac);

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
  }, variant: _mac);

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
  }, variant: _mac);

  // The modal at full size: Appearance and Agents, two window sizes, both
  // appearances.
  for (final (size, w) in [
    (const Size(1700, 1000), 1700),
    (const Size(720, 900), 720),
  ]) {
    for (final b in Brightness.values) {
      for (final s in [SettingsSection.appearance, SettingsSection.agents]) {
        testWidgets('render, ${s.name}, $w, ${b.name}', (tester) async {
          final d = await pumpSettingsApp(
            tester,
            settingsFake(),
            s,
            size: size,
            brightness: b,
          );
          expect(tester.takeException(), isNull);
          expectTextInside(tester, size.width);
          expectControlsAtEdge(tester);
          await render(
            tester,
            find.byType(NushiApp),
            'settings_modal_${s.name}_${w}_${b.name}',
          );
          d.dispose();
        }, variant: _mac);
      }
    }
  }
}
