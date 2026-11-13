// Settings › Appearance's Fonts (ADR 0114): the App font and Code font
// menus (the bundled font, the system's on the Mac, the installed ones,
// a filter for hundreds), set and cleared, kept, and shown at once in
// everything the theme draws; the terminal and the phone as they were.
import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/fonts.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_fonts.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/terminal_find.dart' show terminalStyle;
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'screenshots/demo.dart';
import 'settings_harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The installed fonts a test says there are.
class _Fonts implements Fonts {
  new({this.all, this.fixed = const ['Menlo', 'SF Mono'], this.system});

  final List<String>? all;
  final List<String>? fixed;

  @override
  final String? system;

  @override
  Future<List<String>?> families() async => all;

  @override
  Future<List<String>?> monospaced() async => fixed;
}

/// A Mac's worth of families, as the system lists them: [n] that a menu
/// shows, in the system's own order, and among them three it shouldn't (a
/// private one, one that can't be a name, the bundled one again).
List<String> _many(int n) => [
  'Zapfino',
  '.SF NS Rounded',
  'Bad\nName',
  for (var i = 0; i < n - 4; i++)
    '${String.fromCharCode(65 + i % 26)}${i.isEven ? 'venir' : 'ODONI'} $i',
  'Avenir Next',
  'menlo',
  'Menlo',
  'IBM Plex Sans',
];

Future<Daemon> _settings(
  WidgetTester tester, {
  Size size = const Size(1700, 1000),
  Brightness b = Brightness.dark,
}) => pumpSettingsApp(
  tester,
  settingsFake(),
  SettingsSection.appearance,
  size: size,
  brightness: b,
);

Finder _field(String key) => find.byKey(ValueKey(key));

