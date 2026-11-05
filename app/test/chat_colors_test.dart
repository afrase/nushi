import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'theme_sets.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _names = [
  'blue',
  'teal',
  'violet',
  'amber',
  'rust',
  'magenta',
  'slate',
  'green',
];

/// One chat of each color and one with none, the eighth selected in the
/// window's tests.
List<Chat> _chats() => [
  for (final (i, name) in _names.indexed)
    chat('$name-chat', 'claude', 'Work on the ${name}s', age: i)
      ..color = name
      ..worktree = Worktree(branch: 'nushi/$name'),
  chat('plain', 'codex', 'No color at all', age: 9),
];

Color _on(Color tint, Color surface) => Color.alphaBlend(tint, surface);

/// The row titled [title] in the sidebar: its Tap.
Tap _row(WidgetTester tester, String title) => tester.widget<Tap>(
  find.ancestor(of: find.text(title), matching: find.byType(Tap)).first,
);

/// The color of the bar on the row titled [title], or null without one.
Color? _bar(WidgetTester tester, String title) {
  final bar = find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(ColorBar)),
    matching: find.byKey(const Key('color bar')),
  );
  if (bar.evaluate().isEmpty) return null;
  final box = tester.widget<DecoratedBox>(bar).decoration as BoxDecoration;
  return box.color;
}

