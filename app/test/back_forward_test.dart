import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/theme/tokens.dart';
import 'package:nushi/visits.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Back and Forward through the places visited (ADR 0119): the chevrons
// after the sidebar's button, ⌘[ and ⌘], View's items and the palette's.

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _back = 'Back\u2002⌘[';
const _forward = 'Forward\u2002⌘]';

Future<Daemon> _app(
  WidgetTester tester, {
  double width = 1200,
  Brightness brightness = Brightness.dark,
  bool hidden = false,
}) async {
  viewport(tester, Size(width, 700), brightness: brightness);
  sidebarHidden.value = hidden;
  paneWidths.value = {};
  final d = await FakeDaemon([
    chat('a', 'claude', 'Fix the login redirect'),
    chat('b', 'codex', 'Bump the API version', age: 1),
    chat('c', 'claude', 'Release notes', folder: '/Users/me/site', age: 2),
  ]).connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

/// Opens [ids] one after the other, as picks do.
Future<void> _visit(WidgetTester tester, Daemon d, List<String> ids) async {
  for (final id in ids) {
    d.select(id);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _meta(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// Whether the button named [tooltip] can be pressed.
bool _on(WidgetTester tester, String tooltip) =>
    tester
        .widget<IconTap>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconTap),
          ),
        )
        .onTap !=
    null;

/// View's item [label] in the menu bar.
PlatformMenuItem _viewItem(WidgetTester tester, String label) {
  final view = tester
      .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
      .menus
      .whereType<PlatformMenu>()
      .firstWhere((m) => m.label == 'View');
  Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
    PlatformMenuItemGroup(:final members) => members.expand(items),
    _ => [m],
  };
  return view.menus.expand(items).firstWhere((m) => m.label == label);
}

