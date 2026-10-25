import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/bundled_daemon.dart';

void main() {
  test('the daemon is opened as the helper app, through the login shell', () {
    final helper = helperIn('/Applications/Nushi.app');
    expect(helper, '/Applications/Nushi.app/Contents/Helpers/Nushi Daemon.app');
    expect(openHelper(helper, null), ['-n', '-g', helper, '--args', '-login']);
    expect(openHelper(helper, '/tmp/dev'), [
      '-n',
      '-g',
      '--env',
      'NUSHI_DATA=/tmp/dev',
      helper,
      '--args',
      '-login',
    ]);
  });
}
