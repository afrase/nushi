import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Whether a change can be staged: a repository inside the folder is listed
/// as a file, but `git add` would make it a submodule.
bool stageable(FileChange f) => f.skipped != 'a repository of its own';

/// A staging checkbox's value: staged, not, or (null) in part.
bool? stagedValue(Iterable<FileChange> files) {
  final all = files.every((f) => f.staged == 'all');
  return all
      ? true
      : files.every((f) => f.staged.isEmpty)
      ? false
      : null;
}

/// The paths of [files] that are in the index, whole or in part.
Set<String> stagedPaths(Iterable<FileChange> files) => {
  for (final f in files)
    if (f.staged.isNotEmpty) f.path,
};

/// A commit refused because the files staged aren't the ones shown at the
/// click: a reload after it (a turn's, staging's) found others (ADR 0079).
class StagedMoved implements Exception {
  /// The files staged or taken out since the click, by path.
  new(Set<String> paths) : paths = paths.toList()..sort();

  final List<String> paths;

  @override
  String toString() {
    final names = paths.take(3).map(plainName).join(', ');
    final more = paths.length > 3 ? ' and ${paths.length - 3} more' : '';
    return 'Staged files changed since you looked: $names$more. Look them '
        'over and commit again.';
  }
}

/// A staging checkbox over [files], in a row's height. A click stages what
/// isn't, and takes out what all is.
class StageCheck extends StatelessWidget {
  const new(this.files, {required this.onStage, super.key});

  final List<FileChange> files;
  final void Function(List<FileChange>, {required bool on}) onStage;

  @override
  Widget build(BuildContext context) {
    final value = stagedValue(files);
    return SizedBox.square(
      dimension: StageCheck.size,
      child: Transform.scale(
        scale: 0.72,
        child: Checkbox(
          tristate: true,
          value: value,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (_) => onStage(files, on: value != true),
        ),
      ),
    );
  }

  static const size = 20.0;
}

/// Under Uncommitted's files: what's staged, the commit's message, and
/// Commit. Commit takes what's staged, as `git commit` does, so a file
/// changed since it was staged goes as it was ([stagedValue]'s null shows
/// that). ADR 0079.
class CommitBox extends StatefulWidget {
  const new({
    required this.chat,
    required this.files,
    required this.onStage,
    required this.onCommit,
    required this.onWrite,
    super.key,
  });

  final ChatState chat;
  final List<FileChange> files;
  final void Function(List<FileChange>, {required bool on}) onStage;

  /// Commits with this message; what it throws shows here.
  final Future<void> Function(String message) onCommit;

  /// Asks the chat's agent for a message, for what's staged.
  final Future<String> Function() onWrite;

  @override
  State<CommitBox> createState() => _CommitBoxState();
}

class _CommitBoxState extends State<CommitBox> {
  String? _error;
  bool _running = false;
  bool _writing = false;

  int get _staged => stagedPaths(widget.files).length;

  bool get _ready =>
      !_running &&
      _staged > 0 &&
      widget.chat.commitMessage.text.trim().isNotEmpty;

  /// Puts the agent's message in the field, where it can be edited.
  Future<void> _write() async {
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      widget.chat.commitMessage.text = await widget.onWrite();
    } on Object catch (e) {
      _error = errorText(e);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _commit() async {
    if (!_ready) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await widget.onCommit(widget.chat.commitMessage.text);
      widget.chat.commitMessage.clear();
    } on Object catch (e) {
      _error = errorText(e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final files = widget.files.where(stageable).toList();
    final n = _staged;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([chat, chat.commitMessage]),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Row(
              spacing: 6,
              children: [
                if (files.isNotEmpty)
                  StageCheck(files, onStage: widget.onStage),
                Expanded(
                  child: Text(
                    '$n of ${widget.files.length} staged',
                    style: theme.ui(t.textSecondary, size: 12),
                  ),
                ),
                if (_writing)
                  const SizedBox.square(dimension: 12, child: Spinner())
                else if (chat.canWriteCommit)
                  IconTap(
                    Icons.auto_awesome_outlined,
                    size: 14,
                    tooltip: chat.busy
                        ? '${chat.agentName} is working'
                        : 'Write the message with ${chat.agentName}',
                    onTap: n == 0 || chat.busy ? null : _write,
                  ),
              ],
            ),
            CallbackShortcuts(
              bindings: {const Cmd(LogicalKeyboardKey.enter): _commit},
              child: TextField(
                controller: chat.commitMessage,
                // Room to read a whole message; a window's short side keeps
                // room for the files.
                minLines: 5,
                maxLines: (MediaQuery.sizeOf(context).height / 50)
                    .floor()
                    .clamp(5, 14),
                style: theme.ui(t.text),
                decoration: const InputDecoration(
                  hintText: 'Commit message',
                  isDense: true,
                ),
              ),
            ),
            if (chat.busy)
              Text(
                '${chat.agentName} is working, so files may change.',
                style: theme.ui(t.textMuted, size: 11.5),
              ),
            if (_error case final error?)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: SelectableText(
                    error,
                    style: theme.code(t.crashed, size: 11),
                  ),
                ),
              ),
            Button(
              label: _running
                  ? 'Committing…'
                  : n == 0
                  ? 'Commit'
                  : 'Commit $n file${n == 1 ? '' : 's'}',
              kind: ButtonKind.primary,
              tooltip: n == 0 ? 'Stage a file first' : cmdEnterLabel,
              onPressed: _ready ? _commit : null,
            ),
          ],
        ),
      ),
    );
  }
}
