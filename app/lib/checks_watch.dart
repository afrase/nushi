import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// [it]'s failure as the user acts on it, `<node id>@<commit>`, while its
/// checks fail on an open pull request; null otherwise, and from a daemon
/// that doesn't say the commit.
String? failureOf(GitHubItem? it) {
  if (it == null || it.state != 'open' || it.checksOid.isEmpty) return null;
  if (it.checks != 'failure' && it.checks != 'error') return null;
  return '${it.id}@${it.checksOid}';
}

/// The chats whose pull request's checks newly failed (ADR 0138): from the
/// chats' states the sidebar asks for anyway ([PullStates]: one call a
/// host each minute, quietly), never a call of its own. A failure on a
/// commit the user hasn't acted on (Ask to fix, Dismiss, Fix checks) sets
/// the chat's [ChatState.checksFailed], so it needs you; one acted on
/// stays quiet on every ask after, and a failure on a later commit
/// flags it again. A chat first seen with its checks failing isn't
/// flagged for that failure: it isn't new.
class ChecksWatch {
  /// The one of [daemon].
  factory of(Daemon daemon) => _all[daemon] ??= ChecksWatch._(daemon);

  new _(this.daemon) : states = PullStates.of(daemon);

  static final _all = Expando<ChecksWatch>();

  final Daemon daemon;
  final PullStates states;
  bool _on = false;
  bool _judging = false;

  /// Watches from now on: the states are asked for while it does.
  void start() {
    if (_on) return;
    _on = true;
    states
      ..addListener(_judge)
      ..watch();
    checksSeen.addListener(_judge);
    _judge();
  }

  void stop() {
    if (!_on) return;
    _on = false;
    states
      ..removeListener(_judge)
      ..unwatch();
    checksSeen.removeListener(_judge);
  }

  List<GitHubLink> _links(ChatState chat) => [
    for (final l in chat.pulls.isEmpty ? [?chat.pull] : chat.pulls)
      if (l.id.isNotEmpty) l,
  ];

  void _judge() {
    if (_judging) return;
    _judging = true;
    try {
      final seen = checksSeen.value;
      Map<String, List<String>>? first;
      var changed = false;
      for (final chat in daemon.chats.values) {
        if (chat.archived) {
          changed |= chat.failChecks(const []);
          continue;
        }
        final links = _links(chat);
        final failing = [
          for (final l in links)
            if (failureOf(states.item(l)) case final f?) (l, f),
        ];
        final acted = switch (seen[chat.id]) {
          final a? => [...a],
          null => null,
        };
        if (acted == null) {
          // First seen once its pull requests' states are known: what
          // fails then isn't new.
          if (links.any((l) => states.item(l) == null)) continue;
          (first ??= {...seen})[chat.id] = [
            for (final l in links) _first(states.item(l)!),
          ];
          continue;
        }
        // A pull request linked since, as its state is first known: what
        // fails on it then isn't new either.
        final known = {for (final f in acted) f.split('@').first};
        final linked = [
          for (final l in links)
            if (states.item(l) case final it? when !known.contains(it.id))
              _first(it),
        ];
        if (linked.isNotEmpty) {
          acted.addAll(linked);
          (first ??= {...seen})[chat.id] = acted;
        }
        changed |= chat.failChecks([
          for (final (l, f) in failing)
            if (!acted.contains(f)) l,
        ]);
      }
      if (first != null) checksSeen.value = first;
      if (changed) daemon.listChanged(); // the Dock's badge, the rail
    } finally {
      _judging = false;
    }
  }

  /// [it] as it's first seen on a chat: its failure, or that it's known
  /// with none (`<node id>@`), so a later failure of it is new.
  String _first(GitHubItem it) => failureOf(it) ?? '${it.id}@';

  /// The user acted on [chat]'s failed checks (Ask to fix, Dismiss, Fix
  /// checks): they don't need you again, until a later commit's fail.
  void seen(ChatState chat) {
    final now = [for (final l in _links(chat)) ?failureOf(states.item(l))];
    if (now.isEmpty) return;
    final ids = {for (final f in now) f.split('@').first};
    final kept = [
      for (final f in checksSeen.value[chat.id] ?? const <String>[])
        if (!ids.contains(f.split('@').first)) f,
      ...now,
    ];
    checksSeen.value = {...checksSeen.value, chat.id: kept};
  }
}

