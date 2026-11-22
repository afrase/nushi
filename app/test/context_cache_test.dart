import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

ContextCategory _c(
  String name,
  int tokens, {
  String kind = '',
  String part = '',
}) =>
    ContextCategory(name: name, tokens: Int64(tokens), kind: kind, part: part);

void main() {
  final asked = [
    _c('System prompt', 5000),
    _c('Tools', 15000),
    _c('Tools', 300000, kind: 'deferred'),
    _c('Messages', 20000, part: 'messages'),
    // Named as no agent names it: its part says what it is.
    _c('Reserve', 45000, part: 'buffer'),
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

  test('as asked, without usage or a category that is the conversation', () {
    expect(liveCategories(asked, Usage()), same(asked));
    // Named Messages, but no part: from a daemon older than parts.
    final noMessages = [_c('System prompt', 5000), _c('Messages', 9000)];
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
    expect(rememberedContexts, isNot(contains('a')));
    rememberContext(
      'b',
      GetContextUsageResponse(categories: asked, markdown: '# Context'),
    );
    final (_, r) = lastContext('b')!;
    expect(r.categories.length, asked.length);
    expect(r.markdown, isEmpty);
  });

  test('read back with their parts; an entry saved without them dropped', () {
    Map<String, Object?> category(String name, [String? part]) => {
      'name': name,
      'tokens': 5,
      'percent': 0.5,
      'kind': '',
      'part': ?part,
    };
    final read = readContexts(
      jsonEncode({
        'new': {
          'at': 1,
          'categories': [
            category('System prompt', ''),
            category('Messages', 'messages'),
          ],
        },
        'old': {
          'at': 1,
          'categories': [category('System prompt'), category('Messages')],
        },
      }),
    );
    expect(read.keys, ['new']);
    expect(
      [for (final c in read['new']!.$2.categories) c.part],
      ['', 'messages'],
    );
  });

  test('asked in this run: a markdown-only answer too, until the chat is '
      'forgotten', () {
    askedContext('m', GetContextUsageResponse(markdown: 'only text'));
    expect(lastContext('m')!.$2.markdown, 'only text');
    expect(contextAskedAt('m'), isNotNull);
    expect(rememberedContexts, isNot(contains('m'))); // not on disk
    askedContext('n', GetContextUsageResponse(categories: asked));
    forgetContext('m');
    forgetContext('n');
    for (final id in ['m', 'n']) {
      expect(lastContext(id), isNull);
      expect(contextAskedAt(id), isNull);
    }
  });
}
