import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/files_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tree_rows.dart';

import 'fake_daemon.dart';
import 'harness.dart';

FolderEntry _dir(String name, {bool ignored = false}) =>
    FolderEntry(name: name, kind: 'folder', ignored: ignored);

FolderEntry _file(String name, {int size = 1200, bool ignored = false}) =>
    FolderEntry(
      name: name,
      kind: 'file',
      size: Int64(size),
      modifiedMs: Int64(
        fixtureNow.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      ),
      ignored: ignored,
    );

/// The chat's folder as the fake daemon lists it, by folder.
Map<String, List<FolderEntry>> _folder() => {
  '': [
    _dir('app'),
    _dir('docs'),
    _dir('node_modules', ignored: true),
    _file('.env', ignored: true),
    _file('build.zip'),
    _file('logo.png'),
    _file('Makefile'),
    _file('README.md'),
  ],
  'docs': [_dir('img'), _file('report.md', size: 4200)],
  'docs/img': [_file('chart.png')],
  'app': [_dir('lib'), _file('pubspec.yaml')],
  'app/lib': [_file('main.dart')],
  'node_modules': [_dir('left-pad', ignored: true)],
};

/// Git's files: deeper than anything listed so far.
const _gitFiles = [
  'README.md',
  'Makefile',
  'app/pubspec.yaml',
  'app/lib/main.dart',
  'app/lib/widgets/tree_view.dart',
  'app/lib/widgets/tree_row.dart',
  'docs/report.md',
];

Item _write(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

final List<Item> _items = [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Write the report.',
  ),
  _write('w1', 'docs/report.md'),
  _write('w2', 'app/lib/main.dart'),
];

/// The fake daemon's side: the folder, each listing stream open by
/// folder, and what was asked.
class _Folder {
  final Map<String, List<FolderEntry>> tree = _folder();
  final streams = <String, StreamController<WatchChatFolderResponse>>{};
  final asked = <WatchChatFolderRequest>[];

  WatchChatFolderResponse listing(String path, {required bool ignored}) =>
      WatchChatFolderResponse(
        folders: [
          FolderListing(
            path: path,
            entries: [
              for (final e in tree[path] ?? const <FolderEntry>[])
                if (ignored || !e.ignored) e,
            ],
          ),
        ],
      );

  Stream<WatchChatFolderResponse> watch(WatchChatFolderRequest r) {
    asked.add(r);
    // Closed by close, or by the next stream of its folder.
    // ignore: close_sinks
    final s = StreamController<WatchChatFolderResponse>()
      ..add(listing(r.path, ignored: r.ignored));
    unawaited(streams[r.path]?.close());
    streams[r.path] = s;
    return s.stream;
  }

  /// [path] changed: its stream sends it again.
  void changed(String path) => streams[path]!.add(
    listing(path, ignored: asked.lastWhere((r) => r.path == path).ignored),
  );

  void close() {
    for (final s in streams.values) {
      unawaited(s.close());
    }
  }
}

/// The app on a chat whose Files pane is open, at [size].
Future<(Daemon, _Folder)> _app(
  WidgetTester tester, {
  Size size = const Size(1700, 900),
  Brightness? brightness,
  bool open = true,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  filesChats.value = open ? {'c'} : {};
  filesIgnored.value = false;
  final folder = _Folder();
  addTearDown(folder.close);
  final previews = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in previews) {
      unawaited(s.close());
    }
  });
  final d = await _fake(folder, previews).connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, folder);
}

/// The fake daemon on [folder], each preview's stream kept in [previews].
FakeDaemon _fake(
  _Folder folder,
  List<StreamController<WatchChatFileResponse>> previews,
) {
  final c = chat('c', 'claude', 'Write the report');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c, items: _items),
      ListFilesRequest() => ListFilesResponse(paths: _gitFiles),
      _ => null,
    })
    ..streams = (input) {
      if (input is WatchChatFolderRequest) return folder.watch(input);
      if (input is! WatchChatFileRequest) return null;
      final text = '# ${input.path}\n\nThe report.\n';
      final s = StreamController<WatchChatFileResponse>()
        ..add(
          WatchChatFileResponse(
            path: '/Users/me/nushi/${input.path}',
            data: utf8.encode(text),
            size: Int64(text.length),
          ),
        );
      previews.add(s);
      return s.stream;
    };
}

Finder get _pane => find.byType(FilesPane);

Finder _row(String name) => _rowIn(_pane, name);

