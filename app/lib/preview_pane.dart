import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/theme/theme.dart';

/// A file the agent wrote, beside the chat where a subagent's pane opens:
/// its name, Live while the daemon keeps it current, Preview or Source
/// (Markdown), Open in Finder and Close. Read-only.
class PreviewPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.path,
    required this.onClose,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final String path; // as the tool row names it
  final VoidCallback onClose;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  late final _watch = FileWatch(widget.daemon, widget.chat.id, widget.path);
  bool _source = false;

  @override
  void dispose() {
    _watch.dispose();
    super.dispose();
  }

  void _reveal() {
    final p = widget.path;
    final abs =
        _watch.file?.path ??
        (p.startsWith('/') ? p : '${widget.chat.folder}/$p');
    revealInFinder(abs).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final kind = previewKind(widget.path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: t.raised,
            border: Border(bottom: BorderSide(color: t.borderSubtle)),
          ),
          child: ListenableBuilder(
            listenable: _watch,
            builder: (context, _) => Row(
              spacing: 8,
              children: [
                Icon(
                  kind == PreviewKind.image
                      ? Icons.image_outlined
                      : Icons.description_outlined,
                  size: 14,
                  color: t.textSecondary,
                ),
                Expanded(
                  child: Tooltip(
                    message: _watch.file?.path ?? widget.path,
                    child: Text(
                      baseName(widget.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.code(t.text, size: 12),
                    ),
                  ),
                ),
                if (_watch.live) const LiveMark(),
                if (kind == PreviewKind.markdown)
                  SourceSwitch(
                    source: _source,
                    onChanged: (v) => setState(() => _source = v),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTap(
                      Icons.folder_open_outlined,
                      tooltip: 'Open in Finder',
                      size: 14,
                      onTap: _reveal,
                    ),
                    IconTap(
                      Icons.close,
                      tooltip: 'Close',
                      size: 15,
                      onTap: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: t.base,
            child: PreviewBody(
              watch: _watch,
              source: _source,
              onReveal: _reveal,
            ),
          ),
        ),
      ],
    );
  }
}
