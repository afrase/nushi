import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_ask.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _hide = r'Hide the sidebar (⌘\)';
const _show = r'Show the sidebar (⌘\)';

const _title = 'Fix the login redirect after it expires';

List<Chat> _chats() => [
  chat('a', 'claude', _title)..color = 'amber',
  chat('b', 'codex', 'Bump the API version', age: 1),
];

/// What the window asked of `nushi/window`.
List<String> _windowCalls() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('nushi/window'), (c) async {
        calls.add(c.method);
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('nushi/window'), null),
  );
  return calls;
}

/// The window on [fake] (else two chats), the sidebar [hidden], chat a shown
/// if [open].
Future<Daemon> _window(
  WidgetTester tester, {
  FakeDaemon? fake,
  double width = 1200,
  Brightness brightness = Brightness.dark,
  bool hidden = true,
  bool open = true,
}) async {
  viewport(tester, Size(width, 700), brightness: brightness);
  sidebarHidden.value = hidden;
  paneWidths.value = {};
  final d = await (fake ?? FakeDaemon(_chats())).connect(tester);
  if (open) d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// The View menu's labels.
List<String> _viewMenu(WidgetTester tester) {
  final view = tester
      .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
      .menus
      .whereType<PlatformMenu>()
      .firstWhere((m) => m.label == 'View');
  Iterable<String> labels(PlatformMenuItem m) => switch (m) {
    PlatformMenuItemGroup(:final members) => members.expand(labels),
    _ => [m.label],
  };
  return [...view.menus.expand(labels)];
}

void main() {
  setUpAll(loadFonts);

  group('the button', () {
    testWidgets('the sidebar’s top strip: right-aligned; hiding gives the main '
        'area the window, showing brings it back at its width', (tester) async {
      final d = await _window(tester, hidden: false);
      paneWidths.value = {'sidebar': 333};
      await tester.pump();
      final strip = tester.getRect(
        find
            .ancestor(
              of: find.byTooltip(_hide),
              matching: find.byType(PaneHeader),
            )
            .first,
      );
      final button = tester.getRect(find.byTooltip(_hide));
      expect(strip.width, 333);
      expect(button.right, strip.right - 10);
      // Clear of the traffic lights, the sidebar at its narrowest too.
      expect(200 - 10 - button.width, greaterThan(lightsInset));
      final header = find.byType(ChatHeader);
      final state = tester.state(header);
      expect(tester.getRect(header).left, 333);

      await tester.tap(find.byTooltip(_hide));
      await tester.pumpAndSettle();
      expect(sidebarHidden.value, isTrue);
      expect(find.byType(Sidebar), findsNothing);
      expect(tester.getRect(header).left, 0);
      expect(tester.getRect(header).width, 1200);
      expect(tester.state(header), same(state), reason: 'the chat stayed');
      expect(readSaved()['sidebarHidden'], isTrue);
      expect(paneWidths.value['sidebar'], 333);

      await tester.tap(find.byTooltip(_show));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(Sidebar)).width, 333);
      expect(tester.getRect(header).left, 333);
      expect(tester.state(header), same(state), reason: 'the chat stayed');
      expect(readSaved()['sidebarHidden'], isFalse);
      d.dispose();
    }, variant: _mac);

    testWidgets('the list comes back where it was scrolled to', (tester) async {
      final fake = FakeDaemon([
        for (var i = 0; i < 40; i++) chat('c$i', 'claude', 'Chat $i', age: i),
      ]);
      final d = await _window(tester, fake: fake, hidden: false, open: false);
      final list = find.descendant(
        of: find.byType(Sidebar),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(list.first).position.jumpTo(300);
      await tester.pump();
      await tester.tap(find.byTooltip(_hide));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_show));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(list.first).position.pixels, 300);
      d.dispose();
    }, variant: _mac);

    testWidgets('it keeps its clicks, and the strip’s empty space moves and '
        'zooms the window', (tester) async {
      final calls = _windowCalls();
      final d = await _window(tester, hidden: false);
      final button = tester.getRect(find.byTooltip(_hide));
      const empty = Offset(120, 20);

      await tester.tapAt(empty);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(empty);
      await tester.pump();
      expect(calls, ['zoom']);
      await tester.timedDragFrom(
        empty,
        const Offset(60, 30),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(calls, ['zoom', 'drag']);
      expect(sidebarHidden.value, isFalse);

      // Past the double-click's time, a click on the button is the button's.
      calls.clear();
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(button.center);
      await tester.pumpAndSettle();
      expect(sidebarHidden.value, isTrue);
      expect(calls, isEmpty);

      // Hidden, the same of the header, around its button.
      await tester.pump(const Duration(seconds: 1));
      final show = tester.getRect(find.byTooltip(_show));
      expect(show.left, lightsInset);
      await tester.tapAt(const Offset(800, 8));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(800, 8));
      await tester.pump();
      expect(calls, ['zoom']);
      await tester.timedDragFrom(
        const Offset(800, 8),
        const Offset(60, 30),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(calls, ['zoom', 'drag']);
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(show.center);
      await tester.pumpAndSettle();
      expect(sidebarHidden.value, isFalse);
      expect(calls, ['zoom', 'drag']);
      d.dispose();
    }, variant: _mac);
  });

  group('the headers, hidden', () {
    /// The header's row starts past the button, which is past the lights.
    void cleared(WidgetTester tester, String title) {
      final button = tester.getRect(find.byTooltip(_show));
      expect(button.left, greaterThanOrEqualTo(lightsInset));
      expect(button.height, 26);
      expect(button.center.dy, closeTo(21.5, 0.5));
      expect(
        tester.getTopLeft(find.text(title).first).dx,
        greaterThanOrEqualTo(button.right),
      );
    }

    final views = <String, (Finder, void Function(Daemon))>{
      'chat': (find.byType(ChatHeader), (_) {}),
      'jira': (find.byType(PaneHeader), (d) => d.go(const JiraPlace())),
      'github': (find.byType(PaneHeader), (d) => d.go(const GitHubPlace())),
      'nothing': (
        find.byType(PaneHeader),
        (d) => d
          ..selectedId = null
          ..listChanged(),
      ),
      'trust': (
        find.byType(PaneHeader),
        (d) => d
          ..trustAsk = TrustAsk('/Users/me/site', 'Start Claude', [], 'claude')
          ..listChanged(),
      ),
    };
    for (final MapEntry(key: name, value: (header, go)) in views.entries) {
      for (final width in [1700.0, 720.0]) {
        for (final b in Brightness.values) {
          testWidgets('$name, $width wide, ${b.name}: the button past the '
              'lights', (tester) async {
            final d = await _window(tester, width: width, brightness: b);
            go(d);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final bar = tester.getRect(header.first);
            expect(bar.left, 0);
            expect(bar.top, 0);
            expect(bar.width, width);
            final show = tester.getRect(find.byTooltip(_show));
            expect(show.left, lightsInset);
            switch (name) {
              case 'chat':
                // The title, after the chat's color.
                expect(
                  tester.getTopLeft(find.text(_title).first).dx,
                  hiddenHeaderStart + 16,
                );
              case 'jira':
                cleared(tester, 'Jira');
              case 'github':
                cleared(tester, 'GitHub');
              case 'settings':
                cleared(tester, 'Settings');
            }
            // The empty window, wide, is its window golden; the rest are
            // renders.
            final shot = 'sidebar_hidden_${name}_${width.toInt()}_${b.name}';
            if (name == 'nothing' && width == 1700) {
              await expectLater(
                find.byType(NushiApp),
                matchesGoldenFile('goldens/$shot.png'),
              );
            } else {
              await render(tester, find.byType(NushiApp), shot);
            }
            d.dispose();
          }, variant: _mac);
        }
      }
    }

    testWidgets('the chat’s color is a dot in its header only while the '
        'sidebar is hidden', (tester) async {
      const dot = Key('chat color');
      final d = await _window(tester, hidden: false);
      expect(find.byKey(dot), findsNothing);
      sidebarHidden.value = true;
      await tester.pumpAndSettle();
      expect(find.byKey(dot), findsOneWidget);
      expect(tester.getSize(find.byKey(dot)), const Size.square(8));
      expect(find.byTooltip('Amber'), findsOneWidget);
      d.select('b');
      await tester.pumpAndSettle();
      expect(find.byKey(dot), findsNothing);
      expect(
        tester.getTopLeft(find.text('Bump the API version').first).dx,
        hiddenHeaderStart,
      );
      d.dispose();
    }, variant: _mac);

    testWidgets('a full header at 720 wide folds rather than overflows, ⋯ at '
        'its end', (tester) async {
      final link = GitHubLink(
        host: 'github.com',
        repo: 'afrase/nushi',
        number: 12,
        pull: true,
      );
      final fake = FakeDaemon([
        chat('a', 'claude', _title)
          ..color = 'teal'
          ..pull = link,
      ]);
      final d = await _window(tester, fake: fake, width: 720);
      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byType(ChatHeader));
      expect(
        tester.getRect(find.byTooltip('Chat menu')).right,
        header.right - NushiTheme.gutter,
      );
      d.dispose();
    }, variant: _mac);
  });

  group('the bars, hidden', () {
    /// [what] starts past the lights, its bar still from the window's edge.
    void past(WidgetTester tester, Finder bar, Finder what) {
      expect(tester.getRect(bar).left, 0);
      expect(tester.getTopLeft(what).dx, lightsInset);
    }

    for (final (width, b) in [
      (1700.0, Brightness.dark),
      (1700.0, Brightness.light),
      (720.0, Brightness.dark),
      (720.0, Brightness.light),
    ]) {
      testWidgets('the update’s, removed chats’ and a notice’s text start past '
          'the lights, $width wide, ${b.name}', (tester) async {
        viewport(tester, Size(width, 700), brightness: b);
        paneWidths.value = {};
        sidebarHidden.value = true;
        final fake = FakeDaemon(_chats())
          ..answer = ((input) => switch (input) {
            PingRequest() => PingResponse(
              apiVersion: apiVersion,
              build: '7-1000',
            ),
            _ => null,
          });
        final d = Daemon(transport: fake)..bundled = '7-2000';
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        d.select('a');
        fake.emit(
          EventsResponse(
            removedChats: RemovedChats(
              chats: [
                RemovedChat(
                  id: 'k',
                  agent: 'claude',
                  title: 'Old',
                  folder: '/x',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        d
          ..notice = 'Didn’t start Claude in site'
          ..listChanged();
        await tester.pumpAndSettle();

        final update = find.textContaining('Nushi will update its daemon');
        final removed = find.textContaining('Removed “Old”');
        final notice = find.text('Didn’t start Claude in site');
        Finder bar(Finder text) =>
            find.ancestor(of: text, matching: find.byType(Container)).last;
        expect(tester.getTopLeft(update).dx, lightsInset);
        expect(tester.getRect(bar(update)).left, 0);
        final removedIcon = find.byIcon(Icons.history_toggle_off);
        past(tester, bar(removed), removedIcon);
        expect(tester.getTopLeft(removed).dx, greaterThan(lightsInset));
        final noticeIcon = find.byIcon(Icons.shield_outlined);
        past(tester, bar(notice), noticeIcon);
        expect(tester.getTopLeft(notice).dx, greaterThan(lightsInset));
        await render(
          tester,
          find.byType(NushiApp),
          'sidebar_hidden_bars_${width.toInt()}_${b.name}',
        );

        // Beside the sidebar they keep their margin from it.
        sidebarHidden.value = false;
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(update).dx,
          tester.getRect(find.byType(Sidebar)).right + 16,
        );
        d.dispose();
      }, variant: _mac);
    }

    testWidgets('the daemon’s banner too', (tester) async {
      final fake = FakeDaemon(_chats());
      final d = await _window(tester, fake: fake);
      fake.answer = (i) => i is PingRequest ? throw StateError('gone') : null;
      final pinged = d.ping();
      await tester.pump();
      await tester.pump();
      await pinged;
      await tester.pump(DaemonBanner.grace);
      await tester.pump(DaemonBanner.slideFor);
      final text = find.text(
        'Lost the connection to the daemon; reconnecting…',
      );
      expect(tester.getTopLeft(text).dx, lightsInset);
      expect(tester.getRect(find.byType(DaemonBanner)).left, 0);
      expect(tester.getRect(find.byType(DaemonBanner)).top, 0);
      fake.answer = null;
      await d.ping();
      await tester.pump(DaemonBanner.backFor);
      await tester.pump(DaemonBanner.slideFor);
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('the action', () {
    test(r'⌘\ is its own key: no action’s or the chats’ but this', () {
      expect(Act.sidebar.shortcut, r'⌘\');
      expect(Act.sidebar.key, sidebarKey);
      bool same(SingleActivator a) =>
          a.trigger == sidebarKey.trigger &&
          a.meta == sidebarKey.meta &&
          a.control == sidebarKey.control &&
          a.alt == sidebarKey.alt &&
          a.shift == sidebarKey.shift;
      final all = [
        ...actKeys.keys.whereType<SingleActivator>(),
        ...chatKeys.keys.whereType<SingleActivator>(),
        paletteKey,
        paletteKeyToo,
      ];
      expect(all.where(same), hasLength(1));
    });

    testWidgets(r'⌘\ hides and shows it, with the focus in the composer too, '
        'and the View menu says which', (tester) async {
      final d = await _window(tester, hidden: false);
      expect(_viewMenu(tester), contains('Hide Sidebar'));
      expect(_viewMenu(tester), isNot(contains('Show Sidebar')));
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.backslash);
      expect(sidebarHidden.value, isTrue);
      expect(find.byType(Sidebar), findsNothing);
      expect(_viewMenu(tester), contains('Show Sidebar'));
      expect(_viewMenu(tester), isNot(contains('Hide Sidebar')));
      await _key(tester, LogicalKeyboardKey.backslash);
      expect(sidebarHidden.value, isFalse);
      d.dispose();
    }, variant: _mac);

    testWidgets(r'⌘\ still works once the button that had the focus has gone', (
      tester,
    ) async {
      final d = await _window(tester, hidden: false);
      Focus.of(
        tester.element(
          find
              .descendant(
                of: find.byTooltip(_hide),
                matching: find.byType(Container),
              )
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sidebarHidden.value, isTrue);
      await _key(tester, LogicalKeyboardKey.backslash);
      expect(sidebarHidden.value, isFalse);
      d.dispose();
    }, variant: _mac);

    testWidgets('hidden, ⌘K reaches Jira, GitHub, Settings and the sidebar', (
      tester,
    ) async {
      final d = await _window(tester);
      Future<void> run(String query, String row) async {
        await _key(tester, LogicalKeyboardKey.keyK);
        final palette = find.byType(Palette);
        expect(palette, findsOneWidget);
        await tester.enterText(
          find.descendant(of: palette, matching: find.byType(TextField)),
          query,
        );
        await tester.pump();
        expect(
          find.descendant(of: palette, matching: find.text(row)),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      await run('jira', 'Jira');
      expect(d.place, isA<JiraPlace>());
      await run('github', 'GitHub');
      expect(d.place, isA<GitHubPlace>());
      await run('settings', 'Settings');
      expect(d.settingsOpen, isNotNull);
      expect(d.place, isA<GitHubPlace>(), reason: 'Settings is over it');
      d.closeSettings();
      await tester.pumpAndSettle();
      await run('sidebar', 'Show the sidebar');
      expect(sidebarHidden.value, isFalse);
      d.dispose();
    }, variant: _mac);

    testWidgets('the chat’s menu is in its ⋯ while the sidebar is hidden', (
      tester,
    ) async {
      final d = await _window(tester);
      await tester.tap(find.byTooltip('Chat menu'));
      await tester.pumpAndSettle();
      expect(find.text('Color'), findsOneWidget);
      d.dispose();
    }, variant: _mac);
  });

  testWidgets('the phone: no button, no key, whatever is saved', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), ratio: 2);
    sidebarHidden.value = true;
    final fake = FakeDaemon(_chats());
    final phone = Phone(
      PhonePlatform()..saved = pairedRecord(),
      connectTo: (_) => Daemon(transport: fake, remote: true),
    );
    await tester.pumpWidget(PhoneApp(phone));
    await phone.start();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(SidebarButton), findsNothing);
    await tester.tap(find.text(_title));
    await tester.pumpAndSettle();
    expect(find.byType(SidebarButton), findsNothing);
    expect(find.byType(ShowSidebarButton), findsNothing);
    await _key(tester, LogicalKeyboardKey.backslash);
    expect(sidebarHidden.value, isTrue);
    await endPhone(tester, phone);
  });
}
