import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/phone/chat_sheet.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/files_screen.dart';
import 'package:nushi/phone/new_chat_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/turn_status.dart';
import 'package:url_launcher/url_launcher.dart';

/// A chat on the phone: the Mac's transcript (messages, tool rows
/// collapsed, plans, subagents, answerable prompts and questions) and its
/// composer (send, queue, steer, stop); Artifacts in its bar lists the files
/// it wrote, to preview.
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
        actions: [
          if (chat.pull != null)
            PullChip(
              daemon,
              chat,
              onOpen: (url) {
                if (webLink(url) case final uri?) unawaited(launchUrl(uri));
              },
            ),
          if (daemon.daemonApi >= previewApi &&
              chatFiles(chat.items).isNotEmpty)
            ListenableBuilder(
              listenable: chat.opened,
              builder: (context, _) => FilesAction(
                chatArtifacts(chat, pins: false).recent.length,
                onTap: () => FilesScreen.open(context, daemon, chat),
              ),
            ),
          PhoneIcon(
            Icons.more_horiz,
            label: 'Chat',
            onTap: () => unawaited(showChatSheet(context, daemon, chat)),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConnectionBar(phone),
            Expanded(
              child: !chat.loaded && chat.items.isEmpty
                  ? TranscriptSkeleton(chat)
                  : Previews(
                      open: daemon.daemonApi >= previewApi
                          ? (path) =>
                                PreviewScreen.open(context, daemon, chat, path)
                          : null,
                      child: Transcript(
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
            ),
            TurnStatus(chat),
          ],
        ),
        bottom: chat.archived
            ? null
            : chat.sessionGone
            ? ExpiredBar(phone, chat)
            : Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Composer(chat: chat, daemon: daemon, folder: true),
              ),
      ),
    );
  }
}

/// In place of the composer for a chat whose agent deleted its session, as
/// the Mac has it: read-only (a message would fail), with a new chat in
/// its folder.
class ExpiredBar extends StatelessWidget {
  const new(this.phone, this.chat, {super.key});

  final Phone phone;
  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.history_toggle_off, size: 16, color: t.textMuted),
          Expanded(
            child: Text(
              chat.items.any((it) => it.kind != ItemKind.ITEM_KIND_NOTICE)
                  ? 'Read-only: Nushi’s copy of the transcript.'
                  : 'Read-only.',
              style: phoneText(context, color: t.textSecondary, size: 14),
            ),
          ),
          TextButton(
            onPressed: () => newPhoneChat(
              context,
              phone,
              folder: chat.scratch ? '' : chat.folder,
            ),
            child: Text(
              'New chat here',
              style: phoneText(context, color: t.link, size: 14),
            ),
          ),
        ],
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
