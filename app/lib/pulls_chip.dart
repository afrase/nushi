import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_parts.dart' show ItemBadges;
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/theme/theme.dart';

/// The chat header's chip of its pull requests (ADR 0117), found ones too:
/// the primary's icon, `#n` and badges (unless [badges] is off, in a
/// narrow header), then `+2` for the others; its hover is the card for
/// one, the rows (no ⋯) for several; a click opens the Pull request tab.
class PullsChip extends StatelessWidget {
  const new(
    this.daemon,
    this.chat, {
    required this.onShow,
    super.key,
    this.badges = true,
  });

  final Daemon daemon;
  final ChatState chat;
  final VoidCallback onShow;
  final bool badges;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final cp = ChatPull.of(daemon, chat);
    final items = GitHubItems.of(daemon);
    return ListenableBuilder(
      listenable: Listenable.merge([cp, items]),
      builder: (context, _) {
        final links = cp.links;
        final primary = chat.pull ?? links.firstOrNull;
        if (primary == null) return const SizedBox.shrink();
        // Asked once when first built, as a link's chip is; the chat's
        // rows keep it current while it's open.
        items.want(addressOf(primary));
        final it = cp.itemOf(primary);
        final more = links.length - 1;
        return HoverCard(
          onShow: () => items.want(
            addressOf(primary),
            quiet: false,
            fresh: const Duration(minutes: 1),
          ),
          card: (_) => ListenableBuilder(
            listenable: Listenable.merge([cp, items]),
            builder: (context, _) => links.length == 1
                ? GitHubCard(addressOf(primary), items.look(addressOf(primary)))
                : Container(
                    width: 340,
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                    decoration: floatBox(t, radius: NushiTheme.card),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                          child: Text(
                            '${links.length} pull requests',
                            style: theme.ui(
                              t.textMuted,
                              size: 12,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final l in links)
                          PullRow(cp, l, onShow: onShow, menu: false),
                      ],
                    ),
                  ),
          ),
          child: Tap(
            onTap: onShow,
            tooltip: more > 0 ? '' : '${primary.repo}#${primary.number}',
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ItemIcon(it, pull: true, size: 13),
                const SizedBox(width: 3),
                Text('#${primary.number}', style: theme.code(t.link, size: 12)),
                if (badges && it != null) ...[
                  const SizedBox(width: 6),
                  ItemBadges(it, wide: false),
                ],
                if (more > 0) ...[
                  const SizedBox(width: 5),
                  Text('+$more', style: theme.code(t.textMuted, size: 12)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
