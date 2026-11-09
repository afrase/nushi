import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/markdown.dart' show openWebOutside;
import 'package:nushi/native.dart';
import 'package:nushi/outside_page.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_pane.dart';
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

Item _show(String id, String url) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'other',
  title: 'mcp__nushi__show',
  status: 'completed',
  input: jsonEncode({'url': url}),
);

/// The app at [width] on chat c, whose files answer as the daemon would,
/// in /Users/me/nushi; the agent showed a page and linked one, then did
/// [more].
Future<(FakeDaemon, Daemon)> _app(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
  List<Item> more = const [],
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  final c = chat('c', 'claude', 'Build the tea shop');
  final fake = FakeDaemon([c])
    ..answer = ((input) => input is GetChatRequest
        ? GetChatResponse(
            chat: c,
            items: [
              _show('s', 'http://localhost:5173/menu'),
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
      final text = input.path.endsWith('.mmd') ? _flow : _html;
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
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
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
    d.chats['c']!.openPreview('site/index.html');
    await tester.pumpAndSettle();
    expect(opened, isEmpty); // shown, not opened
    expect(_in<PreviewPane>(find.text('index.html')), findsWidgets);
    expect(_in<PreviewPane>(find.text(outsideNote)), findsOneWidget);
    expect(_in<PreviewPane>(find.byTooltip('Reload')), findsNothing);
    expect(_in<PreviewPane>(find.byTooltip('Open in browser')), findsOne);
    await render(tester, find.byType(NushiApp), 'outside_preview_1700');
    await tester.tap(_openButton);
    await tester.pumpAndSettle();
    expect(opened, [Uri.file('/Users/me/nushi/site/index.html')]);
    await tester.tap(_in<PreviewPane>(find.text('Source')));
    await tester.pumpAndSettle();
    expect(
      _in<PreviewPane>(find.textContaining('The Still Kettle')),
      findsOneWidget,
    );
    expect(_in<PreviewPane>(find.byType(SourceView)), findsOneWidget);
    await closeView(tester, d);
  }, variant: linuxOnly);

  testWidgets('narrow, the placeholder over the chat keeps its button whole', (
    tester,
  ) async {
    pagesOutside();
    final (_, d) = await _app(tester, width: 720, brightness: Brightness.dark);
    d.chats['c']!.openPreview('site/index.html');
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), 'outside_preview_720');
    final pane = tester.getRect(find.byType(PreviewPane));
    final button = tester.getRect(_openButton);
    expect(
      pane.contains(button.topLeft) && pane.contains(button.bottomRight),
      isTrue,
    );
    expectTextInside(tester, 720);
    await closeView(tester, d);
  }, variant: linuxOnly);

  testWidgets('a browser that won’t open says so: the runner not answering '
      'yet, and no default browser', (tester) async {
    // The runner's nushi/browser not built yet: it answers not implemented.
    answerBrowser((_) => throw MissingPluginException());
    native
      ..web = const LinuxWebViews()
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
    addTearDown(() => defaultBrowser.value = null);
    final (_, d) = await _app(tester);
    d.chats['c']!.openPreview('site/index.html');
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
    await tester.tap(_in<PreviewPane>(find.byTooltip('Open in browser')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No default browser is set'), findsOneWidget);
    await closeView(tester, d);
  }, variant: linuxOnly);

  testWidgets('a PDF’s preview is the placeholder too, not the phone’s '
      'note', (tester) async {
    final opened = pagesOutside();
    final (_, d) = await _app(tester);
    d.chats['c']!.openPreview('docs/menu.pdf');
    await tester.pumpAndSettle();
    expect(_in<PreviewPane>(find.text(outsideNote)), findsOneWidget);
    expect(find.text('Open it on your Mac to see it.'), findsNothing);
    await tester.tap(_openButton);
    await tester.pumpAndSettle();
    expect(opened, [Uri.file('/Users/me/nushi/docs/menu.pdf')]);
    await closeView(tester, d);
  }, variant: linuxOnly);

  testWidgets('a Mermaid file shows its source, with no Preview to switch '
      'to', (tester) async {
    pagesOutside();
    final (_, d) = await _app(tester);
    d.chats['c']!.openPreview('docs/flow.mmd');
    await tester.pumpAndSettle();
    expect(_in<PreviewPane>(find.text('Preview')), findsNothing);
    expect(_in<PreviewPane>(find.text('Source')), findsNothing);
    expect(_in<PreviewPane>(find.textContaining('Plan --> Build')), findsOne);
    expect(_in<PreviewPane>(find.byTooltip('Open in browser')), findsNothing);
    await closeView(tester, d);
  }, variant: linuxOnly);

  testWidgets('the agent’s page opens a placeholder tab, never the browser; '
      'no Back, Forward, Reload or ⋯; its button and Return open it', (
    tester,
  ) async {
    final opened = pagesOutside();
    final (fake, d) = await _app(tester);
    fake.emit(EventsResponse(chatId: 'c', showUrl: 'http://localhost:5173'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.preview.value, isA<BrowserTab>());
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
  }, variant: linuxOnly);

  testWidgets('narrow, the tab’s placeholder over the chat', (tester) async {
    pagesOutside();
    final (_, d) = await _app(tester, width: 720, brightness: Brightness.dark);
    d.chats['c']!.openBrowserTab('http://localhost:5173/menu');
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), 'outside_tab_720');
    expect(find.byType(BrowserPane), findsOneWidget);
    expectTextInside(tester, 720);
    await closeView(tester, d);
  }, variant: linuxOnly);

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
    expect(d.chats['c']!.preview.value, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened.last, Uri.parse('http://localhost:5173/menu'));
    expect(d.chats['c']!.preview.value, isNull);
    d.openSettings(section: SettingsSection.general);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets); // the page shows
    expect(find.text('Open links in built-in browser'), findsNothing);
    await closeView(tester, d);
  }, variant: linuxOnly);

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
  }, variant: linuxOnly);

  testWidgets('a show row has no Open for what a tab wouldn’t show; its '
      'card doesn’t say a page runs as it opens', (tester) async {
    final opened = pagesOutside();
    final (_, d) = await _app(
      tester,
      more: [
        _show('f', 'file:///Users/me/nushi/evil.html'),
        _show('u', 'http://bank.example@localhost:3000/'),
        Item(
          id: 'p',
          kind: ItemKind.ITEM_KIND_PERMISSION,
          title: 'mcp__nushi__show',
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
  }, variant: linuxOnly);
}
