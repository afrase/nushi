/// A large made-up SQL file, for the finds' tests on big texts: a dump's
/// shape, short statements between long `INSERT` lines, some longer than
/// a source line shows (5000 characters). Its words repeat, as a dump's
/// do: a first letter such as `s` or `e` matches a large share of it.
library;

/// About [bytes] characters of invented SQL, `\n` line ends, the same
/// text for the same size. [rows] is how many rows an `INSERT` line
/// takes (every fifth takes more than twice as many): 1 is a migration's
/// shape, no line past a hundred or so characters; thousands a dump's
/// extended inserts, lines of hundreds of kilobytes.
String bigSql(int bytes, {int rows = 30}) {
  final out = StringBuffer();
  var n = 0;
  while (out.length < bytes) {
    final table = _tables[n % _tables.length];
    switch (n % 6) {
      case 0:
        out
          ..writeln('-- section $n: sample rows for $table')
          ..writeln('CREATE TABLE IF NOT EXISTS $table (')
          ..writeln('  id bigint PRIMARY KEY,')
          ..writeln("  status varchar(32) NOT NULL DEFAULT 'pending',")
          ..writeln('  note text,')
          ..writeln('  created_at timestamp NOT NULL')
          ..writeln(');');
      case 1:
        out.writeln(
          'SELECT id, status, note FROM $table WHERE status = '
          "'settled' ORDER BY created_at DESC LIMIT 50;",
        );
      default:
        // Every fifth long line runs past what a source line shows.
        final count = n % 5 == 2 ? rows * 8 ~/ 3 : rows;
        out.write('INSERT INTO $table (id, status, note, created_at) VALUES ');
        for (var r = 0; r < count; r++) {
          final id = n * 100000 + r;
          if (r > 0) out.write(', ');
          out.write(
            "($id, '${_states[id % _states.length]}', "
            "'${_notes[id % _notes.length]}', "
            "'2025-0${1 + id % 9}-1${id % 10} 0${id % 10}:00:00')",
          );
        }
        out.writeln(';');
    }
    n++;
  }
  return out.toString();
}

const _tables = ['sample_orders', 'shelf_items', 'session_events'];
const _states = ['settled', 'pending', 'escalated', 'reserved'];
const _notes = [
  'seen twice, resent',
  'select the second slot',
  'never set',
  'released early',
  'see the earlier entry',
];
