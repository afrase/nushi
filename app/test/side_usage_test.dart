import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/usage.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The app [size] on chat c, the details panel shown, with what its agent
/// reported of the chat's usage, and a side chat s open (made as the
/// daemon's openSide makes one); [hidden], hidden by ⇧⌘B.
Future<(Daemon, FakeDaemon, ChatState)> _app(
  WidgetTester tester, {
  bool hidden = false,
  Size size = const Size(1700, 760),
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = true;
  final fake = FakeDaemon([chat('c', 'claude', 'Fix the login redirect')]);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  fake.emit(
    EventsResponse(
      chatId: 'c',
      seq: Int64(1),
      usage: Usage(
        contextUsed: Int64(37400),
        contextSize: Int64(1000000),
        cost: 0.42,
        currency: 'USD',
        inputTokens: Int64(950),
        outputTokens: Int64(210),
      ),
    ),
  );
  final side = ChatState('s', '/Users/me/nushi')
    ..agent = 'claude'
    ..loaded = true;
  d.sides['s'] = side;
  d.chats['c']!
    ..sideHidden.value = hidden
    ..side.value = side;
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
  await tester.pumpAndSettle();
  return (d, fake, side);
}

/// The side chat reports [used] of 200k tokens, and [spent] dollars.
Future<void> _report(
  WidgetTester tester,
  FakeDaemon fake,
  int seq,
  int used,
  double spent,
) async {
  fake.emit(
    EventsResponse(
      chatId: 's',
      seq: Int64(seq),
      usage: Usage(
        contextUsed: Int64(used),
        contextSize: Int64(200000),
        cost: spent,
        currency: 'USD',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _context => find.byType(DetailsPanel);

/// The Context widget's "Side chat" line, which only it says in the panel.
Finder get _label =>
    find.descendant(of: _context, matching: find.text('Side chat'));

/// What the side chat's line shows: the text of its value.
Finder _says(String text) => find.descendant(
  of: find.ancestor(of: _label, matching: find.byType(Row)).first,
  matching: find.text(text),
);

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  for (final hidden in [false, true]) {
    final state = hidden ? 'hidden' : 'shown';
    testWidgets("the side chat, $state, has its own line under the chat's, "
        'not reported until it is', (tester) async {
      final (d, fake, _) = await _app(tester, hidden: hidden);
      expect(_label, findsOne);
      expect(_says('Not reported yet'), findsOne);
      // The chat's line stays its own.
      expect(find.text(r'$0.42'), findsOne);
      expect(find.text('4% used'), findsOne);
      expect(
        tester.getTopLeft(_label).dy,
        greaterThan(tester.getTopLeft(find.text(r'$0.42')).dy),
      );
      expect(find.byType(ContextMeter), findsNothing); // open: no summary
      await _report(tester, fake, 1, 24000, 0.03);
      expect(_says('Not reported yet'), findsNothing);
      expect(_says('12%'), findsOne);
      expect(_says(r'$0.03'), findsOne);
      expect(find.byType(ContextMeter), findsOne);
      expect(find.text(r'$0.42'), findsOne);
      await closeView(tester, d);
    }, variant: _mac);
  }

  testWidgets("it follows the side chat's usage live", (tester) async {
    final (d, fake, _) = await _app(tester);
    await _report(tester, fake, 1, 24000, 0.03);
    expect(_says('12%'), findsOne);
    await _report(tester, fake, 2, 150000, 0.11);
    expect(_says('75%'), findsOne);
    expect(_says(r'$0.11'), findsOne);
    expect(_says(r'$0.03'), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('its line goes when the side chat ends', (tester) async {
    final (d, fake, _) = await _app(tester);
    await _report(tester, fake, 1, 24000, 0.03);
    expect(_label, findsOne);
    d.closeSide(d.chats['c']!);
    await tester.pumpAndSettle();
    expect(_label, findsNothing);
    expect(find.byType(ContextMeter), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('and when the daemon ends it (a reload, a move), hidden', (
    tester,
  ) async {
    final (d, fake, _) = await _app(tester, hidden: true);
    expect(_label, findsOne);
    fake.emit(EventsResponse(chatId: 's', removed: true));
    await tester.pumpAndSettle();
    expect(_label, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  // Both lines, as the window shows them: wide with the side chat beside
  // the chat; narrow with it hidden, where the details panel doesn't fit
  // (the window shows the chat, the side chat's chip in its header).
  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final (size, width, hidden) in [
      ('wide', 1700.0, false),
      ('narrow', 720.0, true),
    ]) {
      testWidgets('both lines, $size, $name', (tester) async {
        final (d, fake, _) = await _app(
          tester,
          hidden: hidden,
          size: Size(width, 760),
          brightness: brightness,
        );
        await _report(tester, fake, 1, 24000, 0.03);
        if (size == 'wide') {
          final panel = tester.getRect(_context);
          expect(panel.right, width);
          // The line's meter, then its cost at the panel's right.
          final meter = tester.getRect(find.byType(ContextMeter));
          final spent = tester.getRect(_says(r'$0.03'));
          expect(meter.right, lessThan(spent.left));
          expect(spent.right, lessThanOrEqualTo(panel.right));
          expect(spent.right, greaterThan(panel.right - 30));
          await expectLater(
            _context,
            matchesGoldenFile('goldens/side_usage_panel_$name.png'),
          );
        } else {
          expect(_context, findsNothing);
          expect(find.byType(SideChip), findsOne);
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/side_usage_${size}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
