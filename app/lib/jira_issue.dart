import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue_parts.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/jira_work.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// How often the issue shown is asked for again.
const issuePoll = Duration(seconds: 60);

/// An issue whole: its header (key, type, status with its moves,
/// priority, assignee), its text and comments as Markdown, subtasks,
/// parent, links, attachments, remote links, and a box to comment in.
class JiraIssuePane extends StatefulWidget {
  const new({
    required this.daemon,
    required this.site,
    required this.issueKey,
    required this.onOpen,
    super.key,
    this.now,
  });

  final Daemon daemon;
  final String site;
  final String issueKey;

  /// Shows another issue (a subtask, a link) in its place.
  final void Function(String key) onOpen;

  /// The time ages are counted from (tests); now when null.
  final DateTime? now;

  @override
  State<JiraIssuePane> createState() => _JiraIssuePaneState();
}

class _JiraIssuePaneState extends State<JiraIssuePane> {
  JiraIssue? _issue;
  List<JiraWrite> _writes = const []; // what agents wrote through their tools
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _poll = Timer.periodic(issuePoll, (_) => unawaited(_load(quiet: true)));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final r = await widget.daemon.client.getJiraIssue(
        GetJiraIssueRequest(site: widget.site, key: widget.issueKey),
      );
      if (mounted) {
        setState(() {
          _issue = r.issue;
          _writes = r.agentWrites;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted && !quiet) setState(() => _error = jiraError(e));
    }
  }

  /// Whose a write was: the agent's, in which chat (if Nushi still has it).
  String _byAgent(JiraWrite w) {
    final chat = widget.daemon.chats[w.chat];
    final where = chat == null || chat.title.isEmpty
        ? ''
        : ' in “${chat.title}”';
    return 'by ${agentTitle(w.agent)}$where';
  }

