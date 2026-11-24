import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'panes_app.dart';

// The Files pane's listings and a file's watch, which the daemon polls each
// second (ADR 0090), end while the window is hidden, what they showed still
// showing, and start again once it shows.

void main() {
  setUpAll(loadFonts);

  testWidgets('hidden, the Files and Preview streams end, what showed still '
      'shows; shown again, they start again', (tester) async {
    final (d, fake) = await panesApp(tester, width: 1900);
    // Each watch the daemon serves, by what it watches, while it's open.
    final open = <String>{};
    final inner = fake.streams!;
    fake.streams = (input) {
      final key = switch (input) {
        WatchChatFolderRequest(:final path) => 'folder $path',
        WatchChatFileRequest(:final path) => 'file $path',
        _ => null,
      };
      final s = inner(input);
      if (key == null || s == null) return s;
      late StreamSubscription<Object> sub;
      final c = StreamController<Object>();
      c
        ..onListen = () {
          open.add(key);
          sub = s.listen(c.add, onError: c.addError, onDone: c.close);
        }
        ..onCancel = () {
          open.remove(key);
          return sub.cancel();
        };
      return c.stream;
    };
    await openPanesIn(tester, d, (
      side: false,
      files: true,
      subagent: false,
      command: false,
      previews: 1,
      browser: 0,
    ));
    int asked() => fake.calls
        .where((r) => r is WatchChatFolderRequest || r is WatchChatFileRequest)
        .length;
    expect(open, containsAll(['file PLAN.md', 'folder ']));
    final before = asked();
    expect(find.text('README.md'), findsWidgets);
    expect(find.textContaining('Brew, then pour.'), findsWidgets);

    d.macView.window = false;
    await tester.pumpAndSettle();
    expect(open, isEmpty);
    // What showed shows still.
    expect(find.text('README.md'), findsWidgets);
    expect(find.textContaining('Brew, then pour.'), findsWidgets);
    // Nothing is asked again while hidden, a retry's wait past too.
    await tester.pump(const Duration(seconds: 5));
    expect(asked(), before);

    d.macView.window = true;
    await tester.pumpAndSettle();
    expect(open, containsAll(['file PLAN.md', 'folder ']));
    expect(asked(), greaterThan(before));
    expect(find.text('README.md'), findsWidgets);
    expect(find.textContaining('Brew, then pour.'), findsWidgets);
    await closeView(tester, d);
  }, variant: onMac);
}
