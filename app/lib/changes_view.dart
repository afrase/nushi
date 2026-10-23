import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The chat folder's uncommitted changes, or for a worktree chat a choice
/// of those and the branch's (everything since it left its base): a list of
/// files, and the picked one side by side. It reloads when the agent
/// finishes a turn.
class ChangesView extends StatefulWidget {
  const ChangesView({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<ChangesView> createState() => _ChangesViewState();
}

class _ChangesViewState extends State<ChangesView> {
  List<FileChange> _files = [];
  String? _error;
  bool _loading = false;
  String? _path; // the file shown
  DiffViewController? _controller;
  DiffThemeData? _theme;
  bool _wasBusy = false;
  late String _folder = widget.chat.folder;
  late String _base = widget.daemon.diffBase(widget.chat);

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_chatChanged);
    _load();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_chatChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _chatChanged() {
    final base = widget.daemon.diffBase(widget.chat);
    if (_wasBusy && !widget.chat.busy ||
        _folder != widget.chat.folder ||
        _base != base) {
      _folder = widget.chat.folder;
      _base = base;
      _load();
    }
    _wasBusy = widget.chat.busy;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await widget.daemon.client.getDiff(
        GetDiffRequest(folder: widget.chat.folder, base: _base),
      );
      if (!mounted) return;
      _files = resp.files;
      _error = null;
      final keep = _files.any((f) => f.path == _path);
      _show(keep ? _path : _files.firstOrNull?.path);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String? path) {
    _controller?.dispose();
    _controller = null;
    _path = path;
    final file = _files.where((f) => f.path == path).firstOrNull;
    if (file != null && file.skipped.isEmpty) {
      final diff = TextDiff.compute(file.oldText, file.newText, path: path!);
      final dark = Theme.of(context).brightness == Brightness.dark;
      _theme = dark ? DiffThemeData.dark() : DiffThemeData.light();
      _controller = DiffViewController(
        document: diff.document,
        lines: diff.lines,
        theme: _theme!,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: theme.ui(t.text)),
            Button(label: 'Try again', onPressed: _load),
          ],
        ),
      );
    }
    final file = _files.where((f) => f.path == _path).firstOrNull;
    final chat = widget.chat;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: t.raised,
            border: Border(right: BorderSide(color: t.borderSubtle)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (chat.worktree != null && widget.daemon.canBranchDiff)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Segmented(
                    value: chat.branchDiff,
                    segments: const [(true, 'Branch'), (false, 'Uncommitted')],
                    onChanged: (v) => chat.branchDiff = v,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _files.isEmpty && !_loading
                            ? 'No changes'
                            : '${_files.length} changed',
                        style: theme.ui(t.textSecondary, size: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reload',
                      iconSize: 15,
                      color: t.textSecondary,
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final f in _files) _FileRow(f, f.path == _path, _show),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _controller != null
              ? SideBySideDiff(
                  controller: _controller!,
                  theme: _theme!,
                  inlayBuilder: (context, spec) => const SizedBox.shrink(),
                )
              : Center(
                  child: Text(
                    file == null
                        ? ''
                        : 'Not shown: ${file.path} is ${file.skipped}.',
                    style: theme.ui(t.textMuted),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow(this.file, this.selected, this.onTap);

  final FileChange file;
  final bool selected;
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (letter, color) = switch (file.status) {
      'added' => ('A', t.done),
      'deleted' => ('D', t.crashed),
      _ => ('M', t.running),
    };
    final slash = file.path.lastIndexOf('/');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected ? t.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(NushiTheme.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(NushiTheme.control),
          onTap: () => onTap(file.path),
          child: Tooltip(
            message: file.path,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(letter, style: theme.code(color, size: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: file.path.substring(slash + 1),
                            style: theme.ui(t.text),
                          ),
                          if (slash > 0)
                            TextSpan(
                              text: '  ${file.path.substring(0, slash)}',
                              style: theme.ui(t.textMuted, size: 11.5),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