/// The window on [fake], showing [selected]; the chat [menu]'s menu open, if
/// given.
Future<Daemon> _window(
  WidgetTester tester,
  FakeDaemon fake, {
  required double width,
  Brightness brightness = Brightness.dark,
  String? selected,
  String? menu,
}) async {
  viewport(tester, Size(width, 800), brightness: brightness);
  final d = await fake.connect(tester);
  if (selected != null) d.select(selected);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  if (menu != null) {
    await tester.tap(find.text(menu), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
  }
  return d;
}

void main() {
  setUpAll(loadFonts);

  test('the names are the daemon’s eight, and anything else is no color', () {
    expect([for (final c in ChatColor.values) c.name], _names);
    expect(ChatColor.named('amber'), ChatColor.amber);
    for (final name in ['', 'Amber', '#ff0000', ' amber', 'toString']) {
      expect(ChatColor.named(name), isNull, reason: name);
    }
  });

  for (final (name, t) in everySet) {
    test('each theme has its eight ($name)', () {
      expect(t.avatars, hasLength(ChatColor.values.length));
    });

    // What a row can be: the sidebar's raised, under the pointer, the open
    // chat's, the open chat's behind Settings, and the phone's base.
    final rows = {
      'raised': t.raised,
      'hovered': _on(t.hover, t.raised),
      'open': t.accentSoft,
      'selected': t.selected,
      'base': t.base,
    };

    test('a color’s bar and swatch read on every row ($name)', () {
      for (final MapEntry(key: row, value: fill) in rows.entries) {
        for (final c in ChatColor.values) {
          expect(
            contrast(c.ink(t), fill),
            greaterThanOrEqualTo(3),
            reason: '${c.name} on $row',
          );
        }
      }
    });

    test('a row keeps AA for all its text ($name)', () {
      final inks = {
        'text': t.text,
        'secondary': t.textSecondary,
        'muted': t.textMuted,
        'needs': t.needs,
        'done': t.done,
      };
      for (final MapEntry(key: row, value: fill) in rows.entries) {
        for (final MapEntry(key: ink, value: color) in inks.entries) {
          expect(
            contrast(color, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$ink on $row',
          );
        }
      }
    });
  }

  group('the sidebar', () {
    for (final (name, tokens) in [
      ('dark', Tokens.dark),
      ('light', Tokens.light),
    ]) {
      testWidgets('rows in their colors, one selected ($name)', (tester) async {
        viewport(tester, const Size(400, 600));
        final d = await FakeDaemon(_chats()).connect(tester);
        d.select('amber-chat');
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: const Key('shot'),
                  child: SizedBox(
                    width: 300,
                    height: 560,
                    child: ListenableBuilder(
                      listenable: d,
                      builder: (context, _) => Sidebar(daemon: d),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Only the open chat's row is filled; a color is its bar.
        expect(_row(tester, 'Work on the ambers').fill, tokens.accentSoft);
        expect(_bar(tester, 'Work on the ambers'), ChatColor.amber.ink(tokens));
        expect(_row(tester, 'Work on the teals').fill, isNull);
        expect(_bar(tester, 'Work on the teals'), ChatColor.teal.ink(tokens));
        expect(_row(tester, 'No color at all').fill, isNull);
        expect(_bar(tester, 'No color at all'), isNull);
        // The bar takes no width: a colored row's title starts where a
        // plain one's does.
        expect(
          tester.getTopLeft(find.text('Work on the teals')).dx,
          tester.getTopLeft(find.text('No color at all')).dx,
        );
        final bar = tester.getRect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Work on the teals'),
              matching: find.byType(ColorBar),
            ),
            matching: find.byKey(const Key('color bar')),
          ),
        );
        final box = tester.getRect(
          find
              .ancestor(
                of: find.text('Work on the teals'),
                matching: find.byType(Tap),
              )
              .first,
        );
        expect(bar.left, box.left);
        expect(bar.width, 3);
        expect(bar.top, box.top + 4);
        expect(bar.bottom, box.bottom - 4);
        await expectLater(
          find.byKey(const Key('shot')),
          matchesGoldenFile('goldens/chat_colors_rows_$name.png'),
        );
        await closeView(tester, d);
      });
    }

    testWidgets('a name the app doesn’t know shows as no color', (
      tester,
    ) async {
      final fake = FakeDaemon([chat('c', 'claude', 'Odd')..color = '#ff00ff']);
      final d = await _window(tester, fake, width: 1200);
      expect(d.chats['c']!.color, isNull);
      expect(_bar(tester, 'Odd'), isNull);
      fake.emit(
        EventsResponse(
          chatId: 'c',
          chat: chat('c', 'claude', 'Odd')..color = 'amber',
        ),
      );
      await tester.pumpAndSettle();
      expect(d.chats['c']!.color, ChatColor.amber);
      expect(_bar(tester, 'Odd'), ChatColor.amber.ink(Tokens.dark));
      fake.emit(
        EventsResponse(
          chatId: 'c',
          chat: chat('c', 'claude', 'Odd')..color = 'javascript:x',
        ),
      );
      await tester.pumpAndSettle();
      expect(d.chats['c']!.color, isNull);
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('the menu', () {
    testWidgets('nine swatches, each named, the current one ringed; a pick '
        'closes it and applies at once', (tester) async {
      final fake = FakeDaemon(_chats());
      final d = await _window(
        tester,
        fake,
        width: 1200,
        menu: 'Work on the rusts',
      );
      final swatches = tester.widgetList<Swatch>(find.byType(Swatch)).toList();
      expect(
        [for (final s in swatches) s.tooltip],
        ['No color', for (final c in ChatColor.values) c.label],
      );
      expect(swatches.first.color, isNull);
      expect(
        [for (final s in swatches) s.selected],
        [for (var i = 0; i < 9; i++) i == 5],
      );
      for (final s in find.byType(Swatch).evaluate()) {
        final size = tester.getSize(find.byWidget(s.widget));
        expect(size, const Size.square(Swatch.size));
      }

      await tester.tap(find.byTooltip('Teal'));
      await tester.pump();
      expect(find.byType(Swatch), findsNothing);
      expect(d.chats['rust-chat']!.color, ChatColor.teal);
      await tester.pumpAndSettle();
      final sent = fake.calls.whereType<SetChatColorRequest>().single;
      expect(sent.chatId, 'rust-chat');
      expect(sent.color, 'teal');
      expect(fake.chats[4].color, 'teal');

      await tester.tap(
        find.text('Work on the rusts'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('No color'));
      await tester.pumpAndSettle();
      expect(d.chats['rust-chat']!.color, isNull);
      expect(fake.calls.whereType<SetChatColorRequest>().last.color, '');
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('a swatch works from the keyboard, its focus drawn', (
      tester,
    ) async {
      final fake = FakeDaemon(_chats());
      final d = await _window(
        tester,
        fake,
        width: 1200,
        menu: 'No color at all',
      );
      // The menu takes no focus as it opens: this is where Tab would land.
      FocusNode swatch(String name) => Focus.of(
        tester.element(
          find
              .descendant(
                of: find.byTooltip(name),
                matching: find.byType(Container),
              )
              .first,
        ),
      );
      swatch('Magenta').requestFocus();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(Swatch), findsNothing);
      expect(d.chats['plain']!.color, ChatColor.magenta);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('a color the daemon refuses goes back', (tester) async {
      final refused = Completer<Object>();
      final fake = FakeDaemon(_chats())
        ..answer = ((input) =>
            input is SetChatColorRequest ? refused.future : null);
      final d = await _window(
        tester,
        fake,
        width: 1200,
        menu: 'No color at all',
      );
      await tester.tap(find.byTooltip('Green'));
      await tester.pump();
      expect(d.chats['plain']!.color, ChatColor.green);
      refused.completeError(
        ConnectException(Code.unavailable, 'the disk is full'),
      );
      await tester.pumpAndSettle();
      expect(d.chats['plain']!.color, isNull);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('an older daemon: no Color', (tester) async {
      final d = await FakeDaemon(_chats()).connect(tester);
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      List<MenuEntry> rows() => [
        for (final e in chatMenu(
          context,
          d.chats['plain']!,
          d,
          onRename: () {},
        ))
          if (e.controls != null) e,
      ];
      expect(rows(), hasLength(1));
      d.daemonApi = chatColorApi - 1;
      expect(rows(), isEmpty);
      await closeView(tester, d);
    });
  });

  for (final (width, b) in [
    (1700.0, Brightness.dark),
    (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    (720.0, Brightness.light),
  ]) {
    testWidgets('the whole window, $width wide, ${b.name}: the menu open', (
      tester,
    ) async {
      paneWidths.value = {};
      final d = await _window(
        tester,
        FakeDaemon(_chats()),
        width: width,
        brightness: b,
        selected: 'amber-chat',
        menu: 'Work on the violets',
      );
      expect(tester.takeException(), isNull);
      await render(
        tester,
        find.byType(NushiApp),
        'chat_colors_window_${width.toInt()}_${b.name}',
      );
      await closeView(tester, d);
    }, variant: _mac);
  }

  for (final b in Brightness.values) {
    testWidgets('the phone’s list, 390×844 (${b.name})', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 2, brightness: b);
      final fake = FakeDaemon(_chats());
      final phone = await startPhone(tester, fake);
      expect(find.byType(ChatRow), findsNWidgets(9));
      expect(tester.takeException(), isNull);
      final tokens = b == Brightness.dark ? Tokens.dark : Tokens.light;
      expect(_bar(tester, 'Work on the ambers'), ChatColor.amber.ink(tokens));
      expect(_bar(tester, 'No color at all'), isNull);
      // No wash: nothing between a row and the list is filled with a color.
      for (final m in tester.widgetList<Material>(
        find.ancestor(
          of: find.byType(InkWell),
          matching: find.byType(Material),
        ),
      )) {
        expect([
          for (final c in ChatColor.values) c.ink(tokens),
        ], isNot(contains(m.color)));
      }
      final bar = tester.getRect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Work on the ambers'),
            matching: find.byType(ColorBar),
          ),
          matching: find.byKey(const Key('color bar')),
        ),
      );
      expect(bar.left, 0);
      expect(bar.width, 4);
      await render(
        tester,
        find.byType(PhoneApp),
        'chat_colors_phone_${b.name}',
      );
      await endPhone(tester, phone);
    });
  }
}

/// The WCAG contrast of [a] and [b].
double contrast(Color a, Color b) {
  double lum(Color c) => c.computeLuminance();
  final (hi, lo) = lum(a) > lum(b) ? (lum(a), lum(b)) : (lum(b), lum(a));
  return (hi + 0.05) / (lo + 0.05);
}
