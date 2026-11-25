import 'package:flutter/material.dart';

import 'package:nushi/background_commands.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/workflow_pane.dart';
import 'package:nushi/workflows.dart';

/// The pane of a background task the chat's pane slot shows ([ChatState.
/// pane], a call's id): a background command's, a workflow's or a
/// subagent's. Keyed by the call: another task's pane is its own. A pane
/// whose call went (a rewind, a reload without it) stays the kind it was
/// and says so.
Widget taskPane({
  required ChatState chat,
  required Daemon daemon,
  required String id,
  required VoidCallback onClose,
}) => switch (_kindOf(chat, id)) {
  _Kind.command => BackgroundCommandPane(
    key: ValueKey(id),
    chat: chat,
    daemon: daemon,
    id: id,
    onClose: onClose,
  ),
  _Kind.workflow => WorkflowPane(
    key: ValueKey(id),
    chat: chat,
    daemon: daemon,
    id: id,
    onClose: onClose,
  ),
  _Kind.subagent => SubagentPane(
    key: ValueKey(id),
    chat: chat,
    daemon: daemon,
    id: id,
    onClose: onClose,
  ),
};

/// Whether the pane slot shows a workflow's pane: it has a width of its
/// own, wider than a subagent's (ADR 0127).
bool workflowPaneOpen(ChatState chat, String id) =>
    _kindOf(chat, id) == _Kind.workflow;

enum _Kind { command, workflow, subagent }

/// The kind of the last pane each chat showed, by its call's id: what a
/// call that went was.
final _shown = Expando<(String, _Kind)>('pane kind');

/// The kind of call [id]'s pane: by the call, or, once it went, by what it
/// was when its pane last showed.
_Kind _kindOf(ChatState chat, String id) {
  final call = chat.withRunning.where((it) => it.id == id).firstOrNull;
  if (call == null) {
    if (_shown[chat] case (final was, final kind) when was == id) return kind;
    return _Kind.subagent;
  }
  final kind = call.hasBackgroundCommand()
      ? _Kind.command
      : isWorkflow(call)
      ? _Kind.workflow
      : _Kind.subagent;
  _shown[chat] = (id, kind);
  return kind;
}

/// A task pane's header: [title], Stop while [stoppable], and × to close.
/// Its buttons are the header's (`IconTap.header`), ended where the chat's
/// header ends its own (`PaneHeader.buttonsEnd`, ADR 0122).
class TaskPaneHeader extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.id,
    required this.title,
    required this.stoppable,
    required this.onClose,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final String id; // the task's call, which Stop stops
  final Widget title;
  final bool stoppable;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => PaneHeader(
    end: PaneHeader.buttonsEnd,
    child: Row(
      children: [
        Expanded(child: title),
        if (stoppable)
          stopButton(context, daemon, chat, id, padding: IconTap.header),
        IconTap(
          Icons.close,
          tooltip: 'Close',
          size: 15,
          padding: IconTap.header,
          onTap: onClose,
        ),
      ],
    ),
  );
}

/// What a task pane says once its call went from the chat (a rewind, a
/// reload without it): [text], centred.
class PaneGone extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.ui(theme.t.textMuted, size: 12),
        ),
      ),
    );
  }
}

/// The prompt a subagent or a workflow's agent was given, in a card,
/// folded to a few lines.
class PromptCard extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: cardBox(t),
      child: FoldedText(
        text,
        style: theme.ui(t.text, size: 12),
        folded: 5,
        padding: const EdgeInsets.symmetric(vertical: 2),
      ),
    );
  }
}
