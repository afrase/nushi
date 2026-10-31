import 'dart:async';

import 'package:connectrpc/connect.dart' show ConnectException;
import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/pull_merge_state.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What a confirmation is for: merging now, auto-merge, adding to the
/// merge queue now, or joining it once it can.
enum MergeAct { merge, auto, enqueue, whenReady }

/// Whether the daemon refused [e] because the pull request isn't at the head
/// the user was shown.
bool headMoved(Object e) =>
    e is ConnectException && refusedFor(e, 'head_moved', (_) => false);

/// Asks before [act] on [pull], which can't be taken back and goes out to
/// GitHub in the user's name, then does it at the head [pull] showed; then
/// [onDone] reads it again, as it does when the head moved.
Future<void> confirmMerge(
  BuildContext context,
  Daemon daemon,
  GitHubPull pull,
  MergeAct act, {
  required String method,
  required Future<void> Function() onDone,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _MergeDialog(daemon, pull, act, method),
  );
  if (changed ?? false) await onDone();
}

class _MergeDialog extends StatefulWidget {
  const new(this.daemon, this.pull, this.act, this.method);

  final Daemon daemon;
  final GitHubPull pull;
  final MergeAct act;
  final String method;

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _runner = Runner();
  bool _loading = false;
  String? _error;

  GitHubPull get _pull => widget.pull;
  GitHubRef get _ref => _pull.item.ref;

  /// The act has a commit's text to show: a queue's is its own, and a
  /// rebase keeps the commits' own.
  bool get _hasText =>
      (widget.act == MergeAct.merge || widget.act == MergeAct.auto) &&
      widget.method != 'rebase';

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    if (_hasText) unawaited(_load());
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _runner.dispose();
    super.dispose();
  }

  /// GitHub's commit text first, for the user to change.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.daemon.client.getGitHubMergeText(
        GetGitHubMergeTextRequest(ref: _ref),
      );
      if (!mounted) return;
      final squash = widget.method == 'squash';
      _title.text = squash ? r.squashTitle : r.mergeTitle;
      _body.text = squash ? r.squashBody : r.mergeBody;
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() {
    final client = widget.daemon.client;
    final head = _pull.headOid;
    final base = _pull.base;
    return switch (widget.act) {
      MergeAct.merge => client.mergeGitHubPull(
        MergeGitHubPullRequest(
          ref: _ref,
          headOid: head,
          base: base,
          method: widget.method,
          title: _title.text,
          body: _body.text,
        ),
      ),
      MergeAct.auto || MergeAct.whenReady => client.enableGitHubAutoMerge(
        EnableGitHubAutoMergeRequest(
          ref: _ref,
          headOid: head,
          base: base,
          method: widget.method,
          title: _title.text,
          body: _body.text,
        ),
      ),
      MergeAct.enqueue => client.enqueueGitHubPull(
        EnqueueGitHubPullRequest(ref: _ref, headOid: head, base: base),
      ),
    };
  }

  /// Sends it. A failure stays here to try again, and toasts; a head that
  /// moved closes the dialog, since what it shows is out of date.
  Future<void> _go() async {
    setState(() => _error = null);
    try {
      await _send();
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        if (headMoved(e)) {
          Navigator.pop(context, true);
        } else {
          setState(() => _error = errorText(e));
        }
      }
      rethrow;
    }
  }

  (String, String, String, String) get _words {
    final p = _pull;
    final m = widget.method;
    final queue = p.merge.queueMethod.isEmpty
        ? 'the method it was set up with'
        : methodWords(p.merge.queueMethod);
    return switch (widget.act) {
      MergeAct.merge => (
        '${methodLabel(m)}?',
        methodLabel(m),
        'Merging…',
        "Merging can't be undone.",
      ),
      MergeAct.auto => (
        'Enable auto-merge?',
        'Enable auto-merge',
        'Enabling…',
        'GitHub merges it with ${methodWords(m)} by itself once it can. '
            'Disable auto-merge stops that until then.',
      ),
      MergeAct.enqueue => (
        'Add to the merge queue?',
        'Add to queue',
        'Adding…',
        "The queue merges it with $queue, and its text is the queue's. "
            'Remove from queue stops that until then.',
      ),
      MergeAct.whenReady => (
        'Merge when ready?',
        'Merge when ready',
        'Enabling…',
        'It joins the merge queue by itself once it can; the queue merges '
            "it with $queue, and its text is the queue's.",
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = _pull;
    final (title, action, working, note) = _words;
    final small = theme.ui(t.textSecondary, size: 12.5);
    final code = theme.code(t.text, size: 12);
    final short = p.headOid.substring(0, p.headOid.length.clamp(0, 7));
    // Anyone's names, in the one place that must read as what it is: git
    // takes bidi marks in a branch's name.
    final base = plainName(p.base);
    final head = plainName(p.head);
    return ValueListenableBuilder(
      valueListenable: _runner,
      builder: (context, running, _) => nushiDialog(
        title,
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  key: const ValueKey('merge-what'),
                  TextSpan(
                    children: [
                      TextSpan(text: '#${p.item.ref.number} into '),
                      TextSpan(text: base, style: code),
                      const TextSpan(text: ', from '),
                      TextSpan(text: head, style: code),
                      const TextSpan(text: ' at '),
                      TextSpan(text: short, style: code),
                      if (!_hasText && widget.method.isNotEmpty) ...[
                        const TextSpan(text: ', by '),
                        TextSpan(text: methodWords(widget.method)),
                      ],
                      const TextSpan(text: '.'),
                    ],
                  ),
                  style: small,
                ),
                const SizedBox(height: 6),
                Text(note, style: small),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      if (p.merge.deleteBranch) ...[
                        const TextSpan(text: 'The repository deletes '),
                        TextSpan(text: head, style: code),
                        const TextSpan(text: ' once it merges.'),
                      ] else ...[
                        TextSpan(text: head, style: code),
                        const TextSpan(
                          text: ' stays; Clean up… can delete it after.',
                        ),
                      ],
                    ],
                  ),
                  style: small,
                ),
                if (_hasText) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('merge-title'),
                    controller: _title,
                    enabled: !running && !_loading,
                    decoration: InputDecoration(
                      labelText: 'Commit title',
                      hintText: _loading ? 'Asking GitHub…' : null,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('merge-body'),
                    controller: _body,
                    enabled: !running && !_loading,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Commit message',
                      isDense: true,
                    ),
                  ),
                ],
                if (_error case final e?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(e, style: theme.ui(t.crashed, size: 12)),
                  ),
              ],
            ),
          ),
        ),
        [
          Button(
            label: 'Cancel',
            onPressed: running ? null : () => Navigator.pop(context, false),
          ),
          RunButton(
            label: action,
            running: working,
            kind: ButtonKind.primary,
            runner: _runner,
            run: _loading || (_hasText && _title.text.trim().isEmpty)
                ? null
                : _go,
          ),
        ],
      ),
    );
  }
}
