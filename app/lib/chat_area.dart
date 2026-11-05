import 'package:flutter/material.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';

/// A chat under its header, with a switch between its transcript, its
/// folder's changes and its pull request.
class ChatArea extends StatefulWidget {
  const new(this.chat, this.daemon, {super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  ValueNotifier<ChatTab> get _tab => widget.chat.tab;

  /// Its pull request, looked for while the chat shows (for the tab).
  late final ChatPull _pull;

  @override
  void initState() {
    super.initState();
    // A chat opens on the tab it was left on (ChatState.tab), but on its
    // transcript when it needs you: what it asks is there.
    if (widget.chat.phase == ChatPhase.waiting) _tab.value = ChatTab.chat;
    widget.chat.addListener(_showFile);
    widget.chat.preview.addListener(_showPreview);
    widget.chat.showAsked.addListener(_showAsked);
    _tab.addListener(_showAsked);
    // After this frame: the panes beside the transcript aren't built yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showAsked();
    });
    _pull = ChatPull.of(widget.daemon, widget.chat)..follow();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_showFile);
    widget.chat.preview.removeListener(_showPreview);
    widget.chat.showAsked.removeListener(_showAsked);
    _tab.removeListener(_showAsked);
    _pull.unfollow();
    super.dispose();
  }

  /// A file's preview opened (from Artifacts, or ⌘P) shows beside the chat.
  void _showPreview() {
    if (widget.chat.preview.value != null) _tab.value = ChatTab.chat;
  }

  /// A file its agent asked to show opens while the transcript shows. This
  /// area lives only while its chat is the one showing, so another chat or
  /// a view in its place leaves the ask waiting, and on Changes it waits
  /// too: the agent never moves the user (ADR 0068). In a window too narrow
  /// for the pane beside the transcript it stays closed, or it would lie
  /// over the box and any card waiting; the row's Preview opens it.
  void _showAsked() {
    final chat = widget.chat;
    final path = chat.showAsked.value;
    if (path == null || chat.shownTab != ChatTab.chat) return;
    chat.showAsked.value = null;
    if (chat.previewFits) chat.openPreview(path);
  }

  /// A file to show (ChatState.showFile, from a review's finding) shows in
  /// the Changes view.
  void _showFile() {
    if (widget.chat.openPath != null) _tab.value = ChatTab.changes;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ListenableBuilder(
      listenable: Listenable.merge([showDetails, _tab]),
      builder: (context, _) {
        final show = showDetails.value;
        // The panel goes when the chat would get too narrow.
        final fits = box.maxWidth >= DetailsPanel.width + ChatView.minWidth;
        widget.chat.panelFits = fits;
        // The pull request's tab goes with its link.
        final tab = widget.chat.shownTab;
        final panel = show && fits && tab == ChatTab.chat;
        widget.chat.previewFits =
            box.maxWidth -
                (panel ? DetailsPanel.width : 0) -
                ChatView.previewWidth >=
            ChatView.leastBesideWide;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: widget.chat,
              builder: (context, _) => ChatHeader(
                widget.chat,
                widget.daemon,
                tab: widget.chat.shownTab,
                onTab: (t) => _tab.value = t,
                panel: panel,
                onPanel: fits && tab == ChatTab.chat
                    ? () => showDetails.value = !show
                    : null,
              ),
            ),
            Expanded(
              child: TerminalArea(
                chat: widget.chat,
                daemon: widget.daemon,
                onChanges: () => _tab.value = ChatTab.changes,
                child: switch (tab) {
                  ChatTab.changes => ChangesView(
                    chat: widget.chat,
                    daemon: widget.daemon,
                  ),
                  ChatTab.pull => PullTab(
                    chat: widget.chat,
                    daemon: widget.daemon,
                    onChat: () => _tab.value = ChatTab.chat,
                  ),
                  ChatTab.chat => ChatView(
                    chat: widget.chat,
                    daemon: widget.daemon,
                    details: panel
                        ? DetailsPanel(
                            // It follows the chat it was made for.
                            key: ObjectKey(widget.chat),
                            chat: widget.chat,
                            daemon: widget.daemon,
                            onChanges: () => _tab.value = ChatTab.changes,
                            onPull: () => _tab.value = ChatTab.pull,
                          )
                        : null,
                  ),
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
