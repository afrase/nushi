import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/markdown.dart' show openWebOutside;
import 'package:nushi/native.dart';
import 'package:nushi/outside_page.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/web_views_linux.dart';
import 'package:nushi/window_drag_linux.dart';

import 'browser_fixture.dart' show addressField, typeAddress;
import 'fake_daemon.dart';
import 'harness.dart';
import 'outside_fixture.dart';

// The app without its own web views (Linux, ADR 0104): pages show as
// placeholders, and only the user's click opens one in the default browser;
// what only a web view in the app has (Reload, Back, Forward, the tab's ⋯,
// a diagram's Preview, the built-in browser setting) isn't there.

const _html = '<!doctype html>\n<h1>The Still Kettle</h1>\n';
const _flow = 'graph LR\n  Plan --> Build --> Ship\n';
const _plan = '# The plan\n\n```mermaid\n$_flow```\n';

/// The app at [width] on chat c, whose files answer as the daemon would,
/// in /Users/me/nushi; the agent showed a page and linked one, then did
/// [more].
Future<(FakeDaemon, Daemon)> _app(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
  List<Item> more = const [],
}) async {
  showDetails.value = false;
  final c = chat('c', 'claude', 'Build the tea shop');
  final fake = FakeDaemon([c])
    ..answer = ((input) => input is GetChatRequest
        ? GetChatResponse(
            chat: c,
            items: [
              mcpCall('s', 'nushi', 'show', {
                'url': 'http://localhost:5173/menu',
              }),
              Item(
                id: 'm',
                kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                text: '[The brewing guide](https://tea.example/guide)',
              ),
              ...more,
            ],
          )
        : null)
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      final text = switch (input.path) {
        final p when p.endsWith('.mmd') => _flow,
        final p when p.endsWith('.md') => _plan,
        _ => _html,
      };
      final s = StreamController<WatchChatFileResponse>()
        ..add(
          WatchChatFileResponse(
            path: '/Users/me/nushi/${input.path}',
            data: utf8.encode(text),
            size: Int64(text.length),
          ),
        );
      addTearDown(s.close);
      return s.stream;
    };
  final d = await openApp(
    tester,
    fake,
    size: Size(width, 900),
    brightness: brightness,
  );
  return (fake, d);
}

Finder _in<T>(Finder f) => find.descendant(of: find.byType(T), matching: f);

Finder get _openButton => find.text('Open in Firefox');

Finder get _guideLink =>
    find.textContaining('The brewing guide', findRichText: true).last;

