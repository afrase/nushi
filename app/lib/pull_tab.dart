import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart' show actsNow;
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/pull_header.dart' show pullPad;
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/top_notices.dart';
import 'package:nushi/widgets.dart';

/// A chat's Pull request tab: the GitHub view's pull request (its
/// conversation, review threads, checks with a failed job's log, files,
/// replies and comments) for the chat's pull request; its comments are
/// seen while it shows. A comment, a thread or a failed check goes to the
/// chat's box as a reply card (Send to agent), several together; a bar
/// counts them, with the way back to the chat ([onChat]). ⌘R refreshes it,
/// as its Refresh does (a view's key, as the GitHub view's: the browser's
/// Reload page has it only on the chat, where a page shows).
class PullTab extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChat,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChat;

  @override
  State<PullTab> createState() => _PullTabState();
}

class _PullTabState extends State<PullTab> {
  /// The tab's keys' focus: it takes the focus whenever nothing below the
  /// window's own has it while the tab shows (a tab's click, or a click
  /// out of one of the tab's fields, leaves it at the window, above the
  /// tab), so ⌘R comes here; a field or a terminal with the focus keeps
  /// it.
  final _keys = FocusNode(debugLabel: 'pull tab', skipTraversal: true);

  ChatState get chat => widget.chat;
  Daemon get daemon => widget.daemon;
  VoidCallback get onChat => widget.onChat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeFocus());
    FocusManager.instance.addListener(_takeFocus);
  }

  /// Takes the focus when it's left above the tab (null, the window's).
  void _takeFocus() {
    final now = FocusManager.instance.primaryFocus;
    if (mounted && (now == null || _keys.ancestors.contains(now))) {
      _keys.requestFocus();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_takeFocus);
    _keys.dispose();
    super.dispose();
  }

  /// ⌘R: the pull request asked for now, unless a dialog is over the
  /// views (no key acts there, [actsNow]).
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (!_refreshKey.accepts(e, HardwareKeyboard.instance) ||
        !actsNow(context)) {
      return KeyEventResult.ignored;
    }
    unawaited(ChatPull.of(daemon, chat).refresh());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final source = ChatPull.of(daemon, chat);
    return Focus(
      focusNode: _keys,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: source,
        builder: (context, _) => _build(context, source),
      ),
    );
  }

  Widget _build(BuildContext context, ChatPull source) {
    final l = source.current;
    if (l == null) return const SizedBox.shrink();
    final ref = l.asRef;
    final links = source.links;
    // What went in shows on its rows ("In the box ✓") and in the bar at
    // the foot, with its Go to chat; a toast says only that nothing new
    // did, which neither of those would show.
    Future<void> send(Toasts? toast, List<Reply> replies, String what) async {
      final added = await putReplies(
        daemon,
        chat,
        ref,
        author: source.pull?.item.author ?? '',
        replies: replies,
      );
      if (replies.isEmpty) return;
      toast?.hide();
      if (added > 0) return;
      showToast(toast, sentWords(replies.length, added, what));
    }

    return SendToAgent(
      box: chat.draft.replies,
      onSend: (r, what) => send(Toasts.maybeOf(context), r, what).ignore(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (links.length >= 2) _Picker(source, l, links),
          Expanded(
            child: GitHubPullPane(
              key: ValueKey('${chat.id} ${l.id}'),
              daemon: daemon,
              ref: ref,
              source: source,
            ),
          ),
          ValueListenableBuilder(
            valueListenable: chat.draft.replies,
            builder: (context, replies, _) => replies.isEmpty
                ? const SizedBox.shrink()
                // The update card stands above it (ADR 0128).
                : UnderCard(
                    child: RepliesWaiting(replies.length, onChat: onChat),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The tab's Refresh key, the GitHub view's (⌘R). A held key asks once:
/// each repeat would start another whole read as the last one ends.
const _refreshKey = Cmd(LogicalKeyboardKey.keyR, includeRepeats: false);

/// With several pull requests (ADR 0117), the tab's head starts with a
/// menu field of their rows; the one picked is remembered for the chat.
class _Picker extends StatelessWidget {
  const new(this.cp, this.shown, this.links);

  final ChatPull cp;
  final GitHubLink shown;
  final List<GitHubLink> links;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = cp.itemOf(shown);
    // Over the page's column ([pullPad]), where its head starts.
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: EdgeInsets.fromLTRB(pullPad(box.maxWidth), 12, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: MenuField(
            compact: true,
            tooltip: "The chat's pull requests",
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  ItemIcon(it, pull: true, size: 13),
                  Text(
                    '#${shown.number}',
                    style: theme.code(t.textSecondary, size: 12),
                  ),
                  Flexible(
                    child: Text(
                      it?.title ?? shown.repo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.text, size: 12),
                    ),
                  ),
                ],
              ),
            ),
            entries: [
              for (final l in links)
                MenuEntry.row(
                  (close) => SizedBox(
                    width: 340,
                    child: PullRow(cp, l, onShow: close, menu: false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a toast says of [sent] cards put in the chat's box, [added] of
/// them new there: "Added to the chat's box: CI / rubocop", "Added 6 to
/// the chat's box", "Added 4 to the chat's box; 2 were there already",
/// "Already in the chat's box: CI / rubocop".
String sentWords(int sent, int added, String what) {
  final there = sent - added;
  if (sent == 1 || (added == 0 && what.isNotEmpty)) {
    return added > 0
        ? "Added to the chat's box: $what"
        : "Already in the chat's box: $what";
  }
  if (added == 0) return "All $sent are in the chat's box already";
  final also = there == 0
      ? ''
      : '; $there ${there == 1 ? 'was' : 'were'} there already';
  return "Added $added to the chat's box$also";
}

/// "2 waiting in the chat's box", and Go to chat: under the Pull request
/// tab and over the Changes view while cards they sent wait there.
class RepliesWaiting extends StatelessWidget {
  const new(this.n, {required this.onChat, super.key});

  final int n;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    // A banner set in from the pane's edges, as the blocks around it are
    // (ADR 0111): the accent's soft fill, no line.
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(NushiTheme.gutter - 8, 6, 6, 6),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 14, color: t.text),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$n',
                    style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
                  ),
                  const TextSpan(
                    text:
                        " waiting in the chat's box. They go with your next "
                        'message.',
                  ),
                ],
              ),
              style: theme.ui(t.text, size: 12),
            ),
          ),
          Button(label: 'Go to chat', onPressed: onChat),
        ],
      ),
    );
  }
}