void main() {
  setUpAll(loadFonts);

  group('the visits', () {
    bool all(Visit _) => true;
    const jira = Visit(JiraPlace());
    const a = Visit(ChatPlace(), chat: 'a');
    const b = Visit(ChatPlace(), chat: 'b');
    const c = Visit(ChatPlace(), chat: 'c');

    test('a step goes back and forth; a new visit drops those ahead', () {
      final v = Visits()
        ..see(a)
        ..see(b)
        ..see(b) // the same place: no visit more
        ..see(null) // no chat: no place
        ..see(c);
      expect(v.can(1, all), isFalse);
      expect(v.step(-1, all), b);
      expect(v.step(-1, all), a);
      expect(v.can(-1, all), isFalse);
      expect(v.step(-1, all), isNull);
      expect(v.step(1, all), b);
      v.see(jira);
      expect(v.can(1, all), isFalse, reason: 'c dropped');
      expect(v.step(-1, all), b);
    });

    test('passes over what isn’t live, and the place it’s at', () {
      final v = Visits()
        ..see(a)
        ..see(b)
        ..see(a)
        ..see(c);
      bool notB(Visit x) => x != b;
      expect(v.step(-1, notB), a);
      expect(v.can(-1, notB), isFalse, reason: 'b gone, then a again');
    });

    test('keeps the last hundred', () {
      final v = Visits();
      for (var i = 0; i < 150; i++) {
        v.see(Visit(const ChatPlace(), chat: '$i'));
      }
      var steps = 0;
      while (v.step(-1, all) != null) {
        steps++;
      }
      expect(steps, Visits.most - 1);
    });
  });

  testWidgets('the chevrons after the sidebar’s button go back and forth, '
      'greyed out with nowhere to go', (tester) async {
    final d = await _app(tester);
    expect(_on(tester, _back), isFalse);
    expect(_on(tester, _forward), isFalse);
    // After the sidebar's button, in a row, level with it.
    final sidebar = tester.getRect(find.byTooltip('Hide the sidebar\u2002⌘\\'));
    final back = tester.getRect(find.byTooltip(_back));
    final forward = tester.getRect(find.byTooltip(_forward));
    expect(back.left, sidebar.right + 2);
    expect(forward.left, back.right + 2);
    expect(back.center.dy, sidebar.center.dy);
    expect(forward.right, TitleButtons.right);

    await _visit(tester, d, ['a', 'b', 'c']);
    expect(_on(tester, _back), isTrue);
    expect(_on(tester, _forward), isFalse);
    await tester.tap(find.byTooltip(_back));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'b');
    await tester.tap(find.byTooltip(_back));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'a');
    expect(_on(tester, _back), isFalse);
    await tester.tap(find.byTooltip(_forward));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'b');
    // A pick drops what was ahead.
    await _visit(tester, d, ['a']);
    expect(_on(tester, _forward), isFalse);
    d.dispose();
  }, variant: _mac);

  testWidgets('⌘[ and ⌘], from the composer too; ⌥⌘↑ and ⌥⌘↓ go through '
      'the sidebar instead', (tester) async {
    final d = await _app(tester);
    await _visit(tester, d, ['c', 'a']);
    // The composer has the focus.
    await tester.tap(find.byType(EditableText).first);
    await tester.pump();
    await _meta(tester, LogicalKeyboardKey.bracketLeft);
    expect(d.selectedId, 'c');
    await _meta(tester, LogicalKeyboardKey.bracketRight);
    expect(d.selectedId, 'a');
    // The sidebar's order: b, a (nushi's, the newest first), then c.
    expect(chatOrder(d).map((c) => c.id), ['a', 'b', 'c']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(d.selectedId, 'b');
    expect(keyLabel(previousChatKey), '⌥⌘↑');
    expect(keyLabel(backKey), '⌘[');
    d.dispose();
  }, variant: _mac);

  testWidgets('an archived or deleted chat is passed over', (tester) async {
    final d = await _app(tester);
    await _visit(tester, d, ['a', 'b', 'c']);
    d.chats['b']!.archived = true;
    d.listChanged();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(_back));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'a');
    d.chats.remove('c');
    d.listChanged();
    await tester.pumpAndSettle();
    expect(_on(tester, _forward), isFalse, reason: 'b archived, c gone');
    d.dispose();
  }, variant: _mac);

  testWidgets('Jira and GitHub are places too; Settings isn’t', (tester) async {
    final d = await _app(tester);
    await _visit(tester, d, ['a']);
    d.go(const GitHubPlace());
    await tester.pumpAndSettle();
    d.openSettings();
    await tester.pumpAndSettle();
    // From the menu bar: Settings shuts, and the chat shows again.
    _viewItem(tester, 'Back').onSelected!();
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(d.place, const ChatPlace());
    expect(d.selectedId, 'a');
    expect(_viewItem(tester, 'Back').onSelected, isNull);
    _viewItem(tester, 'Forward').onSelected!();
    await tester.pumpAndSettle();
    expect(d.place, const GitHubPlace());
    expect(_viewItem(tester, 'Forward').shortcut, forwardKey);
    d.dispose();
  }, variant: _mac);

  testWidgets('the palette has them', (tester) async {
    final d = await _app(tester);
    await _visit(tester, d, ['a', 'b']);
    final context = tester.element(find.byType(Scaffold));
    final rows = appActions(context, d);
    final back = rows.firstWhere((a) => a.act == Act.back);
    expect((back.title, back.enabled, back.shortcut), ('Back', true, '⌘['));
    expect(rows.firstWhere((a) => a.act == Act.forward).enabled, isFalse);
    back.run();
    await tester.pumpAndSettle();
    expect(d.selectedId, 'a');
    d.dispose();
  }, variant: _mac);

  testWidgets('on Linux Alt+Left and Alt+Right, which a text field keeps', (
    tester,
  ) async {
    native
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
    final d = await _app(tester);
    await _visit(tester, d, ['c', 'a']);
    expect(find.byTooltip('Back\u2002Alt+Left'), findsOneWidget);
    Future<void> alt(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
    }

    await alt(LogicalKeyboardKey.arrowLeft);
    expect(d.selectedId, 'c');
    await alt(LogicalKeyboardKey.arrowRight);
    expect(d.selectedId, 'a');
    // In the composer it's the line's start, not Back.
    await tester.tap(find.byType(EditableText).first);
    await tester.pump();
    await alt(LogicalKeyboardKey.arrowLeft);
    expect(d.selectedId, 'a');
    d.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: the title buttons, Back on, Forward off ($name)', (
      tester,
    ) async {
      viewport(tester, const Size(160, 60));
      final d = await FakeDaemon([
        chat('a', 'claude', 'One'),
        chat('b', 'claude', 'Two'),
      ]).connect(tester);
      d
        ..select('a')
        ..select('b');
      await tester.pumpWidget(
        themed(
          Center(
            child: RepaintBoundary(
              key: const Key('shot'),
              child: TitleButtons(daemon: d),
            ),
          ),
          tokens: tokens,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/title_buttons_$name.png'),
      );
      d.dispose();
    }, variant: _mac);
  }

  group('renders', () {
    for (final width in [1700.0, 720.0]) {
      for (final b in Brightness.values) {
        for (final hidden in [false, true]) {
          final state = hidden ? 'hidden' : 'shown';
          testWidgets('the title buttons, $width wide, ${b.name}, the '
              'sidebar $state', (tester) async {
            final d = await _app(
              tester,
              width: width,
              brightness: b,
              hidden: hidden,
            );
            await _visit(tester, d, ['a', 'b']);
            expectTextInside(tester, width);
            await render(
              tester,
              find.byType(NushiApp),
              'title_buttons_${width.toInt()}_${b.name}_$state',
            );
            d.dispose();
          }, variant: _mac);
        }
      }
    }
  });
}