Finder _rowIn(Finder of, String name) => find.ancestor(
  of: find.descendant(of: of, matching: find.text(name)),
  matching: find.byType(TreeRowView),
);

/// The rows' names, top to bottom.
List<String> _names(WidgetTester tester) => [
  for (final e in find.byType(TreeRowView).evaluate())
    switch ((e.widget as TreeRowView).row) {
      final r when r.entry => r.name,
      final r => '(${r.kind == TreeRowKind.more ? '${r.count} more' : r.note})',
    },
];

TreeRowView _view(WidgetTester tester, String name) =>
    tester.widget<TreeRowView>(_row(name));

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('⇧⌘E opens the tree: folders first, what git ignores left out '
      'until the eye shows it, dimmed', (tester) async {
    final (d, folder) = await _app(tester, open: false);
    expect(_pane, findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(_pane, findsOneWidget);
    expect(filesChats.value, {'c'});
    expect(_names(tester), [
      'app',
      'docs',
      'build.zip',
      'logo.png',
      'Makefile',
      'README.md',
    ]);
    expect(folder.asked.single.path, '');
    expect(folder.asked.single.ignored, isFalse);
    await tester.tap(find.byTooltip('Show what git ignores'));
    await tester.pumpAndSettle();
    expect(filesIgnored.value, isTrue);
    expect(folder.asked.last.ignored, isTrue);
    expect(_names(tester), containsAllInOrder(['node_modules', '.env']));
    expect(_view(tester, 'node_modules').row.ignored, isTrue);
    // A file nothing previews is dimmed and opens nothing.
    expect(_view(tester, 'build.zip').row.opens, isFalse);
    await tester.tap(_row('build.zip'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.preview.value, isNull);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a folder opens as it is clicked, listed then; a file opens in '
      'the preview; what the chat wrote is marked', (tester) async {
    final (d, folder) = await _app(tester);
    await tester.tap(_row('docs'));
    await tester.pumpAndSettle();
    expect(folder.asked.map((r) => r.path), ['', 'docs']);
    expect(_names(tester).take(5), [
      'app',
      'docs',
      'img',
      'report.md',
      'build.zip',
    ]);
    expect(_view(tester, 'docs').wrote, isTrue);
    expect(_view(tester, 'app').wrote, isTrue); // app/lib/main.dart
    expect(_view(tester, 'report.md').wrote, isTrue);
    expect(_view(tester, 'img').wrote, isFalse);
    await tester.tap(_row('report.md'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.preview.value, 'docs/report.md');
    expect(find.byType(PreviewPane), findsOneWidget);
    expect(_view(tester, 'report.md').showing, isTrue);
    // Closed, its listing ends; the tree keeps that it was open.
    await tester.tap(_row('docs'));
    await tester.pumpAndSettle();
    expect(_names(tester), isNot(contains('report.md')));
    expect(folder.streams['docs']!.hasListener, isFalse);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('↑↓ move, → opens a folder and goes in, ← closes it and goes '
      'up, ⏎ opens a file', (tester) async {
    final (d, _) = await _app(tester);
    await tester.tap(_row('app')); // opens app
    await tester.pumpAndSettle();
    expect(folderTreeOf(d.chats['c']!).selected, 'app');
    await _key(tester, LogicalKeyboardKey.arrowDown); // lib
    await _key(tester, LogicalKeyboardKey.arrowRight); // opens lib
    expect(_names(tester).take(4), ['app', 'lib', 'main.dart', 'pubspec.yaml']);
    await _key(tester, LogicalKeyboardKey.arrowRight); // into it
    expect(folderTreeOf(d.chats['c']!).selected, 'app/lib/main.dart');
    expect(_view(tester, 'main.dart').selected, isTrue);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(d.chats['c']!.preview.value, 'app/lib/main.dart');
    await _key(tester, LogicalKeyboardKey.arrowLeft); // up to lib
    expect(folderTreeOf(d.chats['c']!).selected, 'app/lib');
    await _key(tester, LogicalKeyboardKey.arrowLeft); // closes it
    expect(_names(tester), isNot(contains('main.dart')));
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.enter); // closes app
    expect(_names(tester).first, 'app');
    expect(_names(tester), isNot(contains('lib')));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the filter finds any file by name, in folders not opened '
      'yet, as a tree; ⏎ opens the best; Esc clears it', (tester) async {
    final (d, _) = await _app(tester);
    await tester.enterText(
      find.descendant(of: _pane, matching: find.byType(TextField)),
      'tree',
    );
    await tester.pumpAndSettle();
    expect(_names(tester), [
      'app',
      'lib',
      'widgets',
      'tree_row.dart',
      'tree_view.dart',
    ]);
    // Letters in order count too: "trvw" finds tree_view.
    await tester.enterText(
      find.descendant(of: _pane, matching: find.byType(TextField)),
      'trvw',
    );
    await tester.pumpAndSettle();
    expect(_names(tester).last, 'tree_view.dart');
    expect(_view(tester, 'tree_view.dart').selected, isTrue);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(d.chats['c']!.preview.value, 'app/lib/widgets/tree_view.dart');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_names(tester).first, 'app');
    expect(_names(tester), isNot(contains('widgets')));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a change comes in: the tree keeps what is open and selected', (
    tester,
  ) async {
    final (d, folder) = await _app(tester);
    await tester.tap(_row('docs'));
    await tester.pumpAndSettle();
    await tester.tap(_row('report.md'));
    await tester.pumpAndSettle();
    folder.tree['']!.insert(3, _file('NOTES.md'));
    folder.tree['docs']!.add(_file('summary.md'));
    folder
      ..changed('')
      ..changed('docs');
    await tester.pumpAndSettle();
    expect(
      _names(tester),
      containsAllInOrder([
        'docs',
        'img',
        'report.md',
        'summary.md',
        'NOTES.md',
      ]),
    );
    expect(_view(tester, 'report.md').selected, isTrue);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a big folder says how many more', (tester) async {
    final (d, folder) = await _app(tester);
    folder.streams['']!.add(
      WatchChatFolderResponse(
        folders: [
          FolderListing(path: '', entries: [_file('a.md')], more: 1234),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(_names(tester), ['a.md', '(1234 more)']);
    await closeView(tester, d);
  }, variant: _mac);

  test('matchScore: the name before the path, its start first, letters in '
      'order last', () {
    int s(String p, String q) => matchScore(p, q)!;
    expect(s('src/tree.dart', 'tree'), lessThan(s('src/a_tree.dart', 'tree')));
    expect(s('src/a_tree.dart', 'tree'), lessThan(s('tree/a.dart', 'tree')));
    expect(s('tree/a.dart', 'tree'), lessThan(s('src/t_r_e_e.dart', 'tree')));
    expect(matchScore('src/a.dart', 'tree'), isNull);
    expect(matchScore('app/lib/main.dart', 'lib main'), isNotNull);
  });

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets("the phone: Files in the chat's sheet, the same tree, a "
        'file full screen, $name', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 3, brightness: brightness);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      filesIgnored.value = false;
      final folder = _Folder();
      addTearDown(folder.close);
      final previews = <StreamController<WatchChatFileResponse>>[];
      addTearDown(() {
        for (final s in previews) {
          unawaited(s.close());
        }
      });
      final fake = _fake(folder, previews);
      final phone = Phone(
        PhonePlatform()..saved = pairedRecord(),
        connectTo: (_) => Daemon(transport: fake, remote: true),
      );
      await tester.pumpWidget(PhoneApp(phone));
      await phone.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('Write the report'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      expect(find.byType(FilesScreen), findsOneWidget);
      await tester.tap(find.text('docs'));
      await tester.pumpAndSettle();
      expect(_names(tester).take(4), ['app', 'docs', 'img', 'report.md']);
      // Each row is a touch target.
      expect(
        tester.getSize(_rowIn(find.byType(FilesScreen), 'img')).height,
        greaterThanOrEqualTo(44),
      );
      await render(tester, find.byType(PhoneApp), 'files_phone_$name');
      await tester.tap(find.text('report.md'));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewScreen), findsOneWidget);
      await endPhone(tester, phone);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    for (final (size, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
      testWidgets('renders: the tree beside a preview, $size, $name', (
        tester,
      ) async {
        final (d, _) = await _app(
          tester,
          size: Size(width, 900),
          brightness: brightness,
        );
        await tester.tap(_row('docs'));
        await tester.pumpAndSettle();
        await tester.tap(_row('img'));
        await tester.pumpAndSettle();
        await tester.tap(_row('report.md'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final pane = tester.getRect(_pane);
        expect(pane.width, greaterThanOrEqualTo(200));
        expect(tester.getRect(find.byType(PreviewPane)).left, pane.right);
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'files_${size}_$name');
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
