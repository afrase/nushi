import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:nushi/chat.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show FileUpload;
import 'package:nushi/images.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart';

/// The first daemon that takes a file outside the chat's folder by its
/// absolute path, and a device's files whole (ADR 0091).
const attachApi = 106;

/// The most files one message attaches (the daemon's `chats.MaxUploads`).
const maxAttachedFiles = 10;

/// The most a file sent whole from the phone may weigh (`chats.MaxUpload`).
const int maxUploadBytes = 8 << 20;

/// The most a message's images and the phone's files may weigh together (a
/// photo yet to be read counted at the most it's sent as, [maxImageBytes]),
/// on the Mac too, whose images go as bytes as well: the request stays
/// under the daemon's 32 MB (`api.MaxRequest`) and the images under what
/// the agent takes in one message (about 22 MB for Claude's).
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
    return AttachedFile(name: baseName(path), size: size, path: path);
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

/// Whether files are sent whole: the phone's, which aren't on the Mac
/// (tests set it to be the phone).
bool sendWhole = kIsWeb;

/// The open panel for any files (the phone's picker: photos and files);
/// tests put a fake in its place.
Future<List<XFile>> Function() pickFiles = () =>
    openFiles(confirmButtonText: 'Attach');

/// The Mac's clipboard for what ⌘V attaches (`macos/Runner/Clipboard.swift`).
const _clipboard = MethodChannel('nushi/clipboard');

/// The clipboard's files (Finder's copy: file URLs only, not a copied web
/// link) and its picture as PNG (none when it holds text too: cells copied
/// from Numbers carry a PDF of themselves); tests put fakes in their places.
Future<List<String>> Function() clipboardFiles = () async =>
    await _clipboard.invokeListMethod<String>('files') ?? [];
Future<Uint8List?> Function() clipboardImage = () =>
    _clipboard.invokeMethod<Uint8List>('image');

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
          if (_sent(chat.draft) + maxImageBytes > maxUploadTotal) {
            return 'the picture pasted: $_tooMuch';
          }
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

/// Whether [text] mentions [path] as `@path`: the whole path, not the
/// start of a longer one (`@notes.md.orig` isn't notes.md), so a file
/// attached as a card isn't taken for a mention and dropped. Only what
/// could go on a path ends it there (a letter or digit, `_`, `-`, `/`, a
/// `.` before one of the first three); anything else after it (CJK text,
/// Markdown's backticks, a dash) leaves a mention picked from @ in place.
bool mentionsPath(String text, String path) {
  final at = '@$path';
  for (var i = text.indexOf(at); i >= 0; i = text.indexOf(at, i + 1)) {
    if (!text.startsWith(_goesOn, i + at.length)) return true;
  }
  return false;
}

final _goesOn = RegExp(r'[A-Za-z0-9_\-/]|\.[A-Za-z0-9_\-]');

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
      final name = f.name.isEmpty ? baseName(f.path) : f.name;
      if (chat.canImages &&
          isImageFile(name) &&
          await f.length() <= maxImageFileBytes) {
        if (_sent(draft) + maxImageBytes > maxUploadTotal) {
          refused.add('${plainPath(name)}: $_tooMuch');
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

/// Waits for [attaching] ([attachFiles], [pasteFiles]), saying over
/// [context] what it didn't attach and why.
Future<void> attached(BuildContext context, Future<String> attaching) async {
  try {
    final refused = await attaching;
    if (refused.isNotEmpty && context.mounted) {
      showError(context, 'Not attached: $refused');
    }
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
  }
}

/// Why an image or a phone's file is refused past [maxUploadTotal].
const _tooMuch = 'a message sends ${maxUploadTotal >> 20} MB at most';

/// What [draft] sends already: its images' bytes and a phone's files'.
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
    refused.add('${plainPath(name)}: $_tooMuch');
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
  final name = plainPath(baseName(path));
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
  return AttachedFile(name: baseName(path), size: stat.size, path: path);
}
