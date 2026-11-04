import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// What Continue sends: the words Claude Code's users type to have the
/// agent pick up where a failed turn left off.
const continuePrompt = 'Continue.';

/// What a failed turn's notice offers: its button's label and what it
/// sends.
typedef TurnRetry = ({String label, SendPromptRequest request});

/// What [notice], a failed turn's, offers to send. When the turn got
/// somewhere ([madeProgress]), Continue: [continuePrompt] as a plain
/// message, since the agent has the message and the work in its history
/// and sending the message again has it start over (or say it already
/// did). Else Try again: the chat's last message once more, with its
/// images, as a new one, to a subagent as it went.
///
/// Null unless the notice is the transcript's last item, the chat isn't
/// archived and no rewind is on its way; and for Try again, unless the
/// message can go again: not a subagent's task stopped (it has nothing to
/// send), nor a message for a subagent whose tool call a replay no longer
/// tells.
TurnRetry? failedTurnRetry(ChatState chat, Item notice) {
  final items = chat.items;
  if (notice.status != 'turn_failed' ||
      chat.archived ||
      chat.rewinding.value ||
      items.lastOrNull?.id != notice.id) {
    return null;
  }
  if (madeProgress(items, notice)) {
    return (
      label: 'Continue',
      request: SendPromptRequest(chatId: chat.id, text: continuePrompt),
    );
  }
  final message = items.reversed
      .where((it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE)
      .firstOrNull;
  if (message == null ||
      message.toSubagentStop ||
      message.toSubagentName.isNotEmpty && message.toSubagent.isEmpty ||
      message.text.isEmpty && message.images.isEmpty) {
    return null;
  }
  return (
    label: 'Try again',
    request: SendPromptRequest(
      chatId: chat.id,
      text: message.text,
      images: message.images,
      toSubagent: message.toSubagent,
    ),
  );
}

/// Whether the turn [notice] (the transcript's last item) ended got
/// anywhere after the last user message: the agent said, thought or did
/// something of its own between the two. That is a message with text or
/// images (not one that only repeats the failure, as Claude's "API Error:
/// …" does), a thought, a tool call (a subagent's start among them), a
/// plan, a permission prompt or a question; at the top level, and not a
/// subagent's report, since a subagent started earlier may add those to
/// any turn. Notices aren't the agent's. A message steered into the turn
/// is part of it: the turn's work before it counts, and the agent has the
/// message already. It reads only what a reopen keeps too (kinds, text and
/// Nushi's copy's steered mark, no times or live state), so it holds after
/// the daemon restarts.
bool madeProgress(List<Item> items, Item notice) {
  for (final it in items.reversed.skip(1)) {
    if (it.parent.isNotEmpty || it.report) continue;
    switch (it.kind) {
      case ItemKind.ITEM_KIND_USER_MESSAGE when !it.steered:
        return false;
      case ItemKind.ITEM_KIND_AGENT_MESSAGE:
        final text = it.text.trim();
        if (it.images.isNotEmpty ||
            text.isNotEmpty && !notice.text.contains(text)) {
          return true;
        }
      case ItemKind.ITEM_KIND_THOUGHT ||
          ItemKind.ITEM_KIND_TOOL_CALL ||
          ItemKind.ITEM_KIND_PLAN ||
          ItemKind.ITEM_KIND_PERMISSION ||
          ItemKind.ITEM_KIND_QUESTION:
        return true;
      // Notices, and kinds a newer daemon sends.
      // ignore: no_default_cases
      default:
    }
  }
  return false;
}
