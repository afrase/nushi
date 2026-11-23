import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/github_text.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/pull_reactions.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What each pull request's title or description said when its edit
/// began, by its draft's key, while the edit is open: a look at a chat
/// comes back to the editor, its text kept as a comment box's is
/// ([keepCommentDraft]), and a poll that brings another text meanwhile
/// changes neither (API 128's `was`).
final Map<String, String> _began = runMap();

/// Every open edit's start ([_began]), by its draft's key: on the Mac kept
/// with the comment drafts (ADR 0073), so after a restart the edit comes
/// back open with its text, and Save still sends what it began from.
Map<String, String> get keptPullEdits => _began;

/// Puts back the open edits read at start.
void restorePullEdits(Map<String, String> began) => _began
  ..clear()
  ..addAll(began);

/// Opens [key]'s edit from GitHub's [was], or ends it (null), and says so
/// to the file that keeps it.
void _begin(String key, String? was) {
  if (_began[key] == was) return;
  if (was == null) {
    _began.remove(key);
  } else {
    _began[key] = was;
  }
  commentDraftsChanged.value++;
}

/// Whether the daemon refused [e] because GitHub changed the text since
/// the edit began (`changed_since`).
bool changedSince(Object e) =>
    e is ConnectException && refusedFor(e, 'changed_since');

/// What of a pull request an edit changes.
enum PullPart { title, description }

/// An edit of [pull]'s title or description, in place, as GitHub's page
/// has it: [build]'s look at rest with a pencil (only when GitHub lets the
/// user edit it, `can_edit`), the editor open, Save and Cancel; ⌘⏎ saves
/// the description and ⏎ the title, Esc cancels. A save that GitHub's
/// text has moved past keeps what was written and offers GitHub's.
abstract class _PullEdit<T extends StatefulWidget> extends State<T> {
  Daemon get daemon;
  GitHubPull get pull;
  PullPart get part;
  Future<void> Function() get onSaved;

  final text = TextEditingController();
  final focus = FocusNode();
  bool saving = false;

  /// The last save's refusal, in words.
  String? error;

  /// GitHub's text changed since the edit began ([changedSince]).
  bool moved = false;

  /// GitHub's text, shown under the editor after [moved].
  String? theirs;

  /// What was saved, shown until the pull request read says it too.
  String? saved;

  String get key => githubDraft(
    pull.item.ref,
    part == PullPart.title ? 'title' : 'description',
  );

  /// What GitHub has now, as last read.
  String get now => part == PullPart.title ? pull.item.title : pull.bodySource;

  bool get editing => _began.containsKey(key);

  @override
  void initState() {
    super.initState();
    if (editing) text.text = commentDraft(key);
    text.addListener(_keep);
  }

  void _keep() {
    if (editing) keepCommentDraft(key, text.text);
  }

  @override
  void didUpdateWidget(T old) {
    super.didUpdateWidget(old);
    // The read caught up with the save.
    if (saved != null && now == saved) saved = null;
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  void start() {
    _begin(key, now);
    text.value = TextEditingValue(
      text: now,
      selection: TextSelection.collapsed(offset: now.length),
    );
    setState(_reset);
    focus.requestFocus();
  }

  void _reset() {
    error = null;
    moved = false;
    theirs = null;
  }

  void cancel() {
    if (saving) return;
    _begin(key, null);
    keepCommentDraft(key, '');
    setState(_reset);
  }

  /// GitHub's text under the editor; saving now puts the user's in its
  /// place knowingly.
  void showTheirs() => setState(() {
    theirs = now;
    _begin(key, now);
  });

  Future<void> save() async {
    final was = _began[key];
    if (saving || was == null) return;
    final value = part == PullPart.title ? text.text.trim() : text.text;
    if (part == PullPart.title && value.isEmpty) {
      setState(() => error = 'A pull request needs a title');
      return;
    }
    if (value == was) return cancel();
    setState(() {
      saving = true;
      _reset();
    });
    try {
      await daemon.client.editGitHubPull(
        EditGitHubPullRequest(
          ref: pull.item.ref,
          title: part == PullPart.title ? value : null,
          body: part == PullPart.description ? value : null,
          was: was,
        ),
      );
      _begin(key, null);
      keepCommentDraft(key, '');
      if (mounted) setState(() => saved = value);
      unawaited(onSaved());
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        moved = changedSince(e);
        error = moved
            ? 'Not saved: it changed on GitHub since you opened it. '
                  'Your text is still here.'
            : errorText(e);
      });
      // GitHub's text, for Show GitHub's version.
      if (moved) unawaited(onSaved());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Esc cancels; ⌘⏎ saves, or ⏎ alone when [enterAlone] (the title).
  KeyEventResult keys(FocusNode _, KeyEvent e, {required bool enterAlone}) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      cancel();
      return KeyEventResult.handled;
    }
    final enter =
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (enter && (cmdPressed() || enterAlone)) {
      unawaited(save());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The pencil that opens the editor.
  Widget pencil() => IconTap(
    Icons.edit_outlined,
    key: ValueKey('edit ${part.name}'),
    tooltip: 'Edit',
    onTap: start,
  );

  /// The refusal, and Show GitHub's version once GitHub's text is read
  /// (it's asked for as the refusal comes); then GitHub's text.
  List<Widget> trouble(NushiTheme theme) {
    final t = theme.t;
    final e = error;
    if (e == null) return const [];
    return [
      const SizedBox(height: 6),
      Text(e, style: theme.ui(t.crashed, size: 12)),
      if (moved && theirs == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: now == _began[key]
                ? Text(
                    "Reading GitHub's version…",
                    style: theme.ui(t.textMuted, size: 12),
                  )
                : Button(
                    label: "Show GitHub's version",
                    kind: ButtonKind.quiet,
                    onPressed: showTheirs,
                  ),
          ),
        ),
      if (theirs case final s?) ...[
        const SizedBox(height: 10),
        Text(
          "GitHub's version: Save puts yours in its place",
          style: theme.ui(t.textMuted, size: 12),
        ),
        const SizedBox(height: 4),
        Container(
          key: const ValueKey('github version'),
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.codeBlock,
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          child: SelectableText(
            s.isEmpty ? 'No description' : s,
            style: theme.ui(s.isEmpty ? t.textMuted : t.text, size: 12),
          ),
        ),
      ],
    ];
  }

