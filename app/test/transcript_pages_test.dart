// A long chat on the Mac (ADR 0026): it opens with its recent part, takes
// the page before as it scrolls near the top with what shows kept still,
// pages to its start, says when a page failed; a pin, ⌘F and the rewind
// list reach what isn't loaded; the scrollbar runs the pane's height.
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/message_pins.dart';
import 'package:nushi/pins_rail.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/scrollbar.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/transcript_pages.dart';
import 'package:nushi/turn_status.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';
import 'paged_chat.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The window on chat c: [turns] turns of a long chat (about 11 items
/// each), its messages [pins] pinned.
Future<(Daemon, PagedChat)> _window(
  WidgetTester tester, {
  int turns = 100,
  Size size = const Size(1400, 900),
  Brightness brightness = Brightness.dark,
  List<String> pins = const [],
  bool busy = false,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'A long chat', status: ChatStatus(busy: busy))
    ..pinnedMessages.addAll(pins)
    ..messagePins.addAll([
      for (final id in pins) MessagePin(itemId: id, title: 'Pin $id'),
    ]);
  final paged = PagedChat(c, longChat('c', turns: turns));
  final fake = FakeDaemon([c])..answer = paged.answer;
  _fakes[tester] = fake;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await _settle(tester);
  return (d, paged);
}

final _fakes = Expando<FakeDaemon>();

/// Frames until nothing moves; a spinner that turns doesn't settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The transcript's scroll.
ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// The first message or step whose top shows in the transcript.
Element _firstShown(WidgetTester tester) {
  final top = tester.getRect(find.byType(SelectionArea)).top;
  return find
      .byType(ItemView)
      .evaluate()
      .firstWhere(
        (e) =>
            tester.getRect(find.byElementPredicate((x) => x == e)).top >= top,
      );
}

double _topOf(WidgetTester tester, Element e) =>
    tester.getRect(find.byElementPredicate((x) => x == e)).top;

/// Scrolls up by a wheel's [by], as the user does.
Future<void> _wheel(WidgetTester tester, double by) async {
  final at = tester.getCenter(find.byType(SelectionArea));
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(at));
  await tester.sendEventToBinding(mouse.scroll(Offset(0, -by)));
  await tester.pump();
}

/// Up to near the top, the way a wheel goes: a page is asked for there.
Future<void> _toTop(WidgetTester tester) async {
  final p = _scroll(tester);
  p.jumpTo(p.viewportDimension * 1.5);
  await tester.pump();
  await _wheel(tester, p.viewportDimension);
}

ChatState _chat(Daemon d) => d.chats['c']!;