/// Whether [it]'s checks fail only because some were cancelled
/// ([itemChecks]): its flag then says so, and has nothing to fix.
bool onlyCancelled(GitHubItem? it) =>
    it != null && itemChecks(it) == 'cancelled';

/// Ask to fix: each failed check of [chat]'s flagged pull requests as a
/// reply card in its box, with the failing part of its job's log (Fix
/// checks' cards, `github_agent.dart`); never sent here, and none for a
/// pull request whose checks were only cancelled. The flag goes.
Future<void> askToFix(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) async {
  final cp = ChatPull.of(daemon, chat);
  final states = ChecksWatch.of(daemon).states;
  for (final l in chat.checksFailed) {
    if (onlyCancelled(states.item(l))) continue;
    final p = await cp.whole(context, l);
    if (p == null || !context.mounted) return;
    await toAgent(
      context,
      daemon,
      p.item,
      chat: chat,
      replies: () => checkReplies(daemon, l.asRef, p),
    );
    if (!context.mounted) return;
  }
  ChecksWatch.of(daemon).seen(chat);
}

/// Over the composer while the chat's pull request's checks newly failed
/// (ADR 0138): what failed, Ask to fix (the failed checks' logs into the
/// box, for the user to send) and Dismiss. Checks only cancelled still
/// hold the merge back, so they flag the chat too, in their own words ("A
/// check was cancelled on #12") and the stop sign, with nothing to ask
/// the agent to fix.
class ChecksFailedBar extends StatelessWidget {
  const new(this.chat, this.daemon, {super.key});

  final ChatState chat;
  final Daemon daemon;

  /// "#12" or "#12 and #14", what the bar names.
  static String numbers(List<GitHubLink> links) {
    final ns = [for (final l in links) '#${l.number}'];
    return ns.length == 1
        ? ns.single
        : '${ns.sublist(0, ns.length - 1).join(', ')} and ${ns.last}';
  }

  @override
  Widget build(BuildContext context) {
    final states = ChecksWatch.of(daemon).states;
    // The flag's pull requests can stay the same while what failed on
    // them changes (a failure beside a cancelled check): it reads them
    // as they change.
    return ListenableBuilder(
      listenable: states,
      builder: (context, _) => _bar(context, states),
    );
  }

  Widget _bar(BuildContext context, PullStates states) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final links = chat.checksFailed;
    if (links.isEmpty || chat.archived) return const SizedBox.shrink();
    final failed = [
      for (final l in links)
        if (!onlyCancelled(states.item(l))) l,
    ];
    final cancelled = [
      for (final l in links)
        if (onlyCancelled(states.item(l))) l,
    ];
    final n = [
      for (final l in cancelled) ?states.item(l)?.checkCounts.cancelled,
    ].fold(0, (a, b) => a + b);
    final stopped = n == 1 ? 'a check was cancelled' : 'checks were cancelled';
    final also = cancelled.isEmpty
        ? ''
        : ', and $stopped on ${numbers(cancelled)}';
    final (head, rest) = failed.isEmpty
        ? (
            '${stopped[0].toUpperCase()}${stopped.substring(1)}',
            ' on ${numbers(cancelled)}',
          )
        : ('Checks failed', ' on ${numbers(failed)}$also');
    // The "needs you" amber's soft fill, a notice's (no line, no stripe):
    // it waits on you as a question does.
    return ChatColumn(
      child: Container(
        // In line with the composer under it.
        margin: const EdgeInsets.symmetric(
          horizontal: NushiTheme.gutter,
          vertical: 4,
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: t.needsSoft,
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        child: Row(
          children: [
            if (failed.isEmpty)
              CheckMark(cancelledIcon, size: 15, color: t.textSecondary)
            else
              Icon(Icons.cancel, size: 15, color: t.crashed),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: head,
                      style: theme.ui(
                        t.text,
                        // design: off the type scale, to move to a step
                        size: 12.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: rest),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // design: off the type scale, to move to a step
                style: theme.ui(t.text, size: 12.5),
              ),
            ),
            const SizedBox(width: 8),
            if (failed.isNotEmpty) ...[
              RunButton(
                label: 'Ask to fix',
                kind: ButtonKind.primary,
                tooltip: "Each failed check's log as a card in the chat's box",
                run: () => askToFix(context, daemon, chat),
              ),
              const SizedBox(width: 2),
            ],
            IconTap(
              Icons.close,
              size: 14,
              tooltip: 'Dismiss',
              onTap: () => ChecksWatch.of(daemon).seen(chat),
            ),
          ],
        ),
      ),
    );
  }
}
