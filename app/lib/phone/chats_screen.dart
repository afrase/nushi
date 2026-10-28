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
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

/// The chats, grouped by folder as the Mac's sidebar has them, each with
/// what it's doing; those that need you in a group of their own at the
/// top, so one is never at the bottom of a long list.
class ChatsScreen extends StatelessWidget {
  const new(this.phone, {super.key});

  final Phone phone;

  @override
  Widget build(BuildContext context) {
    final daemon = phone.daemon!;
    return _NeedsYou(
      daemon,
      builder: (context, needs) {
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
                child: groups.isEmpty && needs.isEmpty
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
                          if (needs.isNotEmpty) ...[
                            const PhoneHeading('Needs you'),
                            for (final c in needs)
                              ChatRow(
                                c,
                                onTap: () => openPhoneChat(context, phone, c),
                              ),
                          ],
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
    for (final cs in chatGroups(widget.daemon).values)
      ...cs.where((c) => c.phase == ChatPhase.waiting),
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
/// a word, as the Mac says it ([phaseWord]).
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
