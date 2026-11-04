import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show FileUpload, Item;
import 'package:nushi/history_table.dart' show diskSize;
import 'package:nushi/images.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/skills_list.dart' show revealInFinder;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart';
import 'package:pasteboard/pasteboard.dart';

/// The first daemon that takes a file outside the chat's folder by its
/// absolute path, and a device's files whole (ADR 0091).
const attachApi = 103;

/// The most files one message attaches (the daemon's `chats.MaxUploads`).
const maxAttachedFiles = 10;

/// The most a file sent whole from the phone may weigh (`chats.MaxUpload`).
const int maxUploadBytes = 8 << 20;

/// The most the phone's files and photos may weigh together in one message
/// (a photo yet to be read counted at the most it's sent as,
/// [maxImageBytes]), so the
/// request stays under the daemon's 32 MB (`api.MaxRequest`).
const int maxUploadTotal = 20 << 20;

/// The most an image file may weigh to be read and sent as an image; a
/// larger one is a file card, under the caps of any file.
const int maxImageFileBytes = 25 << 20;

/// The most a file on the Mac may weigh: past it no agent reads one whole.
const int maxLinkedFileBytes = 100 << 20;

/// A file attached to the prompt being written, shown as a file card: one
/// on the Mac by its absolute [path], which the agent gets a link to, or
/// one from the phone with its bytes ([data]), which the daemon saves
/// first (ADR 0091). [size] is -1 when not known (a message taken back).
@immutable
class AttachedFile {
  const new({
    required this.name,
    required this.size,
    this.path = '',
    this.data,
  });

  /// The file at [path] on this Mac, its size read when it can be.
  factory at(String path) {
    var size = -1;
    if (!kIsWeb) {
      try {
        size = File(path).statSync().size;
      } on Object {
        // gone, or not readable: the agent will say
      }
    }
    return AttachedFile(name: fileName(path), size: size, path: path);
  }

  final String name;
  final int size;
  final String path;
  final Uint8List? data;

  @override
  bool operator ==(Object other) =>
      other is AttachedFile &&
      other.name == name &&
      other.path == path &&
      identical(other.data, data);

  @override
  int get hashCode => Object.hash(name, path, data);
}

/// The last part of a path.
String fileName(String path) =>
    path.substring(path.lastIndexOf('/') + 1).ifEmpty(path);

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Whether files are sent whole: the phone's, which aren't on the Mac
/// (tests set it to be the phone).
bool sendWhole = kIsWeb;

/// The open panel for any files (the phone's picker: photos and files);
/// tests put a fake in its place.
Future<List<XFile>> Function() pickFiles = () =>
    openFiles(confirmButtonText: 'Attach');

/// The clipboard's files (Finder's copy) and its image; tests put fakes in
/// their places.
Future<List<String>> Function() clipboardFiles = Pasteboard.files;
Future<Uint8List?> Function() clipboardImage = () => Pasteboard.image;

/// Attaches what ⌘V pastes beside its text: the clipboard's files, or else
/// its image when the agent takes images. Returns what wasn't attached,
/// or ''.
Future<String> pasteFiles(ChatState chat, {required int api}) =>
    chat.draft.images.track(() async {
      final paths = await clipboardFiles();
      if (paths.isNotEmpty) {
        return await attachFiles(chat, [
          for (final p in paths) XFile(p),
        ], api: api);
      }
      if (chat.canImages) {
        if (await clipboardImage() case final image?) {
          await chat.draft.images.add(image);
        }
      }
      return '';
    });

/// What a message sends of [files]: the paths (relative to [folder] for a
/// file inside it, as mentions are, else absolute) and the uploads.
(List<String>, List<FileUpload>) sendable(
  List<AttachedFile> files,
  String folder,
) {
  final paths = <String>[];
  final uploads = <FileUpload>[];
  for (final f in files) {
    if (f.data case final data?) {
      uploads.add(FileUpload(name: f.name, data: data));
    } else {
      paths.add(insideFolder(f.path, folder) ?? f.path);
    }
  }
  return (paths, uploads);
}

/// [path] relative to [folder] when it's inside it, else null.
String? insideFolder(String path, String folder) {
  final base = folder.endsWith('/') ? folder : '$folder/';
  return folder.isNotEmpty && path.startsWith(base)
      ? path.substring(base.length)
      : null;
}

