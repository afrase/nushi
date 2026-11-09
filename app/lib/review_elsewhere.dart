import 'package:flutter/material.dart';

import 'package:nushi/changes_span.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/theme/theme.dart';

/// Above the Changes view's files: the chat's review comments on no file it
/// shows, each with its lines' text, Remove, and Edit while unsent. Their
/// file left the view (committed, reverted: they're outdated), or they were
/// made in another view (named on each). So no comment is counted, or
/// waits in a message, with nowhere to see it or take it out. A related
/// worktree is another view: [related] names them.
class CommentsElsewhere extends StatefulWidget {
  const new({
    required this.chat,
    required this.where,
    required this.paths,
    required this.maxHeight,
    this.related = const [],
    super.key,
  });

  final String chat;
  final String where; // the view shown (ChangesView's)
  final Set<String> paths; // its files
  final double maxHeight;
  final List<RelatedWorktree> related;

  @override
  State<CommentsElsewhere> createState() => _CommentsElsewhereState();
}

class _CommentsElsewhereState extends State<CommentsElsewhere> {
  ReviewComment? _editing;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<ReviewComment> _comments() => [
    for (final c in commentsOf(widget.chat))
      if (c.where != widget.where || !widget.paths.contains(c.path)) c,
  ];

  void _save(String text) {
    _editing?.text = text;
    setState(() => _editing = null);
    setComments(widget.chat, [...commentsOf(widget.chat)]);
  }

  /// Where [c] is: its file, and the view it was made in if not this one.
  String _place(ReviewComment c) => c.where == widget.where
      ? c.path
      : '${whereLabel(c.where, widget.related)} · ${c.path}';

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ValueListenableBuilder(
      valueListenable: reviews,
      builder: (context, _, _) {
        final comments = _comments();
        if (comments.isEmpty) return const SizedBox.shrink();
        final n = comments.length;
        return Container(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.borderSubtle)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 8, 0, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                    n == 1
                        ? '1 comment not on these files'
                        : '$n comments not on these files',
                    style: theme.ui(t.textSecondary, size: 12),
                  ),
                ),
                for (final c in comments)
                  if (c == _editing)
                    ReviewCommentBox(
                      key: ValueKey(c.id),
                      lines: '${_place(c)} · ${c.lines}',
                      controller: _text,
                      editing: true,
                      onSave: _save,
                      onCancel: () => setState(() => _editing = null),
                    )
                  else
                    CommentCard(
                      c,
                      key: ValueKey(c.id),
                      place: _place(c),
                      onEdit: () => setState(() {
                        _editing = c;
                        _text.text = c.text;
                      }),
                      onRemove: () => setComments(widget.chat, [
                        for (final m in commentsOf(widget.chat))
                          if (m != c) m,
                      ]),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A Changes view's name ([ReviewComment.where]): its scope's, and in
/// Commits the commits picked, newest last; a related worktree's first, as
/// its menu names it when it's among [related], else by its folder.
String whereLabel(String where, [List<RelatedWorktree> related = const []]) {
  final scope = _scopeLabel(scopeOf(where));
  final path = worktreeOf(where);
  if (path == null) return scope;
  final w = related.where((w) => w.path == path).firstOrNull;
  return '${w == null ? plainName(path.split('/').last) : worktreeName(w)} '
      '· $scope';
}

/// A scope's name ([scopeOf]) as its tab says it, Commits' by the commits.
String _scopeLabel(String scope) {
  if (scope.split(':') case ['commits', final newest, final oldest]) {
    String short(String hash) => hash.substring(0, hash.length.clamp(0, 7));
    return newest == oldest
        ? 'Commit ${short(newest)}'
        : 'Commits ${short(oldest)}–${short(newest)}';
  }
  return Scope.values.where((s) => s.name == scope).firstOrNull?.label ?? scope;
}
