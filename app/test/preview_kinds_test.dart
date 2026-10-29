import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/diagram_screen.dart';
import 'package:nushi/phone/page_frame.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/web_page.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _html = '''
<!doctype html>
<html>
<head><link rel="stylesheet" href="css/style.css"></head>
<body><h1>The Still Kettle</h1><img src="img/logo.png"></body>
</html>
''';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg"><circle r="4"/></svg>\n';

const _json =
    '{"name":"tea","port":8080,"features":{"menu":true,'
    '"hours":["8-12","13-18"]}}';

const _note = '"a note, with a comma"';

/// A Mermaid file, opened by its path (not among the chat's writes).
const _flow = 'graph LR\n  Plan --> Build --> Ship\n';

final String _csv = [
  'id,name,city,notes',
  for (var i = 1; i <= 600; i++)
    '$i,User $i,${const ['Lisbon', 'Osaka', 'Austin'][i % 3]},$_note',
].join('\n');

const Map<String, String> _files = {
  'site/index.html': _html,
  'site/pic.svg': _svg,
  'config.json': _json,
  'report.pdf': '%PDF-1.7 …',
};

Item _write(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Make the landing page, its picture, the config and the data.',
  ),
  for (final (i, p) in [..._files.keys, 'data.csv'].indexed) _write('w$i', p),
  _write('z', 'dist/app.zip'),
];

final Chat _chat = chat('c', 'claude', 'The landing page');

/// A page host that records what it's asked.
class _Host implements PageHost {
  final loads = <(String, String)>[];
  int reloads = 0;
  bool disposed = false;

  @override
  Widget view(BuildContext context) => const ColoredBox(
    key: Key('page'),
    color: Color(0xFFFBF7F0),
    child: SizedBox.expand(),
  );

  @override
  Future<void> load(String path, String root) async => loads.add((path, root));

  @override
  Future<void> reload() async => reloads++;

  @override
  void dispose() => disposed = true;
}

/// A diagram host that records what it's asked to draw.
class _Diagram implements DiagramHost {
  final shown = <(String, bool)>[];
  bool disposed = false;

  @override
  Widget view(BuildContext context) =>
      const SizedBox.expand(key: Key('diagram'));

  @override
  Future<void> show(
    String source, {
    required bool dark,
    required Color background,
    required Color foreground,
  }) async => shown.add((source, dark));

  @override
  void dispose() => disposed = true;
}

/// The daemon: each file answered once, its stream kept in [streams] to
/// send it again.
FakeDaemon _fake(Map<String, StreamController<WatchChatFileResponse>> streams) {
  addTearDown(() {
    for (final s in streams.values) {
      unawaited(s.close());
    }
  });
  return FakeDaemon([_chat])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: _chat, items: _items),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      // Closed at the test's end, with the others.
      // ignore: close_sinks
      final s = StreamController<WatchChatFileResponse>();
      streams[input.path] = s;
      s.add(_answer(input.path));
      return s.stream;
    };
}

WatchChatFileResponse _answer(String path, [String? text]) {
  final data = utf8.encode(
    text ?? _files[path] ?? (path.endsWith('.mmd') ? _flow : _csv),
  );
  return WatchChatFileResponse(
    path: '/Users/me/nushi/$path',
    data: data,
    size: Int64(data.length),
  );
}

Future<(Daemon, _Host)> _app(
  WidgetTester tester,
  Map<String, StreamController<WatchChatFileResponse>> streams, {
  List<Uri>? opened,
}) async {
  viewport(tester, const Size(1700, 900));
  showDetails.value = false;
  paneWidths.value = {};
  final host = _Host();
  final (wasHost, wasOpen) = (newPageHost, openInBrowser);
  newPageHost = () => host;
  openInBrowser = (url) async => opened?.add(url);
  addTearDown(() {
    newPageHost = wasHost;
    openInBrowser = wasOpen;
  });
  final d = await _fake(streams).connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, host);
}

Finder get _pane => find.byType(PreviewPane);

Finder _inPane(Finder f) => find.descendant(of: _pane, matching: f);

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<void> _dark(WidgetTester tester) async {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  test('what previews as what', () {
    for (final (path, kind) in [
      ('a/index.html', PreviewKind.html),
      ('INDEX.HTM', PreviewKind.html),
      ('pic.svg', PreviewKind.svg),
      ('report.pdf', PreviewKind.pdf),
      ('data.csv', PreviewKind.csv),
      ('config.json', PreviewKind.code),
      ('ci.yaml', PreviewKind.code),
      ('cmd/main.go', PreviewKind.code),
      ('build.log', PreviewKind.code),
      ('Makefile', PreviewKind.code),
      ('notes.md', PreviewKind.markdown),
      ('logo.png', PreviewKind.image),
      ('docs/flow.mmd', PreviewKind.mermaid),
      ('flow.MERMAID', PreviewKind.mermaid),
      // Binaries, unknown types.
      ('dist/app.zip', null),
      ('bin/nushid', null),
      ('.gitignore', null),
      ('go.sum', null),
    ]) {
      expect(previewKind(path), kind, reason: path);
    }
    expect(PreviewKind.html.page && PreviewKind.html.rendered, isTrue);
    expect(PreviewKind.pdf.page && !PreviewKind.pdf.rendered, isTrue);
    expect(PreviewKind.code.page || PreviewKind.code.rendered, isFalse);
    expect(
      PreviewKind.mermaid.rendered && PreviewKind.mermaid.artifact,
      isTrue,
    );
  });

  test('CSV: quoted commas, quotes and line breaks; the first rows kept', () {
    final (rows, total) = parseCsv(
      'a,b,c\r\n1,"x, y","say ""hi"""\n2,"two\nlines",\n3',
      keep: 3,
    );
    expect(rows, [
      ['a', 'b', 'c'],
      ['1', 'x, y', 'say "hi"'],
      ['2', 'two\nlines', ''],
    ]);
    expect(total, 4);
    final (none, zero) = parseCsv('');
    expect(none, isEmpty);
    expect(zero, 0);
  });

  test('JSON pretty-printed; anything else as it is', () {
    expect(prettyJson('{"a":[1,2]}'), '{\n  "a": [\n    1,\n    2\n  ]\n}');
    expect(prettyJson('{"a": nope'), '{"a": nope');
  });

  test('a page stays in its web view only for itself', () {
    const p = '/Users/me/site/index.html';
    expect(staysInPage('file://$p', p, mainFrame: true), isTrue);
    expect(staysInPage('file://$p#menu', p, mainFrame: true), isTrue);
    expect(staysInPage('about:blank', p, mainFrame: true), isTrue);
    expect(staysInPage('https://example.com/', p, mainFrame: false), isTrue);
    for (final out in [
      'https://example.com/',
      'file:///Users/me/site/other.html',
      'file://host$p',
      'mailto:a@b.c',
    ]) {
      expect(staysInPage(out, p, mainFrame: true), isFalse, reason: out);
    }
    expect(
      pageRoot('/Users/me/nushi/site/index.html', ['/Users/me/nushi']),
      '/Users/me/nushi',
    );
    expect(
      pageRoot('/Users/me/nushi-wt/a.html', [
        '/Users/me/nushi',
        '/Users/me/nushi-wt',
      ]),
      '/Users/me/nushi-wt',
    );
    // Outside them (a file a tool call wrote): its own folder.
    expect(pageRoot('/tmp/notes/a.html', ['/Users/me/nushi']), '/tmp/notes/');
  });

  testWidgets('HTML on the Mac: the web view, live, Reload, Open in browser, '
      'its source', (tester) async {
    final streams = <String, StreamController<WatchChatFileResponse>>{};
    final opened = <Uri>[];
    final (d, host) = await _app(tester, streams, opened: opened);
    d.chats['c']!.openPreview('site/index.html');
    await tester.pumpAndSettle();
    // Loaded from disk, reading files in the chat's folder.
    expect(host.loads, [
      ('/Users/me/nushi/site/index.html', '/Users/me/nushi'),
    ]);
    expect(_inPane(find.byKey(const Key('page'))), findsOneWidget);
    // The header: Live, Preview and Source, Reload, Open in browser at its
    // right edge, before Show in Finder and Close.
    expect(_inPane(find.text('Live')), findsOneWidget);
    final reload = _inPane(find.byTooltip('Reload'));
    final browser = _inPane(find.byTooltip('Open in browser'));
    expect(
      [
        for (final f in [reload, browser, find.byTooltip('Close')])
          tester.getCenter(f).dx,
      ],
      orderedEquals(
        [
          for (final f in [reload, browser, find.byTooltip('Close')])
            tester.getCenter(f).dx,
        ]..sort(),
      ),
    );
    expect(tester.getTopRight(find.byTooltip('Close')).dx, greaterThan(1660));
    await tester.tap(reload);
    expect(host.reloads, 1);
    await tester.tap(browser);
    expect(opened, [Uri.file('/Users/me/nushi/site/index.html')]);
    // Rewritten: read again, not loaded anew.
    streams['site/index.html']!.add(
      _answer('site/index.html', _html.replaceAll('Kettle', 'Pot')),
    );
    await tester.pumpAndSettle();
    expect((host.loads.length, host.reloads), (1, 2));
    // Source: the text, highlighted, the page kept (made once).
    await tester.tap(_inPane(find.text('Source')));
    await tester.pumpAndSettle();
    expect(_inPane(find.byType(SourceView)), findsOneWidget);
    expect(
      _inPane(find.textContaining('<h1>The Still Pot</h1>')),
      findsOneWidget,
    );
    await tester.tap(_inPane(find.text('Preview')));
    await tester.pumpAndSettle();
    expect(host.loads, hasLength(1));
    await tester.tap(_inPane(find.byTooltip('Close')));
    await tester.pumpAndSettle();
    expect(host.disposed, isTrue);
    d.dispose();
  }, variant: _mac);

  testWidgets('SVG and PDF in the web view; a PDF has no Source', (
    tester,
  ) async {
    final streams = <String, StreamController<WatchChatFileResponse>>{};
    final (d, host) = await _app(tester, streams);
    d.chats['c']!.openPreview('site/pic.svg');
    await tester.pumpAndSettle();
    expect(host.loads.single.$1, '/Users/me/nushi/site/pic.svg');
    expect(_inPane(find.text('Source')), findsOneWidget);
    d.chats['c']!.openPreview('report.pdf');
    await tester.pumpAndSettle();
    expect(host.loads.last, ('/Users/me/nushi/report.pdf', '/Users/me/nushi'));
    expect(_inPane(find.text('Source')), findsNothing);
    expect(_inPane(find.byTooltip('Reload')), findsOneWidget);
    // Past the daemon's cap a page still shows: the web view reads it.
    streams['report.pdf']!.add(
      WatchChatFileResponse(
        path: '/Users/me/nushi/report.pdf',
        size: Int64(9 << 20),
        tooLarge: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(_inPane(find.byKey(const Key('page'))), findsOneWidget);
    expect(_inPane(find.textContaining('Too large')), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('a binary has no Preview; code has its source only, and '
      "isn't an artifact", (tester) async {
    final (d, _) = await _app(tester, {});
    // Every file written but the zip and the JSON.
    expect(chatFiles(d.chats['c']!.items), [
      'data.csv',
      'report.pdf',
      'site/pic.svg',
      'site/index.html',
    ]);
    expect(isArtifact('config.json'), isFalse);
    d.chats['c']!.openPreview('config.json');
    await tester.pumpAndSettle();
    expect(_inPane(find.text('Source')), findsNothing);
    expect(_inPane(find.byTooltip('Reload')), findsNothing);
    // Pretty-printed, numbered lines.
    expect(_inPane(find.textContaining('"port": 8080,')), findsOneWidget);
    expect(_inPane(find.text(' 3')), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('golden: a JSON file in the pane, dark', (tester) async {
    final (d, _) = await _app(tester, {});
    await _dark(tester);
    d.chats['c']!.openPreview('config.json');
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
      // The highlighting comes from an isolate.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/preview_code_dark.png'),
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('CSV: a table of the first 500 rows, its source; golden, dark', (
    tester,
  ) async {
    final (d, _) = await _app(tester, {});
    await _dark(tester);
    d.chats['c']!.openPreview('data.csv');
    await tester.pumpAndSettle();
    expect(_inPane(find.text('The first 500 rows of 600.')), findsOneWidget);
    expect(_inPane(find.text('city')), findsOneWidget);
    expect(_inPane(find.text('a note, with a comma')), findsWidgets);
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/preview_csv_dark.png'),
    );
    await tester.tap(_inPane(find.text('Source')));
    await tester.pumpAndSettle();
    expect(
      _inPane(find.textContaining('1,User 1,Osaka,"a note, with a comma"')),
      findsOneWidget,
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('Mermaid on the Mac: drawn by the app’s page, again as it '
      'changes and with the theme; its source', (tester) async {
    final streams = <String, StreamController<WatchChatFileResponse>>{};
    final (d, host) = await _app(tester, streams);
    final diagram = _Diagram();
    final was = newDiagramHost;
    newDiagramHost = () => diagram;
    addTearDown(() => newDiagramHost = was);
    d.chats['c']!.openPreview('docs/flow.mmd');
    await tester.pumpAndSettle();
    expect(diagram.shown, [(_flow, false)]);
    expect(host.loads, isEmpty); // not a page of the agent's
    expect(_inPane(find.byKey(const Key('diagram'))), findsOneWidget);
    expect(_inPane(find.text('Preview')), findsOneWidget);
    expect(_inPane(find.byTooltip('Reload')), findsNothing);
    expect(_inPane(find.byTooltip('Open in browser')), findsNothing);
    streams['docs/flow.mmd']!.add(
      _answer('docs/flow.mmd', _flow.replaceAll('Ship', 'Ship it')),
    );
    await tester.pumpAndSettle();
    expect(diagram.shown.last, (_flow.replaceAll('Ship', 'Ship it'), false));
    await _dark(tester);
    expect(diagram.shown.last.$2, isTrue);
    expect(diagram.shown, hasLength(3));
    await tester.tap(_inPane(find.text('Source')));
    await tester.pumpAndSettle();
    expect(_inPane(find.textContaining('Plan --> Build')), findsOneWidget);
    d.chats['c']!.preview.value = null;
    await tester.pumpAndSettle();
    expect(diagram.disposed, isTrue);
    d.dispose();
  }, variant: _mac);

  group('the phone', () {
    Future<Phone> phone(WidgetTester tester) async {
      viewport(tester, const Size(390, 844), ratio: 3);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final platform = PhonePlatform()..saved = pairedRecord();
      final fake = _fake({});
      final p = Phone(
        platform,
        connectTo: (_) => Daemon(transport: fake, remote: true),
      );
      await tester.pumpWidget(PhoneApp(p));
      await p.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('The landing page'));
      await tester.pumpAndSettle();
      return p;
    }

    Future<void> open(WidgetTester tester, Phone p, String path) async {
      PreviewScreen.open(
        tester.element(find.byType(Navigator).first),
        p.daemon!,
        p.daemon!.chats['c']!,
        path,
      );
      await tester.pumpAndSettle();
    }

    Future<void> end(WidgetTester tester, Phone p) async {
      await endPhone(tester, p);
    }

    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('HTML in a frame, saying its files don’t load; golden', (
      tester,
    ) async {
      final p = await phone(tester);
      await _dark(tester);
      await open(tester, p, 'site/index.html');
      final frame = tester.widget<PageFrame>(find.byType(PageFrame));
      expect(frame.html, _html);
      expect(
        find.text('Files beside it (CSS, images) don’t load here.'),
        findsOneWidget,
      );
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/preview_phone_html_dark.png'),
      );
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      expect(find.textContaining('<h1>The Still Kettle</h1>'), findsOneWidget);
      await end(tester, p);
    }, variant: ios);

    testWidgets('Mermaid in a frame of the app’s page; its source', (
      tester,
    ) async {
      final p = await phone(tester);
      await open(tester, p, 'docs/flow.mmd');
      expect(find.byType(DiagramFrame), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      final frame = tester.widget<PageFrame>(find.byType(PageFrame));
      expect(frame.html, contains('<base href="assets/assets/mermaid/">'));
      expect(frame.html, contains(r'show("graph LR\n  Plan --> Build'));
      expect(
        find.text('Files beside it (CSS, images) don’t load here.'),
        findsNothing,
      );
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Plan --> Build'), findsOneWidget);
      await end(tester, p);
    }, variant: ios);

    testWidgets('a PDF only on the Mac; a CSV as a table, golden', (
      tester,
    ) async {
      final p = await phone(tester);
      await _dark(tester);
      await open(tester, p, 'report.pdf');
      expect(find.text('Open it on your Mac to see it.'), findsOneWidget);
      expect(find.byType(PageFrame), findsNothing);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      await open(tester, p, 'data.csv');
      expect(find.text('The first 500 rows of 600.'), findsOneWidget);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/preview_phone_csv_dark.png'),
      );
      await end(tester, p);
    }, variant: ios);
  });
}
