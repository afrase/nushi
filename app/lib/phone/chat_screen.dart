import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
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
            ConnectionBar(phone),
            Expanded(
              child: !chat.loaded && chat.items.isEmpty
                  ? TranscriptSkeleton(chat)
                  : Transcript(
                      chat: chat,
                      daemon: daemon,
                      onTop: () => unawaited(daemon.loadOlder(chat)),
                      header: chat.older > 0 ? Earlier(daemon, chat) : null,
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

/// Above a chat's recent part: how many items come before it, and a tap
/// (or scrolling up) takes the next page.
class Earlier extends StatelessWidget {
  const new(this.daemon, this.chat, {super.key});

  final Daemon daemon;
  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final n = chat.older;
    return SizedBox(
      height: touch,
      child: Center(
        child: chat.loadingOlder
            ? const PhoneSpinner()
            : TextButton(
                onPressed: () => unawaited(daemon.loadOlder(chat)),
                child: Text(
                  n == 1 ? '1 earlier item' : '$n earlier items',
                  style: phoneText(context, color: t.link, size: 14),
                ),
              ),
      ),
    );
  }
}

/// What shows while a chat's transcript is on its way: the shape of a
/// conversation, never a blank screen; after a failed try, that it's
/// trying again.
class TranscriptSkeleton extends StatelessWidget {
  const new(this.chat, {super.key});

  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    Widget bar(double width, {double height = 12}) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Semantics(
      label: 'Loading the chat',
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth - 40;
          return ClipRect(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: bar(w * 0.6, height: 36),
                    ),
                    const SizedBox(height: 8),
                    bar(w * 0.95),
                    bar(w * 0.85),
                    bar(w * 0.5),
                    const SizedBox(height: 8),
                    bar(w * 0.7, height: 28),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      const PhoneSpinner(),
                      const SizedBox(width: 10),
                      Text(
                        chat.loadError.isEmpty
                            ? 'Loading the chat…'
                            : "Couldn't load it yet: trying again",
                        style: phoneText(
                          context,
                          size: 13,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
