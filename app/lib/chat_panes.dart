import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nushi/beside.dart';
import 'package:nushi/beside_fit.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/fork_chat.dart';
import 'package:nushi/settings.dart' show filesTree;
import 'package:nushi/side_chat.dart';
import 'package:nushi/task_pane.dart';

/// The panes that open beside a chat's transcript, left to right, each at
/// the width it opens at until dragged and its least and most: the side
/// chat, the Files pane (its viewer and tree, ADR 0123), a subagent's or a
/// background command's pane (named as the old Wider one was, so a width
/// dragged then stays) or a workflow's, and the browser, in that one's
/// place.
abstract final class ChatPanes {
  static const side = PaneSpec(
    'side',
    initial: 380,
    min: 300,
    cap: 640,
    squeezed: 240,
  );

  /// The viewer at 560 and the tree at 260 (`files_split.dart`); at its
  /// least, the viewer's 300 and the tree's 200. Its rows fold, so lying
  /// over the view it gives first, down to 200, before the rest narrow.
  static const files = PaneSpec(
    'filesPane',
    initial: 820,
    min: 500,
    cap: double.infinity,
    wide: true,
    squeezed: 200,
  );

  /// The Files pane with its viewer alone (its tree hidden, ⇧⌘Y, or a
  /// daemon older than the tree): the same width, so hiding the tree moves
  /// no edge, and the viewer's least.
  static const filesNoTree = PaneSpec(
    'filesPane',
    initial: 820,
    min: 300,
    cap: double.infinity,
    wide: true,
    squeezed: 200,
  );

  /// It opens at the details panel's width before that took its own (ADR
  /// 0092).
  static const subagent = PaneSpec(
    'subagent',
    initial: 264,
    min: 220,
    cap: double.infinity,
    wide: true,
  );

  /// A workflow's tree wants more room than a subagent's steps, and keeps
  /// its own width (ADR 0127).
  static const workflow = PaneSpec(
    'workflow',
    initial: 420,
    min: 280,
    cap: double.infinity,
    wide: true,
  );
  static const browser = PaneSpec(
    'browser',
    initial: 560,
    min: 300,
    cap: double.infinity,
    wide: true,
  );
}

/// The panes open beside [chat]'s transcript, left to right, as the chat
/// view lays them out: a hidden side chat, or an archived chat's, isn't
/// placed, and a subagent's or a command's pane takes the browser's place.
/// [files] and [browser] count that pane as open (the room it would take,
/// when the agent asks for one).
List<PaneSpec> openPanes(
  ChatState chat,
  Daemon daemon, {
  bool files = false,
  bool browser = false,
}) {
  final id = chat.pane.value;
  final pane = id != null;
  return [
    if (chat.side.value != null && !chat.archived && !chat.sideHidden.value)
      ChatPanes.side,
    if (files || filesOpen(chat))
      if (filesTree.value) ChatPanes.files else ChatPanes.filesNoTree,
    if (pane && !browser)
      if (workflowPaneOpen(chat, id))
        ChatPanes.workflow
      else
        ChatPanes.subagent,
    if (browser || !pane && chat.browser.shown.value != null) ChatPanes.browser,
  ];
}

/// [besideFit] for a chat's room with [panes] open: beside a pane dragged
/// as wide as it's wanted (a subagent's, the preview) the transcript keeps
/// [ChatView.leastBesideWide]; beside the rest, [ChatView.minWidth], and
/// beside the details rail [ChatView.leastBesideDetails] (ADR 0092).
BesideFit chatFit({
  required double room,
  required List<PaneSpec> panes,
  required Map<String, double> saved,
  required bool wantRail,
  Map<String, double> live = const {},
}) {
  final wide = panes.any((p) => p.wide);
  return besideFit(
    room: room,
    panes: panes,
    saved: saved,
    live: live,
    wantRail: wantRail,
    least: wide ? ChatView.leastBesideWide : ChatView.minWidth,
    railLeast: wide ? ChatView.leastBesideWide : ChatView.leastBesideDetails,
    rail: DetailsPanel.width,
  );
}

/// The panes open beside [chat]'s transcript, left to right ([openPanes]),
/// each at its own remembered width and closed on its own: the side chat,
/// the Files pane, a subagent's or background command's pane (or the
/// browser in its place). The Files pane's tab row is [fileTabsKey]'s and
/// the browser's [browserTabsKey]'s, so each keeps its scroll as its tabs
/// change. The Files pane or the browser named [cover] is expanded over
/// all of it (ADR 0094), and [onExpand] toggles a pane's, by its name.
List<SidePane> chatPanes(
  BuildContext context,
  ChatState chat,
  Daemon daemon, {
  required GlobalKey fileTabsKey,
  required GlobalKey browserTabsKey,
  required String? cover,
  required ValueChanged<String> onExpand,
}) {
  final side = chat.side.value;
  final id = chat.pane.value;
  return [
    for (final spec in openPanes(chat, daemon))
      SidePane.of(
        spec,
        child: switch (spec.name) {
          'side' => SideChat(
            key: ValueKey(side!.id),
            side: side,
            daemon: daemon,
            onHide: () => chat.sideHidden.value = true,
            onClose: () => unawaited(endSide(context, daemon, chat)),
            onKeep: () => unawaited(keepSide(context, daemon, chat)),
          ),
          'filesPane' => FilesPane(
            chat: chat,
            daemon: daemon,
            tabsKey: fileTabsKey,
            onClose: () => toggleFiles(chat),
            expanded: cover == spec.name,
            onExpand: () => onExpand(spec.name),
          ),
          // Keyed by its id: another subagent's pane is its own, its unsent
          // text too.
          'subagent' || 'workflow' => taskPane(
            chat: chat,
            daemon: daemon,
            id: id!,
            onClose: () => chat.pane.value = null,
          ),
          _ => BrowserPane(
            key: ObjectKey(chat.browser.shown.value),
            chat: chat,
            tab: chat.browser.shown.value!,
            daemon: daemon,
            tabsKey: browserTabsKey,
            onClose: () => closeBrowser(chat),
            expanded: cover == spec.name,
            onExpand: () => onExpand(spec.name),
          ),
        },
      ),
  ];
}
