import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_text.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _long =
    'The redirect read the session after it expired, so the login page sent '
    'people back to a page that sent them to the login page again. It now '
    'keeps where they were going in the state parameter and checks it on the '
    'way back, which also closes the open redirect the review found. The '
    'admin filters had the same shape of bug: a query parameter that was '
    'trusted to be a hash and then read as one. Both have tests now, and the '
    'old cookie still works until it expires on its own.';

Item _tool(
  String id,
  String kind,
  String title, {
  String status = 'completed',
  List<String> paths = const [],
  String text = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: title,
  status: status,
  paths: paths,
  text: text,
);

/// A real turn's shape: what was asked, a run of calls, a failed one, a
/// finished one, a running one with its ask for permission, and the answer.
final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Fix the login redirect after the session expires, and add a test.',
  ),
  Item(
    id: 'm1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'I’ll start from where the session is read.',
  ),
  _tool('t1', 'read', 'Read', paths: ['app/session.go']),
  _tool('t2', 'search', 'Search for redirect'),
  _tool('t3', 'read', 'Read', paths: ['app/login.go']),
  Item(id: 'm2', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: _long),
  _tool(
    't4',
    'execute',
    'go test ./app/...',
    status: 'failed',
    text: 'exit status 1',
  ),
  Item(
    id: 'm3',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'That one was mine: the fixture’s cookie had expired.',
  ),
  _tool('t5', 'edit', 'Edit', paths: ['docs/login-report.md']),
  Item(
    id: 'u2',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Good. Run the whole suite.',
  ),
  _tool('t6', 'execute', 'make check', status: 'in_progress'),
  Item(
    id: 'p',
    kind: ItemKind.ITEM_KIND_PERMISSION,
    title: 'make check',
    status: 'pending',
    options: [
      Option(id: 'y', name: 'Allow once'),
      Option(id: 'n', name: 'Reject'),
    ],
  ),
];

/// The app on a chat with [_items], its preview open with [file].
Future<Daemon> _app(
  WidgetTester tester, {
  required double width,
  Brightness? brightness,
  double height = 1000,
  String? file,
}) async {
  viewport(tester, Size(width, height), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  final c = chat('c', 'claude', 'Fix the login redirect after it expires');
  final fake = FakeDaemon([c])
    ..answer = ((input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: _items)
        : null)
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      const text = '# The report\n\nAll well here.\n';
      final s = StreamController<WatchChatFileResponse>();
      addTearDown(s.close);
      s.add(
        WatchChatFileResponse(
          path: '/Users/me/nushi/${input.path}',
          data: utf8.encode(text),
          size: Int64(text.length),
        ),
      );
      return s.stream;
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  if (file != null) {
    d.chats['c']!.openPreview(file);
    await tester.pumpAndSettle();
  }
  return d;
}

/// The composer's box.
Rect _box(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.byType(TextField),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius != null,
        ),
      )
      .first,
);

Rect _text(WidgetTester tester, String words) =>
    tester.getRect(find.textContaining(words, findRichText: true).first);

/// The fill of the row of [Collapsible] [at], and the color of its outline.
(Color, Color) _look(WidgetTester tester, Finder at) {
  final fill = tester
      .widgetList<ColoredBox>(
        find.descendant(of: at, matching: find.byType(ColoredBox)),
      )
      .first
      .color;
  final frame = tester
      .widgetList<Container>(
        find.descendant(of: at, matching: find.byType(Container)),
      )
      .first;
  final border = (frame.foregroundDecoration! as BoxDecoration).border!;
  return (fill, border.top.color);
}

