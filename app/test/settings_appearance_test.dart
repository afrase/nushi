// Settings › Appearance: its place in the nav and the palette, Mode and
// Chat width as segments, the theme first and picked once, every font in
// one group, a user's card's Show in Finder; the page and a
// card as goldens, and renders with a theme of the user's.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/controls.dart' show Segmented;
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_appearance.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_terminal.dart';
import 'package:nushi/settings_theme.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/theme_preview.dart';

import 'fake_daemon.dart';
import 'fake_desktop.dart';
import 'harness.dart';
import 'settings_harness.dart';

/// A theme of the user's, a dim muted text that reads under AA, and the
/// folder's gone after.
void _custom() {
  final dir = themeFiles.dir..createSync(recursive: true);
  addTearDown(() async {
    await themeFiles.forget();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  File('${dir.path}/Harbor.json').writeAsStringSync(
    '{"name": "Harbor", "from": "nord", '
    '"dark": {"base": "#14202C", "textMuted": "#4A4D55"}, '
    '"light": {"accent": "#0B7A75"}}',
  );
  themeFiles.load();
}

/// The Mac app at [size] in [b], Settings open at [section].
Future<Daemon> _app(
  WidgetTester tester, {
  Size size = const Size(1700, 1000),
  Brightness b = Brightness.dark,
  SettingsSection section = SettingsSection.appearance,
}) =>
    pumpSettingsApp(tester, settingsFake(), section, size: size, brightness: b);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The open menu's item [label].
Finder _menuItem(String label) => find.descendant(
  of: find.byType(MenuItemButton),
  matching: find.text(label),
);

List<ThemeCard> _cards(WidgetTester tester) =>
    tester.widgetList<ThemeCard>(find.byType(ThemeCard)).toList();

void main() {
  setUpAll(loadFonts);

  testWidgets('Appearance is in the nav after General, and the palette '
      'opens it', (tester) async {
    final d = await _app(tester, section: SettingsSection.general);
    final general = tester.getRect(
      find.byKey(const ValueKey('settings-nav-general')),
    );
    final appearance = tester.getRect(
      find.byKey(const ValueKey('settings-nav-appearance')),
    );
    expect(appearance.top, greaterThan(general.top));
    expect(find.byKey(const ValueKey('settings-nav-terminal')), findsOne);
    expect(
      tester.getRect(find.byKey(const ValueKey('settings-nav-terminal'))).top,
      greaterThan(appearance.top),
    );
    await _tap(tester, find.byKey(const ValueKey('settings-nav-appearance')));
    expect(d.settingsOpen, const SettingsAt(SettingsSection.appearance));
    expect(find.byType(AppearanceSection), findsOne);

    d.closeSettings();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    await tester.enterText(find.byType(TextField).last, 'theme');
    await tester.pumpAndSettle();
    expect(find.text('Appearance and themes'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, const SettingsAt(SettingsSection.appearance));
    expect(find.byType(ThemeGroup), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets('Appearance and Chat width moved from General and still '
      'work', (tester) async {
    final d = await _app(tester, section: SettingsSection.general);
    expect(find.byType(GeneralSection), findsOne);
    expect(find.text('Chat width'), findsNothing);
    expect(find.byType(ThemeGroup), findsNothing);
    d.openSettings(section: SettingsSection.appearance);
    await tester.pumpAndSettle();
    // Mode and Chat width are segments, each choice in sight.
    final mode = find.byKey(const ValueKey('appearance-mode'));
    await _tap(tester, find.descendant(of: mode, matching: find.text('Light')));
    expect(appearance.value, ThemeMode.light);
    expect(
      NushiTheme.of(tester.element(find.byType(SettingsView))).t,
      same(Tokens.light),
    );
    final width = find.byKey(const ValueKey('chat-width'));
    await _tap(
      tester,
      find.descendant(of: width, matching: find.text('Full width')),
    );
    expect(chatFullWidth.value, isTrue);
    expect(readSaved()['chatFullWidth'], isTrue);
    await _tap(
      tester,
      find.descendant(of: width, matching: find.text('Centered')),
    );
    expect(chatFullWidth.value, isFalse);
    d.dispose();
  }, variant: onMac);

  testWidgets('Project rail is a switch, off at first, kept once set', (
    tester,
  ) async {
    final d = await _app(tester);
    final row = find.widgetWithText(SettingsRow, 'Project rail');
    final toggle = find.descendant(
      of: row,
      matching: find.byType(SettingsSwitch),
    );
    expect(projectRail.value, isFalse);
    expect(tester.widget<SettingsSwitch>(toggle).value, isFalse);
    expect(
      find.descendant(
        of: row,
        matching: find.text('A column of project tiles beside the chats.'),
      ),
      findsOne,
    );
    await _tap(tester, toggle);
    expect(projectRail.value, isTrue);
    expect(tester.widget<SettingsSwitch>(toggle).value, isTrue);
    expect(readSaved()['projectRailOn'], isTrue);
    await _tap(tester, toggle);
    expect(projectRail.value, isFalse);
    expect(readSaved()['projectRailOn'], isFalse);
    d.dispose();
  }, variant: onMac);

  testWidgets("Project rail says why it isn't shown while it's on", (
    tester,
  ) async {
    final d = await _app(tester);
    final row = find.widgetWithText(SettingsRow, 'Project rail');
    Finder says(String text) =>
        find.descendant(of: row, matching: find.text(text));
    projectRail.value = true;
    sidebarGroupBy.value = GroupBy.date;
    await tester.pumpAndSettle();
    expect(says('Shows while chats are grouped by project.'), findsOne);
    sidebarGroupBy.value = GroupBy.project;
    railFits.value = false;
    await tester.pumpAndSettle();
    expect(says('Shows in a wider window.'), findsOne);
    railFits.value = true;
    await tester.pumpAndSettle();
    expect(says('A column of project tiles beside the chats.'), findsOne);
    projectRail.value = false;
    sidebarGroupBy.value = GroupBy.date;
    await tester.pumpAndSettle();
    expect(says('A column of project tiles beside the chats.'), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets('the Theme group: Mode first, as System, Light and Dark; the '
      'cards draw the set the app shows; the picked theme shows once', (
    tester,
  ) async {
    final d = await _app(tester);
    final group = find.byType(ThemeGroup);
    final mode = find.byKey(const ValueKey('appearance-mode'));
    // Mode is the group's first row, over the cards, and the page has no
    // row named Appearance.
    expect(find.descendant(of: group, matching: mode), findsOne);
    expect(
      tester.getRect(mode).bottom,
      lessThan(tester.getRect(find.byType(ThemeCard).first).top),
    );
    expect(find.widgetWithText(SettingsRow, 'Appearance'), findsNothing);
    expect(
      tester.getRect(group).top,
      lessThan(tester.getRect(find.text('Layout')).top),
    );
    expect(
      tester.widget<Segmented<ThemeMode>>(mode).segments.map((s) => s.$2),
      ['System', 'Light', 'Dark'],
    );
    expect(_cards(tester).map((c) => c.look).toSet(), {Brightness.dark});
    // Picked once: one card ringed and checked, no large picture of it.
    expect(_cards(tester).where((c) => c.picked).single.theme.id, 'nushi');
    expect(find.byKey(const ValueKey('theme-check')), findsOne);
    expect(find.byType(ThemePreview), findsNWidgets(_cards(tester).length));
    expect(find.byKey(const ValueKey('theme-look')), findsNothing);

    await _tap(tester, find.descendant(of: mode, matching: find.text('Light')));
    expect(appearance.value, ThemeMode.light);
    expect(readSaved()['appearance'], 'light');
    expect(_cards(tester).map((c) => c.look).toSet(), {Brightness.light});
    // Each card draws its own theme's light set.
    for (final c in _cards(tester)) {
      expect(
        tester
            .widget<ThemePreview>(
              find.descendant(
                of: find.byWidget(c),
                matching: find.byType(ThemePreview),
              ),
            )
            .tokens,
        same(c.theme.light),
      );
    }
    await _tap(tester, find.descendant(of: mode, matching: find.text('Dark')));
    expect(appearance.value, ThemeMode.dark);
    expect(_cards(tester).map((c) => c.look).toSet(), {Brightness.dark});
    await _tap(
      tester,
      find.descendant(of: mode, matching: find.text('System')),
    );
    expect(appearance.value, ThemeMode.system);
    d.dispose();
  }, variant: onMac);

  testWidgets('every font in one group: App, Code, and the terminal’s family '
      'and size, which Terminal shows too', (tester) async {
    final d = await _app(tester);
    final fonts = find.ancestor(
      of: find.text('Fonts'),
      matching: find.byType(SettingsGroup),
    );
    for (final key in ['app-font', 'code-font', 'terminal-font']) {
      expect(
        find.descendant(of: fonts, matching: find.byKey(ValueKey(key))),
        findsOne,
        reason: key,
      );
    }
    final size = find.descendant(
      of: fonts,
      matching: find.byType(TerminalSizeField),
    );
    await _tap(tester, size);
    await _tap(tester, _menuItem('14'));
    expect(terminalFontSize.value, 14);
    d.openSettings(section: SettingsSection.terminal);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TerminalSizeField),
        matching: find.text('14'),
      ),
      findsOne,
    );
    d.dispose();
  }, variant: onMac);

  testWidgets('a user’s card says Yours, warns, and shows its file in '
      'Finder', (tester) async {
    final opened = fakeDesktop();
    _custom();
    final d = await _app(tester);
    final card = find.ancestor(
      of: find.text('Harbor'),
      matching: find.byType(ThemeCard),
    );
    expect(
      find.descendant(of: card, matching: find.text('Yours · Harbor.json')),
      findsOne,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining(RegExp('^Dark: textMuted on ')),
      ),
      findsOne,
    );
    await _tap(tester, find.byKey(const ValueKey('theme-reveal-Harbor.json')));
    expect(opened.single, ['-R', '${themeFiles.dir.path}/Harbor.json']);
    expect(colorTheme.value, 'nushi', reason: 'Show in Finder picks nothing');
    d.dispose();
  }, variant: onMac);

  // The page at full size, a theme of the user's among the cards.
  for (final (size, w) in [
    (const Size(1700, 1000), 1700),
    (const Size(720, 900), 720),
  ]) {
    for (final b in Brightness.values) {
      testWidgets('renders, $w, ${b.name}', (tester) async {
        _custom();
        final d = await _app(tester, size: size, b: b);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'settings_appearance_${w}_${b.name}',
        );
        // Scrolled to the user's card.
        await tester.ensureVisible(find.text('Harbor'));
        await tester.pumpAndSettle();
        await render(
          tester,
          find.byType(NushiApp),
          'settings_appearance_${w}_${b.name}_yours',
        );
        d.dispose();
      }, variant: onMac);
    }
  }

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    // A card has no golden of its own: its preview's small text draws
    // differently on CI's Mac than here (1% of a 220-wide card), and the
    // page's golden below holds the cards.
    testWidgets('golden, the page, $name', (tester) async {
      final d = await FakeDaemon([]).connect(tester);
      await pumpSettings(
        tester,
        d,
        SettingsSection.appearance,
        tokens: tokens,
        size: const Size(960, 720),
      );
      await expectLater(
        find.byType(SettingsView),
        matchesGoldenFile('goldens/settings_appearance_$name.png'),
      );
      d.dispose();
    });
  }
}
