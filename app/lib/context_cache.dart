import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

/// What last filled each chat's context (its /context categories) and when
/// it was asked, in `context.json` in the data folder, so the Context card
/// has it at once after the app restarts or while a turn runs. Only the
/// categories' names and counts are kept, never the agent's markdown; the
/// [_keep] most recent chats.
const _keep = 300;

File get _file => File('$dataDir/context.json');

final Map<String, (DateTime, GetContextUsageResponse)> _known = () {
  try {
    final saved = jsonDecode(_file.readAsStringSync()) as Map<String, Object?>;
    return {
      for (final MapEntry(:key, :value) in saved.entries)
        if (value case {
          'at': final int at,
          'categories': final List<Object?> cs,
        })
          key: (
            DateTime.fromMillisecondsSinceEpoch(at),
            GetContextUsageResponse(
              categories: [
                for (final c in cs)
                  if (c case {
                    'name': final String name,
                    'tokens': final int n,
                    'percent': final num percent,
                    'kind': final String kind,
                  })
                    ContextCategory(
                      name: name,
                      tokens: Int64(n),
                      percent: percent.toDouble(),
                      kind: kind,
                    ),
              ],
            ),
          ),
    };
  } on Object {
    return <String, (DateTime, GetContextUsageResponse)>{};
  }
}();

/// What [chatId]'s context held when last asked, and when; null if never.
(DateTime, GetContextUsageResponse)? recalledContext(String chatId) =>
    _known[chatId];

/// The chats whose context is remembered.
Iterable<String> get rememberedContexts => _known.keys;

/// Forgets [chatId]'s context (the chat is gone).
void forgetContext(String chatId) {
  if (_known.remove(chatId) != null) _write();
}

/// Keeps [r] as what fills [chatId]'s context now (only when it has
/// categories: a markdown-only answer isn't kept).
void rememberContext(String chatId, GetContextUsageResponse r) {
  if (r.categories.isEmpty) return;
  _known[chatId] = (
    DateTime.now(),
    GetContextUsageResponse(categories: r.categories),
  );
  final oldest = _known.entries.toList()
    ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
  for (final e in oldest.skip(_keep)) {
    _known.remove(e.key);
  }
  _write();
}

void _write() {
  try {
    writeWhole(
      _file,
      jsonEncode({
        for (final MapEntry(:key, value: (at, r)) in _known.entries)
          key: {
            'at': at.millisecondsSinceEpoch,
            'categories': [
              for (final c in r.categories)
                {
                  'name': c.name,
                  'tokens': c.tokens.toInt(),
                  'percent': c.percent,
                  'kind': c.kind,
                },
            ],
          },
      }),
    );
  } on Object {
    // Not remembered; the card still has it until the app quits.
  }
}

/// [cs] (what /context said, maybe a turn ago) brought up to [u], the
/// agent's latest usage: what the conversation adds goes to Messages and
/// comes out of Free space, the rest (system prompt, tools, memory,
/// skills) kept as it was. As it was when [u] says nothing or there's no
/// Messages row.
List<ContextCategory> liveCategories(List<ContextCategory> cs, Usage u) {
  final size = u.contextSize.toInt();
  final used = u.contextUsed.toInt();
  if (size == 0 || used == 0 || !cs.any((c) => c.name == 'Messages')) {
    return cs;
  }
  bool fixed(ContextCategory c) =>
      c.kind == '' && c.name != 'Messages' && c.name != 'Autocompact buffer';
  final rest = cs.where(fixed).fold(0, (n, c) => n + c.tokens.toInt());
  final buffer = cs
      .where((c) => c.name == 'Autocompact buffer')
      .fold(0, (n, c) => n + c.tokens.toInt());
  int now(ContextCategory c) => switch (c) {
    _ when c.name == 'Messages' => (used - rest).clamp(0, size),
    _ when c.kind == 'free' => (size - used - buffer).clamp(0, size),
    _ => c.tokens.toInt(),
  };
  return [
    for (final c in cs)
      if (c.kind == 'deferred')
        c
      else
        ContextCategory(
          name: c.name,
          tokens: Int64(now(c)),
          percent: now(c) / size * 100,
          kind: c.kind,
        ),
  ];
}