/// The open menu's row for [label] (its detail after it, if it has one).
Finder _row(String label) => find.descendant(
  of: find.byType(MenuItemButton),
  matching: find.text(label, findRichText: true),
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The fonts of the theme [of] sees.
NushiTheme _theme(WidgetTester tester, Finder of) =>
    NushiTheme.of(tester.element(of.first));

/// The first family of every piece of text the window draws.
Set<String?> _drawn(WidgetTester tester) {
  final families = <String?>{};
  void visit(InlineSpan span, TextStyle? around) {
    final style = around?.merge(span.style) ?? span.style;
    if (span is TextSpan && (span.text?.trim().isNotEmpty ?? false)) {
      families.add(style?.fontFamily);
    }
    span.visitDirectChildren((child) {
      visit(child, style);
      return true;
    });
  }

  for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
    visit(text.text, null);
  }
  for (final field in tester.widgetList<EditableText>(
    find.byType(EditableText),
  )) {
    families.add(field.style.fontFamily);
  }
  return families;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('App font lists the bundled font, System, then every '
      'installed family; a pick shows at once and is kept', (tester) async {
    native.fonts = _Fonts(all: _many(12), system: '.AppleSystemUIFont');
    final d = await _settings(tester);
    final view = find.byType(SettingsView);
    expect(find.widgetWithText(SettingsGroup, 'Fonts'), findsOne);
    expect(
      find.descendant(
        of: _field('app-font'),
        matching: find.text('IBM Plex Sans'),
      ),
      findsOne,
    );
    expect(_theme(tester, view).uiFamily, 'IBM Plex Sans');

    await _tap(tester, _field('app-font'));
    final labels = [
      for (final b in tester.widgetList<MenuItemButton>(
        find.byType(MenuItemButton),
      ))
        tester
            .widget<Text>(
              find.descendant(
                of: find.byWidget(b),
                matching: find.byType(Text),
              ),
            )
            .textSpan!
            .toPlainText(),
    ];
    // The bundled one first, then System, then the rest in order whatever
    // their case; no private family, no name that can't be one, and the
    // bundled one once.
    expect(labels.take(4), [
      'IBM Plex Sans   bundled',
      'System',
      'Avenir 0',
      'Avenir Next',
    ]);
    expect(labels.sublist(labels.length - 3), ['Menlo', 'menlo', 'Zapfino']);
    expect(labels, hasLength(2 + 12));
    expect(labels.where((l) => l.startsWith('.') || l.contains('\n')), isEmpty);

    await tester.tap(_row('Avenir Next'));
    await tester.pumpAndSettle();
    expect(appFont.value, 'Avenir Next');
    expect(readSaved()['appFont'], 'Avenir Next');
    // The window's theme, with no restart: the bundled font behind it.
    final theme = _theme(tester, view);
    expect(theme.uiFamily, 'Avenir Next');
    expect(theme.uiFallback, ['IBM Plex Sans']);
    expect(theme.codeFamily, 'JetBrains Mono');
    expect(
      find.descendant(
        of: _field('app-font'),
        matching: find.text('Avenir Next'),
      ),
      findsOne,
    );
    final title = tester.widget<Text>(find.text('Appearance').first);
    expect(title.style!.fontFamily, 'Avenir Next');

    await _tap(tester, _field('app-font'));
    await tester.tap(_row('System'));
    await tester.pumpAndSettle();
    expect(appFont.value, '.AppleSystemUIFont');
    expect(
      find.descendant(of: _field('app-font'), matching: find.text('System')),
      findsOne,
    );
    expect(_theme(tester, view).uiFamily, '.AppleSystemUIFont');

    // The bundled one clears it.
    await _tap(tester, _field('app-font'));
    await tester.tap(_row('IBM Plex Sans   bundled'));
    await tester.pumpAndSettle();
    expect(appFont.value, isNull);
    expect(readSaved()['appFont'], isNull);
    expect(_theme(tester, view).uiPicked, isNull);
    expect(_theme(tester, view).uiFallback, isNull);
    expect(codeFont.value, isNull);
    expect(terminalFont.value, isNull);
    d.dispose();
  }, variant: _mac);

  testWidgets('Code font lists the monospaced families only, sets and '
      'clears code’s font, and leaves the terminal’s', (tester) async {
    native.fonts = _Fonts(
      all: _many(12),
      fixed: ['SF Mono', 'JetBrains Mono', 'Menlo'],
      system: '.AppleSystemUIFont',
    );
    final d = await _settings(tester);
    final view = find.byType(SettingsView);
    final before = terminalStyle();
    await _tap(tester, _field('code-font'));
    expect(_row('JetBrains Mono   bundled'), findsOne);
    expect(_row('Menlo'), findsOne);
    expect(_row('SF Mono'), findsOne);
    expect(find.byType(MenuItemButton), findsNWidgets(3));
    expect(_row('System'), findsNothing);
    expect(_row('Zapfino'), findsNothing);

    await tester.tap(_row('Menlo'));
    await tester.pumpAndSettle();
    expect(codeFont.value, 'Menlo');
    expect(readSaved()['codeFont'], 'Menlo');
    final theme = _theme(tester, view);
    expect(theme.codeFamily, 'Menlo');
    expect(theme.codeFallback, ['JetBrains Mono']);
    expect(theme.uiPicked, isNull);
    // The terminal's own setting, and its style, are as they were.
    expect(terminalFont.value, isNull);
    expect(terminalStyle().fontFamily, before.fontFamily);
    expect(terminalStyle().fontFamilyFallback, before.fontFamilyFallback);

    await _tap(tester, _field('code-font'));
    await tester.tap(_row('JetBrains Mono   bundled'));
    await tester.pumpAndSettle();
    expect(codeFont.value, isNull);
    expect(_theme(tester, view).codePicked, isNull);
    d.dispose();
  }, variant: _mac);

  testWidgets('with no system font to name, there’s no System; with no '
      'answer, the bundled font alone', (tester) async {
    native.fonts = _Fonts(all: ['Cantarell', 'Noto Sans']);
    final d = await _settings(tester);
    await _tap(tester, _field('app-font'));
    expect(_row('System'), findsNothing);
    expect(_row('Cantarell'), findsOne);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    d.dispose();

    native.fonts = _Fonts(fixed: null);
    final e = await _settings(tester);
    await _tap(tester, _field('app-font'));
    expect(find.byType(MenuItemButton), findsOne);
    expect(_row('IBM Plex Sans   bundled'), findsOne);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    e.dispose();
  }, variant: _mac);

  testWidgets('a picked family that isn’t installed stays listed, saying '
      'so, and the longest name fits its row', (tester) async {
    native.fonts = _Fonts(all: _many(12), system: '.AppleSystemUIFont');
    final gone = 'W' * 100;
    appFont.value = gone;
    for (final width in [1700.0, 720.0]) {
      final d = await _settings(tester, size: Size(width, 900));
      expect(tester.takeException(), isNull);
      final field = tester.getRect(_field('app-font'));
      expect(field.width, lessThanOrEqualTo(FontField.maxWidth));
      final row = tester.getRect(find.widgetWithText(SettingsRow, 'App font'));
      expect(field.right, moreOrLessEquals(row.right - 14, epsilon: 0.5));
      expect(tester.getRect(find.text('App font')).right, lessThan(field.left));
      expectTextInside(tester, width);
      await _tap(tester, _field('app-font'));
      expect(tester.takeException(), isNull);
      final listed = find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.textContaining('not installed', findRichText: true),
      );
      expect(listed, findsOne);
      expect(
        tester.widget<RichText>(listed).text.toPlainText(),
        '$gone   not installed',
      );
      expectTextInside(tester, width);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      d.dispose();
    }
  }, variant: _mac);

  // The owner's Mac has about 290 families. The menu filters as you type,
  // and opens on the picked family, wherever it is in the list. The one
  // picked here is a font the tests have that has no letters (the
  // terminal's icons): its text is drawn by the bundled font behind it.
  for (final (size, w) in [
    (const Size(1700, 1000), 1700),
    (const Size(720, 900), 720),
  ]) {
    testWidgets('three hundred families: the menu opens on the picked one, '
        'and typing finds another, $w', (tester) async {
      const icons = 'Symbols Nerd Font Mono';
      native.fonts = _Fonts(
        all: [..._many(299), icons],
        system: '.AppleSystemUIFont',
      );
      appFont.value = icons;
      final d = await _settings(tester, size: size);
      await _tap(tester, _field('app-font'));
      final rows = find.byType(MenuItemButton);
      expect(rows, findsNWidgets(2 + 300));
      expect(find.text('Filter'), findsOne);
      // Far down the list, and it shows: inside the list's box, checked.
      final row = find.ancestor(of: _row(icons), matching: rows);
      expect(
        tester.widgetList(rows).toList().indexOf(tester.widget(row)),
        greaterThan(200),
      );
      final list = tester.getRect(
        find.ancestor(of: row, matching: find.byType(Scrollable)).first,
      );
      final picked = tester.getRect(row);
      expect(picked.top, greaterThanOrEqualTo(list.top));
      expect(picked.bottom, lessThanOrEqualTo(list.bottom));
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.check)),
        findsOne,
      );
      expect(tester.takeException(), isNull);
      expectTextInside(tester, size.width);
      await render(tester, find.byType(NushiApp), 'font_menu_300_$w');

      await tester.enterText(find.byType(TextField).last, 'next');
      await tester.pump();
      expect(find.byType(MenuItemButton), findsOne);
      await render(tester, find.byType(NushiApp), 'font_menu_300_${w}_typed');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(appFont.value, 'Avenir Next');
      expect(find.text('Filter'), findsNothing);
      d.dispose();
    }, variant: _mac);
  }

  testWidgets('a font picked while a chat shows redraws all of it, code '
      'and diffs too, and clearing it puts the bundled fonts back', (
    tester,
  ) async {
    viewport(tester, const Size(1700, 1000), brightness: Brightness.dark);
    clock = () => demoNow;
    Collapsible.opened.add('e2');
    addTearDown(Collapsible.opened.clear);
    final fake = FakeDaemon(demoChats())
      ..answer = (input) => switch (input) {
        GetChatRequest(:final chatId) when chatId == heroChat.id =>
          GetChatResponse(
            chat: heroChat,
            items: heroItems,
            status: heroChat.status,
          ),
        _ => null,
      };
    final d = await fake.connect(tester)
      ..select(heroChat.id);
    await tester.pumpWidget(NushiApp(daemon: d));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    String? diffFont() => tester
        .widget<SideBySideDiff>(find.byType(SideBySideDiff).first)
        .theme
        .fontFamily;
    final bundled = _drawn(tester);
    expect(bundled, containsAll(['IBM Plex Sans', 'JetBrains Mono']));
    expect(bundled, isNot(contains(null)), reason: 'text with no font');
    expect(diffFont(), 'JetBrains Mono');
    final terminal = terminalStyle();

    // Two families no test has loaded: what's asked for is what counts.
    appFont.value = 'Avenir Next';
    codeFont.value = 'Menlo';
    await settle();
    final picked = _drawn(tester);
    expect(picked, containsAll(['Avenir Next', 'Menlo']));
    expect(picked, isNot(contains('IBM Plex Sans')));
    expect(picked, isNot(contains('JetBrains Mono')));
    expect(picked, isNot(contains(null)));
    expect(diffFont(), 'Menlo');
    expect(
      tester
          .widget<SideBySideDiff>(find.byType(SideBySideDiff).first)
          .theme
          .fontFamilyFallback
          .first,
      'JetBrains Mono',
    );
    expect(tester.takeException(), isNull);
    // The terminal keeps its own.
    expect(terminalStyle().fontFamily, terminal.fontFamily);

    appFont.value = null;
    codeFont.value = null;
    await settle();
    expect(_drawn(tester), bundled);
    expect(diffFont(), 'JetBrains Mono');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the phone keeps the bundled fonts whatever the Mac picked', (
    tester,
  ) async {
    appFont.value = 'Avenir Next';
    codeFont.value = 'Menlo';
    viewport(tester, const Size(390, 844), ratio: 2);
    final phone = await startPhone(
      tester,
      FakeDaemon([chat('c', 'claude', 'Fix the login')]),
    );
    final theme = _theme(tester, find.byType(ChatsScreen));
    expect(theme.uiPicked, isNull);
    expect(theme.codePicked, isNull);
    expect(theme.ui(theme.t.text).fontFamily, 'IBM Plex Sans');
    expect(theme.code(theme.t.text).fontFamily, 'JetBrains Mono');
    final drawn = _drawn(tester);
    expect(drawn, contains('IBM Plex Sans'));
    expect(drawn, isNot(contains('Avenir Next')));
    expect(drawn, isNot(contains('Menlo')));
    await endPhone(tester, phone);
  });

  // The page as it is with a font picked, the menu shut and open.
  for (final (size, w) in [
    (const Size(1700, 1000), 1700),
    (const Size(720, 900), 720),
  ]) {
    for (final b in Brightness.values) {
      testWidgets('renders, $w, ${b.name}', (tester) async {
        native.fonts = _Fonts(all: _many(300), system: '.AppleSystemUIFont');
        final d = await _settings(tester, size: size, b: b);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, size.width);
        expect(expectControlsAtEdge(tester), greaterThan(4));
        await render(
          tester,
          find.byType(NushiApp),
          'settings_fonts_${w}_${b.name}',
        );
        await _tap(tester, _field('app-font'));
        expect(tester.takeException(), isNull);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'settings_fonts_${w}_${b.name}_menu',
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        d.dispose();
      }, variant: _mac);
    }
  }
}
