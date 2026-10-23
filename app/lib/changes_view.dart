import 'dart:math';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'panes.dart';
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

/// Reloads (`reload`) a chat's changes when its turn ends, it moves, or
/// the base they are counted from changes.
mixin FollowsChanges<T extends StatefulWidget> on State<T> {
  ChatState get chat;
  Daemon get daemon;
  late String base = daemon.diffBase(chat);
  late String _folder = chat.folder;
  bool _wasBusy = false;

  Future<void> reload();

  @override
  void initState() {
    super.initState();
    chat.addListener(_changed);
    reload();
  }

  @override
  void dispose() {
    chat.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final b = daemon.diffBase(chat);
    if (_wasBusy && !chat.busy || _folder != chat.folder || base != b) {
      _folder = chat.folder;
      base = b;
      reload();
    }
    _wasBusy = chat.busy;
  }
}

class _ChangesViewState extends State<ChangesView> with FollowsChanges {
  @override
  ChatState get chat => widget.chat;
  @override
  Daemon get daemon => widget.daemon;
  List<FileChange> _files = [];
  String? _error;
  bool _loading = false;
  String? _path; // the file shown

  @override
  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final resp = await daemon.client.getDiff(
        GetDiffRequest(folder: chat.folder, base: base),
      );
      if (!mounted) return;
      _files = resp.files;
      _error = null;
      if (!_files.any((f) => f.path == _path)) {
        _path = _files.firstOrNull?.path;
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: theme.ui(t.text)),
            Button(label: 'Try again', onPressed: reload),
          ],
        ),
      );
    }
    final file = _files.where((f) => f.path == _path).firstOrNull;
    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Resizable(
            name: 'files',
            initial: 240,
            min: 180,
            max: min(560, box.maxWidth - 360),
            child: ColoredBox(
              color: t.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (chat.worktree != null && daemon.canBranchDiff)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Segmented(
                        value: chat.branchDiff,
                        segments: const [
                          (true, 'Branch'),
                          (false, 'Uncommitted'),
                        ],
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
                        IconTap(
                          Icons.refresh,
                          tooltip: 'Reload',
                          size: 15,
                          onTap: _loading ? null : reload,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final f in _files)
                          _FileRow(
                            f,
                            f.path == _path,
                            (p) => setState(() => _path = p),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: file != null && file.skipped.isEmpty
                ? DiffBox(file, key: ValueKey(file.path), fit: false)
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
      ),
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
    final theme = NushiTheme.of(context), t = theme.t;
    final (letter, color) = switch (file.status) {
      'added' => ('A', t.done),
      'deleted' => ('D', t.crashed),
      _ => ('M', t.running),
    };
    final slash = file.path.lastIndexOf('/');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Tap(
        onTap: () => onTap(file.path),
        selected: selected,
        tooltip: file.path,
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
    );
  }
}

/// A file's change side by side. With [fit] it is only as tall as the
/// change (up to fifteen lines, then it scrolls), in a thin frame; else as
/// tall as its box.
class DiffBox extends StatefulWidget {
  const DiffBox(this.change, {super.key, this.fit = true});

  final FileChange change;
  final bool fit;

  @override
  State<DiffBox> createState() => _DiffBoxState();
}

class _DiffBoxState extends State<DiffBox> {
  DiffViewController? _controller;
  late DiffThemeData _theme;
  double _height = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _build();
  }

  @override
  void didUpdateWidget(DiffBox old) {
    super.didUpdateWidget(old);
    if (old.change != widget.change) _build();
  }

  void _build() {
    final d = widget.change;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _theme = Theme.of(context).brightness == Brightness.dark
        ? DiffThemeData.dark()
        : DiffThemeData.light();
    final diff = TextDiff.compute(d.oldText, d.newText, path: d.path);
    _controller?.dispose();
    _controller = DiffViewController(
      document: diff.document,
      lines: diff.lines,
      theme: _theme,
      devicePixelRatio: dpr,
    );
    final doc = diff.document;
    final rows = max(doc.oldLineCount, doc.newLineCount).clamp(1, 15);
    _height = _theme.lineHeightFor(dpr) * rows + 6;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = SideBySideDiff(
      controller: _controller!,
      theme: _theme,
      inlayBuilder: (context, spec) => const SizedBox.shrink(),
    );
    if (!widget.fit) return diff;
    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: box(
        NushiTheme.of(context).t.borderSubtle,
        radius: NushiTheme.control,
      ),
      child: diff,
    );
  }
}
