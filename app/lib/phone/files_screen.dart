import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';

/// The files a chat wrote that preview ([chatFiles]), on the phone: each
/// row its name and folder; a tap opens it full screen.
class FilesScreen extends StatelessWidget {
  const new(this.daemon, this.chat, {super.key});

  final Daemon daemon;
  final ChatState chat;

  static void open(BuildContext context, Daemon daemon, ChatState chat) =>
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(builder: (_) => FilesScreen(daemon, chat)),
          )
          .ignore();

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final files = chatFiles(chat.items);
        return PhoneScreen(
          title: 'Artifacts',
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              for (final f in files)
                InkWell(
                  onTap: () => PreviewScreen.open(context, daemon, chat, f),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: touch + 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                              color: t.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The chat screen's bar's "Artifacts 4": opens [FilesScreen].
class FilesAction extends StatelessWidget {
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
