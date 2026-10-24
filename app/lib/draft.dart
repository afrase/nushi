import 'package:flutter/widgets.dart';

import 'images.dart';
import 'replies.dart';

/// What the user is writing to a chat: the box's text, the files mentioned
/// with @, the reply cards and the images. It lives on the chat, not in the
/// view, so switching chats, a peek at Changes or the MCP servers, or a
/// lost connection don't lose it.
class Draft {
  final text = TextEditingController();
  final mentions = <String>{};
  final Replies replies = ValueNotifier(const []);
  final images = Attachments();

  /// Text to quote in the box (a side question's start), taken by the box.
  final quote = ValueNotifier<String?>(null);

  /// The subagent a message taken back was for: its call and type. The
  /// message goes there again.
  final relay = ValueNotifier<(String call, String agent)?>(null);
}
