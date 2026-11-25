import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/blame.dart';
import 'package:nushi/file_tabs.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'change_marks_test.dart' show changeShown;
import 'harness.dart';

// Blame's model (issue #78): each line's run, as blamed or through an
// edit since; the daemon's reasons in the path row's words; Blame a tab's.

/// Made-up commits' ids.
const blameStart = 'c0ffee1aa2b3c4d5e6f708192a3b4c5d6e7f8091';
const blameGreet = 'b16b00b5a1a2a3a4a5a6a7a8a9aaabacadaeaf00';
const blameName = '5eed5eed0123456789abcdef0123456789abcdef';
const blameBlank = 'fa11fa11fa11fa11fa11fa11fa11fa11fa11fa11';

/// A run of [count] lines from [start], [ago] before `fixtureNow`.
BlameRun blameRun(
  int start,
  int count,
  String commit,
  String author,
  Duration ago,
  String subject,
) => BlameRun(
  start: start,
  count: count,
  commit: commit,
  author: author,
  authorUnixSeconds: Int64(
    fixtureNow.subtract(ago).millisecondsSinceEpoch ~/ 1000,
  ),
  subject: subject,
);

/// [changeShown]'s 14 lines: a long name's run, a run of one, a short
/// name's, the last two not committed.
final List<BlameRun> blameRuns = [
  blameRun(1, 3, blameStart, 'Ada Lovelace', const Duration(days: 40), 'Start'),
  blameRun(
    4,
    1,
    blameBlank,
    'Lin Ye',
    const Duration(days: 400),
    'Space it out',
  ),
  blameRun(
    5,
    4,
    blameGreet,
    'Margaret Featherstonehaugh-Applegate',
    const Duration(hours: 3),
    'Greet by name',
  ),
  blameRun(9, 1, blameName, 'Bo', const Duration(days: 2), 'One blank line'),
  blameRun(
    10,
    3,
    blameStart,
    'Ada Lovelace',
    const Duration(days: 40),
    'Start',
  ),
  BlameRun(start: 13, count: 2),
];

/// [blameRuns] as an answer for [changeShown].
final blamed = Blamed(blameRuns, changeShown);

void main() {
  group('the cells', () {
    test('as blamed: a run named on its first line, uncommitted ones '
        'without a commit', () {
      final cells = blameCells(blamed, changeShown) as List<BlameCell>;
      expect(cells, hasLength(14));
      expect(
        [
          for (final (i, c) in cells.indexed)
            if (c.first) i,
        ],
        [0, 3, 4, 8, 9, 12],
      );
      expect(cells[12].run, isNull);
      expect(cells[13].run, isNull);
      expect(cells[5].commit, blameGreet);
    });

    test('an edit since: its lines not committed, the rest keep theirs', () {
      // A line added at the top, greet's comment changed, main's call
      // gone.
      final now = '// top\n${changeShown.replaceFirst('hello to', 'hi to')}'
          .replaceFirst('\tgreet("you")\n', '');
      final cells = blameCells(blamed, now) as List<BlameCell>;
      expect(cells, hasLength(14));
      expect(cells.map((c) => c.commit), [
        '', // added
        blameStart, blameStart, blameStart,
        blameBlank,
        '', // changed
        blameGreet, blameGreet, blameGreet,
        blameName,
        blameStart, blameStart, // the call went
        '', '',
      ]);
      expect(cells[1].first, isTrue);
      expect(cells[5].first, isTrue);
      expect(cells[6].first, isTrue);
    });

    test('none when the runs miss a line, or there are none', () {
      expect(
        blameCells(Blamed(blameRuns.sublist(1), changeShown), ''),
        isEmpty,
      );
      expect(
        blameCells(Blamed(blameRuns, '$changeShown\nmore\n'), ''),
        isEmpty,
      );
      expect(blameCells(Blamed.nothing, changeShown), isEmpty);
    });

    test("the daemon's reasons, in the path row's words", () {
      expect(NoBlame.of('not a repository').label, 'Not in a git repository');
      expect(NoBlame.of('ignored').label, 'Ignored by git');
      expect(NoBlame.of('untracked').label, 'Not committed yet');
      expect(NoBlame.of('new').label, 'New file: not committed yet');
      expect(NoBlame.of('a link'), NoBlame.link);
      expect(NoBlame.of('binary'), NoBlame.binary);
      expect(NoBlame.of('too large'), NoBlame.tooLarge);
      expect(NoBlame.of('too many lines').label, 'Over 10,000 lines: no blame');
      expect(NoBlame.of('anything else'), NoBlame.failed);
    });
  });

  test("Blame is a tab's: off as it opens, gone as it closes or a "
      'provisional tab gives way', () {
    final tabs = FileTabs()..open('a.go', folder: '/f');
    final a = tabs.shown.value!;
    tabs.blame('a.go', on: true);
    expect(tabs.blamed.value, {'a.go'});
    tabs.close(a);
    expect(tabs.blamed.value, isEmpty);
    tabs
      ..open('b.go', folder: '/f', keep: false)
      ..blame('b.go', on: true)
      ..open('c.go', folder: '/f', keep: false);
    expect(tabs.blamed.value, isEmpty);
    expect(tabs.kept('/f')!.json.containsKey('blamed'), isFalse);
  });
}
