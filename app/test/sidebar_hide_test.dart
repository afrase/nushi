import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
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
      final strip = tester.getRect(find.byType(Sidebar));
      final button = tester.getRect(find.byTooltip(_hide));
      expect(strip.width, 333);
      // Its icon 5 in from the strip's end, as it was; its box, a header's
      // icon button's, reaches past that.
      expect(button.right, strip.right - Sidebar.end + SidebarButton.reach);
      expect(
        button.center.dx,
        strip.right - Sidebar.end - SidebarButton.iconInset - 8,
      );
      // In the strip the traffic lights sit in, level with them and with
      // the header's middle (36 from the window's top: the window's
      // margin and half a header), and clear of them with the sidebar at
      // its narrowest too (they end 80 from its left).
      expect(button.center.dy, NushiTheme.windowPad + PaneHeader.height / 2);
      expect(button.center.dy, 36);
      expect(200 - Sidebar.end - button.width, greaterThan(95));
      // The strip ends where the header does, and New chat starts there.
      expect(Sidebar.topHeight, tester.getRect(find.byType(ChatHeader)).bottom);
      expect(tester.getRect(find.byType(WideButton)).top, Sidebar.topHeight);
      final header = find.byType(ChatHeader);
      final element = tester.element(header);
      // The main pane starts where the sidebar ends, which brings the gap.
      expect(tester.getRect(header).left, 333);
      expect(tester.getRect(header).top, NushiTheme.windowPad);

      await tester.tap(find.byTooltip(_hide));
      await tester.pumpAndSettle();
      expect(sidebarHidden.value, isTrue);
      expect(find.byType(Sidebar), findsNothing);
      expect(tester.getRect(header).left, NushiTheme.windowPad);
      // The window less its margins: the details are under it.
      expect(tester.getRect(header).width, 1200 - 2 * NushiTheme.windowPad);
      expect(tester.element(header), same(element), reason: 'the chat stayed');
      expect(readSaved()['sidebarHidden'], isTrue);
      expect(paneWidths.value['sidebar'], 333);

      await tester.tap(find.byTooltip(_show));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(Sidebar)).width, 333);
      expect(tester.getRect(header).left, 333);
      expect(tester.element(header), same(element), reason: 'the chat stayed');
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

    // The owner, of the beta: the button at a header's left was smaller
    // than the icon buttons at its right. It's the same control: the same
    // icon, the same box around it, so the same fill under the pointer.
    for (final (hidden, brightness) in [
      for (final hidden in [true, false])
        for (final b in Brightness.values) (hidden, b),
    ]) {
      final state = hidden ? 'hidden' : 'shown';
      testWidgets('it’s the header’s icon button, as the ones at the '
          'header’s right, the sidebar $state, ${brightness.name}', (
        tester,
      ) async {
        final d = await _window(tester, hidden: hidden, brightness: brightness);
        IconTap button(Pattern tooltip) => tester.widget<IconTap>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconTap),
          ),
        );
        // How large the icon is drawn in the button.
        Size icon(Pattern tooltip) => tester.getSize(
          find
              .descendant(
                of: find.byTooltip(tooltip),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        final own = hidden ? _show : _hide;
        final other = RegExp(r'^(Show|Hide) details$');
        expect(tester.getSize(find.byTooltip(own)), const Size.square(32));
        expect(
          tester.getSize(find.byTooltip(own)),
          tester.getSize(find.byTooltip(other)),
        );
        expect(icon(own), const Size.square(16));
        expect(icon(own), icon(other));
        expect(button(own).padding, button(other).padding);
        expect(button(own).padding, IconTap.header);
        // Level with them.
        expect(
          tester.getCenter(find.byTooltip(own)).dy,
          closeTo(tester.getCenter(find.byTooltip(other)).dy, 0.5),
        );
        // To look at: at rest, then under the pointer, its fill the size
        // of the details button's beside the header's other end.
        final shot = 'header_sidebar_${state}_${brightness.name}';
        await render(tester, find.byType(NushiApp), shot);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.byTooltip(own)));
        await tester.pump();
        await render(tester, find.byType(NushiApp), '${shot}_pointer');
        d.dispose();
      }, variant: _mac);
    }

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
      expect(calls, ['arm', 'arm', 'zoom']);
      await tester.timedDragFrom(
        empty,
        const Offset(60, 30),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(calls, ['arm', 'arm', 'zoom', 'arm']);
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
      expect(
        show.left,
        NushiTheme.windowPad + lightsInset - SidebarButton.reach,
      );
      // In the header's empty middle, between its state and its switch.
      final space = Offset(
        (tester.getRect(find.byType(PhasePill)).right +
                tester.getRect(find.byType(Segmented<ChatTab>)).left) /
            2,
        12,
      );
      await tester.tapAt(space);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(space);
      await tester.pump();
      expect(calls, ['arm', 'arm', 'zoom']);
      await tester.timedDragFrom(
        space,
        const Offset(60, 30),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(calls, ['arm', 'arm', 'zoom', 'arm']);
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(show.center);
      await tester.pumpAndSettle();
      expect(sidebarHidden.value, isFalse);
      expect(calls, ['arm', 'arm', 'zoom', 'arm']);
      d.dispose();
    }, variant: _mac);
  });

  group('the headers, hidden', () {
    /// The header's row starts past the button, which is past the lights.
    void cleared(WidgetTester tester, String title) {
      final button = tester.getRect(find.byTooltip(_show));
      expect(
        button.left,
        greaterThanOrEqualTo(lightsInset - SidebarButton.reach),
      );
      expect(button.size, const Size.square(32));
      // In the middle of the pane's header, over its hairline.
      expect(
        button.center.dy,
        closeTo(NushiTheme.windowPad + (PaneHeader.height - 1) / 2, 0.5),
      );
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
            // The main pane's top, the window's margin in on every side.
            final bar = tester.getRect(header.first);
            expect(bar.left, NushiTheme.windowPad);
            expect(bar.top, NushiTheme.windowPad);
            expect(bar.width, width - 2 * NushiTheme.windowPad);
            final show = tester.getRect(find.byTooltip(_show));
            // Its icon 5 past the lights' room, its box around it.
            expect(
              show.left,
              NushiTheme.windowPad + lightsInset - SidebarButton.reach,
            );
            expect(
              show.center.dx,
              NushiTheme.windowPad + lightsInset + SidebarButton.iconInset + 8,
            );
            switch (name) {
              case 'chat':
                // The title, after the chat's color.
                expect(
                  tester.getTopLeft(find.text(_title).first).dx,
                  NushiTheme.windowPad +
                      hiddenHeaderStart +
                      ColorChip.width +
                      8,
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

    testWidgets('the chat’s color is a chip in its header only while the '
        'sidebar is hidden', (tester) async {
      final dot = find.descendant(
        of: find.byType(ChatHeader),
        matching: find.byKey(const Key('chat color')),
      );
      final d = await _window(tester, hidden: false);
      expect(dot, findsNothing);
      sidebarHidden.value = true;
      await tester.pumpAndSettle();
      expect(dot, findsOneWidget);
      expect(
        tester.getSize(dot),
        const Size(ColorChip.width, ColorChip.height),
      );
      expect(find.byTooltip('Amber'), findsOneWidget);
      d.select('b');
      await tester.pumpAndSettle();
      expect(dot, findsNothing);
      expect(
        tester.getTopLeft(find.text('Bump the API version').first).dx,
        NushiTheme.windowPad + hiddenHeaderStart,
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
        header.right - ChatHeader.end,
      );
      d.dispose();
    }, variant: _mac);
  });

  group('the bars, hidden', () {
    /// [bar] floats under the pane's header, clear of the lights, in the
    /// pane's middle and no wider than a notice gets.
    void floats(WidgetTester tester, Finder bar, double width) {
      final r = tester.getRect(bar);
      expect(
        r.top,
        greaterThanOrEqualTo(NushiTheme.windowPad + PaneHeader.height),
      );
      expect(r.width, lessThanOrEqualTo(FloatBar.width));
      expect(r.left, greaterThanOrEqualTo(NushiTheme.windowPad + 16));
      expect(r.center.dx, moreOrLessEquals(width / 2, epsilon: 1));
    }

    for (final (width, b) in [
      (1700.0, Brightness.dark),
      (1700.0, Brightness.light),
      (720.0, Brightness.dark),
      (720.0, Brightness.light),
    ]) {
      testWidgets(
        'the update’s, removed chats’ and a notice’s cards float under '
        'the header, $width wide, ${b.name}',
        (tester) async {
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
              find.ancestor(of: text, matching: find.byType(FloatBar));
          // The header keeps the pane's top: nothing is over or under the
          // lights, and nothing in the pane moved.
          expect(
            tester.getRect(find.byType(ChatHeader)).top,
            NushiTheme.windowPad,
          );
          for (final text in [update, removed, notice]) {
            floats(tester, bar(text), width);
          }
          await render(
            tester,
            find.byType(NushiApp),
            'sidebar_hidden_bars_${width.toInt()}_${b.name}',
          );

          // Beside the sidebar they are over the pane, not the sidebar.
          sidebarHidden.value = false;
          await tester.pumpAndSettle();
          expect(
            tester.getRect(bar(update)).left,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(Sidebar)).right + 16,
            ),
          );
          d.dispose();
        },
        variant: _mac,
      );
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
      floats(
        tester,
        find.ancestor(of: text, matching: find.byType(FloatBar)),
        tester.getSize(find.byType(NushiApp)).width,
      );
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
      final key = sidebarKey.single;
      bool same(ShortcutActivator k) {
        final a = k is Cmd ? k.single : k as SingleActivator;
        return a.trigger == key.trigger &&
            a.meta == key.meta &&
            a.control == key.control &&
            a.alt == key.alt &&
            a.shift == key.shift;
      }

      final all = [
        ...actKeys.keys,
        ...chatKeys.keys,
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
    final phone = await startPhone(tester, fake);
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
