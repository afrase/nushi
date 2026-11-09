import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/markdown_outline.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/rail_menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _go = 'somewhere to go when a heading is picked from the outline.';

/// A section's words: enough lines to scroll past.
String _words(String name) => [
  for (var i = 1; i <= 6; i++)
    'The $name section runs on for a while, line $i, so the view has $_go',
].join('\n\n');

/// A roadmap, as the screenshots' is: a title, sections and their parts.
final String _roadmap = [
  '# Roadmap',
  _words('opening'),
  '## Plans',
  '### The app',
  _words('app'),
  '### Previews',
  _words('previews'),
  '### Changes and review',
  _words('changes'),
  '### GitHub',
  _words('GitHub'),
  '## Decisions to revisit',
  _words('decisions'),
].join('\n\n');

const _flat = '# Notes\n\nNo other heading here, so no outline.\n';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The daemon: a chat whose folder holds `docs/roadmap.md` and
/// `docs/notes.md`; any other file is the notes' text.
FakeDaemon _fake() {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Plan the work', folder: '/Users/me/kettle');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Plan.'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      final text = input.path.endsWith('roadmap.md') ? _roadmap : _flat;
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: input.path.startsWith('/')
              ? input.path
              : '/Users/me/kettle/${input.path}',
          data: utf8.encode(text),
          size: Int64(text.length),
        ),
      );
      return s.stream;
    };
}

/// The app on the chat, [file] in the preview.
Future<Daemon> _app(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
  String file = 'docs/roadmap.md',
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  final d = await _fake().connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  d.chats['c']!.openPreview(file);
  await tester.pumpAndSettle();
  return d;
}

Finder _inPane(Finder f) =>
    find.descendant(of: find.byType(PreviewPane), matching: f);

Finder get _rail => find.byType(Rail);

