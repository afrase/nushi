import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/github_text.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

export 'package:nushi/github_text.dart';

/// A comment or a review in the conversation: its author (marked when
/// outside the repository, or a bot), when, a review's state, its text.
/// A bot's comment (not a review) folds to one line, its first words, with
/// Show; a long text shows its first lines, with Show the whole review (or
/// comment).
///
/// In a chat's tab it can be sent to the agent ([SendToAgent]), unless
/// it's part of a thread ([sendable] false: the thread is sent whole).
class CommentEntry extends StatefulWidget {
  const new(
    this.comment, {
    required this.now,
    super.key,
    this.sendable = true,
    this.mark = true,
  });

  final GitHubComment comment;
  final DateTime now;
  final bool sendable;

  /// A bot's mark before its name (none where an avatar shows it).
  final bool mark;

  @override
  State<CommentEntry> createState() => _CommentEntryState();
}

class _CommentEntryState extends State<CommentEntry> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = widget.comment;
    final folds = c.bot && c.review.isEmpty && c.body.isNotEmpty;
    final long = !folds && longText(c.body);
    final review = switch (c.review) {
      'approved' => ('approved', t.done),
      'changes_requested' => ('requested changes', t.crashed),
      'commented' => ('reviewed', t.textSecondary),
      'dismissed' => ('review dismissed', t.textMuted),
      _ => null,
    };
    final toggle = LinkText(
      folds
          ? (_open ? 'Hide' : 'Show')
          : _open
          ? 'Show less'
          : c.review.isEmpty
          ? 'Show the whole comment'
          : 'Show the whole review',
      size: 12,
      onTap: () => setState(() => _open = !_open),
    );
    final head = Row(
      children: [
        if (c.bot && widget.mark) ...[
          Icon(Icons.smart_toy_outlined, size: 13, color: t.textMuted),
          const SizedBox(width: 5),
        ],
        Text(
          c.author,
          style: theme.ui(t.text, size: 12.5, weight: FontWeight.w600),
        ),
        if (c.bot) Text('  bot', style: theme.ui(t.textMuted, size: 11.5)),
        if (c.outside && !c.bot)
          Tooltip(
            message: "Not the repository's owner, a member or a collaborator",
            child: Text('  outside', style: theme.ui(t.needs, size: 11.5)),
          ),
        if (review != null)
          Text('  ${review.$1}', style: theme.ui(review.$2, size: 11.5)),
        if (folds && !_open)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                commentSummary(c.body),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          ),
        Text(
          '  ${githubAgo(c.createdMs.toInt(), widget.now)}',
          style: theme.ui(t.textMuted, size: 11.5),
        ),
        if (!folds || _open) const Spacer(),
        if (folds) ...[const SizedBox(width: 10), toggle],
        if (widget.sendable && c.body.isNotEmpty)
          SendIcon(() async => commentReply(c)),
        if (c.url.isNotEmpty)
          IconTap(
            Icons.open_in_new,
            size: 13,
            tooltip: 'Open on GitHub',
            onTap: () => openWeb(c.url),
          ),
      ],
    );
    final clamped = long && !_open;
    final body = AgentMarkdown(
      githubText(clamped ? textStart(c.body) : c.body),
      images: githubImage,
    );
    return Padding(
      padding: EdgeInsets.only(top: folds ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          if (c.body.isNotEmpty && (!folds || _open))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: clamped ? Clamped(body) : body,
            ),
          if (long)
            Padding(padding: const EdgeInsets.only(top: 4), child: toggle),
        ],
      ),
    );
  }
}

/// [child]'s first three lines or so, fading out at the foot.
class Clamped extends StatelessWidget {
  const new(this.child, {super.key});

  final Widget child;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.55, 1],
      colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    ).createShader(r),
    child: ClipRect(
      child: SizedBox(
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    ),
  );
}

/// A box for a comment or a reply: Markdown, ⌘⏎ or the button posts it;
/// what GitHub said wrong shows under it.
class CommentBox extends StatefulWidget {
  const new({
    required this.hint,
    required this.onPost,
    super.key,
    this.label = 'Comment',
    this.autofocus = false,
    this.onCancel,
    this.note = '',
    this.primary = false,
  });

  final String hint;
  final String label;

  /// Small print at the buttons' left ("Markdown · posts to GitHub as
  /// octo").
  final String note;

  /// Its button is the accent's (the conversation's box).
  final bool primary;
  final bool autofocus;
  final Future<void> Function(String text) onPost;
  final VoidCallback? onCancel;

  @override
  State<CommentBox> createState() => _CommentBoxState();
}

class _CommentBoxState extends State<CommentBox> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPost(text);
      _text.clear();
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _post,
        const SingleActivator(LogicalKeyboardKey.escape): ?widget.onCancel,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            autofocus: widget.autofocus,
            enabled: !_busy,
            minLines: 2,
            maxLines: 8,
            style: theme.ui(t.text),
            decoration: InputDecoration(hintText: widget.hint, isDense: true),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(e, style: theme.ui(t.crashed, size: 12)),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.note.isNotEmpty)
                Expanded(
                  child: Text(
                    widget.note,
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ),
              if (widget.onCancel case final cancel?)
                Button(label: 'Cancel', onPressed: cancel),
              const SizedBox(width: 6),
              Button(
                label: _busy ? 'Posting…' : widget.label,
                hint: '⌘⏎',
                kind: widget.primary
                    ? ButtonKind.primary
                    : ButtonKind.secondary,
                onPressed: _busy ? null : _post,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