void main() {
  setUpAll(loadFonts);

  testWidgets('a long chat opens with its recent part only, at its bottom', (
    tester,
  ) async {
    final (d, paged) = await _window(tester);
    expect(paged.items.length, greaterThan(1000));
    final asked = paged.asked.whereType<GetChatRequest>().single;
    expect(asked.recent, Daemon.macRecentItems);
    final c = _chat(d);
    expect(c.items.length, lessThan(Daemon.macRecentItems + 10));
    expect(c.older, paged.items.length - c.items.length);
    expect(paged.pages, isEmpty, reason: 'no page until it scrolls up');
    final p = _scroll(tester);
    expect(p.pixels, p.maxScrollExtent);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('near the top the page before comes under a spinner, and '
      'what shows stays where it was in every frame it fills in', (
    tester,
  ) async {
    final (d, paged) = await _window(tester);
    final hold = paged.hold = Completer<void>();
    await _toTop(tester);
    expect(paged.pages.length, 1);
    expect(paged.pages.single.before, _chat(d).items.first.id);
    expect(
      find.descendant(
        of: find.byType(EarlierMessages),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 100));
    final seen = _firstShown(tester);
    final y = _topOf(tester, seen);
    final thumb = _scroll(tester).maxScrollExtent;
    // After layout and paint, in each frame the page fills in.
    final tops = <double>[];
    var watching = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (watching) tops.add(_topOf(tester, seen));
    });
    paged.hold = null;
    hold.complete();
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    watching = false;
    expect(tops.length, greaterThan(2));
    expect(tops, everyElement(moreOrLessEquals(y, epsilon: 1)));
    expect(
      _scroll(tester).maxScrollExtent,
      greaterThan(thumb),
      reason: 'the page is above: the list is longer, its thumb shorter',
    );
    expect(_chat(d).older, lessThan(paged.items.length - 200));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('page by page to the start, where no spinner shows', (
    tester,
  ) async {
    final (d, paged) = await _window(tester, turns: 60);
    for (var i = 0; i < 10 && _chat(d).older > 0; i++) {
      await _toTop(tester);
      await _settle(tester);
    }
    expect(_chat(d).older, 0);
    expect(_chat(d).items.length, paged.items.length);
    expect(paged.pages.length, greaterThan(1));
    expect(find.byType(EarlierMessages), findsNothing);
    _scroll(tester).jumpTo(0);
    await tester.pump();
    expect(find.textContaining('Turn 0:', findRichText: true), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a failed page says so and asks no more until Try again', (
    tester,
  ) async {
    final (d, paged) = await _window(tester);
    paged.fail = true;
    await _toTop(tester);
    await _settle(tester);
    expect(find.text('Couldn’t load earlier messages · '), findsOneWidget);
    expect(_chat(d).olderFailed, isTrue);
    final asked = paged.pages.length;
    await _wheel(tester, 200);
    await _settle(tester);
    expect(paged.pages.length, asked, reason: 'not again on its own');
    paged.fail = false;
    _scroll(tester).jumpTo(0);
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await _settle(tester);
    expect(paged.pages.length, asked + 1);
    expect(find.text('Couldn’t load earlier messages · '), findsNothing);
    expect(_chat(d).olderFailed, isFalse);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a pin on a message not loaded yet goes there', (tester) async {
    final (d, paged) = await _window(tester, pins: ['c-a2']);
    expect(_chat(d).items.any((it) => it.id == 'c-a2'), isFalse);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(900, 600));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(
      tester.getCenter(
        find
            .descendant(
              of: find.byType(PinsRail),
              matching: find.byType(PinDash),
            )
            .first,
      ),
    );
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(PinsRail),
        matching: find.text('Pin c-a2'),
      ),
    );
    await _settle(tester);
    expect(_chat(d).items.any((it) => it.id == 'c-a2'), isTrue);
    expect(
      paged.pages.where((p) => p.limit == 500),
      isNotEmpty,
      reason: 'the pages up to it, in as few calls as the daemon allows',
    );
    final list = tester.getRect(find.byType(SelectionArea));
    final at = tester.getRect(
      find.textContaining('What turn 2 found', findRichText: true).first,
    );
    expect(at.top - list.top, inInclusiveRange(0, 80));
    final flash = tester.widget<PinFlash>(
      find.ancestor(
        of: find.textContaining('What turn 2 found', findRichText: true).first,
        matching: find.byType(PinFlash),
      ),
    );
    expect(flash.on, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('going to several messages pages only for those not loaded', (
    tester,
  ) async {
    final (d, paged) = await _window(tester);
    final c = _chat(d);
    expect(c.items.any((it) => it.id == 'c-a99'), isTrue);
    await d.loadOlder(c, through: ['c-a99', 'c-a80']);
    expect(c.items.any((it) => it.id == 'c-a80'), isTrue);
    expect(paged.pages.length, 1);
    expect(c.older, greaterThan(0), reason: 'not to the start');
    // Two at once: one after the other, the second with nothing to take.
    final first = d.loadOlder(c, through: ['c-a20']);
    final second = d.loadOlder(c, through: ['c-a20']);
    await Future.wait([first, second]);
    expect(paged.pages.length, 2);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⌘F says it looks in what’s loaded; Load all takes the rest '
      'and finds there', (tester) async {
    final (d, _) = await _window(tester);
    final c = _chat(d);
    c.find
      ..open()
      ..query = 'Turn 3:';
    await _settle(tester);
    expect(find.text('Searching loaded messages · '), findsOneWidget);
    expect(c.find.count, 'None');
    expect(
      tester.getRect(find.byType(FindBar)).bottom -
          tester.getRect(find.byType(SelectionArea)).top,
      lessThanOrEqualTo(FindBar.withNote),
      reason: 'what the transcript keeps clear of it',
    );
    await tester.tap(find.text('Load all'));
    await _settle(tester);
    expect(c.older, 0);
    expect(find.text('Searching loaded messages · '), findsNothing);
    expect(c.find.count, '1 of 1');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('at the bottom while a page comes in above, it follows what '
      'streams in', (tester) async {
    final (d, paged) = await _window(tester, busy: true);
    final c = _chat(d);
    final hold = paged.hold = Completer<void>();
    final load = d.loadOlder(c);
    await tester.pump();
    final painted = <double>[];
    var watching = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (!watching) return;
      final p = _scroll(tester);
      painted.add(p.maxScrollExtent - p.pixels);
    });
    final last = c.items.last;
    var seq = 1;
    Future<void> chunk() async {
      _fakes[tester]!.emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(seq++),
          item: ItemEvent(
            item: Item(id: last.id, text: '\n\nAnd one more line.'),
            index: paged.items.length - 1,
            append: true,
          ),
        ),
      );
      await tester.pump();
    }

    await chunk();
    paged.hold = null;
    hold.complete();
    await load;
    for (var i = 0; i < 8; i++) {
      await chunk();
    }
    watching = false;
    expect(c.older, lessThan(paged.items.length - 200), reason: 'it came');
    expect(painted, everyElement(moreOrLessEquals(0)));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the rewind list takes every page into the list, not the '
      'transcript, and lists the first message', (tester) async {
    final (d, paged) = await _window(tester, turns: 60);
    final c = _chat(d)..canRewind = true;
    for (final it in paged.items) {
      if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE) it.rewindable = true;
    }
    final older = c.older;
    unawaited(pickRewind(tester.element(find.byType(ChatView)), d, c));
    await _settle(tester);
    expect(c.older, older, reason: 'the transcript lays out none of them');
    expect(paged.pages, isNotEmpty);
    final rows = find.descendant(
      of: find.byType(RewindPicker),
      matching: find.textContaining('Turn '),
    );
    expect(rows, findsNWidgets(60));
    expect(
      tester.widget<Text>(rows.last).data,
      startsWith('Turn 0:'),
      reason: 'the oldest last',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('left at its bottom a chat goes back to its recent part; '
      'left scrolled up it keeps what it loaded', (tester) async {
    viewport(tester, const Size(1400, 900));
    showDetails.value = false;
    final paged = PagedChat(
      chat('c', 'claude', 'A long chat'),
      longChat('c', turns: 100),
    );
    final other = chat('s', 'claude', 'Short', age: 5);
    final fake = FakeDaemon([paged.chat, other])
      ..answer = (input) =>
          paged.answer(input) ??
          (input is GetChatRequest
              ? GetChatResponse(chat: other, items: longChat('s', turns: 1))
              : null);
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await _settle(tester);
    final c = _chat(d);
    final recent = c.items.length;
    await d.loadOlder(c);
    await _settle(tester);
    expect(c.items.length, greaterThan(recent));
    // At its bottom, following it: let go of all but the recent part.
    d.select('s');
    await _settle(tester);
    expect(c.items.length, recent);
    expect(c.older, paged.items.length - recent);
    // Scrolled up: kept, and it opens where it was.
    d.select('c');
    await _settle(tester);
    await _toTop(tester);
    await _settle(tester);
    final had = c.items.length;
    expect(had, greaterThan(recent));
    d.select('s');
    await _settle(tester);
    expect(c.items.length, had);
    expect(c.kept, isNotNull);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('what a chat let go scrolled up kept is taken back once, not '
      'on every reload after', (tester) async {
    final (d, paged) = await _window(tester);
    final c = _chat(d)..keptItems = 500;
    c.stale!();
    await _settle(tester);
    expect(paged.asked.whereType<GetChatRequest>().last.recent, 500);
    expect(c.keptItems, 0);
    final had = c.items.length;
    c.stale!();
    await _settle(tester);
    expect(paged.asked.whereType<GetChatRequest>().last.recent, had);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('Rewind… in a long chat is offered only when the chat may '
      'rewind now', (tester) async {
    final (d, _) = await _window(tester);
    final c = _chat(d)..canRewind = true;
    expect(c.older, greaterThan(0));
    bool rewind() => appActions(
      tester.element(find.byType(ChatView)),
      d,
    ).firstWhere((a) => a.act == Act.rewind).enabled;
    expect(rewind(), isTrue);
    c.busy = true;
    expect(rewind(), isFalse, reason: 'a turn runs');
    c
      ..busy = false
      ..archived = true;
    expect(rewind(), isFalse, reason: 'archived');
    c
      ..archived = false
      ..canRewind = false;
    expect(rewind(), isFalse, reason: "the agent can't rewind");
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('taken again (the daemon restarted), it takes as much as it '
      'had', (tester) async {
    final (d, paged) = await _window(tester);
    final c = _chat(d);
    await d.loadOlder(c);
    await _settle(tester);
    final had = c.items.length;
    // As the events' stream starting again does (Daemon._listChats), or an
    // event past what it has: unloaded, and loaded again.
    c.stale!();
    await _settle(tester);
    final again = paged.asked.whereType<GetChatRequest>().last;
    expect(paged.asked.whereType<GetChatRequest>().length, 2);
    expect(again.recent, had);
    expect(c.items.length, had);
    await closeView(tester, d);
  }, variant: _mac);

  for (final width in [1700.0, 720.0]) {
    testWidgets('the scrollbar runs down past the composer to the pane’s '
        'bottom, $width wide; the last message clears the composer', (
      tester,
    ) async {
      final (d, _) = await _window(tester, size: Size(width, 900));
      final pane = tester.getRect(find.byType(ChatView));
      // The transcript's, over the composer too.
      final bar = find
          .descendant(
            of: find.ancestor(
              of: find.byType(Composer),
              matching: find.byType(OverBottom),
            ),
            matching: find.byType(MacScrollbar),
          )
          .first;
      // Its only one: the list draws none of its own under it.
      final list = find
          .descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        find.ancestor(of: list, matching: find.byType(MacScrollbar)),
        findsOneWidget,
      );
      expect(tester.getRect(bar).bottom, pane.bottom);
      expect(tester.getRect(bar).right, pane.right);
      // At the end, the thumb sits at the bottom, beside the composer's row.
      final painter =
          tester
                  .widgetList<CustomPaint>(
                    find.descendant(
                      of: bar,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .first
                  .foregroundPainter!
              as ScrollbarPainter;
      final box = tester.getRect(bar);
      // Shown: the pointer near its bottom.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: box.center);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(box.bottomRight - const Offset(4, 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        painter.hitTestOnlyThumbInteractive(
          Offset(box.width - 6, box.height - 8),
          PointerDeviceKind.mouse,
        ),
        isTrue,
      );
      final words = tester.getRect(
        find
            .textContaining('Want me to look at the logout', findRichText: true)
            .last,
      );
      final status = tester.getRect(find.byType(TurnStatus));
      expect(words.bottom, lessThanOrEqualTo(status.top));
      expect(
        tester.getRect(find.byType(Composer)).top,
        greaterThanOrEqualTo(status.bottom),
      );
      await closeView(tester, d);
    }, variant: _mac);
  }

  for (final b in Brightness.values) {
    for (final width in [1700.0, 720.0]) {
      testWidgets('renders: the top with its spinner, mid-chat, the bottom '
          '(${b.name}, $width)', (tester) async {
        final (d, paged) = await _window(
          tester,
          size: Size(width, 1000),
          brightness: b,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset(width / 2, 500));
        addTearDown(mouse.removePointer);
        // The bottom, the pointer near the scrollbar.
        await mouse.moveTo(Offset(width - 4, 900));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await render(
          tester,
          find.byType(NushiApp),
          'pages_bottom_${b.name}_$width',
        );
        // Mid-chat.
        await mouse.moveTo(Offset(width / 2, 500));
        _scroll(tester).jumpTo(_scroll(tester).maxScrollExtent / 2);
        await tester.pump();
        await mouse.moveTo(Offset(width - 4, 500));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await render(
          tester,
          find.byType(NushiApp),
          'pages_mid_${b.name}_$width',
        );
        // The top, its page on its way.
        paged.hold = Completer<void>();
        await _toTop(tester);
        _scroll(tester).jumpTo(0);
        await tester.pump(const Duration(milliseconds: 300));
        await render(
          tester,
          find.byType(NushiApp),
          'pages_top_${b.name}_$width',
        );
        // The top once a page failed.
        paged.fail = true;
        paged.hold!.complete();
        paged.hold = null;
        await _settle(tester);
        _scroll(tester).jumpTo(0);
        await tester.pump();
        expect(find.text('Try again'), findsOneWidget);
        await render(
          tester,
          find.byType(NushiApp),
          'pages_failed_${b.name}_$width',
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