  Future<void> _comment(String markdown) async {
    await widget.daemon.client.addJiraComment(
      AddJiraCommentRequest(
        site: widget.site,
        key: widget.issueKey,
        markdown: markdown,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final i = _issue;
    if (i == null) {
      return Center(
        child: Text(
          _error ?? 'Loading ${widget.issueKey}…',
          style: theme.ui(_error == null ? t.textMuted : t.crashed),
        ),
      );
    }
    final now = widget.now ?? DateTime.now();
    String age(int ms) {
      final when = DateTime.fromMillisecondsSinceEpoch(ms);
      return ago(now.difference(when), when);
    }

    final images = jiraImages(widget.daemon.client, widget.site);
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.ui(t.textSecondary, weight: FontWeight.w600, size: 12),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          _header(theme, i),
          const SizedBox(height: 6),
          Text(
            i.summary,
            style: theme.ui(t.text, size: 18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (i.reporter.isNotEmpty) 'Reported by ${i.reporter}',
              if (i.created > 0) age(i.created.toInt()),
              if (i.updated > 0) 'updated ${age(i.updated.toInt())}',
              if (i.labels.isNotEmpty) i.labels.join(', '),
            ].join(' · '),
            style: theme.ui(t.textMuted, size: 12),
          ),
          if (i.hasParent())
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Ref(i.parent, prefix: 'Parent', onOpen: widget.onOpen),
            ),
          section('Description', [
            if (i.description.isEmpty)
              Text('No description', style: theme.ui(t.textMuted))
            else
              AgentMarkdown(i.description, images: images),
          ]),
          if (i.acceptanceCriteria.isNotEmpty)
            section('Acceptance criteria', [
              AgentMarkdown(i.acceptanceCriteria, images: images),
            ]),
          if (i.subtasks.isNotEmpty)
            section('Subtasks', [
              for (final s in i.subtasks) _Ref(s, onOpen: widget.onOpen),
            ]),
          if (i.links.isNotEmpty)
            section('Links', [
              for (final l in i.links)
                _Ref(l.issue, prefix: l.relation, onOpen: widget.onOpen),
            ]),
          if (i.attachments.isNotEmpty)
            section('Attachments', [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final a in i.attachments)
                    if (a.mimeType.startsWith('image/'))
                      AttachmentImage(
                        widget.daemon.client,
                        widget.site,
                        a.id,
                        size: 96,
                      )
                    else
                      Text(
                        '${a.name} · ${(a.size.toInt() / 1024).ceil()} KB',
                        style: theme.ui(t.text, size: 12),
                      ),
                ],
              ),
            ]),
          if (i.remoteLinks.isNotEmpty)
            section('Remote links', [
              for (final r in i.remoteLinks)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tap(
                    onTap: () {
                      if (webLink(r.url) case final u?) unawaited(launchUrl(u));
                    },
                    child: Text(
                      r.title.isEmpty ? r.url : r.title,
                      style: theme.ui(t.link),
                    ),
                  ),
                ),
            ]),
          ListenableBuilder(
            listenable: widget.daemon,
            builder: (context, _) {
              final chats = [
                for (final c in widget.daemon.chats.values)
                  if (c.jiraSite == widget.site && c.jiraKey == i.key) c,
              ]..sort((a, b) => b.created.compareTo(a.created));
              return chats.isEmpty
                  ? const SizedBox.shrink()
                  : section('Chats', [
                      for (final c in chats)
                        Tap(
                          onTap: () => widget.daemon.select(c.id),
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              AgentMark(c.agent, color: t.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.title.isEmpty ? 'New chat' : c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.ui(t.text),
                                ),
                              ),
                              Text(
                                age(c.created.millisecondsSinceEpoch),
                                style: theme.ui(t.textMuted, size: 12),
                              ),
                            ],
                          ),
                        ),
                    ]);
            },
          ),
          if (_writes.where((w) => w.kind == 'move').toList() case final moves
              when moves.isNotEmpty)
            section('Moved by agents', [
              for (final w in moves)
                Text(
                  'To ${w.to} · ${age(w.at.toInt())} · ${_byAgent(w)}',
                  style: theme.ui(t.textSecondary, size: 12),
                ),
            ]),
          section('Comments', [
            for (final c in i.comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        c.author,
                        age(c.created.toInt()),
                        if (_writes
                                .where(
                                  (w) =>
                                      w.kind == 'comment' && w.comment == c.id,
                                )
                                .firstOrNull
                            case final w?)
                          _byAgent(w),
                      ].join(' · '),
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                    AgentMarkdown(c.body, images: images),
                  ],
                ),
              ),
            CommentBox(onPost: _comment),
          ]),
        ],
      ),
    );
  }

  Widget _header(NushiTheme theme, JiraIssue i) {
    final t = theme.t;
    final dim = theme.ui(t.textSecondary, size: 12);
    return Row(
      children: [
        Text(i.key, style: theme.code(t.textSecondary, size: 12)),
        const SizedBox(width: 10),
        Text(i.type, style: dim),
        const SizedBox(width: 10),
        StatusMenu(
          i,
          load: () => issueMoves(
            context,
            widget.daemon,
            widget.site,
            i,
            onMoved: _load,
          ),
        ),
        if (i.priority.isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(i.priority, style: dim),
        ],
        const SizedBox(width: 10),
        Text(i.assignee.isEmpty ? 'Unassigned' : i.assignee, style: dim),
        const Spacer(),
        Menu(
          entries: folderEntries(
            widget.daemon,
            onPick: (f) =>
                startWork(context, widget.daemon, widget.site, i.key, f),
          ),
          child: Text('Start a chat ▾', style: theme.ui(t.link, size: 12)),
        ),
        const SizedBox(width: 6),
        IconTap(Icons.refresh, tooltip: 'Refresh', onTap: _load),
        IconTap(
          Icons.open_in_new,
          tooltip: 'Open in the browser',
          onTap: webLink(i.url) == null
              ? null
              : () => unawaited(launchUrl(webLink(i.url)!)),
        ),
      ],
    );
  }
}

/// Another issue: its key, summary and status; a click shows it.
class _Ref extends StatelessWidget {
  const new(this.ref, {required this.onOpen, this.prefix = ''});

  final JiraIssueRef ref;
  final String prefix;
  final void Function(String key) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Tap(
      onTap: () => onOpen(ref.key),
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        children: [
          if (prefix.isNotEmpty) ...[
            Text(prefix, style: theme.ui(t.textMuted, size: 12)),
            const SizedBox(width: 8),
          ],
          Text(ref.key, style: theme.code(t.link, size: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ref.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text),
            ),
          ),
          Text(ref.status, style: theme.ui(t.textMuted, size: 12)),
        ],
      ),
    );
  }
}
