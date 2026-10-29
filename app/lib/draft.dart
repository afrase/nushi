import 'package:flutter/widgets.dart';

import 'package:nushi/images.dart';
import 'package:nushi/replies.dart';

/// What the user is writing to a chat: the box's text, the files mentioned
/// with @, the reply cards and the images. It lives on the chat, not in the
/// view, so switching chats, a peek at Changes or the MCP servers, or a
/// lost connection don't lose it.
class Draft {
  final text = TextEditingController();
  final mentions = <String>{};
  final Replies replies = ValueNotifier(const []);
  final images = Attachments();

  /// Adds [r] as a card, unless it's there already (the same comment,
  /// thread or check sent twice).
  void addReply(Reply r) {
    final now = replies.value;
    if (now.contains(r)) return;
    replies.value = [...now, r];
  }

  /// Text to quote in the box (a side question's start), taken by the box.
  final quote = ValueNotifier<String?>(null);

  /// The subagent a message taken back was for: its call and type. The
  /// message goes there again.
  final relay = ValueNotifier<(String call, String agent)?>(null);
}

/// An agent's question form half answered (QuestionCard): what's picked
/// and written, and the question it's on. It lives on the chat, so a look
/// at another chat or at Settings doesn't lose it.
final class QuestionDraft {
  /// The options picked, by field id.
  final picked = <String, List<String>>{};

  /// The text written, by field id.
  final text = <String, TextEditingController>{};

  /// The question shown (the last is Submit).
  int tab = 0;
}
