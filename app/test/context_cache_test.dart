import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

ContextCategory _c(String name, int tokens, {String kind = ''}) =>
    ContextCategory(name: name, tokens: Int64(tokens), kind: kind);

void main() {
  final asked = [
    _c('System prompt', 5000),
    _c('Tools', 15000),
    _c('Tools', 300000, kind: 'deferred'),
    _c('Messages', 20000),
    _c('Autocompact buffer', 45000),
    _c('Free space', 915000, kind: 'free'),
  ];

  test('a turn later, what the conversation added goes to Messages and '
      'out of Free space; the rest stays', () {
    final now = liveCategories(
      asked,
      Usage(contextUsed: Int64(46400), contextSize: Int64(1000000)),
    );
    int of(String name, {String kind = ''}) =>
        now.firstWhere((c) => c.name == name && c.kind == kind).tokens.toInt();
    expect(of('Messages'), 46400 - 20000);
    expect(of('System prompt'), 5000);
    expect(of('Tools', kind: 'deferred'), 300000);
    expect(of('Free space', kind: 'free'), 1000000 - 46400 - 45000);
    expect(
      now.firstWhere((c) => c.name == 'Messages').percent,
      closeTo(2.64, 1e-9),
    );
  });

  test('as asked, without usage or a Messages row', () {
    expect(liveCategories(asked, Usage()), same(asked));
    final noMessages = [_c('System prompt', 5000)];
    expect(
      liveCategories(
        noMessages,
        Usage(contextUsed: Int64(9000), contextSize: Int64(100000)),
      ),
      same(noMessages),
    );
  });

  test('remembered: categories only, markdown-only answers not', () {
    rememberContext('a', GetContextUsageResponse(markdown: 'only text'));
    expect(recalledContext('a'), isNull);
    rememberContext(
      'b',
      GetContextUsageResponse(categories: asked, markdown: '# Context'),
    );
    final (_, r) = recalledContext('b')!;
    expect(r.categories.length, asked.length);
    expect(r.markdown, isEmpty);
  });
}
