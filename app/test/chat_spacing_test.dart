import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/cards.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_plus.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/message_actions.dart';
import 'package:nushi/native.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/window_drag_linux.dart';

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

/// The app on a chat with [items] ([_items] if not given), its preview open
/// with [file], [pane] wide if given.
Future<Daemon> _app(
  WidgetTester tester, {
  required double width,
  List<Item>? items,
  Brightness? brightness,
  double height = 1000,
  String? file,
  double? pane,
}) async {
  viewport(tester, Size(width, height), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {'preview': ?pane};
  final c = chat('c', 'claude', 'Fix the login redirect after it expires');
  final fake = FakeDaemon([c])
    ..answer = ((input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: items ?? _items)
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

/// The fill of the row of [Collapsible] [at], and what outlines it.
(Color?, BoxBorder?) _look(WidgetTester tester, Finder at) {
  final frame = tester
      .widgetList<Container>(
        find.descendant(of: at, matching: find.byType(Container)),
      )
      .first;
  expect(frame.foregroundDecoration, isNull);
  final box = frame.decoration! as BoxDecoration;
  return (box.color, box.border);
}

/// The room beside the chat's column in a view [width] wide.
double _pad(double width) => width - 2 * NushiTheme.gutter > chatWidth
    ? (width - chatWidth) / 2
    : NushiTheme.gutter;

void main() {
  setUpAll(loadFonts);

  group('the gutters', () {
    for (final width in [1700.0, 720.0]) {
      testWidgets('header, transcript and composer share them, '
          '${width.toInt()} wide', (tester) async {
        final d = await _app(tester, width: width);
        final view = tester.getRect(find.byType(ChatView));
        final box = _box(tester);
        // The column's middle on a wide window, the gutter on a narrow one.
        final left = view.left + _pad(view.width);
        expect(box.left, left);
        expect(box.right, view.right - _pad(view.width));
        expect(_text(tester, 'I’ll start from').left, left);
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
          view.right - ChatHeader.end,
        );
        // A message's bubble ends at the column's right.
        expect(
          _text(tester, 'Good. Run the whole suite.').right,
          box.right - 18,
        );
        await closeView(tester, d);
      }, variant: _mac);
    }

    testWidgets('at full width everything takes the pane, to the gutters', (
      tester,
    ) async {
      chatFullWidth.value = true;
      final d = await _app(tester, width: 1700);
      final view = tester.getRect(find.byType(ChatView));
      final left = view.left + NushiTheme.gutter;
      final box = _box(tester);
      expect(box.left, left);
      expect(box.right, view.right - NushiTheme.gutter);
      expect(_text(tester, 'I’ll start from').left, left);
      expect(_text(tester, 'Good. Run the whole suite.').right, box.right - 18);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('a failed row’s box and the permission card are on the text '
        'column; its chevron and icon don’t move', (tester) async {
      final d = await _app(tester, width: 1700);
      final view = tester.getRect(find.byType(ChatView));
      final left = view.left + _pad(view.width);
      Finder row(String words) => find.ancestor(
        of: find.textContaining(words, findRichText: true).first,
        matching: find.byType(Collapsible),
      );
      Rect in_(Finder r, Finder f) =>
          tester.getRect(find.descendant(of: r, matching: f).first);
      final failed = row('go test');
      final fine = row('make check');
      expect(tester.getRect(failed).left, left);
      expect(tester.getRect(failed).right, left + chatWidth);
      final card = tester.getRect(find.byType(WaitingCard));
      expect(card.left, left);
      expect(card.right, left + chatWidth);
      expect(
        in_(failed, find.byType(Chevron)).left,
        in_(fine, find.byType(Chevron)).left,
      );
      expect(
        in_(failed, find.byIcon(Icons.terminal)).left,
        in_(fine, find.byIcon(Icons.terminal)).left,
      );
      // What ends a row ends it at the same place: a failed row's word, a
      // row's Preview.
      expect(
        in_(failed, find.text('failed')).right,
        tester.getRect(find.byType(PreviewButton)).right,
      );
      expect(
        in_(failed, find.text('failed')).right,
        tester.getRect(failed).right - Collapsible.side,
      );
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('the header', () {
    testWidgets('56 high, the bar’s gaps with room, ⋯ and the tabs in place', (
      tester,
    ) async {
      final d = await _app(tester, width: 1700);
      final header = tester.getRect(find.byType(ChatHeader));
      expect(header.height, 56);
      // The segmented control in the row's middle, over its hairline.
      final tabs = tester.getRect(find.byType(Segmented<ChatTab>));
      expect(tabs.center.dy, closeTo(header.center.dy - 0.5, 0.01));
      final terminal = tester.getRect(find.byType(TerminalButton));
      expect(terminal.left - tabs.right, NushiTheme.barGap);
      // At the pane's edge, which is the window's margin in.
      expect(
        tester.getRect(find.byTooltip('Chat menu')).right,
        1700 - NushiTheme.windowPad - ChatHeader.end,
      );
      final menu = tester.getRect(find.byTooltip('Chat menu'));
      final files = tester.getRect(find.byType(FilesButton));
      final browser = tester.getRect(find.byType(BrowserButton));
      final details = tester.getRect(find.byTooltip('Show details'));
      expect(files.left - terminal.right, NushiTheme.iconGap);
      expect(browser.left - files.right, NushiTheme.iconGap);
      expect(details.left - browser.right, NushiTheme.iconGap);
      expect(menu.left - details.right, NushiTheme.iconGap);
      await closeView(tester, d);
    }, variant: _mac);

    test('the bar’s gaps never fold anything', () {
      // Where each case first folds without them: 524 for the row, 80 for
      // the title, the browser's button 32, then what the case adds (the
      // Pull request segment 106, a model 50, the Files button 32); each
      // button's gap 2.
      for (final (pull, model, files, first) in [
        (false, false, false, 636.0),
        (true, false, false, 742.0),
        (false, true, false, 686.0),
        (true, true, false, 792.0),
        (false, false, true, 668.0),
        (true, true, true, 824.0),
      ]) {
        for (final panel in [false, true]) {
          HeaderFolds at(double width) => headerFolds(
            width,
            pull: pull,
            panel: panel,
            files: files,
            model: model,
          );
          final gaps =
              headerGaps +
              NushiTheme.iconGap +
              (files ? NushiTheme.iconGap : 0);
          expect(at(first).any, isFalse);
          expect(at(first - 1).any, isTrue);
          expect(at(first).roomy, isFalse);
          expect(at(first + gaps - 1).roomy, isFalse);
          expect(at(first + gaps).roomy, isTrue);
          expect(at(first + gaps).gaps, gaps);
          for (var w = 300.0; w < first; w += 5) {
            expect(at(w).roomy, isFalse, reason: 'folded at $w');
          }
        }
      }
    });
  });

  group('the composer', () {
    for (final width in [1700.0, 720.0]) {
      testWidgets('a card: the text over one row of controls inside it, 16 '
          'from the bottom, ${width.toInt()} wide', (tester) async {
        final d = await _app(tester, width: width);
        final box = _box(tester);
        final t = NushiTheme.of(tester.element(find.byType(Composer))).t;
        final look =
            tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.byType(TextField),
                            matching: find.byWidgetPredicate(
                              (w) =>
                                  w is Container &&
                                  w.decoration is BoxDecoration &&
                                  (w.decoration! as BoxDecoration)
                                          .borderRadius !=
                                      null,
                            ),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(look.color, t.raised);
        expect((look.border! as Border).top.color, t.line);
        expect(look.boxShadow, isNotEmpty);
        // The row: the +, the pickers, and what sends; all in the box.
        final input = tester.getRect(find.byType(TextField));
        final plus = tester.getRect(find.byType(PlusButton));
        final row = tester.getRect(find.byType(Pickers));
        expect(input.left - box.left, greaterThanOrEqualTo(12));
        expect(plus.top, greaterThan(input.bottom));
        expect(plus.left, box.left + 13);
        expect(plus.size, const Size.square(PillButton.height));
        expect(row.center.dy, plus.center.dy);
        expect(row.left, greaterThan(plus.right));
        expect(row.right, lessThanOrEqualTo(box.right - 13));
        expect(box.bottom - plus.bottom, 11);
        expect(tester.getRect(find.byType(Composer)).bottom - box.bottom, 16);
        await closeView(tester, d);
      }, variant: _mac);
    }
  });

  group('the transcript', () {
    testWidgets('14 on 22, at most 800 wide in the middle', (tester) async {
      final d = await _app(tester, width: 1700);
      final line = _text(tester, 'I’ll start from');
      expect(line.height, 22);
      final text = _text(tester, 'The redirect read the session');
      expect(text.width, lessThanOrEqualTo(chatWidth));
      expect(text.height % 22, 0);
      final view = tester.getRect(find.byType(ChatView));
      expect(text.left, view.left + _pad(view.width));
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('14 on 22 for a message that names a file', (tester) async {
      // A finished message whose paths are links is built apart from one
      // without: it must still be a transcript's message (ADR 0072).
      final d = await _app(
        tester,
        width: 1700,
        items: [
          Item(
            id: 'm',
            kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
            text: 'The fix is in `app/session.go`, and nowhere else.',
          ),
        ],
      );
      expect(_text(tester, 'The fix is in').height, 22);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('items 16 apart, 28 after a message for its actions, 32 '
        'before a user message', (tester) async {
      final d = await _app(tester, width: 1700);
      final first = _text(tester, 'I’ll start from');
      final next = _text(tester, 'The redirect read the session');
      final run = tester.getRect(find.byType(RunView));
      expect(run.top - first.bottom, messageActionsHeight);
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

    testWidgets('each a card’s fill with no outline; a failed one says so '
        'in red, its icon red too', (tester) async {
      final d = await _app(tester, width: 1700);
      final t = NushiTheme.of(tester.element(find.byType(ChatView))).t;
      for (final words in ['docs/login-report.md', 'make check', 'go test']) {
        expect(_look(tester, call(words)), (t.raised, null));
        expect(tester.getSize(call(words)).height, Collapsible.height);
      }
      final failed = call('go test');
      Finder inside(Finder f) => find.descendant(of: failed, matching: f);
      expect(
        tester.widget<Text>(inside(find.text('failed'))).style!.color,
        t.crashed,
      );
      expect(
        tester.widget<Icon>(inside(find.byIcon(Icons.terminal))).color,
        t.crashed,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: call('make check'),
                matching: find.byIcon(Icons.terminal),
              ),
            )
            .color,
        t.toolAccent,
      );
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('on the phone it’s still a card, a touch target high', (
      tester,
    ) async {
      viewport(tester, const Size(390, 200));
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: TouchTargets(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: ToolCallView(
                  _tool('a', 'read', 'Read', paths: ['a.go']),
                ),
              ),
            ),
          ),
        ),
      );
      expect(_look(tester, find.byType(Collapsible)), (
        Tokens.dark.raised,
        null,
      ));
      expect(
        tester.getSize(find.byType(Collapsible)).height,
        TouchTargets.size,
      );
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
                      LineIcon.folder,
                      tooltip: 'Show files',
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
                    IconTap.line(
                      LineIcon.more,
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
      final terminal = find.byType(TerminalButton);
      final details = find.byTooltip('Show details');
      expect(tester.getSize(terminal), const Size(32, 32));
      expect(tester.getSize(details), const Size(32, 32));
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
      expect(open.lit, isTrue); // on: the accent on its soft fill
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('the menus’ drawn icons', () {
    for (final (name, brightness, tokens) in [
      ('dark', Brightness.dark, Tokens.dark),
      ('light', Brightness.light, Tokens.light),
    ]) {
      testWidgets('the header’s ⋯ with its buttons folded in, $name', (
        tester,
      ) async {
        viewport(tester, const Size(420, 420), ratio: 2);
        final d = await FakeDaemon([]).connect(tester);
        final c = ChatState('c', '/Users/me/repo')
          ..agent = 'omp'
          ..title = 'Fix the login redirect after the session expires'
          ..pull = GitHubLink(number: 12, pull: true);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 330,
                  child: ChatHeader(
                    c,
                    d,
                    tab: ChatTab.chat,
                    onTab: (_) {},
                    panel: false,
                    onPanel: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Chat menu'));
        await tester.pumpAndSettle();
        expect(find.text('Show terminal', findRichText: true), findsOne);
        expect(find.text('Show files', findRichText: true), findsOne);
        expect(find.text('Show details', findRichText: true), findsOne);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/header_menu_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('the preview’s folded ⋯, at the narrowest pane, $name', (
        tester,
      ) async {
        final d = await _app(
          tester,
          width: 720,
          height: 600,
          brightness: brightness,
          file: 'docs/login-report.md',
          pane: 300,
        );
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        expect(find.text('Show in Finder', findRichText: true), findsOne);
        await render(tester, find.byType(NushiApp), 'preview_menu_720_$name');
        d.dispose();
      }, variant: _mac);
    }

    // Linux's words (ADR 0104), in its window, on its platform.
    for (final width in [1700.0, 720.0]) {
      testWidgets('the preview’s folded ⋯ on Linux, ${width.toInt()} wide', (
        tester,
      ) async {
        native
          ..conventions = linuxConventions
          ..window = const LinuxWindow();
        final d = await _app(
          tester,
          width: width,
          height: 600,
          file: 'docs/login-report.md',
          pane: 300,
        );
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        expect(find.text('Show in Folder', findRichText: true), findsOne);
        expect(find.text('Show in Finder', findRichText: true), findsNothing);
        await render(
          tester,
          find.byType(NushiApp),
          'linux_preview_menu_${width.toInt()}',
        );
        d.dispose();
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
    }
  });

  // The chat's window goldens: a turn at 1700 with the details panel, and
  // at 720, where the layout narrows; the sidebar hidden (it has its own).
  group('the window', () {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      for (final width in [1700.0, 720.0]) {
        testWidgets('a turn, $name, ${width.toInt()} wide', (tester) async {
          sidebarHidden.value = true;
          final d = await _app(tester, width: width, brightness: brightness);
          showDetails.value = width > 720;
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
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
        // The column's composer clear of the preview beside it.
        final preview = tester.getRect(find.byType(PreviewPane));
        expect(_box(tester).right, lessThan(preview.left));
        await render(
          tester,
          find.byType(NushiApp),
          'spacing_preview_1700_$name',
        );
        d.dispose();
      }, variant: _mac);
    }
  });
}
