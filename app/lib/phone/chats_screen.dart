import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/phone/chat_screen.dart';
import 'package:nushi/phone/connection_bar.dart';
import 'package:nushi/phone/new_chat_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/settings_screen.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

/// The chats, grouped by folder as the Mac's sidebar has them, each with
/// what it's doing; those that need you in a group of their own at the
/// top, so one is never at the bottom of a long list, then the pinned
/// ones (the daemon keeps them), as the Mac's Pinned has them.
class ChatsScreen extends StatelessWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  @override
  Widget build(BuildContext context) {
    final daemon = phone.daemon!;
    return _NeedsYou(
      daemon,
      builder: (context, needs) {
        final pinned = [
          for (final c in pinnedChats(daemon))
            if (!needs.contains(c)) c,
        ];
        final groups = {
          for (final MapEntry(:key, :value) in chatGroups(daemon).entries)
            if (value.where((c) => !needs.contains(c)).toList() case final rest
                when rest.isNotEmpty)
              key: rest,
        };
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
                child: groups.isEmpty && needs.isEmpty && pinned.isEmpty
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
                          _Sections(
                            [
                              if (needs.isNotEmpty)
                                (
                                  const ValueKey(#needs),
                                  const PhoneHeading('Needs you'),
                                  needs,
                                ),
                              if (pinned.isNotEmpty)
                                (
                                  const ValueKey(#pinned),
                                  const PhoneHeading('Pinned'),
                                  pinned,
                                ),
                              for (final MapEntry(key: folder, value: chats)
                                  in groups.entries)
                                (ValueKey(folder), _Folder(folder), chats),
                            ],
                            row: (c) => ChatRow(
                              c,
                              key: ValueKey(c.id),
                              onTap: () => openPhoneChat(context, phone, c),
                            ),
                          ),
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

/// Builds with the chats that need you (a permission prompt or a
/// question), the newest first, again when the daemon's list changes or a
/// chat starts or stops needing you (not at each streamed chunk).
class _NeedsYou extends StatefulWidget {
  const new(this.daemon, {required this.builder});

  final Daemon daemon;
  final Widget Function(BuildContext context, List<ChatState> needs) builder;

  @override
  State<_NeedsYou> createState() => _NeedsYouState();
}

class _NeedsYouState extends State<_NeedsYou> {
  final _chats = <ChatState>{};
  List<ChatState> _needs = const [];

  @override
  void initState() {
    super.initState();
    widget.daemon.addListener(_relisted);
    _follow();
  }

  @override
  void dispose() {
    widget.daemon.removeListener(_relisted);
    for (final c in _chats) {
      c.removeListener(_changed);
    }
    super.dispose();
  }

  /// The list changed: follow its chats, and build.
  void _relisted() => setState(_follow);

  void _follow() {
    final now = widget.daemon.chats.values.toSet();
    for (final c in _chats.difference(now)) {
      c.removeListener(_changed);
    }
    for (final c in now.difference(_chats)) {
      c.addListener(_changed);
    }
    _chats
      ..clear()
      ..addAll(now);
    _needs = _waiting();
  }

  void _changed() {
    final needs = _waiting();
    if (listEquals(needs, _needs)) return;
    setState(() => _needs = needs);
  }

  List<ChatState> _waiting() => [
    for (final c in widget.daemon.chats.values)
      if (!c.archived && c.phase == ChatPhase.waiting) c,
  ]..sort((a, b) => b.created.compareTo(a.created));

  @override
  Widget build(BuildContext context) => widget.builder(context, _needs);
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

/// The list's sections, each a heading and its chats' rows ([row]): a
/// section or a row that comes grows in, one that goes fades and folds
/// ([SlideList]), so a chat that starts needing you leaves its project
/// and comes into "Needs you", which grows in with it and folds once
/// none does. With Reduce Motion they come and go at once.
class _Sections extends StatelessWidget {
  const new(this.sections, {required this.row});

  final List<(Key, Widget, List<ChatState>)> sections;
  final Widget Function(ChatState chat) row;

  @override
  Widget build(BuildContext context) => SlideList<Object>(
    count: sections.length,
    accepts: (_) => false, // nothing drags here
    onMove: (_, _) {},
    item: (i, _) {
      final (key, heading, chats) = sections[i];
      return Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          SlideList<Object>(
            count: chats.length,
            accepts: (_) => false,
            onMove: (_, _) {},
            item: (j, _) => row(chats[j]),
          ),
        ],
      );
    },
  );
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
/// a word, as the Mac says it ([phaseWord]); tinted with its color, as on
/// the Mac, which is where one is set.
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
        final (word, color) = phaseWord(chat.phase, t);
        final row = InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: touch + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ChatDot(chat: chat, sparks: true),
                  const SizedBox(width: 10),
                  AgentMark(chat.agent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chat.shownTitle,
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
        return switch (chat.color?.tint(t)) {
          final tint? => Material(color: tint, child: row),
          null => row,
        };
      },
    );
  }
}
