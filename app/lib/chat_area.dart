import 'package:flutter/material.dart';
import 'package:nushi/beside.dart';
import 'package:nushi/beside_fit.dart' show PaneSpec;
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_panes.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/files_open.dart';
import 'package:nushi/panes.dart' show Pane;
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/type_to_box.dart';

/// A chat in the main area (ADR 0111, 0123): one pane of its transcript, its
/// folder's changes or its pull request, its details rail at the
/// transcript's right, its header over the two and its terminal under
/// them, and right of all of those its side panes ([chatPanes]), each the
/// pane's full height. The header and its buttons stay where they are as
/// the details show and hide; the rail tucks itself away when the panes
/// need its room. All of it is laid out by one [Beside], which keeps the
/// header and the terminal as the tabs change. Over it, [notices]: the
/// bars, the newer release's card and the toasts' place, the toasts over
/// the transcript and the card in the area's bottom right corner, above
/// the bars at the foot of whatever is there (ADR 0128).
class ChatArea extends StatefulWidget {
  const new(this.chat, this.daemon, {super.key, this.notices});

  final ChatState chat;
  final Daemon daemon;
  final ({Widget bars, Widget card})? notices;

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  ValueNotifier<ChatTab> get _tab => widget.chat.tab;

  /// Its pull request, looked for while the chat shows (for the tab).
  late final ChatPull _pull;

  /// The area's width, as last built: what the panes' and the details'
  /// room is worked out from when asked.
  double _width = double.infinity;

  /// The file view's and the browser's tab rows: each tab's view is made
  /// again as it shows, and its row moves to the new one with its place
  /// kept.
  final GlobalKey<State> _fileTabs = GlobalKey();

  /// The details panel's, the same for every chat's area: another chat
  /// picked (a new area), the panel moves to it, the last chat's rows
  /// showing until the new one's are known ([DetailsPanel]).
  static final GlobalKey<State> _details = GlobalKey();
  final GlobalKey<State> _browserTabs = GlobalKey();

  /// The pane that takes the whole area, over the transcript (its Expand,
  /// ADR 0094): the Files pane or the browser, by its name; null for none.
  /// It lasts while that pane shows on the Chat tab: the pane closed or
  /// hidden, the other one showing a tab, a subagent's pane in the
  /// browser's place, a terminal opening, another chat (another area) or
  /// another tab put it back.
  final _cover = ValueNotifier<String?>(null);

  /// Where ⌃` and the keys stay when what had the focus goes.
  final _keys = FocusNode(skipTraversal: true);

  /// Tells its chat what covers it ([ChatState.covered]).
  void _covered() => widget.chat.covered = _cover.value;

