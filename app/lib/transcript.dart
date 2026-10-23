import 'dart:math';

import 'package:flutter/material.dart';

import 'bottom_follower.dart';
import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'items.dart';
import 'replies.dart';
import 'subagents.dart';
import 'theme/theme.dart';
import 'tool_calls.dart';
import 'widgets.dart';

/// The items, with each run of tool calls as one list, and each subagent
/// as one [Subagent] with what it did.
List<Object> _entries(List<Item> items, {required bool busy}) {
  final subs = {for (final s in subagentsOf(items, busy: busy)) s.call.id: s};
  final out = <Object>[];
  for (final it in items) {
    final last = out.lastOrNull;
    if (subs.containsKey(it.parent)) continue;
    if (subs[it.id] case final sub?) {
      out.add(sub);
    } else if (it.kind == ItemKind.ITEM_KIND_TOOL_CALL && last is List<Item>) {
      last.add(it);
    } else if (it.kind == ItemKind.ITEM_KIND_TOOL_CALL &&
        last is Item &&
        last.kind == ItemKind.ITEM_KIND_TOOL_CALL) {
      out.last = [last, it];
    } else {
      out.add(it);
    }
  }
  return out;
}

/// A chat's items, built as they scroll into view. It opens at the bottom
/// and follows it while the agent writes; scrolled up, it stays put and
/// offers a way back to the latest. Selected text gets a toolbar above it
/// to start a side chat about it, or to reply to it.
class Transcript extends StatefulWidget {
  const Transcript({
    super.key,
    required this.chat,
    required this.daemon,
    required this.onReply,
    this.onSide,
  });

  final ChatState chat;
  final Daemon daemon;

  /// Takes a reply to the selection (for the composer); null hides the
  /// action.
  final void Function(Reply reply)? onReply;

  /// Opens a side question about the selection; null hides the action.
  final void Function(String selection)? onSide;

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
  }) {
    final (key, items) = switch (e) {
      final List<Item> run => ('group ${run.first.id}', run),
      final Subagent s => ('agent ${s.call.id}', [s.call, s.busy, ...s.items]),
      _ => ((e as Item).id, [e]),
    };
    final from = [live, still, ...items];
    final was = before[key];
    final same =
        was != null &&
        was.$1.length == from.length &&
        Iterable.generate(from.length)
            .every((i) => identical(was.$1[i], from[i]));
    return (_built[key] = same
            ? was
            : (
                from,
                // Keyed, the item's state follows it as items arrive.
                Padding(
                  key: ValueKey(key),
                  padding: const EdgeInsets.only(top: 12),
                  child: RepaintBoundary(
                    child: e is Subagent
                        ? KeyedSubtree(
                            key: _subagents.putIfAbsent(
                              e.call.id,
                              GlobalKey.new,
                            ),
                            child: _view(e, live: live, still: still),
                          )
                        : _view(e, live: live, still: still),
                  ),
                ),
              ))
        .$2;
  }

  /// An entry's view: an item, a run of tool calls or a subagent.
  Widget _view(Object e, {required bool live, required bool still}) =>
      switch (e) {
        final List<Item> run => ToolGroupView(run, still: still),
        final Subagent s => SubagentCard(
          s,
          still: still,
          nested: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in _entries(items, busy: widget.chat.busy))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _view(e, live: false, still: still),
                ),
            ],
          ),
        ),
        _ => ItemView(
          e as Item,
          widget.chat.id,
          widget.daemon,
          live: live,
          still: still,
        ),
      };

  /// The subagent cards, by their call's id, to scroll to (ChatState.reveal).
  final _subagents = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    widget.chat.reveal.addListener(_reveal);
  }

  void _reveal() {
    final id = widget.chat.reveal.value;
    if (id == null) return;
    widget.chat.reveal.value = null;
    if (_subagents[id]?.currentContext case final c?) {
      Scrollable.ensureVisible(
        c,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  @override
  void dispose() {
    widget.chat.reveal.removeListener(_reveal);
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
    final theme = NushiTheme.of(context), t = theme.t;
    final chat = widget.chat;
    final entries = _entries(chat.items, busy: chat.busy);
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
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, e) in entries.indexed)
                        _entry(
                          before,
                          e,
                          live: chat.busy && i == entries.length - 1,
                          still: chat.waiting,
                        ),
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

/// Places its child centered just above [at] (a selection's top and bottom
/// middle), or below it when there is no room above, inside the box.
class _Above extends SingleChildLayoutDelegate {
  _Above(this.at);

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
