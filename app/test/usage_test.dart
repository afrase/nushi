import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/usage.dart';

void main() {
  test('deferred rows stay out of the bar, and the shares add up', () {
    ContextCategory c(String name, int tokens, double percent) =>
        ContextCategory(name: name, tokens: Int64(tokens), percent: percent);
    // A 1M context, as a user's /context listed it.
    final all = [
      c('System prompt', 2000, 0.2),
      c('System tools', 14500, 1.5),
      c('MCP tools', 4400, 0.4),
      c('MCP server instructions', 631, 0.1),
      c('MCP tools (deferred)', 327000, 32.7),
      c('System tools (deferred)', 21600, 2.2),
      c('Custom agents', 2400, 0.2),
      c('Memory files', 6100, 0.6),
      c('Skills', 5500, 0.6),
      c('Messages', 193000, 19.2),
      c('Free space', 739000, 73.9),
      c('Autocompact buffer', 33000, 3.3),
    ];
    final shares = contextShares(all);
    expect(shares.map((s) => s.$1.name), isNot(contains(endsWith('(deferred)'))));
    expect(shares.length, 10);
    expect(shares.fold(0.0, (n, s) => n + s.$2), closeTo(1, 1e-9));
    final messages = shares.firstWhere((s) => s.$1.name == 'Messages').$2;
    expect(messages, closeTo(0.192, 0.002));
    expect(contextShares([c('MCP tools (deferred)', 5, 1)]), isEmpty);
  });
}
