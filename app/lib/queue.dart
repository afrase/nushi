import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/grow.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/stop_label.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The messages waiting for the agent, as pills over the composer: a click
/// takes one back to edit ([onEdit]), ⏩ sends it now, in place of the
/// running turn ([onSendNow]; a turn runs), × drops it ([onRemove]).
///
/// A pill coming pops in ([PopIn], from 0.96); one going (sent, edited or
/// removed) fades out rising over [Motion.exit], where it was, taking no
/// click. With Reduce Motion they come and go at once.
class QueuePills extends StatefulWidget {
  const new(
    this.chat, {
    required this.onEdit,
    required this.onRemove,
    this.onSendNow,
    super.key,
  });

  final ChatState chat;
  final void Function(QueuedMessage) onEdit;
  final void Function(QueuedMessage) onRemove;
  final void Function(QueuedMessage)? onSendNow;

  @override
  State<QueuePills> createState() => _QueuePillsState();
}

class _QueuePillsState extends State<QueuePills> {
  List<QueuedMessage> _shown = []; // the queue as last built, going ones too
  final _going = <String>{}; // ids fading out
  Set<String>? _first; // the ids it was first built with: no pop

  /// The queue, with the pills going kept where they were.
  List<QueuedMessage> _merged(List<QueuedMessage> queue) {
    final ids = {for (final m in queue) m.id};
    final still = reduceMotion(context);
    final out = [...queue];
    for (final (i, m) in _shown.indexed) {
      if (ids.contains(m.id)) {
        _going.remove(m.id); // back again
        continue;
      }
      if (still) continue;
      _going.add(m.id);
      out.insert(i.clamp(0, out.length), m);
    }
    return _shown = out;
  }

  void _gone(String id) {
    if (!mounted || !_going.remove(id)) return;
    setState(() => _shown = [..._shown.where((m) => m.id != id)]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final first = _first ??= {for (final m in chat.queue) m.id};
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in _merged(chat.queue))
            _PillMotion(
              key: ValueKey(m.id),
              play: !first.contains(m.id),
              going: _going.contains(m.id),
              onGone: () => _gone(m.id),
              child: _pill(theme, t, m),
            ),
        ],
      ),
    );
  }

  Widget _pill(NushiTheme theme, Tokens t, QueuedMessage m) {
    final chat = widget.chat;
    final onEdit = widget.onEdit;
    final onRemove = widget.onRemove;
    final onSendNow = widget.onSendNow;
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: ShapeDecoration(
        color: t.raised,
        shape: StadiumBorder(side: BorderSide(color: t.borderStrong)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Tap(
              onTap: () => onEdit(m),
              tooltip: 'Edit',
              radius: 14,
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(Icons.schedule, size: 13, color: t.textMuted),
                  Flexible(
                    child: m.toSubagentStop
                        ? Text.rich(
                            stopLabel(
                              theme,
                              t.textSecondary,
                              chat,
                              name: m.toSubagentName,
                              call: m.toSubagent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            _label(m),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.ui(t.textSecondary, size: 12),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (onSendNow case final now?
              when chat.started != null && !m.toSubagentStop)
            IconTap(
              Icons.fast_forward,
              size: 13,
              tooltip: 'Send now: stop the turn and send it',
              onTap: () => now(m),
            ),
          IconTap(
            Icons.close,
            size: 13,
            tooltip: 'Remove',
            onTap: () => onRemove(m),
          ),
        ],
      ),
    );
  }
}

/// A pill popping in, unless not [play]; [going], fading out rising over
/// [Motion.exit], then [onGone].
class _PillMotion extends StatefulWidget {
  const new({
    required this.play,
    required this.going,
    required this.onGone,
    required this.child,
    super.key,
  });

  final bool play;
  final bool going;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<_PillMotion> createState() => _PillMotionState();
}

class _PillMotionState extends State<_PillMotion>
    with SingleTickerProviderStateMixin {
  late final _out = AnimationController(vsync: this, duration: Motion.exit)
    ..addStatusListener((s) {
      if (s.isCompleted) widget.onGone();
    });

  @override
  void initState() {
    super.initState();
    if (widget.going) _out.forward().ignore();
  }

  @override
  void didUpdateWidget(_PillMotion old) {
    super.didUpdateWidget(old);
    if (widget.going == old.going) return;
    widget.going ? _out.forward().ignore() : _out.value = 0;
  }

  @override
  void dispose() {
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: widget.going,
    child: ExcludeFocus(
      excluding: widget.going,
      child: AnimatedBuilder(
        animation: _out,
        builder: (context, child) {
          final v = Motion.leave.transform(_out.value);
          return Opacity(
            opacity: 1 - v,
            child: Transform.translate(offset: Offset(0, -6 * v), child: child),
          );
        },
        child: PopIn(play: widget.play, from: 0.96, child: widget.child),
      ),
    ),
  );
}

/// A queued message in one line: its text, or what it holds.
String _label(QueuedMessage m) {
  final (replies, text) = splitReplies(m.text);
  final line = (text.isEmpty ? replies.firstOrNull?.text ?? '' : text)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (line.isNotEmpty) {
    return m.toSubagentName.isEmpty ? line : 'To ${m.toSubagentName}: $line';
  }
  if (replies.isNotEmpty) return 'Reply';
  return m.images.length == 1 ? 'An image' : '${m.images.length} images';
}