  /// Cancel and Save, with [note] at their left.
  Widget buttons(NushiTheme theme, {String note = ''}) => Row(
    spacing: 6,
    children: [
      Expanded(child: Text(note, style: theme.ui(theme.t.textMuted, size: 12))),
      Button(
        label: 'Cancel',
        kind: ButtonKind.quiet,
        onPressed: saving ? null : cancel,
      ),
      Button(
        label: saving ? 'Saving…' : 'Save',
        hint: part == PullPart.description ? cmdEnterLabel : '',
        kind: ButtonKind.primary,
        onPressed: saving ? null : save,
      ),
    ],
  );
}

/// The description: the pull request's text alone on a card, a pencil at
/// its top right (Edit) when GitHub lets the user edit it; an empty one
/// says so, so one can be added. Editing, the card holds the Markdown
/// source in a field, Save and Cancel (ADR 0137).
class PullDescription extends StatefulWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.onSaved,
    super.key,
    this.me = '',
  });

  final Daemon daemon;
  final GitHubPull pull;
  final Future<void> Function() onSaved;

  /// Who the user is on its host ('' when not known).
  final String me;

  @override
  State<PullDescription> createState() => _PullDescriptionState();
}

class _PullDescriptionState extends _PullEdit<PullDescription> {
  @override
  Daemon get daemon => widget.daemon;
  @override
  GitHubPull get pull => widget.pull;
  @override
  PullPart get part => PullPart.description;
  @override
  Future<void> Function() get onSaved => widget.onSaved;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final Widget child;
    if (editing) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            skipTraversal: true,
            onKeyEvent: (n, e) => keys(n, e, enterAlone: false),
            child: TextField(
              key: const ValueKey('description field'),
              controller: text,
              focusNode: focus,
              readOnly: saving,
              minLines: 6,
              maxLines: 24,
              style: theme.ui(t.text),
              decoration: const InputDecoration(
                hintText: 'Add a description',
                isDense: true,
              ),
            ),
          ),
          ...trouble(theme),
          const SizedBox(height: 8),
          buttons(
            theme,
            note: widget.me.isEmpty
                ? 'Markdown'
                : 'Markdown · saves to GitHub as ${widget.me}',
          ),
        ],
      );
    } else {
      final shown = saved ?? pull.body;
      final body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: shown.isEmpty
                ? Text('No description', style: theme.ui(t.textMuted, size: 12))
                : SelectionArea(
                    child: AgentMarkdown(
                      githubText(shown),
                      images: githubImage,
                    ),
                  ),
          ),
          if (pull.canEdit) ...[const SizedBox(width: 8), pencil()],
        ],
      );
      // Its reactions under it, as GitHub's description has them.
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          body,
          Align(
            alignment: Alignment.centerLeft,
            child: Reactions(
              pull.item.id,
              pull.reactions,
              reacting: (
                daemon: widget.daemon,
                host: pull.item.ref.host,
                onChanged: widget.onSaved,
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      key: const ValueKey('pull-description'),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        pull.canEdit && !editing ? 10 : 16,
        14,
      ),
      decoration: cardBox(t),
      child: child,
    );
  }
}

/// The page's title, selectable, with a pencil beside it (Edit) when
/// GitHub lets the user edit it, then [trailing] (Open on GitHub).
/// Editing, a one-line field with Save and Cancel in its place.
class PullTitle extends StatefulWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.onSaved,
    required this.trailing,
    super.key,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final Future<void> Function() onSaved;
  final Widget trailing;

  @override
  State<PullTitle> createState() => _PullTitleState();
}

class _PullTitleState extends _PullEdit<PullTitle> {
  @override
  Daemon get daemon => widget.daemon;
  @override
  GitHubPull get pull => widget.pull;
  @override
  PullPart get part => PullPart.title;
  @override
  Future<void> Function() get onSaved => widget.onSaved;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    if (!editing) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SelectableText(
              saved ?? pull.item.title,
              style: theme.ui(t.text, size: 20, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          if (pull.canEdit) pencil(),
          widget.trailing,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 6,
          children: [
            Expanded(
              child: Focus(
                skipTraversal: true,
                onKeyEvent: (n, e) => keys(n, e, enterAlone: true),
                child: TextField(
                  key: const ValueKey('title field'),
                  controller: text,
                  focusNode: focus,
                  readOnly: saving,
                  style: theme.ui(t.text, size: 14),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    isDense: true,
                  ),
                ),
              ),
            ),
            Button(
              label: 'Cancel',
              kind: ButtonKind.quiet,
              onPressed: saving ? null : cancel,
            ),
            Button(
              label: saving ? 'Saving…' : 'Save',
              kind: ButtonKind.primary,
              onPressed: saving ? null : save,
            ),
          ],
        ),
        ...trouble(theme),
      ],
    );
  }
}
