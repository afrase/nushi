import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';
import 'package:nushi/widgets.dart';

/// Opens the New chat screen, on [folder] if given ('' for none); a chat
/// started there opens.
Future<void> newPhoneChat(
  BuildContext context,
  Phone phone, {
  String? folder,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => NewChatScreen(phone, folder: folder)),
);

/// A new chat: a folder (one of the chats', none, or a path typed) and an
/// agent.
class NewChatScreen extends StatefulWidget {
  const new(this.phone, {super.key, this.folder});

  final Phone phone;

  /// The folder picked at first; the most recent one when null.
  final String? folder;

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  late final Daemon _daemon = widget.phone.daemon!;
  // The folder asked for first, even when no live chat has it.
  late final List<String> _recent = {
    if (widget.folder case final f? when f.isNotEmpty) f,
    ...recentFolders(_daemon.chats.values),
  }.toList();
  late String _folder = widget.folder ?? _recent.firstOrNull ?? '';
  late String _agent = lastAgent(_daemon.chats.values);
  final _typed = TextEditingController();
  bool _starting = false;
  TrustAsk? _asked; // the trust question shown, until answered

  @override
  void initState() {
    super.initState();
    _daemon.addListener(_trust);
  }

  @override
  void dispose() {
    _daemon.removeListener(_trust);
    // Backing out is a no: the start doesn't wait on a question gone.
    _asked?.decide(start: false);
    _daemon.trustAsk?.decide(start: false);
    _typed.dispose();
    super.dispose();
  }

  /// A folder that brings code of its own asks first, as on the Mac, with
  /// each thing it runs, exactly: "Start anyway" approves them.
  void _trust() {
    final ask = _daemon.trustAsk;
    if (ask == null || !mounted) return;
    _daemon.trustAsk = null;
    _asked = ask;
    unawaited(
      showDialog<bool>(
        context: context,
        builder: (context) => nushiDialog(
          'Start ${agentTitle(ask.agent)} here?',
          _TrustRuns(ask),
          [
            Button(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context, false),
            ),
            Button(
              label: 'Start anyway',
              kind: ButtonKind.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ).then((start) => ask.decide(start: start ?? false)),
    );
  }

  Future<void> _start() async {
    final folder = _typed.text.trim().isNotEmpty ? _typed.text.trim() : _folder;
    setState(() => _starting = true);
    try {
      await _daemon.startChat(folder, _agent);
      final chat = _daemon.selected;
      if (!mounted) return;
      if (chat != null) {
        Navigator.of(context).pop();
        await openPhoneChat(context, widget.phone, chat);
      }
    } on Object catch (e) {
      if (mounted) phoneSay(context, errorText(e));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ValueListenableBuilder(
      valueListenable: agentList,
      builder: (context, agents, _) => PhoneScreen(
        title: 'New chat',
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PhoneHeading('Folder'),
            for (final f in [..._recent, ''])
              _Choice(
                folderParts(f, scratch: f.isEmpty).$1,
                detail: folderParts(f, scratch: f.isEmpty).$2,
                picked: _typed.text.trim().isEmpty && _folder == f,
                onTap: () => setState(() {
                  _folder = f;
                  _typed.clear();
                }),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                controller: _typed,
                onChanged: (_) => setState(() {}),
                autocorrect: false,
                style: phoneText(context),
                decoration: const InputDecoration(
                  hintText: 'Another folder: /Users/you/project',
                ),
              ),
            ),
            const PhoneHeading('Agent'),
            for (final a in agents.values)
              _Choice(
                a.title,
                detail: a.ready ? '' : a.problem,
                mark: AgentMark(a.name, color: t.textSecondary),
                picked: _agent == a.name,
                onTap: () => setState(() => _agent = a.name),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: PhoneButton(
                _starting ? 'Starting…' : 'Start',
                primary: true,
                onTap: _starting || _agent.isEmpty ? null : _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a folder's code runs: each thing, its file (from the folder), and
/// its command, a line of its own, as the Mac's trust card shows it.
class _TrustRuns extends StatelessWidget {
  const new(this.ask);

  final TrustAsk ask;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    String shown(String file) => file.startsWith('${ask.folder}/')
        ? file.substring(ask.folder.length + 1)
        : tildePath(file);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'This folder brings code for it to run:',
            style: phoneText(context, size: 15),
          ),
          for (final FolderRun r in ask.runs)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  '${r.what} (${shown(r.file)})',
                  style: phoneText(context, size: 15),
                ),
                if (r.command.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      r.command,
                      style: theme.code(t.textSecondary, size: 12.5),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const new(
    this.label, {
    required this.picked,
    required this.onTap,
    this.detail = '',
    this.mark,
  });

  final String label;
  final String detail;
  final bool picked;
  final VoidCallback onTap;
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: touch + 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              if (mark case final m?) ...[m, const SizedBox(width: 10)],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: label, style: phoneText(context)),
                      if (detail.isNotEmpty)
                        TextSpan(
                          text: '  $detail',
                          style: phoneText(
                            context,
                            color: t.textMuted,
                            size: 13,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                picked ? Icons.check_circle : Icons.circle_outlined,
                size: 22,
                color: picked ? t.accentInk : t.borderStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
