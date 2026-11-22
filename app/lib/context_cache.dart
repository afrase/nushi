import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/run_state.dart';

/// What last filled each chat's context (its /context categories) and when
/// it was asked, in `context.json` in the data folder, so the Context widget
/// has it at once after the app restarts or while a turn runs. Only the
/// categories' names, counts, kinds and parts are kept, never the agent's
/// markdown; the [_keep] most recent chats. An entry none of whose
/// categories has a part (saved by an older app, or from a daemon older
/// than parts, API 141) is neither kept nor read back: it comes back the
/// next time the context is asked.
const _keep = 300;

File get _file => File('$dataDir/context.json');

final Map<String, (DateTime, GetContextUsageResponse)> _known = () {
  try {
    return readContexts(_file.readAsStringSync());
  } on Object {
    return <String, (DateTime, GetContextUsageResponse)>{};
  }
}();

/// The contexts saved in `context.json` as [text]. Throws when it isn't
/// JSON's object.
@visibleForTesting
Map<String, (DateTime, GetContextUsageResponse)> readContexts(String text) {
  final saved = jsonDecode(text) as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in saved.entries)
      if (value case {'at': final int at, 'categories': final List<Object?> cs})
        if (_categories(cs) case final categories?)
          key: (
            DateTime.fromMillisecondsSinceEpoch(at),
            GetContextUsageResponse(categories: categories),
          ),
  };
}

/// The categories saved as [cs]; null when one isn't as this app writes
/// it (one without its part, saved by an older app), or none has a part.
List<ContextCategory>? _categories(List<Object?> cs) {
  final out = [
    for (final c in cs)
      if (c case {
        'name': final String name,
        'tokens': final int n,
        'percent': final num percent,
        'kind': final String kind,
        'part': final String part,
      })
        ContextCategory(
          name: name,
          tokens: Int64(n),
          percent: percent.toDouble(),
          kind: kind,
          part: part,
        ),
  ];
  return out.length == cs.length && _parted(out) ? out : null;
}

/// Whether some of [cs] says its part: every agent's harness that reads
/// categories gives one at least the conversation's; none did before API
/// 141, whose categories would read as if the agent had no buffer.
bool _parted(List<ContextCategory> cs) => cs.any((c) => c.part.isNotEmpty);

/// What each chat's context held when asked in this run, and when (a
/// markdown-only answer too): the Details panel's, kept across panels so
/// switching chats doesn't ask again.
final Map<String, (DateTime, GetContextUsageResponse)> _asked = runMap();

/// What was last asked of [chatId]'s context: in this run, else as
/// remembered from an earlier one.
(DateTime, GetContextUsageResponse)? lastContext(String chatId) =>
    _asked[chatId] ?? _known[chatId];

/// When [chatId]'s context was asked in this run; null if it wasn't.
DateTime? contextAskedAt(String chatId) => _asked[chatId]?.$1;

/// Keeps [r] as what [chatId]'s context holds now: for this run, and on
/// disk as [rememberContext] keeps it.
void askedContext(String chatId, GetContextUsageResponse r) {
  _asked[chatId] = (clock(), r);
  rememberContext(chatId, r);
}

/// The chats whose context is remembered.
Iterable<String> get rememberedContexts => _known.keys;

/// Forgets [chatId]'s context (the chat is gone).
void forgetContext(String chatId) {
  _asked.remove(chatId);
  if (_known.remove(chatId) != null) _write();
}

/// Keeps [r] as what fills [chatId]'s context now (only when it has
/// categories with their parts: a markdown-only answer isn't kept).
void rememberContext(String chatId, GetContextUsageResponse r) {
  if (r.categories.isEmpty || !_parted(r.categories)) return;
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
      utf8.encode(
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
                    'part': c.part,
                  },
              ],
            },
        }),
      ),
    );
  } on Object {
    // Not remembered; the card still has it until the app quits.
  }
}

/// [cs] (what /context said, maybe a turn ago) brought up to [u], the
/// agent's latest usage: what the conversation adds goes to Messages and
/// comes out of Free space, the rest (system prompt, tools, memory,
/// skills) kept as it was. As it was when [u] says nothing or no category
/// is the conversation (its part "messages").
List<ContextCategory> liveCategories(List<ContextCategory> cs, Usage u) {
  final size = u.contextSize.toInt();
  final used = u.contextUsed.toInt();
  if (size == 0 || used == 0 || !cs.any((c) => c.part == 'messages')) {
    return cs;
  }
  bool fixed(ContextCategory c) => c.kind == '' && c.part == '';
  final rest = cs.where(fixed).fold(0, (n, c) => n + c.tokens.toInt());
  final buffer = cs
      .where((c) => c.part == 'buffer')
      .fold(0, (n, c) => n + c.tokens.toInt());
  int now(ContextCategory c) => switch (c) {
    _ when c.part == 'messages' => (used - rest).clamp(0, size),
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
          part: c.part,
        ),
  ];
}
