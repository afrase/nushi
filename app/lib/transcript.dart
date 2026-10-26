import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/bottom_follower.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/widgets.dart';

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
/// to start a side chat about it, or to reply to it. Given [items] (a
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

  @override
  State<Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<Transcript> {
  final _follower = BottomFollower();
  final _area = GlobalKey<SelectionAreaState>();
  String _selected = '';
  bool _down = false; // a pointer is down on the transcript
  Rect? _at; // the selection's top and bottom middle, where the toolbar shows
  String? _replyTo; // the selection a reply is being written to

  // The widget built for each entry, by key, and what it was built from.
  var _built = <String, (List<Object>, Widget)>{};

  /// An entry's widget, the one built before if its items are the same.
  Widget _entry(
    Map<String, (List<Object>, Widget)> before,
    Object e, {
    required bool live,
    required bool still,
    required double top,
  }) {
    final (key, items) = switch (e) {
      // A call and the group it becomes keep their place (and state).
      final List<Item> run => (run.first.id, run),
      final SubagentRun s => ('agent ${s.call.id}', [s.call, ...s.items]),
      _ => ((e as Item).id, [e]),
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
                  child: RepaintBoundary(
                    child: _view(
                      e,
                      live: live,
                      still: still,
                      rewindable: rewindable,
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
    final SubagentRun s => SubagentLine(s, widget.chat, still: still),
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
    _follower.dispose();
    super.dispose();
  }

  // The selection is reported a frame after the pointer goes up: offer the
  // toolbar once both have happened.
  void _offer() {
    if (_down || _at != null || _selected.trim().isEmpty) return;
    final a = _area.currentState?.selectableRegion.contextMenuAnchors;
    final box = context.findRenderObject() as RenderBox?;
    if (a == null || box == null) return;
    setState(
      () => _at = Rect.fromPoints(
        box.globalToLocal(a.primaryAnchor),
        box.globalToLocal(a.secondaryAnchor ?? a.primaryAnchor),
      ),
    );
  }

  void _closeToolbar() => setState(() => _at = _replyTo = null);

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final entries = _entries(widget.items ?? chat.items);
    final live = widget.items == null ? chat.busy : widget.live;
    _follower.stick();
    final before = _built;
    _built = {};
    final onReply = widget.onReply;
    final onSide = chat.canFork ? widget.onSide : null;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          NotificationListener(
            onNotification: _follower.onNotification,
            // One selection across the transcript, messages included whole;
            // when a drag or double-click leaves text selected, the popover
            // shows where the pointer went up.
            child: Listener(
              onPointerDown: (_) => setState(() {
                _down = true;
                _at = _replyTo = null;
              }),
              onPointerUp: (_) {
                _down = false;
                _offer();
              },
              child: SelectionArea(
                key: _area,
                onSelectionChanged: (c) {
                  _selected = c?.plainText ?? '';
                  _offer();
                },
                // Every item is laid out, so the list knows its exact
                // height: the scrollbar keeps its size and nothing shifts
                // as items come into view. Unchanged items keep their
                // widget, so a streamed chunk rebuilds only its message.
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
                          top: _gap(entries, i, header: widget.header != null),
                        ),
                      if (widget.footer case final f?)
                        Padding(padding: _sides, child: f),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_at case final at? when onReply != null || onSide != null)
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _Above(at),
                child: switch (_replyTo) {
                  final quote? => ReplyBox(
                    quote: quote,
                    onReply: onReply!,
                    onClose: _closeToolbar,
                  ),
                  null => SelectionToolbar(
                    onSide: onSide == null
                        ? null
                        : () {
                            final selected = _selected;
                            _closeToolbar();
                            onSide(selected);
                          },
                    onReply: onReply == null
                        ? null
                        : () => setState(() => _replyTo = _selected),
                  ),
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
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: t.raised,
                        shape: StadiumBorder(
                          side: BorderSide(color: t.borderStrong),
                        ),
                      ),
                      child: Tap(
                        onTap: _follower.follow,
                        radius: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 6,
                          children: [
                            Icon(Icons.arrow_downward, size: 14, color: t.text),
                            Text(
                              'Jump to latest',
                              style: theme.ui(t.text, size: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

const _sides = EdgeInsets.symmetric(horizontal: 20);

bool _isBand(Object e) =>
    e is Item && e.kind == ItemKind.ITEM_KIND_USER_MESSAGE;

/// A user message's band, or the agent starting on its own.
bool _opens(Object e) =>
    _isBand(e) ||
    e is Item && e.kind == ItemKind.ITEM_KIND_NOTICE && e.status == 'own_turn';

/// The room above entry [i]: more around what opens a chapter than between
/// the agent's steps, so each exchange reads as one.
double _gap(List<Object> entries, int i, {required bool header}) =>
    _opens(entries[i])
    ? (i == 0 && !header ? 8 : 28)
    : (i > 0 && _opens(entries[i - 1]) ? 18 : 12);

/// Places its child centered just above [at] (a selection's top and bottom
/// middle), or below it when there is no room above, inside the box.
class _Above extends SingleChildLayoutDelegate {
  new(this.at);

  final Rect at;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => c.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    var y = at.top - child.height - 6;
    if (y < 4) y = at.bottom + 6;
    return Offset(
      (at.center.dx - child.width / 2).clamp(
        8,
        max(8, size.width - child.width - 8),
      ),
      y.clamp(4, max(4, size.height - child.height - 4)),
    );
  }

  @override
  bool shouldRelayout(_Above old) => old.at != at;
}
