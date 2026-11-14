import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show Item;
import 'package:nushi/history_table.dart' show diskSize;
import 'package:nushi/images.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/skills_list.dart' show revealInFinder;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart';

/// The icon of a file's kind, by its name.
IconData fileKindIcon(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'png' ||
    'jpg' ||
    'jpeg' ||
    'gif' ||
    'webp' ||
    'bmp' ||
    'heic' ||
    'svg' => Icons.image_outlined,
    'zip' ||
    'gz' ||
    'tgz' ||
    'tar' ||
    'xz' ||
    'bz2' ||
    '7z' => Icons.folder_zip_outlined,
    'csv' ||
    'tsv' ||
    'xlsx' ||
    'xls' ||
    'numbers' => Icons.table_chart_outlined,
    'txt' ||
    'md' ||
    'rtf' ||
    'doc' ||
    'docx' ||
    'pages' ||
    'log' => Icons.description_outlined,
    'mp3' || 'wav' || 'm4a' || 'aiff' || 'flac' => Icons.audio_file_outlined,
    'mp4' || 'mov' || 'webm' || 'mkv' => Icons.video_file_outlined,
    '' => Icons.insert_drive_file_outlined,
    _ => Icons.code,
  };
}

/// What a file card says under the name: its kind and size ("PDF · 1.2 MB").
String fileCardDetail(AttachedFile f) {
  final ext = f.name.contains('.') ? f.name.split('.').last.toUpperCase() : '';
  final kind = ext.isEmpty || ext.length > 5 ? 'File' : ext;
  return f.size < 0 ? kind : '$kind · ${diskSize(f.size)}';
}

/// The box's card of an attached file: its kind's icon, its name and its
/// kind and size, and a × that takes it out. Its tooltip says where it is,
/// or that the phone sends it to the Mac.
class FileCard extends StatelessWidget {
  const new(this.file, {required this.onRemove, super.key});

  final AttachedFile file;
  final VoidCallback onRemove;

  /// A card's least height.
  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tooltip(
          context,
          file.data != null
              ? '${plainPath(file.name)}: saved on the ${conventions.machine} '
                    'for the agent when sent'
              : plainPath(file.path),
          Container(
            constraints: const BoxConstraints(maxWidth: 240, minHeight: height),
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            decoration: BoxDecoration(
              color: t.lifted,
              borderRadius: BorderRadius.circular(NushiTheme.card),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: t.hover,
                    borderRadius: BorderRadius.circular(NushiTheme.control),
                  ),
                  child: Icon(
                    fileKindIcon(file.name),
                    size: 17,
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plainPath(file.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.text, size: 12),
                      ),
                      Text(
                        fileCardDetail(file),
                        maxLines: 1,
                        style: theme.ui(t.textMuted, size: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        RemoveBadge(onRemove),
      ],
    );
  }
}

/// A file a sent message attached, in the transcript: a small chip with its
/// kind's icon and name, in the colors of the user message's band it is
/// on. A click shows it: in the chat's preview when it is in the chat's
/// folder and the preview shows its kind ([onOpen]), else in Finder
/// ([onReveal], the Mac's).
class FileChip extends StatelessWidget {
  const new(this.path, {super.key, this.onOpen, this.onReveal});

  final String path;
  final VoidCallback? onOpen;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final ink = t.userBandText;
    // As wide as it reads: a phone's Tap fills its row otherwise.
    return IntrinsicWidth(
      child: Tap(
        tooltip: plainPath(path),
        onTap: onOpen ?? onReveal,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: t.userBandCodeBlock,
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fileKindIcon(path), size: 14, color: ink),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  plainPath(baseName(path)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(ink, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sent message's attached files as chips: those of [item]'s files its
/// text doesn't mention as @path (ADR 0091); null when there are none.
Widget? messageFiles(BuildContext context, Item item, ChatState chat) {
  final attached = [
    for (final f in item.files)
      if (!mentionsPath(item.text, f)) f,
  ];
  if (attached.isEmpty) return null;
  final open = Previews.of(context)?.open;
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final f in attached)
        FileChip(
          absoluteIn(chat.folder, f),
          onOpen: open != null && !f.startsWith('/') && opensInPreview(f)
              ? () => open(f)
              : null,
          onReveal: kIsWeb || !f.startsWith('/') && chat.folder.isEmpty
              ? null
              : () => revealInFinder(absoluteIn(chat.folder, f)).ignore(),
        ),
    ],
  );
}