/// Attaches [files] (picked, dropped or pasted) to [chat]'s draft: an image
/// as an image when the agent takes images ([Attachments]), anything else,
/// or an image it doesn't take, as a file card. The draft's [Attachments.ready]
/// waits for all of it. Returns what wasn't attached and why, or ''.
Future<String> attachFiles(
  ChatState chat,
  List<XFile> files, {
  required int api,
}) {
  final draft = chat.draft;
  return draft.images.track(() async {
    final refused = <String>[];
    for (final f in files) {
      // As the browser or the path gives it; shown only through plainPath.
      final name = f.name.isEmpty ? fileName(f.path) : f.name;
      if (chat.canImages &&
          isImageFile(name) &&
          await f.length() <= maxImageFileBytes) {
        if (sendWhole && _sent(draft) + maxImageBytes > maxUploadTotal) {
          refused.add(
            '${plainPath(name)}: a message sends '
            '${maxUploadTotal >> 20} MB at most',
          );
          continue;
        }
        try {
          await draft.images.add(await f.readAsBytes());
          continue;
        } on Object {
          // not an image Flutter reads: a file card, as any other file
        }
      }
      if (draft.files.value.length >= maxAttachedFiles) {
        refused.add('a message takes $maxAttachedFiles files at most');
        break;
      }
      final file = sendWhole
          ? await _upload(f, name, draft, api: api, refused: refused)
          : _onMac(f.path, chat.folder, api: api, refused: refused);
      if (file != null && !draft.files.value.contains(file)) {
        draft.files.value = [...draft.files.value, file];
      }
    }
    return refused.join('; ');
  });
}

/// What a phone's [draft] sends already: its files' and photos' bytes.
int _sent(Draft draft) =>
    draft.files.value.fold(0, (n, f) => n + (f.data?.length ?? 0)) +
    draft.images.value.fold(0, (n, i) => n + i.data.length);

/// A file of the phone's, its bytes read; null, with why in [refused],
/// when the daemon can't take it, or it or the [draft]'s files and photos
/// with it are too large.
Future<AttachedFile?> _upload(
  XFile f,
  String name,
  Draft draft, {
  required int api,
  required List<String> refused,
}) async {
  if (api < attachApi) {
    refused.add('the Mac’s Nushi takes photos only until it’s updated');
    return null;
  }
  final size = await f.length();
  if (size > maxUploadBytes) {
    refused.add('${plainPath(name)} is over ${maxUploadBytes >> 20} MB');
    return null;
  }
  if (_sent(draft) + size > maxUploadTotal) {
    refused.add(
      '${plainPath(name)}: a message sends ${maxUploadTotal >> 20} MB at most',
    );
    return null;
  }
  return AttachedFile(name: name, size: size, data: await f.readAsBytes());
}

/// A file on the Mac by its path; null, with why in [refused], for a
/// folder, what isn't a file, one too large, or one outside the chat's
/// folder when the daemon doesn't take those.
AttachedFile? _onMac(
  String path,
  String folder, {
  required int api,
  required List<String> refused,
}) {
  final name = plainPath(fileName(path));
  final stat = File(path).statSync();
  if (stat.type == FileSystemEntityType.directory) {
    refused.add('$name is a folder: mention one with @');
    return null;
  }
  if (stat.type != FileSystemEntityType.file) {
    refused.add('$name isn’t a file');
    return null;
  }
  if (stat.size > maxLinkedFileBytes) {
    refused.add('$name is over ${maxLinkedFileBytes >> 20} MB');
    return null;
  }
  if (api < attachApi && insideFolder(path, folder) == null) {
    refused.add('$name is outside the chat’s folder: update Nushi to send it');
    return null;
  }
  return AttachedFile(name: fileName(path), size: stat.size, path: path);
}

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
String fileDetail(AttachedFile f) {
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
        Tooltip(
          message: file.data != null
              ? '${plainPath(file.name)}: saved on the Mac for the agent '
                    'when sent'
              : plainPath(file.path),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240, minHeight: height),
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            decoration: BoxDecoration(
              color: t.raised,
              border: Border.all(color: t.borderSubtle),
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
                        style: theme.ui(t.text, size: 12.5),
                      ),
                      Text(
                        fileDetail(file),
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
/// kind's icon and name. A click shows it: in the chat's preview when it is
/// in the chat's folder and the preview shows its kind ([onOpen]), else in
/// Finder ([onReveal], the Mac's).
class FileChip extends StatelessWidget {
  const new(
    this.path, {
    super.key,
    this.onOpen,
    this.onReveal,
    this.band = true,
  });

  final String path;
  final VoidCallback? onOpen;
  final VoidCallback? onReveal;

  /// On a user message's band (its colors), not the box.
  final bool band;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final ink = band ? t.userBandText : t.text;
    // As wide as it reads: a phone's Tap fills its row otherwise.
    return IntrinsicWidth(
      child: Tap(
        tooltip: plainPath(path),
        onTap: onOpen ?? onReveal,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: band ? t.userBandBorder : t.borderSubtle),
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fileKindIcon(path), size: 14, color: ink),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  plainPath(fileName(path)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(ink, size: 12.5),
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
      if (!item.text.contains('@$f')) f,
  ];
  if (attached.isEmpty) return null;
  final open = Previews.of(context)?.open;
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final f in attached)
        FileChip(
          f.startsWith('/') ? f : '${chat.folder}/$f',
          onOpen: open != null && !f.startsWith('/') && previewKind(f) != null
              ? () => open(f)
              : null,
          onReveal: kIsWeb || !f.startsWith('/') && chat.folder.isEmpty
              ? null
              : () =>
                    revealInFinder(f.startsWith('/') ? f : '${chat.folder}/$f')
                        .ignore(),
        ),
    ],
  );
}