void main() {
  setUpAll(loadFonts);

  group('the gutters', () {
    for (final width in [1700.0, 720.0]) {
      testWidgets('header, transcript and composer share them, '
          '${width.toInt()} wide', (tester) async {
        final d = await _app(tester, width: width);
        final view = tester.getRect(find.byType(ChatView));
        final box = _box(tester);
        expect(box.left, view.left + NushiTheme.gutter);
        // The transcript's cap on a wide window, the gutter on a narrow one.
        expect(
          box.right,
          min(
            view.left + NushiTheme.gutter + readableWidth,
            view.right - NushiTheme.gutter,
          ),
        );
        expect(
          _text(tester, 'I’ll start from').left,
          view.left + NushiTheme.gutter,
        );
        expect(
          tester
              .getRect(
                find.descendant(
                  of: find.byType(ChatHeader),
                  matching: find.text(d.chats['c']!.shownTitle),
                ),
              )
              .left,
          view.left + NushiTheme.gutter,
        );
        expect(
          tester.getRect(find.byTooltip('Chat menu')).right,
          view.right - NushiTheme.gutter,
        );
        // A band's text too, though its fill goes edge to edge.
        expect(
          _text(tester, 'Good. Run the whole suite.').left,
          view.left + NushiTheme.gutter,
        );
        await closeView(tester, d);
      }, variant: _mac);
    }

    testWidgets('a tool row’s chevron is on the gutter, its box round it', (
      tester,
    ) async {
      final d = await _app(tester, width: 1700);
      final view = tester.getRect(find.byType(ChatView));
      final failed = find.ancestor(
        of: find.textContaining('go test', findRichText: true).first,
        matching: find.byType(Collapsible),
      );
      expect(
        tester.getRect(failed).left,
        view.left + NushiTheme.gutter - Collapsible.inset,
      );
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('the header', () {
    testWidgets('44 high, the bar’s gaps with room, ⋯ and the tabs in place', (
      tester,
    ) async {
      final d = await _app(tester, width: 1700);
      final header = tester.getRect(find.byType(ChatHeader));
      expect(header.height, 44);
      final tabs = tester.getRect(find.byType(PlainTabs<ChatTab>));
      expect(tabs.bottom, header.bottom - 1);
      final terminal = tester.getRect(find.byType(TerminalButton));
      expect(terminal.left - tabs.right, NushiTheme.groupGap);
      final menu = tester.getRect(find.byTooltip('Chat menu'));
      final details = tester.getRect(find.byTooltip('Show details'));
      expect(details.left - terminal.right, NushiTheme.iconGap);
      expect(menu.left - details.right, NushiTheme.iconGap);
      await closeView(tester, d);
    }, variant: _mac);

    test('the bar’s gaps never fold anything', () {
      // Where each case first folded before them: 455 for the row, 80 for
      // the title, then what the case adds.
      for (final (pull, model, first) in [
        (false, false, 535.0),
        (true, false, 623.0),
        (false, true, 585.0),
        (true, true, 673.0),
      ]) {
        for (final panel in [false, true]) {
          HeaderFolds at(double width) =>
              headerFolds(width, pull: pull, panel: panel, model: model);
          expect(at(first).any, isFalse);
          expect(at(first - 1).any, isTrue);
          expect(at(first).roomy, isFalse);
          expect(at(first + headerGaps).roomy, isTrue);
          for (var w = 300.0; w < first; w += 5) {
            expect(at(w).roomy, isFalse, reason: 'folded at $w');
          }
        }
      }
    });
  });

  group('the composer', () {
    for (final width in [1700.0, 720.0]) {
      testWidgets('48 high, its footer 8 under it, 12 from the bottom, '
          '${width.toInt()} wide', (tester) async {
        final d = await _app(tester, width: width);
        final box = _box(tester);
        expect(box.height, closeTo(48, 0.5));
        final footer = tester.getRect(find.byType(Pickers));
        expect(footer.top - box.bottom, 8);
        expect(footer.left, box.left);
        expect(footer.right, box.right);
        expect(
          tester.getRect(find.byType(Composer)).bottom - footer.bottom,
          12,
        );
        final input = tester.getRect(find.byType(TextField));
        expect(input.left - box.left, greaterThanOrEqualTo(12));
        await closeView(tester, d);
      }, variant: _mac);
    }
  });

  group('the transcript', () {
    testWidgets('14 on 22, at most 860 wide at the left', (tester) async {
      final d = await _app(tester, width: 1700);
      final line = _text(tester, 'I’ll start from');
      expect(line.height, 22);
      final text = _text(tester, 'The redirect read the session');
      expect(text.width, lessThanOrEqualTo(860));
      expect(text.height % 22, 0);
      final view = tester.getRect(find.byType(ChatView));
      expect(text.left, view.left + NushiTheme.gutter);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('items 16 apart, 32 before a user message', (tester) async {
      final d = await _app(tester, width: 1700);
      final first = _text(tester, 'I’ll start from');
      final next = _text(tester, 'The redirect read the session');
      final run = tester.getRect(find.byType(RunView));
      expect(run.top - first.bottom, 16);
      expect(next.top - run.bottom, 16);
      final band = find
          .ancestor(
            of: find.textContaining('Good. Run the', findRichText: true),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.padding != null,
            ),
          )
          .last;
      final row = find.ancestor(
        of: find.textContaining('docs/login-report.md', findRichText: true),
        matching: find.byType(ToolCallView),
      );
      expect(tester.getRect(band).top - tester.getRect(row).bottom, 32);
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('tool rows', () {
    Finder call(String words) => find.ancestor(
      of: find.textContaining(words, findRichText: true).first,
      matching: find.byType(Collapsible),
    );

    testWidgets('no box until one fails, which keeps its row', (tester) async {
      final d = await _app(tester, width: 1700);
      final t = NushiTheme.of(tester.element(find.byType(ChatView))).t;
      for (final words in ['docs/login-report.md', 'make check']) {
        expect(_look(tester, call(words)), (
          Colors.transparent,
          Colors.transparent,
        ));
      }
      expect(_look(tester, call('go test')), (t.crashedSoft, t.crashed));
      final failed = call('go test');
      Finder inside(Finder f) => find.descendant(of: failed, matching: f);
      expect(inside(find.text('failed')), findsOneWidget);
      expect(inside(find.byIcon(Icons.terminal)), findsOneWidget);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('on the phone it’s still a card in the tool rows’ tint', (
      tester,
    ) async {
      viewport(tester, const Size(390, 200));
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: TouchTargets(
            child: Scaffold(
              body: ToolCallView(_tool('a', 'read', 'Read', paths: ['a.go'])),
            ),
          ),
        ),
      );
      const t = Tokens.dark;
      expect(_look(tester, find.byType(Collapsible)), (
        t.toolTint,
        t.toolBorder,
      ));
    }, variant: _mac);
  });

  group('the header’s drawn icons', () {
    for (final (name, tokens) in [
      ('dark', Tokens.dark),
      ('light', Tokens.light),
    ]) {
      testWidgets('close up, 2×, $name', (tester) async {
        viewport(tester, const Size(260, 44), ratio: 2);
        final t = tokens;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Scaffold(
              body: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: NushiTheme.iconGap,
                  children: [
                    IconTap.line(
                      LineIcon.terminal,
                      tooltip: 'Show terminal',
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.details,
                      tooltip: 'Show details',
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.details,
                      tooltip: 'Hide details',
                      color: t.text,
                      onTap: () {},
                    ),
                    IconTap(
                      Icons.more_horiz,
                      tooltip: 'Chat menu',
                      onTap: () {},
                    ),
                    const SizedBox(width: NushiTheme.groupGap),
                    IconTap.line(
                      LineIcon.folderOpen,
                      tooltip: 'Show in Finder',
                      size: 14,
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.close,
                      tooltip: 'Close',
                      size: 15,
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.close,
                      tooltip: 'Close tab',
                      size: 12,
                      padding: 3,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/header_icons_$name.png'),
        );
      }, variant: _mac);
    }

    testWidgets('the same room as a Material icon, and the look of its state', (
      tester,
    ) async {
      final d = await _app(tester, width: 1700);
      final t = NushiTheme.of(tester.element(find.byType(ChatView))).t;
      final terminal = find.byType(TerminalButton);
      final details = find.byTooltip('Show details');
      expect(tester.getSize(terminal), const Size(26, 26));
      expect(tester.getSize(details), const Size(26, 26));
      expect(
        find.descendant(of: terminal, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.descendant(of: details, matching: find.byType(CustomPaint)),
        findsWidgets,
      );
      showDetails.value = true;
      await tester.pumpAndSettle();
      final open = tester.widget<IconTap>(
        find
            .ancestor(
              of: find.byTooltip('Hide details'),
              matching: find.byType(IconTap),
            )
            .first,
      );
      expect(open.line, LineIcon.details);
      expect(open.color, t.text);
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('goldens', () {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      for (final width in [1700.0, 720.0]) {
        testWidgets('a turn, $name, ${width.toInt()} wide', (tester) async {
          final d = await _app(tester, width: width, brightness: brightness);
          await expectLater(
            find.byType(NushiApp),
            matchesGoldenFile(
              'goldens/spacing_turn_${width.toInt()}_$name.png',
            ),
          );
          d.dispose();
        }, variant: _mac);
      }
      testWidgets('a turn beside the preview, $name', (tester) async {
        final d = await _app(
          tester,
          width: 1700,
          brightness: brightness,
          file: 'docs/login-report.md',
        );
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/spacing_preview_1700_$name.png'),
        );
        d.dispose();
      }, variant: _mac);
    }
  });
}
