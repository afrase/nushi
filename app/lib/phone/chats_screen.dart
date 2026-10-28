import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/phone/chat_screen.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/new_chat_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/settings_screen.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

/// The chats, grouped by folder as the Mac's sidebar has them, each with
/// what it's doing.
class ChatsScreen extends StatelessWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  @override
  Widget build(BuildContext context) {
    final daemon = phone.daemon!;
    return ListenableBuilder(
      listenable: daemon,
      builder: (context, _) {
        final groups = chatGroups(daemon);
        return PhoneScreen(
          title: 'Chats',
          actions: [
            PhoneIcon(
              Icons.add,
              label: 'New chat',
              onTap: daemon.connected
                  ? () => newPhoneChat(context, phone)
                  : null,
            ),
            PhoneIcon(
              Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => SettingsScreen(phone)),
              ),
            ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConnectionBar(phone),
              UpdateBar(phone),
              Expanded(
                child: groups.isEmpty
                    ? Center(
                        child: Text(
                          daemon.connected ? 'No chats' : '',
                          style: phoneText(
                            context,
                            color: NushiTheme.of(context).t.textMuted,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final MapEntry(key: folder, value: chats)
                              in groups.entries) ...[
                            _Folder(folder),
                            for (final c in chats)
                              ChatRow(
                                c,
                                onTap: () => openPhoneChat(context, phone, c),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Opens [chat] on its own screen; the daemon knows it shows, so no push
/// comes for it meanwhile.
Future<void> openPhoneChat(
  BuildContext context,
  Phone phone,
  ChatState chat,
) async {
  phone.open(chat.id);
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => ChatScreen(phone, chat)));
  if (phone.daemon?.selectedId == chat.id) phone.daemon?.selectedId = null;
  unawaited(phone.view(null));
}

class _Folder extends StatelessWidget {
  const new(this.folder);

  final String folder;

  @override
  Widget build(BuildContext context) {
    final (name, parent) = folder.isEmpty
        ? ('No folder', '')
        : folderParts(folder);
    return PhoneHeading(name, detail: parent);
  }
}

/// A chat in the list: its state, its agent, its title, and its state in
/// a word: "done" while a turn's end is unseen, then "idle" (always "done"
/// from a daemon that doesn't keep it).
class ChatRow extends StatelessWidget {
  const new(this.chat, {required this.onTap, super.key});

  final ChatState chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final (word, color) = chat.waiting
            ? ('needs you', t.needs)
            : chat.busy
            ? ('running', t.running)
            : chat.reopenFailed
            ? ("couldn't start", t.crashed)
            : chat.unseen ?? false
            ? ('done', t.done)
            : chat.asleep
            ? ('asleep', t.idle)
            : chat.fresh
            ? ('new', t.idle)
            : chat.unseen == false
            ? ('idle', t.idle)
            : ('done', t.done);
        return InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: touch + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ChatDot(chat: chat),
                  const SizedBox(width: 10),
                  AgentMark(chat.agent, color: t.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chat.title.isEmpty ? 'New chat' : chat.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: phoneText(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(word, style: phoneText(context, color: color, size: 13)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