/// The rail's current entry.
int _current(WidgetTester tester) => tester.widget<Rail>(_rail).current.value;

ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(OutlinedMarkdown),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// The pointer, a mouse's, over the rail.
Future<TestGesture> _hover(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getTopLeft(_rail) + const Offset(20, 14));
  await tester.pumpAndSettle();
  return mouse;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('no outline over the source', (tester) async {
    final d = await _app(tester);
    expect(_rail, findsOneWidget);
    await tester.tap(_inPane(find.byType(SourceButton)));
    await tester.pumpAndSettle();
    expect(_rail, findsNothing);
    await tester.tap(_inPane(find.byType(SourceButton)));
    await tester.pumpAndSettle();
    expect(_rail, findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the rail: a dash per heading, the current one following '
      'the scroll', (tester) async {
    final d = await _app(tester);
    final rail = tester.widget<Rail>(_rail);
    expect(
      [for (final e in rail.entries) (e.title, e.depth)],
      [
        // A lone title stands with the sections under it, as Claude's.
        ('Roadmap', 0),
        ('Plans', 0),
        ('The app', 1),
        ('Previews', 1),
        ('Changes and review', 1),
        ('GitHub', 1),
        ('Decisions to revisit', 0),
      ],
    );
    expect(rail.outline, isTrue);
    expect(_current(tester), 0);
    final scroll = _scroll(tester);
    // A heading at the view's top is the current one.
    final previews = tester.getTopLeft(
      _inPane(find.textContaining('Previews', findRichText: true)).first,
    );
    final top = tester.getTopLeft(find.byType(OutlinedMarkdown));
    scroll.jumpTo(previews.dy - top.dy - 10);
    await tester.pumpAndSettle();
    expect(_current(tester), 3);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_current(tester), 0);
    // The rail stays put as the text scrolls, left of it.
    final dash = tester.getRect(find.byType(RailDash).first);
    final text = tester.getRect(
      _inPane(find.textContaining('Roadmap', findRichText: true)).first,
    );
    expect(dash.right, lessThan(text.left - RailFit.gap + 0.5));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('hovering the rail lists the headings; a click scrolls there '
      'and leaving closes it', (tester) async {
    final d = await _app(tester);
    expect(find.byType(RailMenu), findsNothing);
    final mouse = await _hover(tester);
    expect(find.byType(RailMenu), findsOneWidget);
    final menu = find.byType(RailMenu);
    expect(
      find.descendant(of: menu, matching: find.text('Changes and review')),
      findsOneWidget,
    );
    // Indented by its level.
    final plans = tester.getTopLeft(
      find.descendant(of: menu, matching: find.text('Plans')),
    );
    final app = tester.getTopLeft(
      find.descendant(of: menu, matching: find.text('The app')),
    );
    expect(app.dx, greaterThan(plans.dx));
    await mouse.moveTo(
      tester.getCenter(
        find.descendant(of: menu, matching: find.text('Previews')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: menu, matching: find.text('Previews')),
    );
    await tester.pumpAndSettle();
    expect(_current(tester), 3);
    expect(_scroll(tester).pixels, greaterThan(0));
    final heading = tester.getTopLeft(
      _inPane(find.textContaining('Previews', findRichText: true)).first,
    );
    // At the view's top, where the first heading was.
    final view = tester.getTopLeft(find.byType(OutlinedMarkdown));
    expect(heading.dy - view.dy, inInclusiveRange(18, 30));
    await mouse.moveTo(tester.getCenter(find.byType(PreviewBody)));
    await tester.pump(Rail.linger);
    await tester.pumpAndSettle();
    expect(find.byType(RailMenu), findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('under Reduce Motion a pick goes there at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final d = await _app(tester);
    final mouse = await _hover(tester);
    await mouse.moveTo(
      tester.getCenter(
        find.descendant(
          of: find.byType(RailMenu),
          matching: find.text('Decisions to revisit'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(RailMenu),
        matching: find.text('Decisions to revisit'),
      ),
    );
    await tester.pump();
    final scroll = _scroll(tester);
    expect(scroll.pixels, scroll.maxScrollExtent);
    // The last heading, though it can't reach the top.
    expect(_current(tester), 6);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('no rail with fewer than two headings', (tester) async {
    final d = await _app(tester, file: 'docs/notes.md');
    expect(
      _inPane(find.textContaining('No other heading', findRichText: true)),
      findsOneWidget,
    );
    expect(_rail, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('narrow, the rail keeps the text its room', (tester) async {
    final d = await _app(tester);
    paneWidths.value = {'preview': 400};
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PreviewPane)).width, 400);
    final dash = tester.getRect(find.byType(RailDash).first);
    final text = tester.getRect(
      _inPane(find.textContaining('Roadmap', findRichText: true)).first,
    );
    final pane = tester.getRect(find.byType(PreviewPane));
    expect(text.left - pane.left, lessThanOrEqualTo(40));
    expect(dash.right, lessThanOrEqualTo(text.left - RailFit.gap + 0.5));
    expect(tester.takeException(), isNull);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('golden: the rail and its menu, $name', (tester) async {
      final d = await _app(tester, width: 1200, brightness: brightness);
      await expectLater(
        find.byType(PreviewPane),
        matchesGoldenFile('goldens/markdown_outline_$name.png'),
      );
      await closeView(tester, d);
      // The rail on its own, its menu open, a row under the pointer.
      viewport(tester, const Size(360, 300), brightness: brightness);
      final current = ValueNotifier(3);
      addTearDown(current.dispose);
      final theme = NushiTheme(
        brightness == Brightness.dark ? Tokens.dark : Tokens.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey(#host),
          debugShowCheckedModeBanner: false,
          theme: theme.toThemeData(),
          home: Scaffold(
            backgroundColor: theme.t.base,
            body: Align(
              alignment: Alignment.topLeft,
              child: Rail(
                label: 'Outline',
                outline: true,
                entries: const [
                  RailEntry('0', 'Roadmap'),
                  RailEntry('1', 'Plans'),
                  RailEntry('2', 'The app', depth: 1),
                  RailEntry('3', 'Previews', depth: 1),
                  RailEntry('4', 'A part of it', depth: 2),
                  RailEntry('5', 'Decisions to revisit'),
                ],
                current: current,
                fit: RailFit.of(55),
                onPick: (_) {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey(#host)),
        matchesGoldenFile('goldens/markdown_outline_rail_$name.png'),
      );
      final mouse = await _hover(tester);
      await mouse.moveTo(tester.getCenter(find.text('The app')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey(#host)),
        matchesGoldenFile('goldens/markdown_outline_menu_$name.png'),
      );
    }, variant: _mac);

    for (final width in [1700.0, 720.0]) {
      testWidgets('renders: the outline, ${width.toInt()} wide, $name', (
        tester,
      ) async {
        final d = await _app(tester, width: width, brightness: brightness);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'outline_${width.toInt()}_$name',
        );
        await _hover(tester);
        await render(
          tester,
          find.byType(NushiApp),
          'outline_${width.toInt()}_menu_$name',
        );
        await closeView(tester, d);
      }, variant: _mac);
    }

    testWidgets('the phone: the path line, and a tap on the rail lists the '
        'headings, $name', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 3, brightness: brightness);
      final phone = Phone(
        PhonePlatform()..saved = pairedRecord(),
        connectTo: (_) => Daemon(transport: _fake(), remote: true),
      );
      await tester.pumpWidget(PhoneApp(phone));
      await phone.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('Plan the work'));
      await tester.pumpAndSettle();
      PreviewScreen.open(
        tester.element(find.byType(Navigator).first),
        phone.daemon!,
        phone.daemon!.chats['c']!,
        'docs/roadmap.md',
      );
      await tester.pumpAndSettle();
      expect(find.text('docs / roadmap.md'), findsOneWidget);
      expect(find.byType(SourceButton), findsOneWidget);
      expect(find.byType(Rail), findsOneWidget);
      expect(tester.takeException(), isNull);
      await render(tester, find.byType(PhoneApp), 'outline_phone_$name');
      await tester.tap(find.byType(Rail));
      await tester.pumpAndSettle();
      expect(find.byType(RailMenu), findsOneWidget);
      await render(tester, find.byType(PhoneApp), 'outline_phone_menu_$name');
      await tester.tap(
        find.descendant(
          of: find.byType(RailMenu),
          matching: find.text('Decisions to revisit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RailMenu), findsNothing);
      expect(tester.widget<Rail>(find.byType(Rail)).current.value, 6);
      await endPhone(tester, phone);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
