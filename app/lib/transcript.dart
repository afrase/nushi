import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:nushi/bottom_follower.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/tool_calls.dart';

/// Whether [e] is a tool call that shows as a row, and can join a run of
/// them (a review's findings show as a card of their own).
bool _row(Object? e) =>
    e is Item && e.kind == ItemKind.ITEM_KIND_TOOL_CALL && !e.hasFindings();

/// The items, with each run of tool calls as one list, and each subagent
/// as one [SubagentRun] with what it did.
List<Object> _entries(List<Item> items) {
  final subs = {for (final s in subagentsOf(items)) s.call.id: s};
  final out = <Object>[];
  for (final it in items) {
    final last = out.lastOrNull;
    if (subs.containsKey(it.parent)) continue;
    if (subs[it.id] case final sub?) {
      out.add(sub);
    } else if (_row(it) && last is List<Item>) {
      last.add(it);
    } else if (_row(it) && _row(last)) {
      out.last = [last! as Item, it];
    } else {
      out.add(it);
    }
  }
  return out;
}

/// A chat's items, built as they scroll into view. It opens at the bottom
/// and follows it while the agent writes; scrolled up, it stays put and
/// offers a way back to the latest. Selected text gets a toolbar above it
/// to ask a side question about it, or to reply to it; selected by touch, the
/// selection's own menu has those beside Copy. Given [items] (a
/// subagent's steps) it shows those instead, between [header] and
/// [footer], [live] while more come.
class Transcript extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onReply,
    super.key,
    this.onSide,
    this.items,
    this.live = false,
    this.header,
    this.footer,
    this.onTop,
  });

  final ChatState chat;
  final Daemon daemon;

  /// Takes a reply to the selection (for the composer); null hides the
  /// action.
  final void Function(Reply reply)? onReply;

  /// Opens a side question about the selection; null hides the action.
  final void Function(String selection)? onSide;

  final List<Item>? items;
  final bool live;
  final Widget? header;
  final Widget? footer;

  /// Called as the user scrolls near the top (the phone takes an older
  /// page then); what shows stays put as items come in above it.
  final VoidCallback? onTop;

  @override
  State<Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<Transcript> {
  final _follower = BottomFollower();
  final _area = GlobalKey<SelectionAreaState>();
  // A click outside (the composer) takes the focus and clears the
  // selection without reporting it: the toolbar goes with it. An open reply
  // box stays, its quote kept.
  late final FocusNode _areaFocus = FocusNode(debugLabel: 'transcript')
    ..addListener(() {
      if (!_areaFocus.hasFocus && _at != null && _replyTo == null) {
        _closeToolbar();
      }
    });
  String _selected = '';
  bool _down = false; // a pointer is down on the transcript
  // Pacing holds while a pointer is down or text is selected.
  final _hold = ValueNotifier<bool>(false);
  bool _touch = false; // the last pointer down was a finger (or a pen)
  Rect? _at; // the selection's top and bottom middle, where the toolbar shows
  String? _replyTo; // the selection a reply is being written to
  _Anchor _anchor = _Anchor(); // where the reply box opened

  // The widget built for each entry, by key, and what it was built from.
  var _built = <String, (List<Object>, Widget)>{};

  // The first entry's key at the last build: when items come in above it,
  // the list moves down by their height, so what shows stays put.
  String? _first;

  // The entries' keys at the last build, once the chat had loaded: what
  // comes in after them rises in. Not what a load or an older page brings.
  List<String>? _shown;
  ChatState? _shownChat;

  /// The keys of [entries] that are new since the last build, after the
  /// last of what was there; none on the first build or a load.
  Set<String> _arrived(List<Object> entries) {
    final keys = [for (final e in entries) _keyOf(e)];
    final was = _shownChat == widget.chat ? _shown : null;
    final loaded = widget.items != null || widget.chat.loaded;
    _shown = loaded ? keys : null;
    _shownChat = widget.chat;
    if (was == null || was.isEmpty) return const {};
    final known = was.toSet();
    final last = keys.lastIndexWhere(known.contains);
    if (last < 0) return const {}; // all of it anew: a reload
    return {for (final k in keys.skip(last + 1)) k};
  }

  bool _onScroll(Notification n) {
    if (widget.onTop case final top?
        when n is ScrollUpdateNotification &&
            n.depth == 0 &&
            (n.scrollDelta ?? 0) < 0 &&
            n.metrics.pixels < 800) {
      top();
    }
    return _follower.onNotification(n);
  }

  void _keepPlace(List<Object> entries) {
    if (widget.onTop == null || entries.isEmpty) return;
    final was = _first;
    final first = _first = _keyOf(entries.first);
    if (was == null || was == first || !_follower.scroll.hasClients) return;
    if (_follower.following || !entries.any((e) => _keyOf(e) == was)) return;
    final max = _follower.scroll.position.maxScrollExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_follower.scroll.hasClients) return;
      final q = _follower.scroll.position;
      q.jumpTo(
        (q.pixels + q.maxScrollExtent - max).clamp(0, q.maxScrollExtent),
      );
    });
  }

  /// An entry's widget, the one built before if its items are the same.
  Widget _entry(
    Map<String, (List<Object>, Widget)> before,
    Object e, {
    required bool live,
    required bool still,
    required double top,
    bool rise = false,
  }) {
    final key = _keyOf(e);
    final items = switch (e) {
      final List<Item> run => run,
      final SubagentRun s => [s.call, ...s.items],
      _ => [e],
    };
    final rewindable = e is Item && canRewindTo(widget.chat, e);
    final from = [live, still, rewindable, top, ...items];
    final was = before[key];
    final same =
        was != null &&
        was.$1.length == from.length &&
        Iterable<int>.generate(from.length)
            .every((i) => identical(was.$1[i], from[i]));
    return (_built[key] = same
            ? was
            : (
                from,
                // Keyed, the item's state follows it as items arrive.
                Padding(
                  key: ValueKey(key),
                  // A user message's band goes edge to edge.
                  padding: _isBand(e)
                      ? EdgeInsets.only(top: top)
                      : _sides.copyWith(top: top),
                  // New while the chat is open, it rises in, once.
                  child: Enter.rise(
                    play: rise,
                    child: RepaintBoundary(
                      // A call's title types out as it comes, or as it
                      // joins a run; not what the chat opened with.
                      child: Arriving(
                        play: rise || was != null,
                        child: _view(
                          e,
                          live: live,
                          still: still,
                          rewindable: rewindable,
                        ),
                      ),
                    ),
                  ),
                ),
              ))
        .$2;
  }

  /// An entry's view: an item, a run of tool calls or a subagent.
  Widget _view(
    Object e, {
    required bool live,
    required bool still,
    bool rewindable = false,
  }) => switch (e) {
    final List<Item> run => ToolGroupView(run, still: still),
    final SubagentRun s => SubagentLine(
      s,
      widget.chat,
      still: still,
      daemon: widget.daemon,
    ),
    _ => ItemView(
      e as Item,
      widget.chat,
      widget.daemon,
      live: live,
      still: still,
      onRewind: rewindable
          ? () => rewind(context, widget.daemon, widget.chat, e)
          : null,
    ),
  };

  @override
  void initState() {
    super.initState();
    // A finished subagent's steps open at the top, at its prompt.
    if (widget.items != null && !widget.live) _follower.following = false;
  }

  @override
  void dispose() {
    _hold.dispose();
    _follower.dispose();
    _areaFocus.dispose();
    super.dispose();
  }

  // The selection is reported a frame after the pointer goes up: offer the
  // toolbar once both have happened.
  // On touch the selection's own menu offers the actions instead (_menu).
  void _offer() {
    if (_touch || _down || _at != null || _selected.trim().isEmpty) return;
    if (_anchors() case final at?) setState(() => _at = at);
  }

  /// The selection's top and bottom middle, in the transcript's box.
  Rect? _anchors() {
    final a = _area.currentState?.selectableRegion.contextMenuAnchors;
    final box = context.findRenderObject() as RenderBox?;
    if (a == null || box == null) return null;
    return Rect.fromPoints(
      box.globalToLocal(a.primaryAnchor),
      box.globalToLocal(a.secondaryAnchor ?? a.primaryAnchor),
    );
  }

  void _openReply() => setState(() {
    _at ??= _anchors();
    _replyTo = _selected;
    _anchor = _Anchor();
  });

  /// The selection's menu: as the platform's on a mouse; on touch, one menu
  /// of Copy, Side question and Reply where the platform draws its own, so
  /// nothing of Nushi's sits under it (iOS's Copy | Select All hid the
  /// toolbar on the phone).
  Widget _menu(
    SelectableRegionState region, {
    required VoidCallback? onSide,
    required VoidCallback? onReply,
  }) {
    if (!_touch || (onSide == null && onReply == null)) {
      return AdaptiveTextSelectionToolbar.selectableRegion(
        selectableRegionState: region,
      );
    }
    VoidCallback then(VoidCallback run) => () {
      region.hideToolbar();
      run();
    };
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: region.contextMenuAnchors,
      buttonItems: [
        ...region.contextMenuButtonItems.where(
          (b) => b.type == ContextMenuButtonType.copy,
        ),
        if (onSide != null)
          ContextMenuButtonItem(
            label: 'Side question',
            onPressed: then(onSide),
          ),
        if (onReply != null)
          ContextMenuButtonItem(label: 'Reply', onPressed: then(onReply)),
      ],
    );
  }

  void _closeToolbar() => setState(() => _at = _replyTo = null);

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final entries = _entries(widget.items ?? chat.items);
    _keepPlace(entries);
    final arrived = _arrived(entries);
    final live = widget.items == null ? chat.busy : widget.live;
    _follower.stick();
    final before = _built;
    _built = {};
    final onReply = widget.onReply;
    final onSide = chat.canFork ? widget.onSide : null;
    final side = onSide == null
        ? null
        : () {
            final selected = _selected;
            _closeToolbar();
            onSide(selected);
          };
    final reply = onReply == null ? null : _openReply;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          NotificationListener(
            onNotification: _onScroll,
            // One selection across the transcript, messages included whole;
            // when a drag or double-click leaves text selected, the popover
            // shows where the pointer went up.
            child: Listener(
              onPointerDown: (e) => setState(() {
                _down = _hold.value = true;
                _touch = e.kind != PointerDeviceKind.mouse;
                _at = _replyTo = null;
              }),
              onPointerUp: (_) {
                _down = false;
                _hold.value = _selected.isNotEmpty;
                _offer();
              },
              child: SelectionArea(
                key: _area,
                focusNode: _areaFocus,
                contextMenuBuilder: (context, region) =>
                    _menu(region, onSide: side, onReply: reply),
                onSelectionChanged: (c) {
                  _selected = c?.plainText ?? '';
                  _hold.value = _down || _selected.isNotEmpty;
                  _offer();
                },
                // Every item is laid out, so the list knows its exact
                // height: the scrollbar keeps its size and nothing shifts
                // as items come into view. Unchanged items keep their
                // widget, so a streamed chunk rebuilds only its message.
                child: PacingHold(
                  notifier: _hold,
                  child: SingleChildScrollView(
                    controller: _follower.scroll,
                    padding: const EdgeInsets.only(top: 2, bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.header case final h?)
                          Padding(padding: _sides, child: h),
                        for (final (i, e) in entries.indexed)
                          _entry(
                            before,
                            e,
                            live: live && i == entries.length - 1,
                            still: chat.waiting,
                            top: _gap(
                              entries,
                              i,
                              header: widget.header != null,
                            ),
                            rise: arrived.contains(_keyOf(e)),
                          ),
                        if (widget.footer case final f?)
                          Padding(padding: _sides, child: f),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_at case final at? when onReply != null || onSide != null)
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _Above(at, _replyTo == null ? null : _anchor),
                child: switch (_replyTo) {
                  // Its own layer: typing repaints only the box.
                  final quote? => RepaintBoundary(
                    child: ReplyBox(
                      quote: quote,
                      onReply: onReply!,
                      onClose: _closeToolbar,
                    ),
                  ),
                  null => SelectionToolbar(onSide: side, onReply: reply),
                },
              ),
            ),
          ListenableBuilder(
            listenable: _follower,
            builder: (context, _) => _follower.following
                ? const SizedBox.shrink()
                : Positioned(
                    right: 20,
                    bottom: 12,
                    child: JumpChip(
                      // A prompt waits below: the chip says so.
                      needs: widget.items == null && chat.waiting,
                      onTap: _follower.follow,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

const _sides = EdgeInsets.symmetric(horizontal: 20);

/// An entry's key: a call and the group it becomes keep their place (and
/// state).
String _keyOf(Object e) => switch (e) {
  final List<Item> run => run.first.id,
  final SubagentRun s => 'agent ${s.call.id}',
  _ => (e as Item).id,
};

bool _isBand(Object e) =>
    e is Item && e.kind == ItemKind.ITEM_KIND_USER_MESSAGE;

/// A user message's band, the agent starting on its own, or where a
/// reopened chat's history comes from changes.
bool _opens(Object e) =>
    _isBand(e) ||
    e is Item &&
        e.kind == ItemKind.ITEM_KIND_NOTICE &&
        const {'own_turn', 'compacted', 'history_differs'}.contains(e.status);

/// The room above entry [i]: more around what opens a chapter than between
/// the agent's steps, so each exchange reads as one.
double _gap(List<Object> entries, int i, {required bool header}) =>
    _opens(entries[i])
    ? (i == 0 && !header ? 8 : 28)
    : (i > 0 && _opens(entries[i - 1]) ? 18 : 12);

/// Where a reply box's bottom edge went when it opened: it stays there as
/// the box grows a line at a time, so the box grows upward, as Claude's.
class _Anchor {
  double? bottom;
}

/// Places its child centered just above [at] (a selection's top and bottom
/// middle), or below it when there is no room above, inside the box. With
/// an [anchor] (the reply box) the child keeps the bottom edge it first
/// had, kept inside too.
class _Above extends SingleChildLayoutDelegate {
  new(this.at, [this.anchor]);

  final Rect at;
  final _Anchor? anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: max(0, c.maxWidth - 16),
    maxHeight: max(0, c.maxHeight - 8),
  );

  @override
  Offset getPositionForChild(Size size, Size child) {
    double inside(double y) =>
        y.clamp(4, max(4, size.height - child.height - 4));
    final double y;
    if (anchor?.bottom case final bottom?) {
      y = inside(bottom - child.height);
    } else {
      final above = at.top - child.height - 6;
      y = inside(above < 4 ? at.bottom + 6 : above);
      anchor?.bottom = y + child.height;
    }
    return Offset(
      (at.center.dx - child.width / 2).clamp(
        8,
        max(8, size.width - child.width - 8),
      ),
      y,
    );
  }

  @override
  bool shouldRelayout(_Above old) => old.at != at || old.anchor != anchor;
}
