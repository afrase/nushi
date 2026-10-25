import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/daemon.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('app_log'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('values are written as slog writes them', () {
    expect(quote('plain'), 'plain');
    expect(quote('two words'), '"two words"');
    expect(quote('a "b"\nc\\'), r'"a \"b\"\nc\\"');
    expect(quote(''), '""');
    expect(quote('k=v'), '"k=v"');
    expect(
      timestamp(DateTime(2026, 10, 25, 9, 5, 3, 7)),
      matches(r'^2026-10-25T09:05:03\.007[+-]\d\d:\d\d$'),
    );
  });

  test('without a daemon, lines go to app.log, rotated', () async {
    final log = AppLog('${dir.path}/app.log')..maxSize = 150;
    for (var i = 0; i < 6; i++) {
      await log.write('warn', 'line $i', attrs: {'k': 'v $i'});
    }
    final now = File('${dir.path}/app.log').readAsStringSync();
    expect(now, contains('level=WARN msg="line 5" source=app k="v 5"'));
    expect(now, startsWith('time=20'));
    expect(File('${dir.path}/app.log.1').existsSync(), isTrue);
    expect(File('${dir.path}/app.log.2').existsSync(), isTrue);
    expect(File('${dir.path}/app.log.3').existsSync(), isFalse);
  });

  test("an error each frame can't flood the log", () async {
    final log = AppLog('${dir.path}/app.log');
    for (var i = 0; i < 50; i++) {
      await log.write('error', 'overflow');
    }
    final lines = File('${dir.path}/app.log').readAsLinesSync();
    expect(lines, hasLength(20));
  });

  test("Flutter's errors reach the log with their stacks", () async {
    final original = FlutterError.onError;
    final file = File(appLog.path);
    if (file.existsSync()) file.deleteSync();
    expect(appLog.path, startsWith(dataDir)); // the tests' own folder
    FlutterError.onError = (_) {}; // the test's handler would fail it
    catchErrors();
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('broke'),
        stack: StackTrace.current,
        library: 'rendering library',
      ),
    );
    FlutterError.onError = original;
    await Future<void>.delayed(Duration.zero);
    final line = file.readAsStringSync();
    expect(
      line,
      contains(
        'level=ERROR msg="Bad state: broke" source=app from=flutter '
        'library="rendering library"',
      ),
    );
    expect(line, contains('stack="#0'));
    expect(line, contains('app_log_test.dart'));
  });
}
