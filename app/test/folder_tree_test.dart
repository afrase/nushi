// A chat's folder as the Files pane lists it (FolderTree): kept for the
// chat while the app runs, and let go with it; and git's list of its files
// for the pane's filter (GitFiles).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// Makes a tree for a chat no one else holds, and shows it in a pane that
/// then closes.
WeakReference<FolderTree> _shown(Daemon daemon) {
  final tree = folderTreeOf(ChatState('c', '/tmp/c'))..attach(daemon);
  return WeakReference(tree..detach());
}

void main() {
  testWidgets('a chat whose Files pane was opened is freed with its tree', (
    tester,
  ) async {
    var watched = 0;
    final fake = FakeDaemon([])
      ..streams = (input) {
        if (input is! WatchChatFolderRequest) return null;
        watched++;
        return StreamController<WatchChatFolderResponse>().stream;
      };
    final d = await fake.connect(tester);
    final tree = _shown(d);
    await tester.pump();
    expect(watched, 1); // the pane listed it
    // Garbage until the VM collects; a held tree never goes.
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && tree.target != null; i++) {
        final garbage = [
          for (var j = 0; j < 1000; j++) List<int>.filled(100, j),
        ];
        expect(garbage, isNotEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    expect(tree.target, isNull);
    await closeView(tester, d);
  });

  testWidgets("git's list follows a moved chat to its new folder", (
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
    final git = GitFiles();
    addTearDown(git.dispose);
    git
      ..ask(d, '/old')
      // Moved a moment later: asked at once, not after the 5 seconds.
      ..ask(d, '/new');
    await tester.pump();
    expect(asked, ['/old', '/new']);
    expect(git.paths, ['new.dart']);
    // The old folder's answer, late, is let go.
    old.complete(ListFilesResponse(paths: ['old.dart']));
    await tester.pump();
    expect(git.paths, ['new.dart']);
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
}
