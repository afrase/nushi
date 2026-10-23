import 'dart:math';

import 'package:flutter/material.dart';

import 'cards.dart';
import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'images.dart';
import 'markdown.dart';
import 'question_card.dart';
import 'replies.dart';
import 'theme/theme.dart';
import 'thinking.dart';
import 'tool_calls.dart';

/// The items, with each run of tool calls as one list.
List<Object> _entries(List<Item> items) {
  final out = <Object>[];
  for (final it in items) {
    final last = out.lastOrNull;
    if (it.kind == ItemKind.ITEM_KIND_TOOL_CALL) {
      if (last is List<Item>) {
        last.add(it);
        continue;
      }
      if (last is Item && last.kind == ItemKind.ITEM_KIND_TOOL_CALL) {
        out.last = [last, it];
        continue;
      }
    }
    out.add(it);
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
  final _scroll = ScrollController();
  bool _follow = true; // keep the bottom in view
  bool _jumping = false; // the scroll moves because of us
  final _area = GlobalKey<SelectionAreaState>();
  String _selected = '';
  bool _down = false; // a pointer is down on the transcript
  Rect? _at; // the selection's top and bottom middle, where the toolbar shows
  String? _replyTo; // the selection a reply is being written to

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_jumping) return;
      final p = _scroll.position;
      final atBottom = p.pixels >= p.maxScrollExtent - 24;
      if (atBottom != _follow) setState(() => _follow = atBottom);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls to the bottom after this frame's layout. Lazily built items
  /// change the list's height as they come into view, so it checks again
  /// whenever the height changes ([ScrollMetricsNotification]).
  void _stick() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_follow || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels == p.maxScrollExtent) return;
    _jumping = true;
    p.jumpTo(p.maxScrollExtent);
    _jumping = false;
  });

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

  void _latest() {
    setState(() => _follow = true);
    _stick();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final entries = _entries(chat.items);
    _stick();
    final onReply = widget.onReply;
    final onSide = chat.canFork ? widget.onSide : null;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _stick();
              return false;
            },
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
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    // Keyed here, the item's state follows it as items arrive.
                    return Padding(
                      key: ValueKey(
                        e is List<Item>
                            ? 'group ${e.first.id}'
                            : (e as Item).id,
                      ),
                      padding: const EdgeInsets.only(top: 12),
                      child: e is List<Item>
                          ? ToolGroupView(e)
                          : _ItemView(
                              e as Item,
                              chat.id,
                              widget.daemon,
                              live: chat.busy && i == entries.length - 1,
                            ),
                    );
                  },
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
          if (!_follow)
            Positioned(
              right: 20,
              bottom: 12,
              child: _LatestButton(onPressed: _latest),
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

class _LatestButton extends StatelessWidget {
  const _LatestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Material(
      color: t.raised,
      elevation: 2,
      shape: StadiumBorder(side: BorderSide(color: t.borderStrong)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(Icons.arrow_downward, size: 14, color: t.text),
              Text('Jump to latest', style: theme.ui(t.text, size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView(this.item, this.chatId, this.daemon, {required this.live});

  final Item item;
  final String chatId;
  final Daemon daemon;

  /// The newest item while the agent works.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    switch (item.kind) {
      case ItemKind.ITEM_KIND_USER_MESSAGE:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Who('You'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.raised,
                border: Border.all(color: t.borderSubtle),
                borderRadius: BorderRadius.circular(NushiTheme.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  if (item.images.isNotEmpty) Thumbnails(item.images),
                  if (item.text.isNotEmpty) UserMessageText(item.text),
                ],
              ),
            ),
          ],
        );
      case ItemKind.ITEM_KIND_TOOL_CALL:
        return ToolCallView(item);
      case ItemKind.ITEM_KIND_QUESTION:
        return QuestionCard(
          item,
          onAnswer: (answer) => daemon.answerQuestion(chatId, item.id, answer),
        );
      case ItemKind.ITEM_KIND_THOUGHT:
        return ThoughtView(item, live: live);
      case ItemKind.ITEM_KIND_PLAN:
        return PlanView(item);
      case ItemKind.ITEM_KIND_NOTICE:
        final (icon, color) = switch (item.status) {
          'cancelled' => (Icons.stop_circle_outlined, t.textMuted),
          'error' => (Icons.error_outline, t.crashed),
          _ => (Icons.info_outline, t.needs),
        };
        return Row(
          spacing: 6,
          children: [
            Icon(icon, size: 14, color: color),
            Expanded(
              child: Text(item.text, style: theme.ui(color, size: 12.5)),
            ),
          ],
        );
      case ItemKind.ITEM_KIND_PERMISSION:
        return PermissionCard(
          item,
          onAnswer: (option) =>
              daemon.answerPermission(chatId, item.id, option),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Who('Claude'),
            const SizedBox(height: 4),
            AgentMarkdown(item.text),
            if (item.images.isNotEmpty) Thumbnails(item.images, size: 240),
          ],
        );
    }
  }
}

/// The small header above a message: who wrote it.
class _Who extends StatelessWidget {
  const _Who(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Text(
      name,
      style: theme.ui(theme.t.textSecondary, size: 12, weight: FontWeight.w600),
    );
  }
}