  @override
  void initState() {
    super.initState();
    _cover.addListener(_covered);
    // A chat opens on the tab it was left on (ChatState.tab), but on its
    // transcript when it needs you: what it asks is there.
    if (widget.chat.phase == ChatPhase.waiting) _tab.value = ChatTab.chat;
    widget.chat.addListener(_showFile);
    widget.chat.files.shown.addListener(_filesShown);
    widget.chat.filesOpened.addListener(_fileOpened);
    filesChats.addListener(_filesShown);
    _tab.addListener(_filesShown);
    _filesShown();
    _browserTab = widget.chat.browser.shown.value;
    widget.chat.browser.shown.addListener(_showBrowserTab);
    widget.chat.pane.addListener(_collapse);
    filesChats.addListener(_collapse);
    widget.chat.showAsked.addListener(_showAsked);
    _tab.addListener(_showAsked);
    _tab.addListener(_collapse);
    _terminalOpen = terminalChats.value.contains(widget.chat.id);
    terminalChats.addListener(_terminalShown);
    // After this frame: the panes beside the transcript aren't built yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showAsked();
    });
    _pull = ChatPull.of(widget.daemon, widget.chat)..follow();
    // Where the focus goes when what had it goes (the terminal hidden, the
    // details tucked away): typing there still writes in the box (ADR 0121).
    typesThrough.add(_keys);
  }

  @override
  void dispose() {
    widget.chat.removeListener(_showFile);
    widget.chat.files.shown.removeListener(_filesShown);
    widget.chat.filesOpened.removeListener(_fileOpened);
    filesChats.removeListener(_filesShown);
    _tab.removeListener(_filesShown);
    widget.chat.browser.shown.removeListener(_showBrowserTab);
    widget.chat.pane.removeListener(_collapse);
    filesChats.removeListener(_collapse);
    widget.chat.showAsked.removeListener(_showAsked);
    _tab.removeListener(_showAsked);
    _tab.removeListener(_collapse);
    terminalChats.removeListener(_terminalShown);
    // Gone, it has no room to say; the chat shows nowhere until it's back.
    if (widget.chat.panelFits == _panelFits) {
      widget.chat.panelFits = ChatState.fitsAlways;
    }
    _pull.unfollow();
    if (widget.chat.covered == _cover.value) widget.chat.covered = null;
    _cover.dispose();
    _inFiles.dispose();
    typesThrough.remove(_keys);
    _keys.dispose();
    super.dispose();
  }

  /// Whether the pane [name] shows beside the transcript, so it can cover
  /// it: the Files pane while it's open, the browser while a tab shows in
  /// it, on the Chat tab.
  bool _coverable(String? name) {
    final chat = widget.chat;
    if (name == null || chat.shownTab != ChatTab.chat) return false;
    return switch (name) {
      'filesPane' => filesOpen(chat),
      'browser' => chat.pane.value == null && chat.browser.shown.value != null,
      _ => false,
    };
  }

  /// What covers no longer shows: it's put back.
  void _collapse() {
    if (!_coverable(_cover.value)) _cover.value = null;
  }

  /// The browser's tab that showed, as last heard.
  BrowserTab? _browserTab;

  /// A browser tab opened or shown puts an expanded Files pane back (it
  /// shows in the browser beside it), but not the next one showing as one
  /// closes; a browser hidden or closed is put back.
  void _showBrowserTab() {
    final browser = widget.chat.browser;
    final was = _browserTab;
    final now = _browserTab = browser.shown.value;
    final closed = was != null && !browser.tabs.value.contains(was);
    if (now != null && !closed && _cover.value == ChatPanes.files.name) {
      _cover.value = null;
    }
    _collapse();
  }

  /// Whether its chat's terminal was open, as last heard.
  late bool _terminalOpen;

  /// Its chat's terminal opened, however (⌃`, the palette, a command's
  /// Open in terminal): over an expanded browser tab, which covers it, the
  /// tab is put back, or the terminal would open where nothing shows it.
  void _terminalShown() {
    final open = terminalChats.value.contains(widget.chat.id);
    if (open && !_terminalOpen) _cover.value = null;
    _terminalOpen = open;
  }

  /// ⌃`: the terminal shows or hides. Over an expanded browser tab, which
  /// covers it, it only shows: the tab is put back, and a terminal open
  /// under it is shown, not closed unseen ([_terminalShown] puts the tab
  /// back for one that opens).
  void _toggleTerminal() {
    if (_cover.value != null && terminalChats.value.contains(widget.chat.id)) {
      _cover.value = null;
      return;
    }
    toggleTerminalOf(widget.chat, _keys);
  }

  /// A file opened shows in the Files pane beside the chat, so an expanded
  /// browser is put back for it (ADR 0094); an expanded Files pane shows it
  /// where it is.
  void _fileOpened() {
    if (_cover.value == ChatPanes.browser.name) _cover.value = null;
  }

  /// The file the Files pane shows while it shows: what a tool row's
  /// Preview and a file chip mark as open.
  final _inFiles = ValueNotifier<PreviewFile?>(null);

  void _filesShown() => _inFiles.value = filesShown(widget.chat)
      ? widget.chat.files.shown.value
      : null;

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
    switch (asked) {
      case ShowFile(:final path) when _filesFit():
        chat.openInFiles(path);
      case ShowPage(:final url) when _browserFits():
        chat.showPage(url);
      case _:
    }
  }

  /// Whether the Files pane is open, or opens beside the transcript and
  /// leaves it [ChatView.leastBesideWide], as [Beside] works it out
  /// ([chatFit]): the details rail tucks itself away for it and the panes
  /// narrow, each to its least at most. It is read when asked, since a side
  /// chat opens without building this area again.
  bool _filesFit() =>
      filesOpen(widget.chat) ||
      _fits(openPanes(widget.chat, widget.daemon, files: true));

  /// Whether the browser opens beside the transcript, as [_filesFit] (a
  /// subagent's pane takes no room: the browser takes its place).
  bool _browserFits() =>
      _fits(openPanes(widget.chat, widget.daemon, browser: true));

  bool _fits(List<PaneSpec> panes) => !chatFit(
    room: _width,
    panes: panes,
    saved: paneWidths.value,
    wantRail: false,
  ).over;

  /// Whether the details rail has room to show beside the transcript and
  /// the panes open now, at their saved widths: the window is wide enough
  /// for it (ADR 0092), and the panes leave it room (ADR 0123).
  bool _panelFits() =>
      _width >= _railFrom &&
      chatFit(
        room: _width,
        panes: openPanes(widget.chat, widget.daemon),
        saved: paneWidths.value,
        wantRail: true,
      ).rail;

  /// The narrowest chat area with room for the details at all (ADR 0092).
  static const double _railFrom =
      DetailsPanel.width + ChatView.leastBesideDetails;

  /// A file to show (ChatState.showFile, from a review's finding) shows in
  /// the Changes view.
  void _showFile() {
    if (widget.chat.openPath != null) _tab.value = ChatTab.changes;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _width = box.maxWidth;
      final chat = widget.chat;
      return Pane(
        child: TerminalKeys(
          focus: _keys,
          onToggle: _toggleTerminal,
          child: ListenableBuilder(
            listenable: Listenable.merge([showDetails, _tab]),
            builder: (context, _) {
              final show = showDetails.value;
              // The panel goes when the chat would get too narrow, and
              // its button with it; beside panes that need its room it's
              // tucked away, still wanted (ADR 0123).
              final fits = box.maxWidth >= _railFrom;
              chat.panelFits = _panelFits;
              // The pull request's tab goes with its link.
              final tab = chat.shownTab;
              final onChat = tab == ChatTab.chat;
              final panel = show && fits && onChat;
              // Made here, once a change of these, so a pane opening or
              // closing doesn't build them again.
              final head = ListenableBuilder(
                listenable: chat,
                builder: (context, _) => ChatHeader(
                  chat,
                  widget.daemon,
                  tab: chat.shownTab,
                  onTab: (t) => _tab.value = t,
                  panel: panel,
                  onPanel: fits && onChat
                      ? () => showDetails.value = !show
                      : null,
                ),
              );
              final main = switch (tab) {
                ChatTab.changes => ChangesView(
                  chat: chat,
                  daemon: widget.daemon,
                ),
                ChatTab.pull => PullTab(
                  chat: chat,
                  daemon: widget.daemon,
                  onChat: () => _tab.value = ChatTab.chat,
                ),
                ChatTab.chat => ChatView(
                  chat: chat,
                  daemon: widget.daemon,
                  onPull: () => _tab.value = ChatTab.pull,
                ),
              };
              final foot = TerminalFoot(
                chat: chat,
                daemon: widget.daemon,
                onChanges: () => _tab.value = ChatTab.changes,
                onHide: _toggleTerminal,
              );
              final details = panel
                  ? SidePane.fixed(
                      'details',
                      width: DetailsPanel.width,
                      child: DetailsPanel(
                        key: _details,
                        chat: chat,
                        daemon: widget.daemon,
                        onChanges: () => _tab.value = ChatTab.changes,
                        onPull: () => _tab.value = ChatTab.pull,
                      ),
                    )
                  : null;
              return Previews(
                // Only the transcript's rows open a preview or a tab.
                open: onChat ? chat.openInFiles : null,
                browse: onChat ? (url) => chat.openBrowserTab('$url') : null,
                browseFits: _browserFits,
                current: _inFiles,
                name: (path) => relativeIn(chat.folder, path),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    chat.pane,
                    chat.browser.shown,
                    chat.side,
                    chat.sideHidden,
                    filesChats,
                    filesTree,
                    _cover,
                  ]),
                  builder: (context, _) => _beside(
                    context,
                    tab: tab,
                    head: head,
                    main: main,
                    foot: foot,
                    details: details,
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );

  /// [main] with the chat's panes and [details] beside it (on the Chat
  /// tab), [head] over them and [foot] under them.
  Widget _beside(
    BuildContext context, {
    required ChatTab tab,
    required Widget head,
    required Widget main,
    required Widget foot,
    required SidePane? details,
  }) {
    final chat = widget.chat;
    final onChat = tab == ChatTab.chat;
    final panes = onChat
        ? chatPanes(
            context,
            chat,
            widget.daemon,
            fileTabsKey: _fileTabs,
            browserTabsKey: _browserTabs,
            cover: _coverable(_cover.value) ? _cover.value : null,
            onExpand: (name) =>
                _cover.value = _cover.value == name ? null : name,
          )
        : const <SidePane>[];
    // One is dragged as wide as it's wanted (PaneSpec.wide).
    final wide = panes.any((p) => p.wide);
    final cover = _coverable(_cover.value) ? _cover.value : null;
    return Beside(
      scene: tab,
      head: head,
      main: main,
      foot: foot,
      keep: _keys,
      // The text's column glides as a pane opens or closes beside it.
      columnSides: onChat ? (width) => chatSides(context, width) : null,
      // The least the transcript keeps beside the panes, and beside the
      // details too (ADR 0092): narrower, the rail tucks away, and
      // narrower than that the panes lie over it ([chatFit]).
      least: wide ? ChatView.leastBesideWide : ChatView.minWidth,
      railLeast: wide ? ChatView.leastBesideWide : ChatView.leastBesideDetails,
      cover: cover,
      panes: panes,
      details: details,
      notices: widget.notices,
    );
  }
}
