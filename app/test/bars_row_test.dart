import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_commands.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_update.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/main.dart';
import 'package:nushi/trust_card.dart';
import 'package:nushi/widgets.dart';

import 'browser_fixture.dart' show browserFakes;
import 'fake_daemon.dart' show FakeDaemon, loadFonts;
import 'harness.dart';
import 'right_panes_fixture.dart';

// The bars (the daemon's update waiting for idle chats, a notice) take a
// row of their own and never lie over what's under them (ADR 0128,
// amended 2026-11-17): the case is the update's bar lying over
// the transcript's first lines and a background command's pane for as
// long as a chat ran.

const _notice = 'Didn’t start Claude in site';

/// The bars on [d]: the update's, waiting for chat c, and with [notice]
/// a notice's too.
Future<void> _bars(
  WidgetTester tester,
  Daemon d,
  FakeDaemon fake, {
  bool notice = false,
}) async {
  fake.on(
    (input) => switch (input) {
      PingRequest() => PingResponse(apiVersion: apiVersion, build: '7-1000'),
      RestartWhenIdleRequest() => RestartWhenIdleResponse(
        holds: [RestartHold(chatId: 'c', why: 'in background')],
      ),
      _ => null,
    },
  );
  d.bundled = '7-2000';
  await d.ping();
  if (notice) d.notice = _notice;
  d.listChanged();
  await tester.pumpAndSettle();
}

/// What a bar must never lie over, where it shows: the chat's header, its
/// view (the transcript and the composer), the details, a pane, a view's
/// own header and what's under it.
const _under = [
  ChatHeader,
  ChatView,
  Composer,
  DetailsPanel,
  BackgroundCommandPane,
  BrowserPane,
  TrustCard,
];

/// Every bar shown lies over nothing in [_under], keeps its text and its
/// button inside the window, and Restart now takes a click; the window
/// rendered as [name] first, to look at.
Future<void> _clear(
  WidgetTester tester,
  String name, {
  required double width,
  int bars = 1,
}) async {
  await render(tester, find.byType(NushiApp), name);
  final shown = [
    ...find.byType(DaemonUpdateBar).evaluate(),
    ...find.byType(NoticeBar).evaluate(),
  ];
  expect(shown, hasLength(bars));
  for (final e in shown) {
    final bar = tester.getRect(find.byElementPredicate((x) => x == e));
    expect(bar.left, greaterThanOrEqualTo(0));
    expect(bar.right, lessThanOrEqualTo(width));
    for (final type in _under) {
      for (final u in find.byType(type).hitTestable().evaluate()) {
        final r = tester.getRect(find.byElementPredicate((x) => x == u));
        final o = bar.intersect(r);
        expect(
          o.width <= 0.5 || o.height <= 0.5,
          isTrue,
          reason: '${e.widget.runtimeType} $bar over $type $r',
        );
      }
    }
  }
  expect(find.text('Restart now').hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadFonts);

  for (final width in [1700.0, 1200.0, 900.0, 720.0, 480.0]) {
    final w = width.toInt();
    group('$w wide', () {
      testWidgets('a plain chat', (tester) async {
        final (d, fake) = await panesApp(tester, width: width, details: false);
        await _bars(tester, d, fake);
        await _clear(tester, 'plain_$w', width: width);
        // The transcript starts under the bar, not under it in z.
        final bar = tester.getRect(find.byType(DaemonUpdateBar));
        expect(tester.getRect(find.byType(ChatView)).top, greaterThan(bar.top));
        await closeView(tester, d);
      }, variant: onMac);

      testWidgets('the details open', (tester) async {
        final (d, fake) = await panesApp(tester, width: width);
        await _bars(tester, d, fake);
        await _clear(tester, 'details_$w', width: width);
        await closeView(tester, d);
      }, variant: onMac);

      for (final sidebar in [false, true]) {
        final side = sidebar ? 'sidebar' : 'nosidebar';
        testWidgets('a background command’s pane, $side', (tester) async {
          final (d, fake) = await panesApp(
            tester,
            width: width,
            sidebar: sidebar,
            open: (
              side: false,
              files: false,
              subagent: false,
              command: true,
              previews: 0,
              browser: 0,
            ),
          );
          await _bars(tester, d, fake);
          await _clear(tester, 'command_${side}_$w', width: width);
          await closeView(tester, d);
        }, variant: onMac);
      }

      testWidgets('two bars, a pane open', (tester) async {
        final (d, fake) = await panesApp(
          tester,
          width: width,
          open: (
            side: false,
            files: false,
            subagent: false,
            command: true,
            previews: 0,
            browser: 0,
          ),
        );
        await _bars(tester, d, fake, notice: true);
        await _clear(tester, 'two_$w', width: width, bars: 2);
        await closeView(tester, d);
      }, variant: onMac);

      testWidgets('a pane expanded', (tester) async {
        browserFakes();
        final (d, fake) = await panesApp(
          tester,
          width: width,
          open: (
            side: false,
            files: false,
            subagent: false,
            command: false,
            previews: 0,
            browser: 1,
          ),
        );
        await tester.tap(find.byTooltip('Expand'));
        await tester.pumpAndSettle();
        await _bars(tester, d, fake);
        await _clear(tester, 'expanded_$w', width: width);
        await closeView(tester, d);
      }, variant: onMac);

      testWidgets('GitHub', (tester) async {
        final (d, fake) = await panesApp(tester, width: width);
        d.go(const GitHubPlace());
        await tester.pumpAndSettle();
        await _bars(tester, d, fake);
        await _clear(tester, 'github_$w', width: width);
        // Under GitHub's header, and what's under that is pushed down.
        final bar = tester.getRect(find.byType(DaemonUpdateBar));
        expect(bar.top, greaterThanOrEqualTo(8 + 56));
        final body = tester.getRect(
          find
              .descendant(
                of: find.byType(GitHubView),
                matching: find.ancestor(
                  of: find.textContaining('Sign in with'),
                  matching: find.byType(Expanded),
                ),
              )
              .last,
        );
        expect(body.top, greaterThanOrEqualTo(bar.bottom));
        await closeView(tester, d);
      }, variant: onMac);

      testWidgets('a toast while a bar shows', (tester) async {
        final (d, fake) = await panesApp(
          tester,
          width: width,
          open: (
            side: false,
            files: false,
            subagent: false,
            command: true,
            previews: 0,
            browser: 0,
          ),
        );
        await _bars(tester, d, fake);
        showToast(
          Toasts.maybeOf(tester.element(find.byType(ChatView))),
          'Copied the link',
        );
        await tester.pumpAndSettle();
        await _clear(tester, 'toast_$w', width: width);
        final bar = tester.getRect(find.byType(DaemonUpdateBar));
        final toast = tester.getRect(find.text('Copied the link'));
        expect(toast.top, greaterThanOrEqualTo(bar.bottom));
        Toasts.maybeOf(tester.element(find.byType(ChatView)))!.hide();
        await tester.pumpAndSettle();
        await closeView(tester, d);
      }, variant: onMac);
    });
  }
}
