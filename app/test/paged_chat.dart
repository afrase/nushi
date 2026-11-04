import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A chat's items as the daemon pages them (internal/api's GetChat with
/// `recent`, GetChatItems): a page reaches back to the call of a subagent
/// whose steps are in it. Every request is in [asked]; while [fail] is set
/// a page fails, and while [hold] is set a page waits for it.
class PagedChat {
  new(this.chat, this.items);

  final Chat chat;
  final List<Item> items;
  final asked = <Object>[];
  bool fail = false;
  Completer<void>? hold;

  /// FakeDaemon's answer for this chat's GetChat and GetChatItems.
  Object? answer(Object input) => switch (input) {
    GetChatRequest(:final chatId) when chatId == chat.id => _chat(input),
    GetChatItemsRequest(:final chatId) when chatId == chat.id => _page(input),
    _ => null,
  };

  GetChatResponse _chat(GetChatRequest r) {
    asked.add(r);
    final start = r.recent > 0 ? _start(items.length, r.recent) : 0;
    return GetChatResponse(
      chat: chat,
      status: chat.status,
      items: items.sublist(start),
      older: start,
    );
  }

  Future<GetChatItemsResponse> _page(GetChatItemsRequest r) async {
    asked.add(r);
    if (hold case final h?) await h.future;
    if (fail) throw ConnectException(Code.unavailable, 'the link dropped');
    final end = items.indexWhere((it) => it.id == r.before);
    if (end < 0) throw ConnectException(Code.notFound, 'no such item');
    final start = _start(end, r.limit <= 0 || r.limit > 500 ? 500 : r.limit);
    return GetChatItemsResponse(items: items.sublist(start, end), older: start);
  }

  /// The daemon's pageStart.
  int _start(int end, int n) {
    var start = end - n < 0 ? 0 : end - n;
    final index = {for (final (i, it) in items.take(end).indexed) it.id: i};
    for (var i = end - 1; i >= start; i--) {
      if (index[items[i].parent] case final j? when j < start) start = j;
    }
    return start;
  }

  /// The pages asked for after the first load.
  Iterable<GetChatItemsRequest> get pages =>
      asked.whereType<GetChatItemsRequest>();
}
