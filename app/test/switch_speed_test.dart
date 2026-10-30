import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';

/// The app on two long chats (about 300 items each), Alpha shown.
Future<Daemon> _twoLongChats(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
}) async {
  viewport(tester, Size(width, 1000), brightness: brightness);
  showDetails.value = true;
  final a = chat('a', 'claude', 'Alpha long chat');
  final b = chat('b', 'claude', 'Beta long chat', age: 5);
  final items = {'a': longChat('a'), 'b': longChat('b')};
  final fake = FakeDaemon([a, b])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(
            chat: input.chatId == 'a' ? a : b,
            items: items[input.chatId],
          )
        : null;
  final d = await fake.connect(tester);
  d.select('a');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Finder _row(String title) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(title));

/// The fill of [title]'s row in the sidebar.
Color? _rowColor(WidgetTester tester, String title) {
  final tap = find.ancestor(of: _row(title), matching: find.byType(Tap));
  final box = tester.widget<Container>(
    find.descendant(of: tap.first, matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color;
}

int _items() => find.byType(ItemView, skipOffstage: false).evaluate().length;

void main() {
  setUpAll(loadFonts);

  testWidgets('a long chat opens on its last entries, its header and row '
      'at once; the rest fills in over the next frames', (tester) async {
    final d = await _twoLongChats(tester);
    final all = _items();
    expect(all, 81, reason: 'every message of Alpha, once filled in');

    await tester.tap(_row('Beta long chat'));
    await tester.pump();
    final t = NushiTheme.of(tester.element(find.byType(Sidebar))).t;
    expect(_rowColor(tester, 'Beta long chat'), t.selected);
    expect(
      find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text('Beta long chat'),
      ),
      findsOneWidget,
    );
    expect(_items(), lessThanOrEqualTo(Transcript.firstEntries));

    // Each frame after it adds a bounded number, until all of it is there.
    var was = _items();
    while (true) {
      await tester.pump();
      final now = _items();
      expect(now - was, lessThanOrEqualTo(Transcript.moreEntries));
      if (now == was) break;
      was = now;
    }
    expect(_items(), all);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a row shows the press as the pointer goes down, before the '
      'click ends', (tester) async {
    final d = await _twoLongChats(tester);
    final t = NushiTheme.of(tester.element(find.byType(Sidebar))).t;
    final press = await tester.startGesture(
      tester.getCenter(_row('Beta long chat')),
    );
    await tester.pump();
    expect(_rowColor(tester, 'Beta long chat'), t.pressed);
    expect(d.selectedId, 'a', reason: 'it opens on the click');
    await press.up();
    await tester.pump();
    expect(d.selectedId, 'b');
    expect(_rowColor(tester, 'Beta long chat'), t.selected);
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final width in [1700.0, 720.0]) {
      testWidgets('golden, a row pressed, $name, ${width.toInt()} wide', (
        tester,
      ) async {
        final d = await _twoLongChats(
          tester,
          width: width,
          brightness: brightness,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        final press = await tester.startGesture(
          tester.getCenter(_row('Beta long chat')),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile(
            'goldens/switch_pressed_${name}_${width.toInt()}.png',
          ),
        );
        await press.up();
        await tester.pumpAndSettle();
        await closeView(tester, d);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  }

  testWidgets('scrolled up while it fills in, what shows stays put', (
    tester,
  ) async {
    final d = await _twoLongChats(tester);
    await tester.tap(_row('Beta long chat'));
    await tester.pump();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 120),
    );
    await tester.pump();
    final reply = find.textContaining('What turn 26 found', findRichText: true);
    final y = tester.getTopLeft(reply).dy;
    await tester.pumpAndSettle();
    expect(_items(), 81);
    expect(tester.getTopLeft(reply).dy, moreOrLessEquals(y, epsilon: 1));
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
