import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/beside.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/top_notices.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'update_fixtures.dart';

// Where the toasts and the update card show, in the window and on the
// phone, rendered to look at.

void main() {
  setUpAll(loadFonts);
  setUp(() {
    brewCask = null;
  });

  void say(BuildContext context, String text, {ToastAction? action}) =>
      showToast(Toasts.maybeOf(context), text, action: action);
  void hide(BuildContext context) => Toasts.maybeOf(context)!.hide();

  for (final width in [1700.0, 720.0]) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      if (rendering) ('light', Brightness.light),
    ]) {
      for (final hidden in [false, true]) {
        final where = '${width.toInt()}_${name}_${hidden ? 'nobar' : 'bar'}';
        testWidgets('toasts and the update card, $where', (tester) async {
          sidebarHidden.value = hidden;
          // Each Check for updates waits for its answer here.
          var checked = Completer<CheckForUpdatesResponse>();
          var found = UpdateCheck();
          final fake = updateDaemon(UpdateCheck.new)
            ..answer = (input) => switch (input) {
              PingRequest() => PingResponse(
                apiVersion: apiVersion,
                version: '0.1.16',
                update: found,
              ),
              CheckForUpdatesRequest() => checked.future,
              _ => null,
            };
          final d = await openWithUpdate(
            tester,
            fake,
            width: width,
            brightness: brightness,
          );
          final context = tester.element(find.byType(Scaffold));
          Future<void> shot(String what) async {
            await tester.pumpAndSettle();
            await render(tester, find.byType(MaterialApp), '${what}_$where');
          }

          // Under the header, 8 points down, centred over the transcript
          // (the composer's centre), left of the details rail.
          final main = tester.getRect(find.byType(Beside));
          final transcript = tester.getRect(find.byType(ChatView));
          final headerBottom = main.top + PaneHeader.height;
          expect(transcript.top, headerBottom);
          void under(Rect box) {
            expect(box.top, headerBottom + 8);
            expect(box.center.dx, closeTo(transcript.center.dx, 0.5));
            expect(box.width, ToastHost.width);
          }

          say(context, 'Committed 3f2a9c1');
          await shot('a_plain');
          under(toast(tester));
          hide(context);
          await tester.pumpAndSettle();
          // A failure, where every other toast shows.
          showError(context, "Couldn't push: the remote refused it.");
          await shot('a_failure');
          under(toast(tester));
          // A failure goes by its × (hide leaves it).
          await tester.tap(find.byTooltip('Dismiss'));
          await tester.pumpAndSettle();
          say(
            context,
            'Archived side chat',
            action: (label: 'Undo', onPressed: () {}),
          );
          await shot('b_action');
          under(toast(tester));
          hide(context);
          await tester.pumpAndSettle();
          var checking = checkForUpdates(context, d);
          await tester.pump(const Duration(milliseconds: 400));
          await shot('c_checking');
          expect(
            find.descendant(
              of: find.byType(ToastLine),
              matching: find.byType(Spinner),
            ),
            findsOneWidget,
          );
          checked.complete(
            CheckForUpdatesResponse(update: UpdateCheck(latest: '0.1.16')),
          );
          await checking;
          await shot('d_up_to_date');
          expect(find.text('Nushi is up to date (0.1.16).'), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(ToastLine),
              matching: find.byIcon(Icons.check_circle),
            ),
            findsOneWidget,
          );
          expect(find.byType(Spinner), findsNothing);
          hide(context);
          await tester.pumpAndSettle();
          // The update card, alone and with a toast.
          found = newerUpdate('0.1.17');
          checked = Completer()
            ..complete(CheckForUpdatesResponse(update: newerUpdate('0.1.17')));
          checking = checkForUpdates(context, d);
          await tester.pump();
          await checking;
          await shot('e_card');
          // The window's bottom right, over the details rail, not up with
          // the toasts (ADR 0128, amended 2026-11-19).
          final card = tester.getRect(updateToast);
          expect(card.right, main.right - TopNotices.cardInset);
          expect(card.top, greaterThan(transcript.center.dy));
          say(
            context,
            'Archived side chat',
            action: (label: 'Undo', onPressed: () {}),
          );
          await shot('f_card_toast');
          // Each where it was alone: neither moves for the other.
          final both = toast(tester);
          expect(both.overlaps(card), isFalse);
          under(both);
          expect(tester.getRect(updateToast), card);
          // Over Settings, where it was, and pressable.
          d.openSettings();
          await shot('h_settings');
          expect(toast(tester), both);
          expect(find.text('Undo').hitTestable(), findsOneWidget);
          d.closeSettings();
          await tester.pumpAndSettle();
          // Beside a side pane: over what's left of the transcript.
          hide(context);
          toggleFiles(d.chats['c']!);
          await tester.pumpAndSettle();
          say(context, 'Committed 3f2a9c1');
          await shot('i_side_pane');
          // Centred over what's left of the transcript where a toast fits
          // there, else over the whole area; inside it either way.
          final left = tester.getRect(find.byType(ChatView));
          final files = tester.getRect(find.byType(FilesPane));
          final right = min(left.right, files.left);
          expect(
            toast(tester).center.dx,
            closeTo(
              right - left.left >= ToastHost.width + 16
                  ? (left.left + right) / 2
                  : main.center.dx,
              0.5,
            ),
          );
          expectInside(tester, toast(tester));
          expectInside(tester, tester.getRect(updateToast));
          expectTextInside(tester, width);
          toggleFiles(d.chats['c']!);
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }

  // No window lets a toast or the card out of the main area: with Files
  // over the transcript, and in windows narrower than a toast.
  for (final width in [720.0, 480.0, 400.0]) {
    testWidgets('a toast and the card stay inside, ${width.toInt()} wide', (
      tester,
    ) async {
      sidebarHidden.value = true;
      final d = await openWithUpdate(
        tester,
        updateDaemon(() => newerUpdate('0.1.17')),
        width: width,
        brightness: Brightness.light,
      );
      toggleFiles(d.chats['c']!);
      await tester.pumpAndSettle();
      showToast(
        Toasts.maybeOf(tester.element(find.byType(Scaffold))),
        'Committed 3f2a9c1',
        action: (label: 'Undo', onPressed: () {}),
      );
      await tester.pumpAndSettle();
      final main = tester.getRect(find.byType(Beside));
      final box = toast(tester);
      expect(box.width, min(ToastHost.width, main.width - 16));
      expectInside(tester, box);
      expectInside(tester, tester.getRect(updateToast));
      expect(box.overlaps(tester.getRect(updateToast)), isFalse);
      // Their words too, none cut at the main area's edge.
      for (final of in [find.byType(ToastLine), updateToast]) {
        for (final e
            in find
                .descendant(of: of, matching: find.byType(RichText))
                .evaluate()) {
          final r = e.renderObject! as RenderBox;
          expectInside(tester, r.localToGlobal(Offset.zero) & r.size);
        }
      }
      await render(
        tester,
        find.byType(MaterialApp),
        'j_inside_${width.toInt()}',
      );
      toggleFiles(d.chats['c']!);
      await closeView(tester, d);
    }, variant: onMac);
  }

  testWidgets('the phone: a toast at the bottom', (tester) async {
    viewport(tester, const Size(390, 844), ratio: 3);
    final phone = await startPhone(
      tester,
      FakeDaemon([chat('a', 'claude', 'Fix the login redirect')]),
    );
    await tester.pumpAndSettle();
    showToast(
      Toasts.maybeOf(tester.element(find.text('Fix the login redirect'))),
      'Copied',
    );
    await tester.pumpAndSettle();
    await render(tester, find.byType(MaterialApp), 'g_phone');
    // At the bottom, near the thumb, the screen's width but its margins.
    final box = toast(tester);
    expect(box.bottom, 844 - 8);
    expect(box.left, 8);
    expect(box.right, 390 - 8);
    await endPhone(tester, phone);
  });
}

/// The showing toast's card.
Rect toast(WidgetTester tester) => tester.getRect(
  find
      .ancestor(of: find.byType(ToastLine), matching: find.byType(Material))
      .first,
);

/// [box] at least 8 points inside the main area.
void expectInside(WidgetTester tester, Rect box) {
  final main = tester.getRect(find.byType(Beside));
  expect(box.left, greaterThanOrEqualTo(main.left + 8 - 0.5));
  expect(box.right, lessThanOrEqualTo(main.right - 8 + 0.5));
}
