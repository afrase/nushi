// Settings › Appearance: its place in the nav and the palette, Appearance
// and Chat width moved from General, the cards' Dark and Light (a look,
// never the appearance), a user's card's Show in Finder; the page and a
// card as goldens, and renders with a theme of the user's.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_appearance.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/settings_theme.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/theme_preview.dart';

import 'fake_daemon.dart';
import 'fake_desktop.dart';
import 'harness.dart';
import 'settings_harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

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
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'theme');
    await tester.pumpAndSettle();
    expect(find.text('Appearance and themes'), findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, const SettingsAt(SettingsSection.appearance));
    expect(find.byType(ThemeGroup), findsOne);
    d.dispose();
  }, variant: _mac);

  testWidgets('Appearance and Chat width moved from General and still '
      'work', (tester) async {
    final d = await _app(tester, section: SettingsSection.general);
    expect(find.byType(GeneralSection), findsOne);
    expect(find.text('Chat width'), findsNothing);
    expect(find.byType(ThemeGroup), findsNothing);
    d.openSettings(section: SettingsSection.appearance);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('As the system'));
    await _tap(tester, _menuItem('Light'));
    expect(appearance.value, ThemeMode.light);
    expect(
      NushiTheme.of(tester.element(find.byType(SettingsView))).t,
      same(Tokens.light),
    );
    await _tap(tester, find.text('Centered'));
    await _tap(tester, _menuItem('Full width'));
    expect(chatFullWidth.value, isTrue);
    d.dispose();
  }, variant: _mac);

  testWidgets('Dark and Light change the cards only; the picked one stays '
      'both, and Appearance stays', (tester) async {
    final d = await _app(tester);
    final app = NushiTheme.of(tester.element(find.byType(SettingsView))).t;
    expect(_cards(tester).map((c) => c.look).toSet(), {Brightness.dark});
    final tabs = find.byKey(const ValueKey('theme-look'));
    await _tap(tester, find.descendant(of: tabs, matching: find.text('Light')));
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
    expect(appearance.value, ThemeMode.system);
    expect(
      NushiTheme.of(tester.element(find.byType(SettingsView))).t,
      same(app),
    );
    final picked = find.byKey(const ValueKey('theme-picked'));
    final shown = [
      for (final p in tester.widgetList<ThemePreview>(
        find.descendant(of: picked, matching: find.byType(ThemePreview)),
      ))
        p.tokens,
    ];
    expect(shown, [same(Tokens.dark), same(Tokens.light)]);
    await _tap(tester, find.descendant(of: tabs, matching: find.text('Dark')));
    expect(_cards(tester).map((c) => c.look).toSet(), {Brightness.dark});
    d.dispose();
  }, variant: _mac);

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
  }, variant: _mac);

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
      }, variant: _mac);
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
      colorTheme.value = 'nushi';
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
