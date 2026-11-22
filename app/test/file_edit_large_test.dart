import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/source_editor.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// A file being edited that grows past what the watch sends (5 MiB, so no
// data and no sum): the edit can't be saved, and says why, never ''.

void main() {
  setUpAll(loadFonts);

  test('past 5 MiB it’s over 1 MiB, as one over 1 MiB is', () {
    expect(
      notEditable(WatchChatFileResponse(tooLarge: true, size: Int64(6 << 20))),
      'it’s over 1 MiB.',
    );
  });

  testWidgets('an unsaved edit of a file grown past 5 MiB is kept, read '
      'only with its reason', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final (file, _) = decodeFile(utf8.encode('a log\n'));
    final e = FileEdit(d, 'c', 'app.log', file!, 'sum');
    e.controller.text = 'a log, edited\n';
    expect(e.unsaved, isTrue);

    e.receive(
      WatchChatFileResponse(
        path: '/x/app.log',
        tooLarge: true,
        size: Int64(6 << 20),
      ),
    );
    expect(e.readOnly, 'it’s over 1 MiB.');
    expect(e.unsaved, isTrue);
    expect(e.controller.text, 'a log, edited\n');
    e.dispose();
    d.dispose();
  });

  testWidgets('the pane shows the unsaved edit read only, with the limit, '
      'not "Too large to preview"', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    fake.sendWatch(
      'main.go',
      WatchChatFileResponse(
        path: '/Users/me/nushi/main.go',
        tooLarge: true,
        size: Int64(6 << 20),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Too large to preview'), findsNothing);
    expect(find.byType(SourceEditor), findsOneWidget);
    expect(find.text('Read-only: it’s over 1 MiB.'), findsOneWidget);
    expect(e.text, '// mine\n$goSource');
    for (final width in [1700.0, 720.0]) {
      viewport(tester, Size(width, 900));
      await tester.pumpAndSettle();
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(NushiApp),
        'file_edit_too_large_${width.toInt()}',
      );
    }
    await endEditor(tester, d);
  }, variant: onMac);
}
