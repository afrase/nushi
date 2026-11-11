// Settings › Appearance's Theme (ADR 0086): a pick repaints the app at once
// and is remembered; the user's theme files load, partial and broken ones
// say what's wrong, and an edit to one reloads it.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
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

/// The tokens the app paints [of] with.
Tokens _painted(WidgetTester tester, Finder of) =>
    NushiTheme.of(tester.element(of)).t;

/// Taps [f] once it's scrolled into view.
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

/// Writes [text] as the theme file [name], and the folder's gone after.
File _file(String name, String text) {
  final dir = themeFiles.dir..createSync(recursive: true);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return File('${dir.path}/$name')..writeAsStringSync(text);
}

/// The Mac app on Settings › Appearance, [size] wide, dark.
Future<Daemon> _app(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
}) async {
  viewport(tester, size, brightness: Brightness.dark);
  final d =
      await FakeDaemon([chat('a', 'claude', 'Fix the login')]).connect(tester)
        ..openSettings(section: SettingsSection.appearance);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a theme picked repaints the app at once and is kept across '
      'a relaunch', (tester) async {
    Directory(dataDir).createSync(recursive: true);
    final d = await _app(tester);
    expect(_painted(tester, find.byType(SettingsView)), same(Tokens.dark));
    expect(find.byType(ThemeCard), findsNWidgets(builtInThemes.length));
    await _tap(tester, find.text('Nord'));
    await tester.pumpAndSettle();
    final nord = builtInTheme('nord')!;
    expect(_painted(tester, find.byType(SettingsView)), same(nord.dark));
    expect(colorTheme.value, 'nord');
    expect(readSaved()['theme'], 'nord');
    final picked = tester.widget<ThemeCard>(
      find.ancestor(of: find.text('Nord'), matching: find.byType(ThemeCard)),
    );
    expect(picked.picked, isTrue);
    // Light: the same theme's light set.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(_painted(tester, find.byType(SettingsView)), same(nord.light));
    await closeView(tester, d);

    // A new window reads the pref as kept.
    final again = await _app(tester);
    expect(_painted(tester, find.byType(SettingsView)), same(nord.dark));
    await closeView(tester, again);
  }, variant: _mac);

  testWidgets('Tokyo Night is picked from its card, and kept by its id', (
    tester,
  ) async {
    Directory(dataDir).createSync(recursive: true);
    final d = await _app(tester);
    await _tap(tester, find.text('Tokyo Night'));
    await tester.pumpAndSettle();
    final tokyo = builtInTheme('tokyo-night')!;
    expect(_painted(tester, find.byType(SettingsView)), same(tokyo.dark));
    expect(readSaved()['theme'], 'tokyo-night');
    expect(pickedTheme(), same(tokyo));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(_painted(tester, find.byType(SettingsView)), same(tokyo.light));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a theme picked shows on the next frame, and rebuilding the '
      'app with the same theme changes nothing below it', (tester) async {
    final d = await _app(tester);
    await _tap(tester, find.text('Nord'));
    await tester.pump();
    final nord = builtInTheme('nord')!;
    // No frames of a theme animation, each a rebuild of all that reads it.
    expect(_painted(tester, find.byType(SettingsView)), same(nord.dark));
    expect(
      NushiTheme.forTheme(nord, Brightness.dark),
      same(NushiTheme.forTheme(nord, Brightness.dark)),
    );
    await closeView(tester, d);
  }, variant: _mac);

  test('a theme made once is made again for another platform', () {
    // ThemeData takes its platform when it is made, so a theme cached
    // under one platform must not answer for another: a test for the Mac
    // after one that ran as Android would get Android's controls.
    final nord = builtInTheme('nord')!;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = NushiTheme.forTheme(nord, Brightness.light);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final mac = NushiTheme.forTheme(nord, Brightness.light);
    debugDefaultTargetPlatformOverride = null;
    expect(android.platform, TargetPlatform.android);
    expect(mac.platform, TargetPlatform.macOS);
  });

  testWidgets('a theme file saved as it was tells no one; one that changed '
      'does', (tester) async {
    final file = _file('Harbor.json', '{"from": "nord"}');
    themeFiles.load();
    var told = 0;
    void count() => told++;
    themeFiles.addListener(count);
    addTearDown(() => themeFiles.removeListener(count));
    file.writeAsStringSync('{"from": "nord"}'); // an editor's save
    themeFiles.load();
    expect(told, 0);
    file.writeAsStringSync('{"from": "solarized"}');
    themeFiles.load();
    expect(told, 1);
    expect(themeFiles.value.single.file, 'Harbor.json');
  });

  testWidgets('720 wide, the tiles wrap and nothing runs off', (tester) async {
    _file(
      'A long name for a theme.json',
      '{"name": "A long name for a theme"}',
    );
    themeFiles.load();
    final d = await _app(tester, size: const Size(720, 900));
    expect(tester.takeException(), isNull);
    expectTextInside(tester, 720);
    await render(tester, find.byType(NushiApp), 'theme_picker_720_dark');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a theme file loads as a tile; a partial, a broken and a '
      'low-contrast file each say what they are', (tester) async {
    _file('Good.json', '{"from": "solarized", "dark": {"base": "#101820"}}');
    _file('Broken.json', '{"dark": {');
    _file('Odd.json', '{"dark": {"basee": "#101010", "text": "red"}}');
    _file('Low.json', '{"name": "Dim", "dark": {"textMuted": "#4A4D55"}}');
    _file('notes.txt', 'not a theme');
    // Only regular files: a link and a pipe (which a read would wait on
    // forever) are passed over.
    final good = '${themeFiles.dir.path}/Good.json';
    Link('${themeFiles.dir.path}/Linked.json').createSync(good);
    Process.runSync('mkfifo', ['${themeFiles.dir.path}/Pipe.json']);
    themeFiles.load();
    expect(
      [for (final f in themeFiles.value) f.file],
      ['Broken.json', 'Good.json', 'Low.json', 'Odd.json'],
    );
    final d = await _app(tester, size: const Size(1700, 1100));
    expect(find.text('Good'), findsOne);
    expect(find.text('Dim'), findsOne);
    expect(find.text('Odd'), findsOne);
    // A file that's no theme says so under the cards; one that is says
    // what's wrong on its own card.
    expect(find.textContaining('Broken'), findsOne);
    expect(
      find.text('Broken.json: Isn’t JSON: Unexpected end of input.'),
      findsOne,
    );
    Finder onCard(String name, Finder f) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(ThemeCard)),
      matching: f,
    );
    expect(
      onCard('Odd', find.text('"dark.basee" is no token: ignored.')),
      findsOne,
    );
    expect(
      onCard(
        'Odd',
        find.text('"dark.text" isn’t #RRGGBB or #AARRGGBB: ignored.'),
      ),
      findsOne,
    );
    expect(
      onCard(
        'Dim',
        find.textContaining(RegExp(r'^Dark: textMuted on .+ under 4\.5:1')),
      ),
      findsOne,
    );
    expect(onCard('Dim', find.textContaining('Light:')), findsNothing);
    expect(onCard('Good', find.text('Yours · Good.json')), findsOne);
    expect(onCard('Nord', find.text('Built in')), findsOne);
    // The custom card's colors are its own: its preview draws in them.
    final mine = tester.widget<ThemeCard>(
      find.ancestor(of: find.text('Good'), matching: find.byType(ThemeCard)),
    );
    expect(mine.theme.dark.base, const Color(0xFF101820));
    expect(
      find.descendant(
        of: find.byWidget(mine),
        matching: find.byWidgetPredicate(
          (w) => w is ThemePreview && w.tokens.base == const Color(0xFF101820),
        ),
      ),
      findsOne,
    );
    await render(tester, find.byType(NushiApp), 'theme_files_1700_dark');

    await _tap(tester, find.text('Good'));
    await tester.pumpAndSettle();
    expect(colorTheme.value, 'custom:Good');
    final t = _painted(tester, find.byType(SettingsView));
    expect(t.base, const Color(0xFF101820));
    expect(t.raised, builtInTheme('solarized')!.dark.raised);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a picked theme whose file goes shows Nushi’s, and is back '
      'with it', (tester) async {
    final f = _file('Gone.json', '{"dark": {"base": "#101820"}}');
    themeFiles.load();
    colorTheme.value = 'custom:Gone';
    final d = await _app(tester);
    expect(
      _painted(tester, find.byType(SettingsView)).base,
      const Color(0xFF101820),
    );
    f.deleteSync();
    themeFiles.load();
    await tester.pumpAndSettle();
    expect(_painted(tester, find.byType(SettingsView)).base, Tokens.dark.base);
    expect(colorTheme.value, 'custom:Gone');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('editing a theme file reloads it, and the app repaints', (
    tester,
  ) async {
    final f = _file('Live.json', '{"dark": {"base": "#101820"}}');
    themeFiles.load();
    colorTheme.value = 'custom:Live';
    final d = await _app(tester);
    await tester.runAsync(() async => themeFiles.watch());
    addTearDown(themeFiles.stop);
    await tester.runAsync(
      () => f.writeAsString('{"dark": {"base": "#203040"}}'),
    );
    await untilReal(
      tester,
      () => pickedTheme().dark.base == const Color(0xFF203040),
    );
    await tester.pumpAndSettle();
    expect(
      _painted(tester, find.byType(SettingsView)).base,
      const Color(0xFF203040),
    );
    // A new file shows as a tile of its own.
    await tester.runAsync(
      () => File('${f.parent.path}/Second.json').writeAsString('{}'),
    );
    await untilReal(tester, () => find.text('Second').evaluate().isNotEmpty);
    await tester.runAsync(themeFiles.stop);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('New from writes the current theme whole, picks it and shows '
      'it in Finder; Show folder opens the folder', (tester) async {
    final opened = fakeDesktop();
    addTearDown(() {
      if (themeFiles.dir.existsSync()) {
        themeFiles.dir.deleteSync(recursive: true);
      }
    });
    colorTheme.value = 'catppuccin';
    final d = await _app(tester);
    await _tap(tester, find.text('New from Catppuccin'));
    await tester.pumpAndSettle();
    final file = File('${themeFiles.dir.path}/Catppuccin.json');
    expect(file.existsSync(), isTrue);
    expect(colorTheme.value, 'custom:Catppuccin');
    expect(opened.single, ['-R', file.path]);
    final made = pickedTheme();
    expect(made.dark.base, builtInTheme('catppuccin')!.dark.base);
    expect(themeFiles.value.single.notes, isEmpty);
    // Again: a name of its own.
    await _tap(tester, find.text('New from Catppuccin'));
    await tester.pumpAndSettle();
    expect(
      File('${themeFiles.dir.path}/Catppuccin 2.json').existsSync(),
      isTrue,
    );
    await _tap(tester, find.text('Show folder'));
    await tester.pumpAndSettle();
    expect(opened.last, [themeFiles.dir.path]);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, the theme picker, $name', (tester) async {
      colorTheme.value = 'nushi';
      final d = await FakeDaemon([]).connect(tester);
      await pumpSettings(
        tester,
        d,
        SettingsSection.appearance,
        tokens: tokens,
        size: const Size(1000, 900),
      );
      await expectLater(
        find.byType(ThemeGroup),
        matchesGoldenFile('goldens/theme_picker_$name.png'),
      );
      d.dispose();
    });
  }
}