void main() {
  setUpAll(loadFonts);

  testWidgets('a page’s preview is a placeholder that opens the file the '
      'daemon confirmed, only on a click; no Reload; its source still shows', (
    tester,
  ) async {
    final opened = pagesOutside();
    final (_, d) = await _app(tester);
    d.chats['c']!.openInFiles('site/index.html');
    await tester.pumpAndSettle();
    expect(opened, isEmpty); // shown, not opened
    expect(_in<FilesPane>(find.text('index.html')), findsWidgets);
    expect(_in<FilesPane>(find.text(outsideNote)), findsOneWidget);
    expect(_in<FilesPane>(find.byTooltip('Reload')), findsNothing);
    expect(_in<FilesPane>(find.byTooltip('Open in browser')), findsOne);
    await render(tester, find.byType(NushiApp), 'outside_preview_1700');
    await tester.tap(_openButton);
    await tester.pumpAndSettle();
    expect(opened, [Uri.file('/Users/me/nushi/site/index.html')]);
    await tester.tap(_in<FilesPane>(find.byType(SourceButton)));
    await tester.pumpAndSettle();
    expect(
      _in<FilesPane>(find.textContaining('The Still Kettle')),
      findsOneWidget,
    );
    expect(_in<FilesPane>(find.byType(SourceView)), findsOneWidget);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('beside the details rail, right of it, the placeholder keeps '
      'its button in the pane, under its top row', (tester) async {
    final opened = pagesOutside();
    // Wide enough for the rail beside the Files pane.
    final (_, d) = await _app(tester, width: 2000);
    showDetails.value = true;
    await tester.pumpAndSettle();
    d.chats['c']!.openInFiles('site/index.html');
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), 'outside_preview_rail_2000');
    final pane = tester.getRect(find.byType(FilesPane));
    final rail = tester.getRect(find.byType(DetailsPanel));
    expect(pane.left, rail.right);
    expect(pane.right, tester.getRect(find.byType(Pane)).right);
    // The pane's top row is level with the chat's header; the button is
    // in the body under it, whole.
    expect(
      tester.getRect(find.byType(ChatHeader)).bottom,
      pane.top + PaneHeader.height,
    );
    final button = tester.getRect(_openButton);
    expect(button.top, greaterThanOrEqualTo(pane.top + PaneHeader.height));
    expect(
      pane.contains(button.topLeft) && pane.contains(button.bottomRight),
      isTrue,
    );
    expectTextInside(tester, 2000);
    await tester.tap(_openButton);
    await tester.pumpAndSettle();
    expect(opened, [Uri.file('/Users/me/nushi/site/index.html')]);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('narrow, the placeholder over the chat keeps its button whole', (
    tester,
  ) async {
    pagesOutside();
    final (_, d) = await _app(tester, width: 720, brightness: Brightness.dark);
    d.chats['c']!.openInFiles('site/index.html');
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), 'outside_preview_720');
    final pane = tester.getRect(find.byType(FilesPane));
    final button = tester.getRect(_openButton);
    expect(
      pane.contains(button.topLeft) && pane.contains(button.bottomRight),
      isTrue,
    );
    expectTextInside(tester, 720);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('a browser that won’t open says so: the runner not answering '
      'yet, and no default browser', (tester) async {
    // The runner's nushi/browser not built yet: it answers not implemented.
    answerBrowser((_) => throw MissingPluginException());
    native
      ..web = const LinuxWebViews()
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
    final (_, d) = await _app(tester);
    d.chats['c']!.openInFiles('site/index.html');
    await tester.pumpAndSettle();
    // No name from the runner: the button says "your browser".
    await tester.tap(find.text('Open in your browser'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t open your browser.'), findsOneWidget);
    pagesOutside(
      open: (_) => Future.error(
        const BrowserError(
          'No default browser is set: choose one in your '
          'system’s settings.',
        ),
      ),
    );
    await tester.tap(_in<FilesPane>(find.byTooltip('Open in browser')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No default browser is set'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('a PDF’s preview is the placeholder too, not the phone’s '
      'note', (tester) async {
    final opened = pagesOutside();
    final (_, d) = await _app(tester);
    d.chats['c']!.openInFiles('docs/menu.pdf');
    await tester.pumpAndSettle();
    expect(_in<FilesPane>(find.text(outsideNote)), findsOneWidget);
    expect(find.text('Open it on your Mac to see it.'), findsNothing);
    await tester.tap(_openButton);
    await tester.pumpAndSettle();
    expect(opened, [Uri.file('/Users/me/nushi/docs/menu.pdf')]);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('a Mermaid file shows its source, with no Preview to switch '
      'to', (tester) async {
    pagesOutside();
    final (_, d) = await _app(tester);
    d.chats['c']!.openInFiles('docs/flow.mmd');
    await tester.pumpAndSettle();
    expect(_in<FilesPane>(find.byType(SourceButton)), findsNothing);
    expect(_in<FilesPane>(find.textContaining('Plan --> Build')), findsOne);
    expect(_in<FilesPane>(find.byTooltip('Open in browser')), findsNothing);
    await closeView(tester, d);
  }, variant: onLinux);

  // Review 2026-11-22, F222: Linux's Diagram tab showed the source, as
  // Source did, and a line saying it isn't drawn.
  for (final width in [1700.0, 720.0]) {
    testWidgets('${width.toInt()}: a Markdown file’s Mermaid block shows '
        'its source, with no Diagram and Source tabs', (tester) async {
      pagesOutside();
      final (_, d) = await _app(tester, width: width);
      d.chats['c']!.openInFiles('docs/plan.md');
      await tester.pumpAndSettle();
      await render(
        tester,
        find.byType(NushiApp),
        'outside_mermaid_${width.toInt()}',
      );
      expect(_in<FilesPane>(find.textContaining('Plan --> Build')), findsOne);
      expect(_in<FilesPane>(find.text('Mermaid')), findsOne);
      expect(_in<FilesPane>(find.text('Diagram')), findsNothing);
      expect(_in<FilesPane>(find.text('Source')), findsNothing);
      await closeView(tester, d);
    }, variant: onLinux);
  }

  testWidgets('the agent’s page opens a placeholder tab, never the browser; '
      'no Back, Forward, Reload or ⋯; its button and Return open it', (
    tester,
  ) async {
    final opened = pagesOutside();
    final (fake, d) = await _app(tester);
    fake.emit(EventsResponse(chatId: 'c', showUrl: 'http://localhost:5173'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.browser.shown.value, isA<BrowserTab>());
    expect(opened, isEmpty);
    expect(_in<BrowserPane>(find.text('localhost:5173')), findsWidgets);
    for (final tip in ['Back', 'Forward', 'More']) {
      expect(_in<BrowserPane>(find.byTooltip(tip)), findsNothing, reason: tip);
    }
    expect(_in<BrowserPane>(find.byTooltip(RegExp('^Reload'))), findsNothing);
    await render(tester, find.byType(NushiApp), 'outside_tab_1700');
    await tester.tap(_openButton);
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('http://localhost:5173')]);
    // ⌘R has no page to reload here.
    final context = tester.element(find.byType(BrowserPane));
    expect(
      appActions(context, d).firstWhere((a) => a.act == Act.reloadPage).enabled,
      isFalse,
    );
    // A typed address: the tab follows it, and the browser opens it.
    await tester.tap(addressField);
    await typeAddress(tester, 'localhost:3000/cart');
    expect(opened.last, Uri.parse('http://localhost:3000/cart'));
    expect(_in<BrowserPane>(find.text('localhost:3000')), findsWidgets);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('narrow, the tab’s placeholder over the chat', (tester) async {
    pagesOutside();
    final (_, d) = await _app(tester, width: 720, brightness: Brightness.dark);
    d.chats['c']!.openBrowserTab('http://localhost:5173/menu');
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), 'outside_tab_720');
    expect(find.byType(BrowserPane), findsOneWidget);
    expectTextInside(tester, 720);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('a chat’s link and the show row’s Open go straight to the '
      'browser; Settings has no built-in browser row', (tester) async {
    final opened = pagesOutside();
    final outside = <Uri>[];
    final was = openWebOutside;
    openWebOutside = (url) async => outside.add(url);
    addTearDown(() => openWebOutside = was);
    final (_, d) = await _app(tester);
    await tester.tap(_guideLink);
    await tester.pumpAndSettle();
    // The app that opens https, as every page here (not url_launcher's).
    expect(opened, [Uri.parse('https://tea.example/guide')]);
    expect(outside, isEmpty);
    expect(d.chats['c']!.browser.shown.value, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened.last, Uri.parse('http://localhost:5173/menu'));
    expect(d.chats['c']!.browser.shown.value, isNull);
    d.openSettings(section: SettingsSection.general);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets); // the page shows
    expect(find.text('Open links in built-in browser'), findsNothing);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('a chat’s link with no default browser says so', (tester) async {
    pagesOutside(
      open: (_) => Future.error(
        const BrowserError(
          'No default browser is set: choose one in your '
          'system’s settings.',
        ),
      ),
    );
    final (_, d) = await _app(tester);
    await tester.tap(_guideLink);
    await tester.pumpAndSettle();
    expect(find.textContaining('No default browser is set'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onLinux);

  testWidgets('a show row has no Open for what a tab wouldn’t show; its '
      'card doesn’t say a page runs as it opens', (tester) async {
    final opened = pagesOutside();
    final (_, d) = await _app(
      tester,
      more: [
        mcpCall('f', 'nushi', 'show', {
          'url': 'file:///Users/me/nushi/evil.html',
        }),
        mcpCall('u', 'nushi', 'show', {
          'url': 'http://bank.example@localhost:3000/',
        }),
        Item(
          id: 'p',
          kind: ItemKind.ITEM_KIND_PERMISSION,
          title: 'mcp__nushi__show',
          mcpServer: 'nushi',
          mcpTool: 'show',
          input: jsonEncode({'path': 'site/index.html'}),
          status: 'pending',
          options: [Option(id: 'yes', name: 'Yes', kind: 'allow_once')],
        ),
      ],
    );
    // Only the first show's page, http://localhost:5173/menu.
    expect(find.text('Open'), findsOneWidget);
    expect(
      find.byTooltip('Open file:///Users/me/nushi/evil.html'),
      findsNothing,
    );
    expect(opened, isEmpty);
    expect(find.text('Show site/index.html'), findsOneWidget);
    expect(find.textContaining('A page runs'), findsNothing);
    await closeView(tester, d);
  }, variant: onLinux);
}
