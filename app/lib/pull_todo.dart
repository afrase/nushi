import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/pull_todo_row.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The To do list: what blocks the merge ([items]), failing checks first,
/// then review threads and a review bot's findings, each one line with
/// Send (a reply card into the chat's box, with whose it is); picked ones
/// go together (Send n picked), or all (Send all to agent). Its last line
/// says who's next: "Then waiting on @team: approval required as code
/// owner." [onChanged] asks for the pull request again after a reply or a
/// resolve.
class PullTodo extends StatefulWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.items,
    required this.now,
    required this.onChanged,
    super.key,
    this.older = const {},
    this.onOlder,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final List<TodoItem> items;

  /// The review bots whose findings come from a message on an older
  /// commit than the head, and that commit: their group says so, with the
  /// way to the message in Activity ([onOlder]).
  final Map<String, String> older;
  final ValueChanged<GitHubComment>? onOlder;
  final DateTime now;
  final Future<void> Function() onChanged;

  @override
  State<PullTodo> createState() => _PullTodoState();
}

class _PullTodoState extends State<PullTodo> {
  final _picked = <String>{};

  Future<void> _send(List<TodoItem> items) async {
    final p = widget.pull;
    await toAgent(
      context,
      widget.daemon,
      p.item,
      what: items.length == 1 ? items.single.what : '',
      replies: () async {
        final rs = await Future.wait([
          for (final i in items) i.reply(widget.daemon, p.item.ref),
        ]);
        for (final (n, i) in items.indexed) {
          _sent[_key(i)] = rs[n];
        }
        return rs;
      },
    );
    if (mounted) setState(() => _picked.removeAll(items.map((i) => i.id)));
  }

  String _key(TodoItem i) => '${widget.pull.item.id} ${i.id}';

  /// Whether [i]'s card waits in the chat's [box] (it was sent from here
  /// and is still there).
  bool _inBox(List<Reply> box, TodoItem i) {
    final r = _sent[_key(i)];
    return r != null && inBox(box, r);
  }

  @override
  Widget build(BuildContext context) {
    final box = SendToAgent.maybeOf(context)?.box;
    if (box == null) return _build(context, const []);
    return ValueListenableBuilder(
      valueListenable: box,
      builder: (context, cards, _) => _build(context, cards),
    );
  }

  Widget _build(BuildContext context, List<Reply> box) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final items = widget.items;
    _picked.retainAll(items.map((i) => i.id));
    final picked = [
      for (final i in items)
        if (_picked.contains(i.id)) i,
    ];
    final checks = [
      for (final i in items)
        if (i.check != null) i,
    ];
    final reviews = [
      for (final i in items)
        if (i.review != null || i.thread != null) i,
    ];
    final bots = <String, List<TodoItem>>{};
    for (final i in items) {
      if (i.finding case final f?) (bots[f.from.author] ??= []).add(i);
    }
    Widget group(String name) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Text(
        name,
        style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
      ),
    );
    Widget row(TodoItem i) => TodoRow(
      key: ValueKey(i.id),
      item: i,
      daemon: widget.daemon,
      pull: widget.pull,
      now: widget.now,
      picked: _picked.contains(i.id),
      inBox: _inBox(box, i),
      onPick: (v) =>
          setState(() => v ? _picked.add(i.id) : _picked.remove(i.id)),
      onSend: () => _send([i]),
      onChanged: widget.onChanged,
    );
    return framed(
      border: t.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: t.raised,
            padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
            child: Row(
              children: [
                Text(
                  'To do',
                  style: theme.ui(t.text, size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                _Count(items.length),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items.isEmpty
                        ? 'nothing blocks the merge'
                        : 'what blocks the merge, first',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ),
                if (picked.isNotEmpty) ...[
                  Button(
                    label: 'Send ${picked.length} picked',
                    onPressed: () => _send(picked),
                  ),
                  const SizedBox(width: 6),
                ],
                if (items.isNotEmpty)
                  SendButton(
                    label: items.length == 1
                        ? 'Send to agent'
                        : 'Send all ${items.length} to agent',
                    primary: true,
                    tooltip:
                        "Each as a reply card in the chat's box, to send "
                        'with your message',
                    onPressed: () => _send(items),
                  ),
              ],
            ),
          ),
          if (checks.isNotEmpty) ...[
            group('Failing checks'),
            for (final i in checks) row(i),
          ],
          if (reviews.isNotEmpty) ...[
            group('Reviews and threads'),
            for (final i in reviews) row(i),
          ],
          for (final MapEntry(key: bot, value: found) in bots.entries) ...[
            if (widget.older[bot] case final commit?)
              _OlderGroup(
                bot: bot,
                commit: commit,
                onShow: () => widget.onOlder?.call(found.first.finding!.from),
              )
            else
              group('Findings from $bot'),
            for (final i in found) row(i),
          ],
          _Next(pull: widget.pull, after: items.isNotEmpty),
        ],
      ),
    );
  }
}

/// A review bot's findings' group, from a message on an older commit
/// than the head: some may be done, and it says so.
class _OlderGroup extends StatelessWidget {
  const new({required this.bot, required this.commit, required this.onShow});

  final String bot;
  final String commit;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final short = commit.length > 7 ? commit.substring(0, 7) : commit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Findings from $bot',
                    style: theme.ui(
                      t.textSecondary,
                      size: 12,
                      weight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text:
                        '  from a review on an older commit ($short) · '
                        'comment /review for a fresh one',
                  ),
                ],
              ),
              style: theme.ui(t.textMuted, size: 12),
            ),
          ),
          GhostButton(
            'Show the review',
            tooltip: 'Its card in Activity',
            onTap: onShow,
          ),
        ],
      ),
    );
  }
}

/// The cards To do put in a chat's box, by pull request and item: a row
/// whose card is still there says so.
final _sent = <String, Reply>{};

class _Count extends StatelessWidget {
  const new(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.selected,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$n', style: theme.ui(t.textSecondary, size: 11.5)),
    );
  }
}

/// Who's next once the list is done: the reviewers still asked, else the
/// checks still running, else that it can merge.
class _Next extends StatelessWidget {
  const new({required this.pull, required this.after});

  final GitHubPull pull;
  final bool after;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = pull;
    final waiting = waitingOn(p);
    final running = countChecks(p).running;
    final then = after ? 'Then waiting on ' : 'Waiting on ';
    final (String? lead, String? who, String rest) = waiting.isNotEmpty
        ? (
            then,
            names(waiting.map((r) => '@${r.login}')),
            waiting.any((r) => r.codeOwner)
                ? ': approval required as code owner.'
                : ': review requested.',
          )
        : running > 0
        ? (then, null, 'checks: $running running.')
        : after
        ? (null, null, '')
        : (null, null, 'Nothing else waits: it can merge once its rules pass.');
    if (lead == null && rest.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 15, color: t.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (lead != null) TextSpan(text: lead),
                  if (who != null)
                    TextSpan(
                      text: who,
                      style: theme.ui(
                        t.text,
                        size: 12.5,
                        weight: FontWeight.w500,
                      ),
                    ),
                  TextSpan(text: rest),
                ],
              ),
              style: theme.ui(t.textSecondary, size: 12.5),
            ),
          ),
          if (waiting.isNotEmpty && p.item.url.isNotEmpty)
            GhostButton(
              'Ping on GitHub',
              icon: Icons.open_in_new,
              tooltip: 'Open the pull request on GitHub, to ask them',
              onTap: () => openWeb(p.item.url),
            ),
        ],
      ),
    );
  }
}
