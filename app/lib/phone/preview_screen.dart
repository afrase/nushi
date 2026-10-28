import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/page_frame.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/theme/theme.dart';

/// A file the agent wrote, full screen on the phone, from its tool row's
/// Preview: Back, Live, and Preview or Source for a file that renders.
/// A page (HTML, SVG) shows in a sandboxed frame ([PageFrame]) without the
/// files beside it; a PDF only on the Mac. Read-only.
class PreviewScreen extends StatefulWidget {
  const new(this.daemon, this.chat, this.path, {super.key});

  final Daemon daemon;
  final ChatState chat;
  final String path;

  /// Pushes it (in the tap: its history entry comes first, PhoneHistory).
  static void open(
    BuildContext context,
    Daemon daemon,
    ChatState chat,
    String path,
  ) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => PreviewScreen(daemon, chat, path),
        ),
      )
      .ignore();

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final _watch = FileWatch(widget.daemon, widget.chat.id, widget.path);
  bool _source = false;

  @override
  void dispose() {
    _watch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _watch,
    builder: (context, _) => PhoneScreen(
      title: baseName(widget.path),
      actions: [
        if (_watch.live) ...[
          LiveMark(size: 13, version: _watch.file),
          const SizedBox(width: 10),
        ],
        if (previewKind(widget.path)?.rendered ?? false)
          SourceSwitch(
            source: _source,
            onChanged: (v) => setState(() => _source = v),
          ),
        const SizedBox(width: 4),
      ],
      body: PreviewBody(
        watch: _watch,
        source: _source,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        page: _page,
      ),
    ),
  );

  Widget _page(FileWatch watch) => ListenableBuilder(
    listenable: watch,
    builder: (context, _) {
      if (previewStatus(context, watch) case final status?) return status;
      if (previewKind(watch.path) == PreviewKind.pdf) {
        return const PreviewNote('Open it on your Mac to see it.');
      }
      final theme = NushiTheme.of(context);
      final f = watch.file!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Files beside it (CSS, images) don’t load here.',
              style: theme.ui(theme.t.textMuted, size: 12),
            ),
          ),
          Expanded(
            child: PageFrame(
              utf8.decode(f.data, allowMalformed: true),
              key: ValueKey(f),
            ),
          ),
        ],
      );
    },
  );
}
