import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/preview.dart';

/// A file the agent wrote, full screen on the phone, from its tool row's
/// Preview: Back, Live, and Preview or Source for Markdown. Read-only.
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
        if (previewKind(widget.path) == PreviewKind.markdown)
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
      ),
    ),
  );
}
