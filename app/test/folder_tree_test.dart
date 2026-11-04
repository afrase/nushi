// A chat's folder as the Files pane lists it (FolderTree): kept for the
// chat while the app runs, and let go with it.

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/folder_tree.dart';

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
}
