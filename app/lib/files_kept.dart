import 'dart:async';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_tabs.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

// A chat's file tabs kept across launches (ADR 0070's amendment of
// 2026-11-19): Nushi restarts for each update, and its Files pane comes
// back as it was left.

/// The chats whose file tabs are kept: each once, as the daemon first
/// lists it.
final _keeping = Expando<bool>();

/// Keeps [chat]'s file tabs in [fileTabsKept] from now on, after putting
/// back those kept from the last launch whose files are still there (the
/// daemon finds them, as the Files pane would open them; a gone one doesn't
/// come back). Once for each chat; the Mac's only. Until the kept ones are
/// back, a change of tabs saves nothing over them: a restore that fails
/// leaves them as they were, and the chat's next event tries again.
void keepFileTabs(Daemon daemon, ChatState chat) {
  if (_keeping[chat] ?? false) return;
  _keeping[chat] = true;
  final kept = fileTabsKept.value[chat.id];
  if (kept == null) {
    _follow(chat);
  } else {
    unawaited(_restore(daemon, chat, kept));
  }
}

Future<void> _restore(Daemon daemon, ChatState chat, KeptTabs kept) async {
  final FindChatFilesResponse found;
  try {
    found = await daemon.client.findChatFiles(
      FindChatFilesRequest(chatId: chat.id, paths: kept.tabs.take(200)),
    );
  } on Object {
    _keeping[chat] = null; // kept as they were; tried again
    return;
  }
  // A tab opened meanwhile is merged in, and saved with them.
  chat.files.restore(kept, found.found.toSet(), folder: chat.folder);
  _save(chat); // none back: none kept
  _follow(chat);
}

/// Saves [chat]'s tabs whenever they change.
void _follow(ChatState chat) =>
    chat.files.changes.addListener(() => _save(chat));

void _save(ChatState chat) {
  final kept = chat.files.kept(chat.folder);
  final all = {...fileTabsKept.value}..remove(chat.id);
  fileTabsKept.value = {...all, chat.id: ?kept};
}
