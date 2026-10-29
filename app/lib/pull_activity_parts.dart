import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

class ReviewPill extends StatelessWidget {
  const new(this.text, this.color, this.icon, {super.key});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 1, 7, 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 12, color: color),
          Text(
            text,
            style: theme.ui(color, size: 11.5, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// A chip that points elsewhere ("2 unresolved threads · in To do") or
/// opens the rest.
class PointerChip extends StatelessWidget {
  const new(this.text, {required this.onTap, super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = color;
    return Pressable(
      onTap: onTap,
      builder: (context, look) => Container(
        height: controlHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            look.hover ? t.hover : const Color(0x00000000),
            c == null ? t.raised : c.withValues(alpha: 0.08),
          ),
          border: Border.all(
            color: c == null ? t.borderSubtle : c.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        foregroundDecoration: focusRing(t, look),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (icon != null) Icon(icon, size: 13, color: c ?? t.textMuted),
            Text(text, style: theme.ui(t.text, size: 12)),
          ],
        ),
      ),
    );
  }
}

/// A resolved thread as one line: its place, its first words and the last
/// reply; Show opens its comments.
class ResolvedThread extends StatefulWidget {
  const new(this.thread, {required this.now, super.key});

  final GitHubThread thread;
  final DateTime now;

  @override
  State<ResolvedThread> createState() => _ResolvedThreadState();
}

class _ResolvedThreadState extends State<ResolvedThread> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final x = widget.thread;
    final first = x.comments.first;
    final last = x.comments.last;
    final line = x.outdated ? x.originalLine : x.line;
    final words = [
      plainText(first.body),
      if (x.comments.length > 1) '${last.author}: ${plainText(last.body)}',
    ].join(' · ');
    return Container(
      decoration: box(t.borderSubtle, fill: t.raised),
      padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: t.done),
              const SizedBox(width: 8),
              Text(
                '${x.path.split('/').last}${x.onFile ? '' : ':$line'}',
                style: theme.code(t.textMuted, size: 11.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  words,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.textSecondary, size: 12),
                ),
              ),
              Pressable(
                onTap: () => setState(() => _open = !_open),
                builder: (context, look) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text(
                    _open ? 'Hide' : 'Show',
                    style: theme.ui(
                      look.hover ? t.text : t.textSecondary,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in x.comments)
                    CommentEntry(c, now: widget.now, sendable: false),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
