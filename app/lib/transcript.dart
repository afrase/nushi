import 'package:flutter/material.dart';

import 'cards.dart';
import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'question_card.dart';
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
/// offers a way back to the latest.
class Transcript extends StatefulWidget {
  const Transcript({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<Transcript> {
  final _scroll = ScrollController();
  bool _follow = true; // keep the bottom in view
  bool _jumping = false; // the scroll moves because of us

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

  void _latest() {
    setState(() => _follow = true);
    _stick();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final entries = _entries(chat.items);
    _stick();
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _stick();
            return false;
          },
          // One selection across the transcript, messages included whole.
          child: SelectionArea(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                // Keyed here, the item's state follows it as items arrive.
                return Padding(
                  key: ValueKey(
                    e is List<Item> ? 'group ${e.first.id}' : (e as Item).id,
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
        if (!_follow)
          Positioned(
            right: 20,
            bottom: 12,
            child: _LatestButton(onPressed: _latest),
          ),
      ],
    );
  }
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
              child: Text(item.text, style: theme.ui(t.text)),
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
