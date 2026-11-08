import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/window_drag.dart';
import 'package:nushi/window_drag_linux.dart';
import 'package:nushi/window_drag_macos.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Linux's window keeps the system's title bar (ADR 0102): the headers start
// at its inset rather than past the Mac's lights, and neither they nor the
// band over Settings move or zoom the window. Tests pair Linux's window and
// conventions with its platform, as a real Linux machine runs them.

final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

const _title = 'Fix the login redirect after it expires';

/// Linux's window, saying what the headers asked of it.
class _Window implements AppWindow {
  final calls = <String>[];
  static const _linux = LinuxWindow();

  @override
  double get titleInset => _linux.titleInset;

  @override
  bool get headersMoveWindow => _linux.headersMoveWindow;

  @override
  bool get menuBar => _linux.menuBar;

  @override
  Future<void> present({String? token}) async => calls.add('present');

  @override
  Future<void> arm(int micros) async => calls.add('arm');

  @override
  Future<void> zoom() async => calls.add('zoom');
}

/// The window on Linux, [width] wide, with the sidebar [hidden].
Future<Daemon> _window(
  WidgetTester tester, {
  double width = 1200,
  Brightness brightness = Brightness.dark,
  bool hidden = true,
  AppWindow window = const LinuxWindow(),
}) async {
  native
    ..window = window
    ..conventions = linuxConventions;
  viewport(tester, Size(width, 760), brightness: brightness);
  sidebarHidden.value = hidden;
  paneWidths.value = {};
  final d = await FakeDaemon([
    chat('a', 'claude', _title)..color = 'amber',
    chat('b', 'codex', 'Bump the API version', age: 1),
  ]).connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

void main() {
  setUpAll(loadFonts);

  test('each window says where the headers start and whether they move it, '
      "Linux's presenting through its runner with the click's token", () async {
    const mac = MacWindow();
    expect(
      (mac.titleInset, mac.headersMoveWindow, mac.menuBar),
      (84, true, true),
    );
    const linux = LinuxWindow();
    expect(
      (linux.titleInset, linux.headersMoveWindow, linux.menuBar),
      (8, false, false),
    );

    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('nushi/window');
    messenger.setMockMethodCallHandler(channel, (c) async {
      calls.add(c);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await linux.present(token: 'gnome-shell/Nushi/1234-0-host_TIME5');
    await linux.present();
    expect([for (final c in calls) c.method], ['present', 'present']);
    expect(calls.first.arguments, {
      'token': 'gnome-shell/Nushi/1234-0-host_TIME5',
    });
    expect(calls.last.arguments, isEmpty);
  });

  testWidgets('a header neither moves nor zooms the window, the band over '
      'Settings is only its dim, and the sidebar’s button still works', (
    tester,
  ) async {
    final window = _Window();
    final d = await _window(tester, window: window, hidden: false);
    final empty = Offset(
      tester.getRect(find.byType(ChatHeader)).right - 300,
      8,
    );
    await tester.tapAt(empty);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(empty);
    await tester.pump();
    await tester.timedDragFrom(
      empty,
      const Offset(60, 30),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(window.calls, isEmpty);

    await tester.tap(find.byTooltip(r'Hide the sidebar (⌘\)'));
    await tester.pumpAndSettle();
    expect(sidebarHidden.value, isTrue);
    expect(tester.getRect(find.byTooltip(r'Show the sidebar (⌘\)')).left, 8);

    d.openSettings();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TitleBand),
        matching: find.byType(WindowDrag),
      ),
      findsNothing,
    );
    await tester.tapAt(const Offset(600, 8));
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(window.calls, isEmpty);
    d.dispose();
  }, variant: _linux);

  testWidgets('the bars keep their margin with the sidebar hidden, nothing '
      'being over the content there', (tester) async {
    native
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
    viewport(tester, const Size(720, 700));
    paneWidths.value = {};
    sidebarHidden.value = true;
    final fake =
        FakeDaemon([chat('a', 'claude', _title), chat('b', 'codex', 'Bump')])
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
    d
      ..select('a')
      ..notice = 'Didn’t start Claude in site'
      ..listChanged();
    await tester.pumpAndSettle();
    final update = find.textContaining('Nushi will update its daemon');
    expect(tester.getTopLeft(update).dx, 16);
    expect(
      tester.getTopLeft(find.byIcon(Icons.shield_outlined)).dx,
      greaterThanOrEqualTo(16),
    );
    await render(tester, find.byType(NushiApp), 'linux_bars_720_hidden');
    d.dispose();
  }, variant: _linux);

  group('renders', () {
    final views = <String, void Function(Daemon)>{
      'chat': (_) {},
      'nothing': (d) => d
        ..selectedId = null
        ..listChanged(),
      'github': (d) => d.go(const GitHubPlace()),
      'settings': (d) => d.openSettings(),
    };
    for (final MapEntry(key: name, value: go) in views.entries) {
      for (final width in [1700.0, 720.0]) {
        for (final hidden in [true, false]) {
          final shown = hidden ? 'hidden' : 'shown';
          testWidgets('$name, $width wide, the sidebar $shown: the headers '
              "start at Linux's inset", (tester) async {
            final d = await _window(tester, width: width, hidden: hidden);
            go(d);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(PlatformMenuBar), findsNothing);
            if (hidden && name != 'settings') {
              final show = tester.getRect(
                find.byTooltip(r'Show the sidebar (⌘\)'),
              );
              expect(show.left, lightsInset);
              expect(show.top, greaterThanOrEqualTo(0));
              if (name == 'chat') {
                // The title, after the chat's color.
                expect(
                  tester.getTopLeft(find.text(_title).first).dx,
                  hiddenHeaderStart + 16,
                );
              }
            }
            expectTextInside(tester, width);
            await render(
              tester,
              find.byType(NushiApp),
              'linux_${name}_${width.toInt()}_$shown',
            );
            d.dispose();
          }, variant: _linux);
        }
      }
    }
  });
}
