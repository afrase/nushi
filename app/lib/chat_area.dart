import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/folder_tree.dart' show filesApi;
import 'package:nushi/panes.dart' show Pane, paneWidth;
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';

/// A chat in the main area (ADR 0111): a pane of [top] (the window's bars),
/// its header and, under it, its transcript, its folder's changes or its
/// pull request, with the terminal below; and beside the pane, on the
/// window's background, its details as cards, which slide in and out.
class ChatArea extends StatefulWidget {
  const new(this.chat, this.daemon, {super.key, this.top});

  final ChatState chat;
  final Daemon daemon;

  /// What's over its header, inside its pane: the bars.
  final Widget? top;

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  ValueNotifier<ChatTab> get _tab => widget.chat.tab;

  /// Its pull request, looked for while the chat shows (for the tab).
  late final ChatPull _pull;

  /// The area's width and whether the details panel shows, as last built:
  /// what the preview's room is worked out from when the agent asks.
  double _width = double.infinity;
  bool _panel = false;

  /// A browser tab takes the whole area (its Expand): the details go until
  /// it gives it back, as when they lay under it.
  bool _covered = false;

  /// Whether it was built before: the details it shows at first don't slide.
  bool _built = false;

  /// How far past its box the pane is drawn while the details slide.
  final _reach = _Reach();

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
    // Gone, it has no room to say; the chat shows nowhere until it's back.
    if (widget.chat.previewFits == _previewFits) {
      widget.chat.previewFits = ChatState.fitsAlways;
    }
    _pull.unfollow();
    _reach.dispose();
    super.dispose();
  }

  /// A file's preview opened (from Artifacts, or ⌘P) shows beside the chat.
  void _showPreview() {
    if (widget.chat.preview.value != null) _tab.value = ChatTab.chat;
  }

  /// A file or page its agent asked to show opens while the transcript
  /// shows. This area lives only while its chat is the one showing, so
  /// another chat or a view in its place leaves the ask waiting, and on
  /// Changes it waits too: the agent never moves the user (ADR 0068). In a
  /// window too narrow for the pane beside the transcript it stays closed,
  /// or it would lie over the box and any card waiting; the row's Preview
  /// or Open opens it.
  void _showAsked() {
    final chat = widget.chat;
    final asked = chat.showAsked.value;
    if (asked == null || chat.shownTab != ChatTab.chat) return;
    chat.showAsked.value = null;
    if (!_previewFits()) return;
    switch (asked) {
      case ShowFile(:final path):
        chat.openPreview(path);
      case ShowPage(:final url):
        chat.showPage(url);
    }
  }

  /// Whether the preview opens beside the transcript and leaves it
  /// [ChatView.leastBesideWide], as `Beside` works it out: the details
  /// panel, the side chat and the Files pane each take their widths. It is
  /// read when asked, since a side chat or the Files pane opens without
  /// building this area again.
  bool _previewFits() {
    final chat = widget.chat;
    final side =
        chat.side.value != null && !chat.archived && !chat.sideHidden.value;
    final files = filesOpen(chat) && widget.daemon.daemonApi >= filesApi;
    // The widths ChatView's side chat and Files pane open at, as dragged.
    final panes =
        (side ? paneWidth('side', 380).clamp(300, 640) : 0) +
        (files ? paneWidth('files', 260).clamp(200, 480) : 0);
    return _width -
            (_panel ? DetailsPanel.slot : 0) -
            panes -
            ChatView.previewWidth >=
        ChatView.leastBesideWide;
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
        final fits =
            box.maxWidth >= DetailsPanel.slot + ChatView.leastBesideDetails;
        widget.chat.panelFits = fits;
        // The pull request's tab goes with its link.
        final tab = widget.chat.shownTab;
        final panel = show && fits && tab == ChatTab.chat;
        _width = box.maxWidth;
        _panel = panel;
        widget.chat.previewFits = _previewFits;
        final area = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?widget.top,
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
                    besideDetails: panel,
                    onCover: (covered) {
                      if (mounted) setState(() => _covered = covered);
                    },
                  ),
                },
              ),
            ),
          ],
        );
        // The pane is laid out at once at the width the details leave it,
        // so a transcript that lays out every entry does so once; the
        // details slide in from the right and out again ([paneSlide]), and
        // the pane's edge follows them ([Pane.reach]).
        final beside = panel && !_covered;
        final arrives = _built;
        _built = true;
        _reach.beside = beside;
        return Stack(
          children: [
            Positioned.fill(
              right: beside ? DetailsPanel.slot : 0,
              child: Pane(reach: _reach, child: area),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: DetailsPanel.slot,
              child: Presence(
                // What showed as the chat came is there; opened after, it
                // slides in.
                arrives: arrives,
                builder: (_, run, child) {
                  _reach.run.parent = run;
                  return paneSlide(run, child);
                },
                child: beside
                    ? Padding(
                        padding: const EdgeInsets.only(
                          left: NushiTheme.paneGap,
                        ),
                        child: DetailsPanel(
                          // It follows the chat it was made for.
                          key: ObjectKey(widget.chat),
                          chat: widget.chat,
                          daemon: widget.daemon,
                          onChanges: () => _tab.value = ChatTab.changes,
                          onPull: () => _tab.value = ChatTab.pull,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// How much further right than its box a chat's pane is drawn
/// ([Pane.reach]) as its details slide: laid out [beside] them it still
/// reaches the room they haven't taken yet, and laid out without them it
/// stops short of where they still are. Nothing at rest.
class _Reach extends ChangeNotifier implements ValueListenable<double> {
  new() {
    run.addListener(notifyListeners);
  }

  /// The details' slide: 0 gone, 1 shown.
  final run = ProxyAnimation(kAlwaysDismissedAnimation);
  bool beside = false;

  @override
  double get value => DetailsPanel.slot * ((beside ? 1 : 0) - run.value);
}
