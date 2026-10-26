import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// My review's inline comments not sent yet, by pull request, while the
/// app runs; they go to GitHub with the review (Review…), never before.
final _drafts = <String, List<GitHubDraft>>{};

/// Says the drafts changed, for the views that show them.
final ValueNotifier<int> draftsChanged = ValueNotifier(0);

String _key(GitHubRef r) => '${r.host} ${r.repo} ${r.number}';

/// A pull request's drafts.
List<GitHubDraft> reviewDrafts(GitHubRef r) => _drafts[_key(r)] ?? const [];

/// Keeps a pull request's drafts.
void setDrafts(GitHubRef r, List<GitHubDraft> drafts) {
  _drafts[_key(r)] = drafts;
  draftsChanged.value++;
}

/// Asks for the review (comment, approve, request changes, and what it
/// says) and submits it with the drafts, and with my review pending on
/// GitHub if there is one; then [onDone].
Future<void> submitReview(
  BuildContext context,
  Daemon daemon,
  GitHubPull pull, {
  required Future<void> Function() onDone,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReviewDialog(daemon, pull),
  );
  if (sent ?? false) {
    setDrafts(pull.item.ref, const []);
    await onDone();
  }
}

class _ReviewDialog extends StatefulWidget {
  const new(this.daemon, this.pull);

  final Daemon daemon;
  final GitHubPull pull;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  var _event = 'comment';
  final _body = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p = widget.pull;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.daemon.client.submitGitHubReview(
        SubmitGitHubReviewRequest(
          host: p.item.ref.host,
          pull: p.item.id,
          headOid: p.headOid,
          pendingReview: p.pendingReview,
          event: _event,
          body: _body.text.trim(),
          drafts: reviewDrafts(p.item.ref),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = githubError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = widget.pull;
    final n = reviewDrafts(p.item.ref).length;
    final inline = [
      if (n > 0) '$n inline comment${n == 1 ? '' : 's'} from here',
      if (p.pendingComments > 0)
        '${p.pendingComments} in your review pending on GitHub',
    ];
    return nushiDialog(
      'Review #${p.item.ref.number}',
      SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Segmented(
              value: _event,
              segments: const [
                ('comment', 'Comment'),
                ('approve', 'Approve'),
                ('request_changes', 'Request changes'),
              ],
              onChanged: (v) => setState(() => _event = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              enabled: !_busy,
              decoration: const InputDecoration(
                hintText: 'What the review says (Markdown)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              inline.isEmpty
                  ? 'No inline comments: select lines in Files to add some.'
                  : 'With ${inline.join(' and ')}.',
              style: theme.ui(t.textMuted, size: 12),
            ),
            if (_error case final e?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(e, style: theme.ui(t.crashed, size: 12)),
              ),
          ],
        ),
      ),
      [
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: _busy ? null : () => Navigator.pop(context, false),
        ),
        Button(
          label: _busy ? 'Submitting…' : 'Submit review',
          kind: ButtonKind.primary,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
