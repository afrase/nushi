import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/widgets.dart';

/// `/copy`, offered with the agent's commands in every chat and answered
/// here: the agent never sees it (ADR 0075).
final copyCommand = Command(
  name: 'copy',
  description:
      'Copy the agent’s last message as Markdown (/copy 2: the one '
      'before)',
  hint: 'N',
);

final _copy = RegExp(r'^/copy(?:\s+(\d+))?$');

/// Which message [text] asks `/copy` for, 1 the latest; null when it isn't
/// `/copy`.
int? copyAsked(String text) {
  final m = _copy.firstMatch(text);
  if (m == null) return null;
  return m[1] == null ? 1 : int.tryParse(m[1]!) ?? 0;
}

/// The agent's [n]th latest message in [chat] as it wrote it, a subagent's
/// aside; null when there's none that far back.
String? agentMessage(ChatState chat, int n) {
  if (n < 1) return null;
  final messages = chat.items.reversed.where(
    (i) =>
        i.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE &&
        i.parent.isEmpty &&
        i.text.isNotEmpty,
  );
  return messages.skip(n - 1).firstOrNull?.text;
}

/// Copies the agent's [n]th latest message, and says so.
Future<void> copyMessage(BuildContext context, ChatState chat, int n) async {
  final text = agentMessage(chat, n);
  if (text == null) {
    showError(context, 'No agent message to copy');
    return;
  }
  await tryOrShow(context, () async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showError(context, 'Copied');
  });
}
