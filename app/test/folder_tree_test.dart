// A chat's folder as the Files pane lists it (FolderTree): kept for the
// chat while the app runs, and let go with it; and git's list of its files
// for the pane's filter (GitFiles).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  // The tree hangs on its chat alone (an Expando), so it goes with the
  // chat once nothing else holds it: what could is the daemon's stream of
  // the listing and the pref a shown tree follows.
  testWidgets('a chat whose Files pane was opened is freed with its tree: '
      'closed, neither the listing nor the pref holds it', (tester) async {
    final watches = <StreamController<WatchChatFolderResponse>>[];
    final fake = FakeDaemon([])
      ..streams = (input) {
        if (input is! WatchChatFolderRequest) return null;
        watches.add(StreamController<WatchChatFolderResponse>());
        return watches.last.stream;
      };
    final d = await fake.connect(tester);
    final chat = ChatState('c', '/tmp/c');
    final tree = folderTreeOf(chat)..attach(d);
    await tester.pump();
    expect(watches.single.hasListener, isTrue); // the pane listed it
    expect(folderTreeOf(chat), same(tree));
    final told = tree.revision;
    filesIgnored.value = !filesIgnored.value;
    await tester.pump();
    expect(tree.revision, greaterThan(told), reason: 'shown, it follows');
    expect(watches, hasLength(2), reason: 'and lists again');

    tree.detach();
    await tester.pump();
    expect(watches.every((w) => !w.hasListener), isTrue);
    final closed = tree.revision;
    filesIgnored.value = !filesIgnored.value;
    await tester.pump();
    expect(tree.revision, closed);
    expect(watches, hasLength(2));
    await closeView(tester, d);
  });

  testWidgets("git's list is one per folder: a moved chat's is asked at "
      "once, and the old folder's late answer stays the old folder's", (
    tester,
  ) async {
    final old = Completer<ListFilesResponse>();
    final asked = <String>[];
    final fake = FakeDaemon([])
      ..answer = (input) {
        if (input is! ListFilesRequest) return null;
        asked.add(input.folder);
        return input.folder == '/old'
            ? old.future
            : ListFilesResponse(paths: ['new.dart']);
      };
    final d = await fake.connect(tester);
    expect(gitFilesOf('/old'), same(gitFilesOf('/old')));
    gitFilesOf('/old').ask(d);
    // Moved a moment later: asked at once, not after the 5 seconds.
    gitFilesOf('/new').ask(d);
    await tester.pump();
    expect(asked, ['/old', '/new']);
    expect(gitFilesOf('/new').paths, ['new.dart']);
    old.complete(ListFilesResponse(paths: ['old.dart']));
    await tester.pump();
    expect(gitFilesOf('/new').paths, ['new.dart']);
    expect(gitFilesOf('/old').paths, ['old.dart']);
    // Asked again within a few seconds: what it has, no listing.
    gitFilesOf('/new').ask(d);
    await tester.pump();
    expect(asked, ['/old', '/new']);
    await closeView(tester, d);
  });

  testWidgets("a listing that fails keeps git's last list and says why; the "
      'next that answers clears it', (tester) async {
    var fail = false;
    final fake = FakeDaemon([])
      ..answer = (input) => switch (input) {
        ListFilesRequest() when fail => throw Exception('folder gone'),
        ListFilesRequest() => ListFilesResponse(paths: ['a.dart']),
        _ => null,
      };
    final d = await fake.connect(tester);
    final git = gitFilesOf('/x');
    expect(git.listed, isFalse);
    git.ask(d);
    await tester.pump();
    expect(git.paths, ['a.dart']);
    expect((git.error, git.listed), ('', true));
    fail = true;
    clock = () => fixtureNow.add(const Duration(seconds: 6));
    git.ask(d);
    await tester.pump();
    expect(git.paths, ['a.dart']);
    expect(git.error, contains('folder gone'));
    fail = false;
    clock = () => fixtureNow.add(const Duration(seconds: 12));
    git.ask(d);
    await tester.pump();
    expect(git.error, isEmpty);
    await closeView(tester, d);
  });

  testWidgets('revealing a file in a folder git ignores, while they’re '
      'hidden, watches no folder that has no row', (tester) async {
    final live = <String>{};
    final fake = FakeDaemon([])
      ..streams = (input) {
        if (input is! WatchChatFolderRequest) return null;
        final s = StreamController<WatchChatFolderResponse>();
        addTearDown(s.close);
        live.add(input.path);
        s
          ..onCancel = (() => live.remove(input.path))
          // What git ignores is left out: the chat's folder shows src/ only.
          ..add(
            WatchChatFolderResponse(
              folders: [
                FolderListing(
                  path: input.path,
                  entries: [
                    if (input.path.isEmpty)
                      FolderEntry(name: 'src', kind: 'folder'),
                  ],
                ),
              ],
            ),
          );
        return s.stream;
      };
    final d = await fake.connect(tester);
    final tree = folderTreeOf(ChatState('c', '/tmp/c'))..attach(d);
    await tester.pump();
    tree.reveal('node_modules/pkg/dist/index.js');
    await tester.pump();
    expect(tree.settleReveal(tree.rows()), '');
    await tester.pump();
    expect(live, {''});
    // Opened before the folder above lists, it's let go once that comes.
    tree.reveal('build/out/a.js');
    expect(tree.rows().map((r) => r.path), ['src']);
    await tester.pump();
    expect(live, {''});
    tree.detach();
    await tester.pump();
    await closeView(tester, d);
  });

  testWidgets('the filter looks only in folders that show, and drops what '
      'git ignores as they hide', (tester) async {
    var asked = 0;
    final fake = FakeDaemon([])
      ..streams = (input) {
        if (input is! WatchChatFolderRequest) return null;
        final s = StreamController<WatchChatFolderResponse>();
        addTearDown(s.close);
        // Asked again with the ignored hidden, it hasn't answered yet.
        if (asked++ > 1) return s.stream;
        final all = switch (input.path) {
          '' => [
            FolderEntry(name: 'build', kind: 'folder', ignored: true),
            FolderEntry(name: 'debug.log', kind: 'file', ignored: true),
            FolderEntry(name: 'main.dart', kind: 'file'),
          ],
          'build' => [FolderEntry(name: 'out.js', kind: 'file', ignored: true)],
          _ => <FolderEntry>[],
        };
        s.add(
          WatchChatFolderResponse(
            folders: [FolderListing(path: input.path, entries: all)],
          ),
        );
        return s.stream;
      };
    final d = await fake.connect(tester);
    filesIgnored.value = true;
    final tree = folderTreeOf(ChatState('c', '/tmp/c'))..attach(d);
    await tester.pump();
    tree.setOpen('build', open: true);
    await tester.pump();
    expect(tree.listedFiles, containsAll(['build/out.js', 'debug.log']));
    tree.setOpen('build', open: false);
    await tester.pump();
    expect(tree.listedFiles, isNot(contains('build/out.js')));
    filesIgnored.value = false;
    await tester.pump();
    expect(tree.listedFiles, ['main.dart']);
    expect(tree.rows().map((r) => r.path), ['main.dart']);
    tree.detach();
    await tester.pump();
    await closeView(tester, d);
  });

  testWidgets('an open folder git ignores is watched again as soon as the '
      'listing above has it, with no rows asked (a filter typed)', (
    tester,
  ) async {
    final live = <String>{};
    final fake = FakeDaemon([])
      ..streams = (input) {
        if (input is! WatchChatFolderRequest) return null;
        final s = StreamController<WatchChatFolderResponse>();
        addTearDown(s.close);
        live.add(input.path);
        final entries = switch (input.path) {
          '' => [
            if (input.ignored)
              FolderEntry(name: 'build', kind: 'folder', ignored: true),
            FolderEntry(name: 'main.dart', kind: 'file'),
          ],
          'build' => [FolderEntry(name: 'out.js', kind: 'file', ignored: true)],
          _ => <FolderEntry>[],
        };
        s
          ..onCancel = (() => live.remove(input.path))
          ..add(
            WatchChatFolderResponse(
              folders: [FolderListing(path: input.path, entries: entries)],
            ),
          );
        return s.stream;
      };
    final d = await fake.connect(tester);
    filesIgnored.value = true;
    final tree = folderTreeOf(ChatState('c', '/tmp/c'))..attach(d);
    await tester.pump();
    tree.setOpen('build', open: true);
    await tester.pump();
    expect(live, {'', 'build'});
    filesIgnored.value = false;
    await tester.pump();
    filesIgnored.value = true;
    await tester.pump();
    await tester.pump();
    expect(live, {'', 'build'});
    expect(tree.listedFiles, contains('build/out.js'));
    tree.detach();
    await tester.pump();
    await closeView(tester, d);
  });
}
