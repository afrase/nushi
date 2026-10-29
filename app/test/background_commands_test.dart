import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/background_commands.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

void main() {
  test('a background command in a few words', () {
    Item command(
      String state, {
      String end = '',
      int ms = 0,
      String out = '',
    }) => Item(
      id: 't',
      title: 'make',
      backgroundCommand: BackgroundCommand(
        state: state,
        end: end,
        started: Int64(ms),
        ended: Int64(ms == 0 ? 0 : ms + 15000),
        output: out,
      ),
    );
    expect(
      commandState(command('done', end: 'exited with code 0', ms: 1)),
      'done · exited with code 0 · 15s',
    );
    expect(commandState(command('stopped', end: 'killed')), 'stopped');
    expect(commandState(command('started')), 'started');
    expect(lastLine(command('running', out: 'a\nb  \n\n')), 'b');
    expect(
      backgroundCommandsOf([Item(id: 'x'), command('done')]).single.id,
      't',
    );
  });
}
