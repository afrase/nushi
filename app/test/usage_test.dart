import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/usage.dart';

void main() {
  test('deferred rows stay out of the bar, and the shares add up', () {
    ContextCategory c(String name, int tokens, {String kind = ''}) =>
        ContextCategory(name: name, tokens: Int64(tokens), kind: kind);
    final all = [
      c('System prompt', 2000),
      c('Tools', 14500),
      c('Tools', 327000, kind: 'deferred'),
      c('Messages', 193000),
      c('Free space', 739000, kind: 'free'),
    ];
    final shares = contextShares(all);
    expect([for (final s in shares) s.$1.kind], isNot(contains('deferred')));
    expect(shares.length, 4);
    expect(shares.fold(0.0, (n, s) => n + s.$2), closeTo(1, 1e-9));
    final messages = shares.firstWhere((s) => s.$1.name == 'Messages').$2;
    expect(messages, closeTo(193000 / 948500, 1e-9));
    expect(contextShares([c('Tools', 5, kind: 'deferred')]), isEmpty);
  });
}
