import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A pull request a tool call of the open chat opened or merged, for its
/// card in the transcript (ADR 0117 section 4): live only, in the app's
/// memory while the chat shows; never saved.
typedef LivePull = ({GitHubAddress address, bool merged, String url});

final _pullAddress = RegExp(
  r'https://[a-z0-9.-]+(?::\d{1,5})?/[A-Za-z0-9][A-Za-z0-9-]{0,38}/'
  r'[A-Za-z0-9._-]{1,100}/pull/\d{1,9}',
  caseSensitive: false,
);

/// What [it], a tool call just completed in [chat], did to a pull request:
/// opened one (`gh pr create`, a `create_pull_request` tool: the first pull
/// request address in its output on a host [knows] says), or merged one
/// linked to the chat (`gh pr merge`, a `merge_pull_request` tool: the
/// address it names, else the number, else the chat's primary); null for
/// anything else.
LivePull? livePullOf(
  Item it,
  ChatState chat,
  bool Function(String host) knows,
) {
  if (it.kind != ItemKind.ITEM_KIND_TOOL_CALL || it.status != 'completed') {
    return null;
  }
  final what = '${it.title}\n${it.input}\n${it.tool}'.toLowerCase();
  final opened =
      RegExp(r'\bgh\s+pr\s+create\b').hasMatch(what) ||
      what.contains('create_pull_request');
  final merged =
      RegExp(r'\bgh\s+pr\s+merge\b').hasMatch(what) ||
      what.contains('merge_pull_request');
  if (!opened && !merged) return null;
  final named = [
    for (final text in [
      it.text,
      it.rawOutput,
      if (merged) '${it.title}\n${it.input}',
    ])
      for (final m in _pullAddress.allMatches(text))
        if (githubAddress(m[0]!) case final a? when knows(a.host)) (a, m[0]!),
  ];
  if (opened) {
    if (named.firstOrNull case (final a, final url)) {
      return (address: a, merged: false, url: url);
    }
    return null;
  }
  // Merged: only a pull request of the chat's.
  GitHubLink? linked(bool Function(GitHubLink) test) =>
      chat.pulls.where(test).firstOrNull;
  final number = RegExp(r'\bgh\s+pr\s+merge\s+#?(\d+)\b').firstMatch(what)?[1];
  final l = switch (named.firstOrNull) {
    (final a, _) => linked((l) => pullKey(l) == a.key),
    null when number != null => linked((l) => '${l.number}' == number),
    null => chat.pull,
  };
  if (l == null) return null;
  final a = addressOf(l);
  return (address: a, merged: true, url: a.url);
}

/// The card of a pull request the chat's tool call opened or merged (ADR
/// 0117 section 4), after that tool call's turn group: a filled card, the
/// state pill and `owner/repo #n · author · age`, the title with its size
/// as two tags, and under a hairline the checks in words or the row's cue.
/// A click opens the Pull request tab on it; right-click is its row's ⋯.
class LivePullCard extends StatefulWidget {
  const new(this.cp, this.pull, {required this.onShow, super.key});

  final ChatPull cp;
  final LivePull pull;
  final VoidCallback onShow;

  @override
  State<LivePullCard> createState() => _LivePullCardState();
}

class _LivePullCardState extends State<LivePullCard> {
  Timer? _again;

  GitHubItems get _items => GitHubItems.of(widget.cp.daemon);

  @override
  void initState() {
    super.initState();
    final a = widget.pull.address;
    _items.want(a, quiet: false, fresh: Duration.zero);
    // The daemon keeps an open one 30 s: a merge just made is asked once
    // more past that, so the pill says Merged.
    if (widget.pull.merged) {
      _again = Timer(const Duration(seconds: 35), () {
        if (mounted && _items.look(a).item?.state == 'open') {
          _items.want(a, quiet: false, fresh: Duration.zero);
        }
      });
    }
  }

  @override
  void dispose() {
    _again?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final cp = widget.cp;
    final a = widget.pull.address;
    return ListenableBuilder(
      listenable: Listenable.merge([_items, cp]),
      builder: (context, _) {
        final it = _items.look(a).item;
        final link = cp.chat.pulls
            .where((l) => pullKey(l) == a.key)
            .firstOrNull;
        final muted = theme.ui(t.textMuted, size: 12);
        final n = it == null ? null : badgeCounts(it);
        final cue = it == null || link == null
            ? null
            : rowCue(context, cp, link, it);
        final foot = n != null
            ? Row(
                spacing: 8,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: badgeColor(t, n),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    checksSentence(n),
                    style: theme.ui(t.textSecondary, size: 12),
                  ),
                ],
              )
            : cue != null
            ? Text(cue.words, style: theme.ui(cue.color, size: 12))
            : null;
        final head = [
          '${a.repo} #${a.number}',
          if (it != null && it.author.isNotEmpty) it.author,
          if (it != null && it.createdMs > 0)
            agoAt(it.createdMs.toInt(), clock()),
        ].join(' · ');
        final card = Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: t.raised,
            borderRadius: BorderRadius.circular(NushiTheme.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 8,
                children: [
                  if (it != null)
                    ItemStatePill(it)
                  else
                    const ItemIcon(null, pull: true),
                  Expanded(
                    child: Text(
                      head,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      it?.title ?? widget.pull.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: it == null
                          ? theme.code(t.textSecondary, size: 12)
                          : theme.ui(t.text, size: 14),
                    ),
                  ),
                  if (it != null) ...[
                    const SizedBox(width: 12),
                    _Tag(Text(filesWords(it.changedFiles), style: muted)),
                    const SizedBox(width: 6),
                    _Tag(diffSize(theme, it, size: 12)),
                  ],
                ],
              ),
              if (foot != null) ...[
                const SizedBox(height: 10),
                Divider(height: 1, thickness: 1, color: t.line),
                const SizedBox(height: 10),
                foot,
              ],
            ],
          ),
        );
        return Menu(
          filter: false,
          entries: link == null
              ? const []
              : pullRowMenu(context, cp, link, it, onShow: widget.onShow),
          builder: (context, open) => Tap(
            onTap: link == null
                ? null
                : () {
                    cp.pick(link);
                    widget.onShow();
                  },
            onSecondaryTapUp: link == null
                ? null
                : (d) => open(d.localPosition),
            radius: NushiTheme.card,
            tint: false,
            tooltip: it == null ? widget.pull.url : '',
            child: card,
          ),
        );
      },
    );
  }
}

/// A small fill around [child]: the card's size tags.
class _Tag extends StatelessWidget {
  const new(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.selected,
        borderRadius: BorderRadius.circular(NushiTheme.tag),
      ),
      child: child,
    );
  }
}
