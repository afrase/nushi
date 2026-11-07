import 'package:diff_view/diff_view.dart' show EditOp, myersDiff;

/// Past this many lines in the three texts together no merge is tried:
/// Myers' diff keeps memory for every step (diff_box's maxDiffLines).
const _mostLines = 30000;

/// [base] with the changes [mine] and [theirs] each made to it, by lines
/// (ADR 0096): null when a change of one side overlaps or touches one of
/// the other's (a conflict), unless both made the same change there.
/// Texts have `\n` line ends.
String? mergeLines(String base, String mine, String theirs) {
  if (mine == base) return theirs;
  if (theirs == base || theirs == mine) return mine;
  final b = base.split('\n');
  final m = mine.split('\n');
  final t = theirs.split('\n');
  if (b.length + m.length + t.length > _mostLines) return null;
  final ids = <String, int>{};
  List<int> idsOf(List<String> lines) => [
    for (final l in lines) ids.putIfAbsent(l, () => ids.length),
  ];
  final bi = idsOf(b);
  final hunks = [
    ..._hunks(myersDiff(bi, idsOf(m)), m, mine: true),
    ..._hunks(myersDiff(bi, idsOf(t)), t, mine: false),
  ]..sort((x, y) => x.start.compareTo(y.start));
  final out = <String>[];
  var at = 0;
  var i = 0;
  while (i < hunks.length) {
    // A run of hunks that overlap or touch, from either side.
    final start = hunks[i].start;
    var end = hunks[i].end;
    var j = i + 1;
    while (j < hunks.length && hunks[j].start <= end) {
      if (hunks[j].end > end) end = hunks[j].end;
      j++;
    }
    final run = hunks.sublist(i, j);
    final mines = [
      for (final h in run)
        if (h.mine) h,
    ];
    final theirs = [
      for (final h in run)
        if (!h.mine) h,
    ];
    final List<String> lines;
    if (theirs.isEmpty) {
      lines = _apply(b, start, end, mines);
    } else if (mines.isEmpty) {
      lines = _apply(b, start, end, theirs);
    } else {
      final a = _apply(b, start, end, mines);
      final c = _apply(b, start, end, theirs);
      if (a.length != c.length || !_equal(a, c)) return null;
      lines = a;
    }
    out
      ..addAll(b.sublist(at, start))
      ..addAll(lines);
    at = end;
    i = j;
  }
  out.addAll(b.sublist(at));
  return out.join('\n');
}

/// A change of one side: base's lines from start to end (none, for an
/// insertion) become the side's lines.
typedef _Hunk = ({int start, int end, List<String> lines, bool mine});

List<_Hunk> _hunks(List<EditOp> ops, List<String> other, {required bool mine}) {
  final out = <_Hunk>[];
  var i = 0; // in base
  var j = 0; // in other
  var k = 0;
  while (k < ops.length) {
    if (ops[k] == EditOp.equal) {
      i++;
      j++;
      k++;
      continue;
    }
    final start = i;
    final from = j;
    while (k < ops.length && ops[k] != EditOp.equal) {
      if (ops[k] == EditOp.delete) i++;
      if (ops[k] == EditOp.insert) j++;
      k++;
    }
    out.add((start: start, end: i, lines: other.sublist(from, j), mine: mine));
  }
  return out;
}

/// Base's lines from [start] to [end] with [hunks] (one side's, in order,
/// all inside) applied.
List<String> _apply(List<String> b, int start, int end, List<_Hunk> hunks) {
  final out = <String>[];
  var at = start;
  for (final h in hunks) {
    out
      ..addAll(b.sublist(at, h.start))
      ..addAll(h.lines);
    at = h.end;
  }
  return out..addAll(b.sublist(at, end));
}

bool _equal(List<String> a, List<String> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
