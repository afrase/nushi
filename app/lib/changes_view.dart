import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';

/// The chat folder's uncommitted changes: a list of files, and the picked
/// one side by side. It reloads when the agent finishes a turn.
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
    if (_wasBusy && !widget.chat.busy) _load();
    _wasBusy = widget.chat.busy;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await widget.daemon.client.getDiff(
        GetDiffRequest(folder: widget.chat.folder),
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
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    final file = _files.where((f) => f.path == _path).firstOrNull;
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: Column(
            children: [
              ListTile(
                dense: true,
                title: Text(
                  _files.isEmpty && !_loading
                      ? 'No changes'
                      : '${_files.length} changed',
                ),
                trailing: _loading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : IconButton(
                        tooltip: 'Reload',
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: _load,
                      ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final f in _files)
                      ListTile(
                        dense: true,
                        selected: f.path == _path,
                        leading: Text(
                          switch (f.status) {
                            'added' => 'A',
                            'deleted' => 'D',
                            _ => 'M',
                          },
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            color: switch (f.status) {
                              'added' => Colors.green,
                              'deleted' => theme.colorScheme.error,
                              _ => theme.colorScheme.primary,
                            },
                          ),
                        ),
                        minLeadingWidth: 12,
                        title: Tooltip(
                          message: f.path,
                          child: Text(
                            f.path.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: () => _show(f.path),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
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
                  ),
                ),
        ),
      ],
    );
  }
}
