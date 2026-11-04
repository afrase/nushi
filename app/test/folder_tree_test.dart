// A chat's folder as the Files pane lists it (FolderTree): kept for the
// chat while the app runs, and let go with it; and git's list of its files
// for the pane's filter (GitFiles).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// Makes a tree for a chat no one else holds.
WeakReference<FolderTree> _tree() =>
    WeakReference(folderTreeOf(ChatState('c', '/tmp/c')));

void main() {
  test('a chat whose Files pane was opened is freed with its tree', () async {
    final tree = _tree();
    // Garbage until the VM collects; a held tree never goes.
    for (var i = 0; i < 200 && tree.target != null; i++) {
      final garbage = [for (var j = 0; j < 1000; j++) List<int>.filled(100, j)];
      expect(garbage, isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(tree.target, isNull);
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
}
