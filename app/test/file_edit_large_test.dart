import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';

// A file being edited that grows past what the watch sends (5 MiB, so no
// data and no sum): the edit can't be saved, and says why, never ''.

void main() {
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
}
