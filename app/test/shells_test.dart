import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/shells.dart';

void main() {
  test('a background command in a few words', () {
    Item shell(String state, {String end = '', int ms = 0, String out = ''}) =>
        Item(
          id: 't',
          title: 'make',
          shell: Shell(
            state: state,
            end: end,
            started: Int64(ms),
            ended: Int64(ms == 0 ? 0 : ms + 15000),
            output: out,
          ),
        );
    expect(
      shellState(shell('done', end: 'exited with code 0', ms: 1)),
      'done · exited with code 0 · 15s',
    );
    expect(shellState(shell('stopped', end: 'killed')), 'stopped');
    expect(shellState(shell('started')), 'started');
    expect(lastLine(shell('running', out: 'a\nb  \n\n')), 'b');
    expect(shellsOf([Item(id: 'x'), shell('done')]).single.id, 't');
  });
}
