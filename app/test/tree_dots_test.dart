import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tree_dots.dart';
import 'package:nushi/tree_rows.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The Files tree's dot and a file's change marks agree, both ways (ADR
// 0131): a file is dotted when it differs from the base its marks count
// from, whoever changed it, and the folders holding it are too.

const _root = '/Users/me/nushi';

FolderEntry _dir(String name) => FolderEntry(name: name, kind: 'folder');
FolderEntry _file(String name) => FolderEntry(name: name, kind: 'file');

final Map<String, List<FolderEntry>> _tree = {
  '': [_dir('docs'), _dir('internal'), _dir('notes'), _file('README.md')],
  'docs': [_file('report.md')],
  'internal': [_dir('config')],
  'internal/config': [_file('config.go')],
  'notes': [_file('new.md')],
};

const _config = 'package config\n\nconst Port = 8080\n';

/// The chat wrote docs/report.md (now the same as its base); the user
/// changed internal/config/config.go and added notes/new.md.
final List<Item> _items = [
  Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Write it.'),
  Item(
    id: 'w',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'edit',
    title: 'Write',
    status: 'completed',
    paths: const ['docs/report.md'],
  ),
];

/// The app with the chat's Files pane [open], its folder a repository
/// ([git]) or not, each listing's stream in [listings].
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  bool open = true,
  bool git = true,
  Size size = const Size(1700, 900),
  Brightness? brightness,
  int api = apiVersion,
  Object? Function(Object input)? answer,
  Map<String, StreamController<WatchChatFolderResponse>>? listings,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  filesChats.value = open ? {'c'} : {};
  final c = chat('c', 'claude', 'Write it');
  final fake = FakeDaemon([c])
    ..answer = ((input) =>
        answer?.call(input) ??
        switch (input) {
          GetChatRequest() => GetChatResponse(chat: c, items: _items),
          _ => null,
        })
    ..streams = (input) {
      if (input is! WatchChatFolderRequest) return null;
      final s = StreamController<WatchChatFolderResponse>()
        ..add(
          WatchChatFolderResponse(
            folders: [
              FolderListing(path: input.path, entries: _tree[input.path]),
            ],
          ),
        );
      addTearDown(s.close);
      listings?[input.path] = s;
      return s.stream;
    };
  if (git) fake.repositories.add(_root);
  fake
    ..fileDiffs['$_root/internal/config/config.go'] = FileChange(
      path: 'config.go',
      status: 'modified',
      oldText: 'package config\n',
    )
    ..fileDiffs['$_root/notes/new.md'] = FileChange(
      path: 'new.md',
      status: 'untracked',
    )
    ..files['internal/config/config.go'] = utf8.encode(_config)
    ..files['docs/report.md'] = utf8.encode('# Report\n')
    ..files['notes/new.md'] = utf8.encode('new\n');
  final d = (await fake.connect(tester))
    ..daemonApi = api
    ..select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

Finder _row(String name) => find.ancestor(
  of: find.descendant(of: find.byType(FilesPane), matching: find.text(name)),
  matching: find.byType(TreeRowView),
);

String? _dot(WidgetTester tester, String name) =>
    tester.widget<TreeRowView>(_row(name)).dot;

List<GetDiffRequest> _names(FakeDaemon fake) => [
  for (final r in fake.calls.whereType<GetDiffRequest>())
    if (r.names) r,
];

Future<void> _open(WidgetTester tester, String folder) async {
  await tester.tap(_row(folder));
  await tester.pumpAndSettle();
}

