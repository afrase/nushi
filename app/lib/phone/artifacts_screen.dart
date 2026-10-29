import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';

/// The files a chat wrote that preview, on the phone, as [chatArtifacts]
/// sorts them without pins (they're kept in the Mac's `app.json`, which
/// the phone can't reach): the recent, then "Older (n)" folding the rest;
/// each row its name and folder; a tap opens it full screen.
class ArtifactsScreen extends StatefulWidget {
  const new(this.daemon, this.chat, {super.key});

  final Daemon daemon;
  final ChatState chat;

  static void open(BuildContext context, Daemon daemon, ChatState chat) =>
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ArtifactsScreen(daemon, chat),
            ),
          )
          .ignore();

  @override
  State<ArtifactsScreen> createState() => _ArtifactsScreenState();
}

class _ArtifactsScreenState extends State<ArtifactsScreen> {
  bool _older = false;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: artifactsOf(widget.chat),
      builder: (context, _) {
        final a = chatArtifacts(widget.chat, pins: false);
        return PhoneScreen(
          title: 'Artifacts',
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              for (final f in a.recent) _row(context, f),
              if (a.older.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _older = !_older),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: touch),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      spacing: 4,
                      children: [
                        Text(
                          'Older (${a.older.length})',
                          style: phoneText(
                            context,
                            size: 15,
                            color: t.textMuted,
                          ),
                        ),
                        Icon(
                          _older
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 18,
                          color: t.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_older)
                for (final f in a.older) _row(context, f),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String f) => InkWell(
    onTap: () => PreviewScreen.open(context, widget.daemon, widget.chat, f),
    child: Container(
      constraints: const BoxConstraints(minHeight: touch + 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            baseName(f),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: phoneText(context),
          ),
          if (folderOf(f) case final dir when dir.isNotEmpty)
            Text(
              dir,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: phoneText(
                context,
                size: 13,
                color: NushiTheme.of(context).t.textMuted,
              ),
            ),
        ],
      ),
    ),
  );
}

/// The chat screen's bar's "Artifacts 4": opens [ArtifactsScreen].
class ArtifactsAction extends StatelessWidget {
  const new(this.count, {required this.onTap, super.key});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Semantics(
      button: true,
      label: 'Artifacts, $count',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: touch / 2,
        child: SizedBox(
          height: touch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                'Artifacts $count',
                style: phoneText(context, size: 15, color: t.link),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
