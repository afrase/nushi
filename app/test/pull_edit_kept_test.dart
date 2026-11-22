import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/comment_drafts_mac.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_edit.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';
import 'pull_overview_fixture.dart';

/// A pull request's description edit across a restart (ADR 0073): its
/// text and what GitHub said when it began are kept together, so the
/// editor comes back open with the text, and Save still asks GitHub
/// whether it changed since (API 128).
void main() {
  setUpAll(loadFonts);

  const source = 'When a session expires mid-request, it loops.';
  final description = find.byKey(const ValueKey('description field'));

  testWidgets('an open edit comes back after a restart; Save sends what '
      'it began from', (tester) async {
    final dir = Directory.systemTemp.createTempSync('pull-edit-kept');
    addTearDown(() => dir.deleteSync(recursive: true));
    final p = overviewPull()
      ..canEdit = true
      ..bodySource = source
      ..body = source;

    var file = CommentDraftFile(dir.path);
    var (d, _) = await openPullTab(tester, p);
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    await tester.enterText(description, 'Half written');
    await tester.pump();
    file
      ..flush()
      ..close();
    await closeView(tester, d);
    final saved = jsonDecode(
      File('${dir.path}/comment_drafts.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(saved['began'], isNotEmpty);

    // The app quits and starts again: only the file carries over.
    forgetCommentDrafts();
    restorePullEdits({});
    expect(keptPullEdits, isEmpty);
    file = CommentDraftFile(dir.path);
    final FakeDaemon fake;
    (d, fake) = await openPullTab(tester, p);
    expect(
      tester.widget<TextField>(description).controller!.text,
      'Half written',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<EditGitHubPullRequest>().single;
    expect(sent.was, source);
    expect(sent.body, 'Half written');
    file.close(); // its save, timed after the edit ended
    await closeView(tester, d);
  }, variant: onMac);

  test('a file from before the edits were kept still gives its boxes', () {
    final dir = Directory.systemTemp.createTempSync('pull-edit-kept');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/comment_drafts.json').writeAsStringSync(
      jsonEncode({
        'boxes': {'k': 'text'},
        'reviews': <String, Object?>{},
      }),
    );
    final file = CommentDraftFile(dir.path);
    addTearDown(file.close);
    expect(commentDraft('k'), 'text');
    expect(keptPullEdits, isEmpty);
    expect(dir.listSync(), hasLength(1)); // nothing set aside
  });
}