/// Waits out the dots' pause and their answer.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(treeDotsWait);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a file changed from the base is dotted, whoever changed it, '
      'and its folders, closed too; one the chat wrote that equals the '
      'base is not', (tester) async {
    final (d, fake) = await _app(tester);
    expect(_names(fake).single.folder, _root);
    // Closed folders say what's inside.
    expect(_dot(tester, 'internal'), 'holds changed files');
    expect(_dot(tester, 'notes'), 'holds changed files');
    expect(_dot(tester, 'docs'), isNull, reason: 'its file equals the base');
    expect(_dot(tester, 'README.md'), isNull);
    await _open(tester, 'internal');
    expect(_dot(tester, 'config'), 'holds changed files');
    await _open(tester, 'config');
    expect(_dot(tester, 'config.go'), 'changed');
    await _open(tester, 'notes');
    expect(_dot(tester, 'new.md'), 'changed', reason: 'untracked, new');
    await _open(tester, 'docs');
    expect(_dot(tester, 'report.md'), isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('opening a dotted file shows its marks and says so; one the '
      'chat wrote that equals the base says No changes', (tester) async {
    final (d, fake) = await _app(tester);
    final c = d.chats['c']!..openInFiles('internal/config/config.go');
    await tester.pumpAndSettle();
    expect(find.text('2 changed lines since the last commit'), findsOneWidget);
    c.openInFiles('notes/new.md');
    await tester.pumpAndSettle();
    expect(find.text('New file'), findsOneWidget);
    c.openInFiles('docs/report.md');
    await tester.pumpAndSettle();
    expect(find.text('No changes since the last commit'), findsOneWidget);
    // The marks and the dots asked for the same base, found once.
    expect(fake.calls.whereType<GetFolderStatusRequest>(), hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('the dots follow a commit, a turn ending, a listing that '
      'changed and a new base, a moment later', (tester) async {
    final listings = <String, StreamController<WatchChatFolderResponse>>{};
    var branch = 'main';
    final (d, fake) = await _app(
      tester,
      listings: listings,
      answer: (input) => input is GetFolderStatusRequest
          ? GetFolderStatusResponse(
              git: true,
              branch: branch,
              defaultBase: 'main',
            )
          : null,
    );
    final c = d.chats['c']!;
    expect(_names(fake).single.base, isEmpty, reason: 'on main, no commits');
    expect(_dot(tester, 'internal'), 'holds changed files');

    // Committed: config.go is the last commit's now.
    fake.fileDiffs.remove('$_root/internal/config/config.go');
    c.committed();
    await tester.pump();
    expect(_names(fake), hasLength(1), reason: 'not at once');
    await _settle(tester);
    expect(_names(fake), hasLength(2));
    expect(_dot(tester, 'internal'), isNull);

    // Changed on disk, seen in a listing.
    fake.fileDiffs['$_root/README.md'] = FileChange(
      path: 'README.md',
      status: 'modified',
    );
    listings['']!.add(
      WatchChatFolderResponse(
        folders: [FolderListing(path: '', entries: _tree[''])],
      ),
    );
    await _settle(tester);
    expect(_dot(tester, 'README.md'), 'changed');

    // The turn ends on a branch of its own: the base is main's fork.
    branch = 'nushi/fix';
    c
      ..busy = true
      ..notifyListeners();
    await tester.pump();
    c
      ..busy = false
      ..notifyListeners();
    await _settle(tester);
    expect(_names(fake).last.base, 'main');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('outside git, the files the chat wrote keep the dot', (
    tester,
  ) async {
    final (d, fake) = await _app(tester, git: false);
    expect(_names(fake), hasLength(1));
    expect(_dot(tester, 'docs'), 'holds files the chat wrote');
    expect(_dot(tester, 'internal'), isNull);
    await _open(tester, 'docs');
    expect(_dot(tester, 'report.md'), 'the chat wrote it');
    await closeView(tester, d);
  }, variant: onMac);

  for (final (width, brightness) in [
    (1700.0, Brightness.dark),
    if (rendering) (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    if (rendering) (720.0, Brightness.light),
  ]) {
    testWidgets('renders at $width, ${brightness.name}: a changed file open '
        'with its marks, its folders dotted', (tester) async {
      final (d, _) = await _app(
        tester,
        size: Size(width, 900),
        brightness: brightness,
      );
      await _open(tester, 'internal');
      await _open(tester, 'config');
      await _open(tester, 'docs');
      d.chats['c']!.openInFiles('internal/config/config.go');
      await tester.pumpAndSettle();
      expect(
        find.text('2 changed lines since the last commit'),
        findsOneWidget,
      );
      await render(
        tester,
        find.byType(NushiApp),
        'tree_dots_${width.toInt()}_${brightness.name}',
      );
      await closeView(tester, d);
    }, variant: onMac);
  }

  testWidgets('the pane closed asks nothing, even as the chat changes', (
    tester,
  ) async {
    final (d, fake) = await _app(tester, open: false);
    d.chats['c']!.committed();
    await _settle(tester);
    expect(_names(fake), isEmpty);
    await closeView(tester, d);
  }, variant: onMac);
}
