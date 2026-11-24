// The app's own stores on the phone, in a real browser: there is no data
// folder there ([dataDir] throws), so each store checks [appFiles] and
// keeps what it's given in memory, never reaching a file or a catch:
// each case fails if it reached [dataDir] at all ([dataDirOnWeb]), which
// a store's catch would otherwise swallow.
// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

void main() {
  // What a case may not do: reach the data folder, caught or not.
  late int reached;
  setUp(() => reached = dataDirOnWeb);
  void reachedNone() =>
      expect(dataDirOnWeb, reached, reason: 'the data folder was reached');

  test('the phone has no app folder, and the data folder would throw, '
      'each time it is reached', () {
    expect(appFiles, isNull);
    reachedNone();
    expect(() => dataDir, throwsUnsupportedError);
    expect(() => dataDir, throwsUnsupportedError);
    expect(dataDirOnWeb, reached + 2);
  });

  test('a pref the phone changes holds, saved nowhere', () async {
    final was = wrapLines.value;
    addTearDown(() => wrapLines.value = was);
    wrapLines.value = !was;
    await Future<void>.delayed(Duration.zero); // the save's microtask
    expect(wrapLines.value, !was);
    reachedNone();
  });

  test('a review comment is kept in memory', () {
    addTearDown(forgetReviews);
    final c = ReviewComment(
      id: 'r1',
      where: 'uncommitted',
      path: 'main.go',
      old: false,
      start: 1,
      end: 1,
      quote: 'x',
      text: 'Rename this',
    );
    setComments('a', [c]);
    expect(commentsOf('a'), [c]);
    rereadReviews(); // no file to read: none
    expect(commentsOf('a'), isEmpty);
    reachedNone();
  });

  test('a pull request read whole is kept in memory', () {
    addTearDown(forgetPulls);
    final ref = GitHubRef(host: 'github.com', repo: 'me/calc', number: 7);
    final p = GitHubPull(body: 'Adds the log.');
    expect(cachedPull(ref), isNull);
    keepPull(ref, p);
    expect(cachedPull(ref)?.$2, p);
    keepPull(ref, p); // the same again: only its time
    expect(cachedPull(ref)?.$2, p);
    forgetPulls();
    reachedNone();
  });

  test("a chat's context is remembered in memory", () {
    addTearDown(() => forgetContext('c'));
    final r = GetContextUsageResponse(
      categories: [
        ContextCategory(
          name: 'Messages',
          tokens: Int64(20000),
          part: 'messages',
        ),
      ],
    );
    askedContext('c', r);
    expect(rememberedContexts, contains('c'));
    expect(lastContext('c')?.$2.categories.single.name, 'Messages');
    reachedNone();
  });
}
