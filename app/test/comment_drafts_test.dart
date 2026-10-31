import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/comment_drafts_mac.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_review.dart';

void main() {
  late Directory dir;
  final ref = GitHubRef(host: 'github.com', repo: 'o/r', number: 7);
  final inline = GitHubDraft(
    path: 'a.go',
    side: 'RIGHT',
    line: 3,
    body: 'Why?',
  );

  File file() => File('${dir.path}/comment_drafts.json');

  /// The app quit and started again: only the file carries over.
  CommentDraftFile restart(CommentDraftFile was) {
    was
      ..flush()
      ..close();
    forgetCommentDrafts();
    forgetReviewDrafts();
    return CommentDraftFile(dir.path);
  }

  setUp(() => dir = Directory.systemTemp.createTempSync('comment-drafts'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a box and a review outlive a restart, in a private file', () {
    final kept = CommentDraftFile(dir.path);
    keepCommentDraft('jira x ABC-1 comment', 'half a thought');
    setDrafts(ref, [inline]);

    final next = restart(kept);
    addTearDown(next.close);

    expect(commentDraft('jira x ABC-1 comment'), 'half a thought');
    expect(reviewDrafts(ref), [inline]);
    expect(file().statSync().mode & 0x1ff, 0x180);
  });

  test('the file goes with the last draft', () {
    final kept = CommentDraftFile(dir.path);
    addTearDown(kept.close);
    keepCommentDraft('k', 'text');
    setDrafts(ref, [inline]);
    kept.flush();
    expect(file().existsSync(), isTrue);

    keepCommentDraft('k', '');
    setDrafts(ref, const []);
    kept.flush();
    expect(file().existsSync(), isFalse);
  });

  test('it saves on its own once the drafts stop changing', () async {
    final kept = CommentDraftFile(dir.path, delay: Duration.zero);
    addTearDown(kept.close);
    keepCommentDraft('k', 'text');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final j = jsonDecode(file().readAsStringSync()) as Map<String, dynamic>;
    expect(j['boxes'], {'k': 'text'});
  });

  test('nothing changed writes nothing', () {
    final kept = CommentDraftFile(dir.path)..flush();
    addTearDown(kept.close);
    expect(file().existsSync(), isFalse);
  });

  test('a file it cannot read starts empty', () {
    file().writeAsStringSync('{not json');
    final kept = CommentDraftFile(dir.path);
    addTearDown(kept.close);
    expect(keptCommentDrafts, isEmpty);
    expect(keptReviewDrafts, isEmpty);
  });
}
