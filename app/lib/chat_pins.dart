import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

// Pinned chats: the daemon keeps which and in what order (PinChats), so
// the phone shows them too; the app sends the whole order each time.

/// Whether [chat] can be pinned or unpinned: not archived, on a daemon
/// that keeps pins.
bool canPinChat(Daemon d, ChatState? chat) =>
    chat != null && !chat.archived && d.daemonApi >= pinApi;

/// Pins [chat] at the bottom of Pinned, or unpins it, which puts it back
/// in its project where it was (or at the top).
Future<void> toggleChatPin(Daemon d, ChatState chat) {
  final ids = [for (final c in pinnedChats(d)) c.id];
  return setChatPins(
    d,
    chat.pin > 0 ? (ids..remove(chat.id)) : [...ids, chat.id],
  );
}

/// Pins [ids], top first, and unpins every other chat. The chats show it
/// at once; if the daemon refuses, they go back as they were.
Future<void> setChatPins(Daemon d, List<String> ids) async {
  final before = {for (final c in d.chats.values) c.id: c.pin};
  void show(int Function(ChatState) pin) {
    for (final c in d.chats.values) {
      c.pin = pin(c);
    }
    d.listChanged();
  }

  show((c) => ids.indexOf(c.id) + 1);
  try {
    await d.client.pinChats(PinChatsRequest(chatIds: ids));
  } on Object {
    show((c) => before[c.id] ?? 0);
    rethrow;
  }
}

/// [chats] with the one at [from] moved to [to] (its place once it's
/// out).
List<ChatState> reorderedChats(List<ChatState> chats, int from, int to) {
  final out = [...chats];
  return out..insert(to, out.removeAt(from));
}
