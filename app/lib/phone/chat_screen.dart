import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/status.dart';
import 'package:nushi/transcript.dart';

/// A chat on the phone: the Mac's transcript (messages, tool rows
/// collapsed, plans, subagents, answerable prompts and questions) and its
/// composer (send, queue, steer, stop).
class ChatScreen extends StatelessWidget {
  const new(this.phone, this.chat, {super.key});

  final Phone phone;
  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final daemon = phone.daemon!;
    return ListenableBuilder(
      listenable: Listenable.merge([chat, daemon]),
      builder: (context, _) => PhoneScreen(
        title: chat.title.isEmpty ? 'New chat' : chat.title,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!daemon.connected) Offline(daemon),
            Expanded(
              child: Transcript(
                chat: chat,
                daemon: daemon,
                onReply: chat.archived || chat.sessionGone
                    ? null
                    : (r) => chat.draft.replies.value = [
                        ...chat.draft.replies.value,
                        r,
                      ],
              ),
            ),
            if (chat.busy) TurnStatus(chat),
          ],
        ),
        bottom: chat.archived
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Composer(chat: chat, daemon: daemon, folder: true),
              ),
      ),
    );
  }
}
