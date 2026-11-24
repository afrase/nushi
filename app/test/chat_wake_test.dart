import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/phone/chat_sheet.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A chat's Wake: in Sleep's place in its ⋯ while it sleeps, in the menu
/// bar's Chat menu and the palette, and only with a daemon that has
/// WakeChat (`wakeApi`).

/// The app on chat `c`, asleep or awake ([status]), its agents with MCP
/// servers so ⋯ has MCP servers…; [api] the daemon's API: an older one is
/// behind the bundled daemon, which it restarts into once idle, so the app
/// works with it meanwhile (ADR 0056).
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester,
  ChatStatus status, {
  int api = apiVersion,
}) async {
  showDetails.value = false;
  viewport(tester, const Size(1700, 900));
  final fake =
      FakeDaemon([chat('c', 'claude', 'Wire the ledger', status: status)])
        ..agents = [for (final a in readyAgents()) a..mcp = true]
        ..answer = (input) => input is PingRequest && api != apiVersion
            ? PingResponse(apiVersion: api, build: '7-1000')
            : null;
  final d = await fake.connect(tester)
    ..bundled = '7-2000'
    ..select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

/// The text of a row of the open menu.
Finder _row(String label) => find.text(label, findRichText: true);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chat menu'));
  await tester.pumpAndSettle();
}

/// Says [label]'s row is the one under Pin's, where Sleep is.
void _underPin(WidgetTester tester, String label) {
  expect(_row(label), findsOne, reason: label);
  final pin = tester.getTopLeft(_row('Pin'));
  final row = tester.getTopLeft(_row(label));
  expect(row.dx, pin.dx, reason: label);
  expect(row.dy - pin.dy, 30, reason: '$label under Pin');
}

/// The palette's Wake chat row once "wake" is typed.
Future<Finder> _palette(WidgetTester tester) async {
  await press(tester, LogicalKeyboardKey.keyK, cmd: true);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(of: find.byType(Palette), matching: find.byType(TextField)),
    'wake',
  );
  await tester.pump();
  return find.descendant(
    of: find.byType(Palette),
    matching: find.text('Wake chat'),
  );
}

void main() {
  setUpAll(loadFonts);

  testWidgets("a sleeping chat's ⋯ offers Wake in Sleep's place, which "
      'sends one WakeChat; awake again, it offers Sleep', (tester) async {
    final (d, fake) = await _app(tester, ChatStatus(asleep: true));
    await _openMenu(tester);
    _underPin(tester, 'Wake');
    expect(_row('Sleep'), findsNothing);
    expect(_row('MCP servers…'), findsOne);
    expect(_row('Skills…'), findsOne);

    await tester.tap(_row('Wake'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<WakeChatRequest>().single.chatId, 'c');

    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        status: ChatStatus(canSleep: true),
      ),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);
    _underPin(tester, 'Sleep');
    expect(_row('Wake'), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("an awake chat's ⋯ offers Sleep, not Wake, with MCP servers… "
      'and Skills…', (tester) async {
    final (d, _) = await _app(tester, ChatStatus(canSleep: true));
    await _openMenu(tester);
    _underPin(tester, 'Sleep');
    expect(_row('Wake'), findsNothing);
    expect(_row('MCP servers…'), findsOne);
    expect(_row('Skills…'), findsOne);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the menu bar's Chat menu and the palette have Wake for a "
      'sleeping chat', (tester) async {
    final (d, fake) = await _app(tester, ChatStatus(asleep: true));
    final chatMenu = tester
        .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
        .menus
        .whereType<PlatformMenu>()
        .firstWhere((m) => m.label == 'Chat');
    final labels = [for (final m in chatMenu.menus) m.label];
    expect(labels, containsAllInOrder(['Sleep', 'Wake', 'Reload']));
    chatMenu.menus
        .whereType<PlatformMenuItem>()
        .firstWhere((m) => m.label == 'Wake')
        .onSelected!();
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<WakeChatRequest>(), hasLength(1));

    final row = await _palette(tester);
    expect(row, findsOne);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<WakeChatRequest>(), hasLength(2));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a daemon without WakeChat (API 145) offers no Wake', (
    tester,
  ) async {
    final (d, fake) = await _app(
      tester,
      ChatStatus(asleep: true),
      api: wakeApi - 1,
    );
    expect(d.daemonApi, 145);
    expect(await _palette(tester), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await _openMenu(tester);
    expect(_row('Pin'), findsOne);
    expect(_row('Wake'), findsNothing);
    expect(_row('Sleep'), findsNothing);
    expect(fake.calls.whereType<WakeChatRequest>(), isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  // The phone's chat sheet, by the same rule: Wake where Sleep is.
  for (final (size, tag) in const [
    (Size(390, 844), '390'),
    (Size(430, 932), '430'),
    (Size(844, 390), 'landscape'),
  ]) {
    testWidgets("the phone's chat sheet offers Wake for a sleeping chat, "
        'Sleep for an awake one ($tag)', (tester) async {
      viewport(tester, size, ratio: 2);
      final fake = FakeDaemon([
        chat(
          'a',
          'claude',
          'Wire the ledger',
          status: ChatStatus(asleep: true),
        ),
        chat(
          'b',
          'codex',
          'Cap the rates',
          age: 5,
          status: ChatStatus(canSleep: true),
        ),
      ]);
      final phone = await startPhone(tester, fake);
      Future<void> sheet(String title) async {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Chat'));
        await tester.pumpAndSettle();
      }

      Finder inSheet(String label) => find.descendant(
        of: find.byType(ChatSheet),
        matching: find.text(label),
      );

      await sheet('Wire the ledger');
      expect(inSheet('Wake'), findsOne);
      expect(inSheet('Sleep'), findsNothing);
      await tester.ensureVisible(inSheet('Wake')); // landscape scrolls
      await tester.pumpAndSettle();
      await render(tester, find.byType(PhoneApp), 'phone_chat_sheet_wake_$tag');
      await tester.tap(inSheet('Wake'));
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<WakeChatRequest>().single.chatId, 'a');
      expect(find.byType(ChatSheet), findsNothing);

      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      await sheet('Cap the rates');
      expect(inSheet('Sleep'), findsOne);
      expect(inSheet('Wake'), findsNothing);
      await endPhone(tester, phone);
    });
  }
}
