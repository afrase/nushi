import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// A page host that loads nothing: it says what it was asked and plays a
/// page's part (its address, a title, Back once it moved).
class _Host implements BrowserHost {
  new(this.tab);

  final BrowserTab tab;
  final opened = <Uri>[];
  int reloads = 0;
  final _back = ValueNotifier<bool>(false);
  final _forward = ValueNotifier<bool>(false);
  final _failed = ValueNotifier<String>('');

  @override
  ValueListenable<bool> get canBack => _back;
  @override
  ValueListenable<bool> get canForward => _forward;
  @override
  ValueListenable<String> get failed => _failed;

  @override
  Widget view(BuildContext context) => const _Page();

  @override
  Future<void> open(Uri url) async {
    opened.add(url);
    tab.address.value = '$url';
    tab.title.value = 'Tea shop · dev';
    _back.value = opened.length > 1;
  }

  @override
  Future<void> reload() async => reloads++;

  @override
  Future<void> back() async {}

  @override
  Future<void> forward() async {}

  @override
  void dispose() {}
}

/// A page as a dev server might draw it: a heading and a line on white.
class _Page extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFFFFFFF),
    // Cut at the pane's bottom, as a page is.
    child: SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              'Tea shop',
              style: TextStyle(fontSize: 28, color: Color(0xFF1B1B1F)),
            ),
            Text(
              'Fresh leaves, roasted this morning.',
              style: TextStyle(fontSize: 14, color: Color(0xFF55555F)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The hosts made, and the addresses sent to the default browser, while
/// the test runs.
({List<_Host> hosts, List<Uri> opened}) _fakes() {
  final hosts = <_Host>[];
  final opened = <Uri>[];
  final (wasHost, wasOpen) = (newBrowserHost, openInBrowser);
  newBrowserHost = (tab) {
    final h = _Host(tab);
    hosts.add(h);
    return h;
  };
  openInBrowser = (url) async => opened.add(url);
  addTearDown(() {
    newBrowserHost = wasHost;
    openInBrowser = wasOpen;
  });
  return (hosts: hosts, opened: opened);
}

/// The app on chat c (d beside it), at [width].
Future<Daemon> _app(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  final fake =
      FakeDaemon([
          chat('c', 'claude', 'Build the tea shop'),
          chat('d', 'codex', 'Fix the cart', age: 5),
        ])
        ..answer = ((input) =>
            input is GetChatRequest ? GetChatResponse() : null)
        // A file's preview: its text, the stream open until the test ends.
        ..streams = (input) {
          if (input is! WatchChatFileRequest) return null;
          const text = '# The plan\n\nBrew, then pour.\n';
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
  return d;
}

Finder get _field => find.descendant(
  of: find.byType(BrowserBar),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await tester.pumpAndSettle();
}

EditableTextState _editable(WidgetTester tester) =>
    tester.state<EditableTextState>(
      find.descendant(of: _field, matching: find.byType(EditableText)),
    );

void main() {
  setUpAll(loadFonts);

  group('the tabs', () {
    ChatState state() => ChatState('c', '/Users/me/nushi');

    test('each new browser tab is a tab of its own, last', () {
      final c = state()..openPreview('docs/a.md');
      final one = c.openBrowserTab();
      final two = c.openBrowserTab();
      expect(c.previewTabs.value, [const PreviewFile('docs/a.md'), one, two]);
      expect(c.preview.value, two);
      expect(c.previewFile, isNull);
      // A file still opens once, beside them.
      c.openPreview('/Users/me/nushi/docs/a.md');
      expect(c.previewTabs.value, hasLength(3));
      expect(c.previewFile, 'docs/a.md');
    });

    test('closing one shows the next; Close takes them all', () {
      final c = state()..openPreview('a.md');
      final one = c.openBrowserTab('http://localhost:3000');
      c
        ..openPreview('b.md')
        ..showPreviewTab(one)
        ..closePreview(one);
      expect(c.previewFile, 'b.md');
      expect(c.previewNames, ['a.md', 'b.md']);
      c.preview.value = null;
      expect(c.previewTabs.value, isEmpty);
    });

    test('Browser shows the last browser tab, or a new one', () {
      final c = state()..showBrowser();
      final first = c.preview.value! as BrowserTab;
      expect(first.address.value, '');
      final second = c.openBrowserTab();
      c
        ..openPreview('a.md')
        ..showBrowser();
      expect(c.preview.value, same(second));
      c.showBrowser();
      expect(c.previewTabs.value, hasLength(3));
    });

    test('a browser tab says its title, else its address, else New tab', () {
      final tab = BrowserTab();
      expect(tab.label, 'New tab');
      tab.address.value = 'http://localhost:3000/app';
      expect(tab.label, 'localhost:3000/app');
      tab.title.value = '  Tea shop  ';
      expect(tab.label, 'Tea shop');
      // A page names itself: a bidi override shows.
      tab.title.value = 'invoice\u202efdp.sh';
      expect(tab.label, 'invoice\ufffdfdp.sh');
      tab.title.value = 'x' * 300;
      expect(tab.label.length, 120);
    });
  });

  group('in the window', () {
    testWidgets('a new tab: its field has the focus, a hint under it, and '
        'a local address loads', (tester) async {
      final fakes = _fakes();
      final d = await _app(tester);
      d.chats['c']!.openBrowserTab();
      await tester.pumpAndSettle();
      expect(find.text(browserHint), findsOneWidget);
      expect(_editable(tester).widget.focusNode.hasFocus, isTrue);
      expect(fakes.hosts, isEmpty); // no web view for an empty tab
      await _type(tester, 'localhost:3000');
      expect(fakes.hosts.single.opened, [Uri.parse('http://localhost:3000')]);
      expect(find.text(browserHint), findsNothing);
      expect(find.text('Tea shop · dev'), findsOneWidget); // the title
      expect(_editable(tester).widget.controller.text, 'http://localhost:3000');
      expect(fakes.opened, isEmpty);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('another site goes to the browser, a file nowhere, each '
        'saying so', (tester) async {
      final fakes = _fakes();
      final d = await _app(tester);
      d.chats['c']!.openBrowserTab();
      await tester.pumpAndSettle();
      await _type(tester, 'example.com/docs');
      expect(fakes.opened, [Uri.parse('http://example.com/docs')]);
      expect(fakes.hosts, isEmpty);
      expect(find.textContaining('Opened in your browser'), findsOneWidget);
      await _type(tester, 'file:///etc/passwd');
      expect(fakes.opened, hasLength(1));
      expect(find.textContaining('Only a local address'), findsOneWidget);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('+ shows with a browser tab showing, never on a file’s', (
      tester,
    ) async {
      _fakes();
      final d = await _app(tester);
      final c = d.chats['c']!..openPreview('docs/a.md');
      await tester.pumpAndSettle();
      expect(find.byTooltip('New browser tab'), findsNothing);
      c.openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      expect(find.byType(PreviewTabs), findsOneWidget);
      final plus = find.byTooltip('New browser tab');
      expect(plus, findsOneWidget);
      // Right after the last tab.
      final tabs = tester.getRect(find.byType(PreviewTabs));
      expect(tester.getRect(plus).left, tabs.right);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(c.previewTabs.value, hasLength(3));
      expect(find.text(browserHint), findsOneWidget);
      // Back on the file's tab: no +.
      await tester.tap(
        find.descendant(
          of: find.byType(PreviewTabs),
          matching: find.text('a.md'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPane), findsOneWidget);
      expect(find.byTooltip('New browser tab'), findsNothing);
      await closeView(tester, d);
    }, variant: _mac);
  });

  for (final (name, tokens, brightness) in [
    ('light', Tokens.light, Brightness.light),
    ('dark', Tokens.dark, Brightness.dark),
  ]) {
    group('looks, $name', () {
      Future<ChatState> pane(WidgetTester tester, Size size) async {
        viewport(tester, size);
        final c = ChatState('c', '/Users/me/nushi');
        await tester.pumpWidget(
          themed(
            tokens: tokens,
            Center(
              child: RepaintBoundary(
                key: const ValueKey('pane'),
                child: SizedBox.fromSize(
                  size: size,
                  child: ValueListenableBuilder(
                    valueListenable: c.preview,
                    builder: (context, tab, _) => tab is BrowserTab
                        ? BrowserPane(
                            key: ObjectKey(tab),
                            chat: c,
                            tab: tab,
                            onClose: () {},
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
        return c;
      }

      testWidgets('a new tab: the title row with +, the bar, the hint', (
        tester,
      ) async {
        _fakes();
        final c = await pane(tester, const Size(560, 300));
        c.openBrowserTab();
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('pane')),
          matchesGoldenFile('goldens/browser_new_tab_$name.png'),
        );
      }, variant: _mac);

      testWidgets('tabs, a file’s among them, with +; the bar on a page', (
        tester,
      ) async {
        final fakes = _fakes();
        final c = await pane(tester, const Size(560, 160));
        c
          ..openPreview('docs/plan.md')
          ..openBrowserTab('http://localhost:5173')
          ..openBrowserTab('http://localhost:3000');
        await tester.pumpAndSettle();
        // A second page, so Back is on.
        await fakes.hosts.last.open(Uri.parse('http://localhost:3000/menu'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('pane')),
          matchesGoldenFile('goldens/browser_tabs_$name.png'),
        );
      }, variant: _mac);

      testWidgets('the browser’s icons, 2×', (tester) async {
        viewport(tester, const Size(200, 44), ratio: 2);
        final t = tokens;
        await tester.pumpWidget(
          themed(
            tokens: tokens,
            Center(
              child: RepaintBoundary(
                key: const ValueKey('icons'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: NushiTheme.iconGap,
                  children: [
                    IconTap.line(
                      LineIcon.globe,
                      tooltip: 'Browser',
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.globe,
                      tooltip: 'Browser',
                      color: t.accentInk,
                      onTap: () {},
                    ),
                    IconTap.line(
                      LineIcon.plus,
                      tooltip: 'New browser tab',
                      size: 14,
                      padding: 4,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byKey(const ValueKey('icons')),
          matchesGoldenFile('goldens/browser_icons_$name.png'),
        );
      }, variant: _mac);

      for (final width in [1700.0, 720.0]) {
        testWidgets('renders: the window with a browser tab, '
            '${width.toInt()} wide', (tester) async {
          _fakes();
          final d = await _app(tester, width: width, brightness: brightness);
          d.chats['c']!
            ..openPreview('docs/plan.md')
            ..openBrowserTab('http://localhost:3000');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectTextInside(tester, width);
          // The bar's field runs to the pane's edge, its buttons first.
          final pane = tester.getRect(find.byType(BrowserPane));
          final bar = tester.getRect(find.byType(BrowserBar));
          expect((bar.left, bar.right), (pane.left, pane.right));
          expect(tester.getRect(_field).right, closeTo(pane.right - 8, 0.5));
          await render(
            tester,
            find.byType(NushiApp),
            'browser_tab_${width.toInt()}_$name',
          );
          d.chats['c']!.openBrowserTab();
          await tester.pumpAndSettle();
          await render(
            tester,
            find.byType(NushiApp),
            'browser_new_tab_${width.toInt()}_$name',
          );
          await closeView(tester, d);
        }, variant: _mac);
      }
    });
  }
}
