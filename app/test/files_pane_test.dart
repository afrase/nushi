import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_area.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/files_top_row.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pane_tabs.dart';
import 'package:nushi/phone/files_screen.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_path.dart';
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

final List<Item> _items = [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Write the report.',
  ),
  wrote('w1', 'docs/report.md'),
  wrote('w2', 'app/lib/main.dart'),
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
  List<String> git = _gitFiles,
}) async {
  showDetails.value = false;
  filesChats.value = open ? {'c'} : {};
  final folder = _Folder();
  addTearDown(folder.close);
  final previews = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in previews) {
      unawaited(s.close());
    }
  });
  final d = await openApp(
    tester,
    _fake(folder, previews, git: git),
    size: size,
    brightness: brightness,
  );
  return (d, folder);
}

/// The fake daemon on [folder], each preview's stream kept in [previews].
FakeDaemon _fake(
  _Folder folder,
  List<StreamController<WatchChatFileResponse>> previews, {
  List<String> git = _gitFiles,
}) {
  final c = chat('c', 'claude', 'Write the report');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c, items: _items),
      ListFilesRequest() => ListFilesResponse(paths: git),
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

void main() {
  setUpAll(loadFonts);

  group('the pane as Claude desktop has it (ADR 0123)', () {
    testWidgets('no file open: Files alone in its top row, a blank viewer '
        "saying where files come from, the tree at the pane's right", (
      tester,
    ) async {
      final (d, _) = await _app(tester);
      final pane = tester.getRect(_pane);
      final row = find.descendant(
        of: _pane,
        matching: find.byType(FilesTopRow),
      );
      expect(
        find.descendant(of: row, matching: find.text('Files')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(PaneTabs)),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byTooltip('Close tab')),
        findsNothing,
      );
      expect(
        find.descendant(of: _pane, matching: find.byType(PathLine)),
        findsNothing,
      );
      // Claude's words, without its full stops (docs/design.md).
      expect(find.text('Open files appear here'), findsOneWidget);
      expect(
        find.text(
          'Pick a file in the tree, or click a file path in the conversation',
        ),
        findsOneWidget,
      );
      // Centred in the viewer, not the pane.
      final blank = tester.getRect(find.byType(FilesBlank));
      final words = tester.getRect(find.text('Open files appear here'));
      expect(words.center.dx, closeTo(blank.center.dx, 0.5));
      final tree = tester.getRect(find.byType(FilesTree));
      expect(tree.right, pane.right);
      expect(blank.right, tree.left);
      expect(tree.width, 260);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('one file: its name and its ✕ after Files; two: their tabs, '
        'the first name where the one was; the tree never moves', (
      tester,
    ) async {
      final (d, _) = await _app(tester);
      final tree = tester.getRect(find.byType(FilesTree));
      final c = d.chats['c']!..openInFiles('docs/report.md');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FilesTree)), tree);
      final row = find.descendant(
        of: _pane,
        matching: find.byType(FilesTopRow),
      );
      Finder inRow(Finder f) => find.descendant(of: row, matching: f);
      expect(inRow(find.byType(PaneTabs)), findsNothing);
      final name = tester.getRect(inRow(find.text('report.md')));
      expect(inRow(find.byTooltip('Close tab')), findsOneWidget);
      expect(
        name.left,
        greaterThan(tester.getRect(inRow(find.text('Files'))).right),
      );
      c.openInFiles('docs/notes.md');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FilesTree)), tree);
      expect(inRow(find.byType(PaneTabs)), findsOneWidget);
      expect(tester.getRect(inRow(find.text('report.md'))).left, name.left);
      // Its ✕ closes the shown file; the last leaves the viewer blank.
      await tester.tap(inRow(find.byTooltip('Close tab')).last);
      await tester.pumpAndSettle();
      await tester.tap(inRow(find.byTooltip('Close tab')));
      await tester.pumpAndSettle();
      expect(c.fileNames, isEmpty);
      expect(find.byType(FilesBlank), findsOneWidget);
      expect(tester.getRect(find.byType(FilesTree)), tree);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets("the × and the header's button hide the pane and keep its "
        'tabs', (tester) async {
      final (d, _) = await _app(tester);
      final c = d.chats['c']!
        ..openInFiles('docs/report.md')
        ..openInFiles('docs/notes.md');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: _pane, matching: find.byTooltip('Close')),
      );
      await tester.pumpAndSettle();
      expect(_pane, findsNothing);
      expect(c.fileNames, ['docs/report.md', 'docs/notes.md']);
      await tester.tap(find.byType(FilesButton));
      await tester.pumpAndSettle();
      expect(c.shownFile, 'docs/notes.md');
      expect(find.byType(PaneTabs), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);
  });

  testWidgets('the tree hidden: the viewer alone, saying how to go to a '
      'file', (tester) async {
    viewport(tester, const Size(1700, 900));
    showDetails.value = false;
    filesTree.value = false;
    final fake = FakeDaemon([chat('c', 'claude', 'Fix it')]);
    final d = await fake.connect(tester);
    // The pane as the chat's area places it, at its width.
    await tester.pumpWidget(
      themed(
        Center(
          child: SizedBox(
            width: 820,
            height: 700,
            child: FilesPane(chat: d.chats['c']!, daemon: d, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_pane, findsOneWidget);
    expect(find.byType(FilesTree), findsNothing);
    expect(
      tester.getRect(find.byType(FilesBlank)).width,
      tester.getSize(_pane).width,
    );
    expect(
      find.text(
        'Go to a file with ⌘P, or click a file path in the '
        'conversation',
      ),
      findsOneWidget,
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⇧⌘E opens the tree: folders first, what git ignores left out '
      'until the eye shows it, dimmed', (tester) async {
    final (d, folder) = await _app(tester, open: false);
    expect(_pane, findsNothing);
    await press(tester, LogicalKeyboardKey.keyE, cmd: true, shift: true);
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
    expect(d.chats['c']!.files.shown.value, isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a folder opens as it is clicked, listed then; a file opens in '
      'the preview; outside git, what the chat wrote is marked', (
    tester,
  ) async {
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
    expect(_view(tester, 'docs').dot, 'holds files the chat wrote');
    expect(
      _view(tester, 'app').dot,
      'holds files the chat wrote',
    ); // app/lib/main.dart
    expect(_view(tester, 'report.md').dot, 'the chat wrote it');
    expect(_view(tester, 'img').dot, isNull);
    await tester.tap(_row('report.md'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.shownFile, 'docs/report.md');
    expect(find.byType(FileView), findsOneWidget);
    expect(_view(tester, 'report.md').showing, isTrue);
    // Closed, its listing ends; the tree keeps that it was open.
    await tester.tap(_row('docs'));
    await tester.pumpAndSettle();
    expect(_names(tester), isNot(contains('report.md')));
    expect(folder.streams['docs']!.hasListener, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a file opened opens the pane, and a click on its name shows '
      'it in the tree: the folders above it open, its row selected', (
    tester,
  ) async {
    final (d, folder) = await _app(tester, open: false);
    final c = d.chats['c']!..openInFiles('app/lib/main.dart');
    await tester.pumpAndSettle();
    expect(_pane, findsOneWidget);
    // Opening it moves nothing in the tree.
    expect(_names(tester).take(2), ['app', 'docs']);
    final name = find.descendant(
      of: find.byType(FilesPane),
      matching: find.text('main.dart'),
    );
    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(_pane, findsOneWidget);
    expect(filesChats.value, {'c'});
    expect(
      folder.asked.map((r) => r.path),
      containsAll(['', 'app', 'app/lib']),
    );
    expect(_names(tester).take(4), ['app', 'lib', 'main.dart', 'pubspec.yaml']);
    expect(_view(tester, 'main.dart').selected, isTrue);
    expect(_view(tester, 'main.dart').showing, isTrue);
    expect(c.shownFile, 'app/lib/main.dart', reason: 'the preview stays');
    // Open already, it goes to another file the same way.
    c
      ..files.close(const PreviewFile('app/lib/main.dart'))
      ..openInFiles('docs/report.md');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FilesPane),
        matching: find.text('report.md'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_view(tester, 'report.md').selected, isTrue);
    expect(_view(tester, 'main.dart').selected, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a file git ignores, while they’re hidden: the pane opens at '
      'its folder, and nothing scrolls to it later', (tester) async {
    final (d, folder) = await _app(tester, open: false);
    folder.tree['docs']!.add(_file('draft.md', ignored: true));
    final c = d.chats['c']!..openInFiles('docs/draft.md');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FilesPane),
        matching: find.text('draft.md'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_pane, findsOneWidget);
    expect(_names(tester), isNot(contains('draft.md')));
    expect(_view(tester, 'docs').selected, isTrue, reason: 'its folder');
    expect(folderTreeOf(c).revealing, isNull, reason: 'given up');
    // Shown now, it's listed where it is, and the keys stay put.
    filesIgnored.value = true;
    await tester.pumpAndSettle();
    expect(_names(tester), contains('draft.md'));
    expect(_view(tester, 'draft.md').selected, isFalse);
    expect(_view(tester, 'docs').selected, isTrue);
    // In an ignored folder, nothing above it shows: nothing is selected.
    filesIgnored.value = false;
    folder.tree['node_modules/left-pad'] = [_file('index.md', ignored: true)];
    c
      ..files.close(const PreviewFile('docs/draft.md'))
      ..openInFiles('node_modules/left-pad/index.md');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FilesPane),
        matching: find.text('index.md'),
      ),
    );
    await tester.pumpAndSettle();
    expect(folderTreeOf(c).revealing, isNull);
    expect(folderTreeOf(c).selected, isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a file outside the chat’s folder: its name does nothing', (
    tester,
  ) async {
    final (d, _) = await _app(tester, open: false);
    d.chats['c']!.openInFiles('/Users/me/elsewhere/notes.md');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FilesPane),
        matching: find.text('notes.md'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_pane, findsOneWidget);
    expect(folderTreeOf(d.chats['c']!).selected, isNull);
    expect(folderTreeOf(d.chats['c']!).open, isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

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
    expect(d.chats['c']!.shownFile, 'app/lib/main.dart');
    await _key(tester, LogicalKeyboardKey.arrowLeft); // up to lib
    expect(folderTreeOf(d.chats['c']!).selected, 'app/lib');
    await _key(tester, LogicalKeyboardKey.arrowLeft); // closes it
    expect(_names(tester), isNot(contains('main.dart')));
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.enter); // closes app
    expect(_names(tester).first, 'app');
    expect(_names(tester), isNot(contains('lib')));
    await closeView(tester, d);
  }, variant: onMac);

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
    expect(d.chats['c']!.shownFile, 'app/lib/widgets/tree_view.dart');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_names(tester).first, 'app');
    expect(_names(tester), isNot(contains('widgets')));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Search files… with the eye at its end; past its 200 best '
      'matches it says some may not be listed', (tester) async {
    final (d, _) = await _app(
      tester,
      git: [for (var i = 0; i < 250; i++) 'gen/part$i.dart'],
    );
    final field = find.descendant(of: _pane, matching: find.byType(TextField));
    expect(
      tester.widget<TextField>(field).decoration!.hintText,
      'Search files…',
    );
    expect(
      find.descendant(
        of: field,
        matching: find.byTooltip('Show what git ignores'),
      ),
      findsOneWidget,
    );
    const note = 'Some entries may not be listed. Keep typing to narrow.';
    await tester.enterText(field, 'part');
    await tester.pumpAndSettle();
    // 250 match: the best 200 show, and after them the note, with its
    // full stops.
    await tester.drag(find.byType(FilesTree), const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(find.text(note), findsOneWidget);
    final last = tester.getRect(find.byType(TreeRowView).last);
    expect(tester.getRect(find.text(note)).top, greaterThan(last.bottom));
    await render(tester, find.byType(NushiApp), 'files_search_capped');
    // Narrowed to 111: no note.
    await tester.enterText(field, 'part1');
    await tester.pumpAndSettle();
    expect(find.text(note), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a filter isn’t worked out again as the chat streams, only '
      'as the query, the tree or git’s list changes', (tester) async {
    final (d, folder) = await _app(tester);
    final field = find.descendant(of: _pane, matching: find.byType(TextField));
    await tester.enterText(field, 'tree');
    await tester.pumpAndSettle();
    final row = _view(tester, 'tree_view.dart').row;
    // A chunk of the agent's text: the chat notifies, the pane rebuilds.
    d.chats['c']!.notifyListeners();
    await tester.pump();
    expect(_view(tester, 'tree_view.dart').row, same(row));
    // The tree lists again: worked out again.
    folder.changed('');
    await tester.pumpAndSettle();
    expect(_view(tester, 'tree_view.dart').row, isNot(same(row)));
    await closeView(tester, d);
  }, variant: onMac);

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
  }, variant: onMac);

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
  }, variant: onMac);

  testWidgets('a row shows a bidi override in its name and its tooltip', (
    tester,
  ) async {
    // invoice\u202efdp.sh would read as invoicehs.pdf (docs/security.md).
    const name = 'invoice\u202efdp.sh';
    await tester.pumpWidget(
      themed(
        TreeRowView(
          const TreeRow('docs/$name', name, 1, TreeRowKind.file),
          selected: false,
          showing: false,
          dot: null,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('invoice\ufffdfdp.sh'), findsOneWidget);
    expect(find.textContaining('\u202e'), findsNothing);
    final tip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tip.message, startsWith('docs/invoice\ufffdfdp.sh'));
  });

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
    if (rendering) ('light', Brightness.light),
  ]) {
    testWidgets("the phone: Files in the chat's sheet, the same tree, a "
        'file full screen, $name', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 3, brightness: brightness);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final folder = _Folder();
      addTearDown(folder.close);
      final previews = <StreamController<WatchChatFileResponse>>[];
      addTearDown(() {
        for (final s in previews) {
          unawaited(s.close());
        }
      });
      final fake = _fake(folder, previews);
      final phone = await startPhone(tester, fake);
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
      // A tap opens a file full screen: no tab to keep, so no double
      // click's Listener over a row (the desktop's tree has one).
      for (final row in find.byType(TreeRowView).evaluate()) {
        Widget? parent;
        row.visitAncestorElements((e) {
          parent = e.widget;
          return false;
        });
        expect(parent, isNot(isA<Listener>()));
      }
      await render(tester, find.byType(PhoneApp), 'files_phone_$name');
      await tester.tap(find.text('report.md'));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewScreen), findsOneWidget);
      await endPhone(tester, phone);
    }, variant: onPhone);

    for (final (size, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
      testWidgets('renders: the tree right of the open file, $size, $name', (
        tester,
      ) async {
        final (d, _) = await _app(
          tester,
          size: Size(width, 900),
          brightness: brightness,
        );
        expect(find.byType(FilesBlank), findsOneWidget);
        await render(
          tester,
          find.byType(NushiApp),
          'files_blank_${size}_$name',
        );
        final tree = tester.getRect(find.byType(FilesTree));
        await tester.tap(_row('docs'));
        await tester.pumpAndSettle();
        await tester.tap(_row('img'));
        await tester.pumpAndSettle();
        await tester.tap(_row('report.md'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final pane = tester.getRect(_pane);
        // Narrow, over the transcript, it and the preview are narrowed
        // alike to fit the chat's pane, from its left edge (ADR 0123).
        expect(pane.width, greaterThanOrEqualTo(180));
        expect(
          pane.left,
          greaterThanOrEqualTo(tester.getRect(find.byType(ChatArea)).left),
        );
        // The tree at the pane's right edge, the file left of it; opening
        // the file moved the tree not at all.
        expect(tester.getRect(find.byType(FilesTree)), tree);
        expect(tree.right, pane.right);
        expect(tester.getRect(find.byType(FileView)).right, tree.left);
        expect(tester.getRect(find.byType(FileView)).left, pane.left);
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'files_${size}_$name');
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
