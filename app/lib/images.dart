import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The longest side an attached image keeps; larger ones are scaled down
/// (Claude scales images past about 1,568 pixels down anyway).
const maxImageSide = 1568;

/// The most an attached image may weigh once encoded; the API's limit is
/// 5 MB of base64.
const maxImageBytes = 3750000;

/// The image types sent as they are; others are turned into PNG.
String? _mimeType(Uint8List b) => switch (b) {
  [0x89, 0x50, 0x4E, 0x47, ...] => 'image/png',
  [0xFF, 0xD8, 0xFF, ...] => 'image/jpeg',
  [0x47, 0x49, 0x46, 0x38, ...] => 'image/gif',
  [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ...] =>
    'image/webp',
  _ => null,
};

/// An image to attach to a prompt: as it is when it's a PNG, JPEG, GIF or
/// WebP within [maxImageSide] and [maxImageBytes], else scaled down and
/// encoded as PNG. Throws if [bytes] isn't an image Flutter can decode.
Future<ImageData> prepareImage(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final (w, h) = (descriptor.width, descriptor.height);
  final mime = _mimeType(bytes);
  if (mime != null &&
      w <= maxImageSide &&
      h <= maxImageSide &&
      bytes.length <= maxImageBytes) {
    descriptor.dispose();
    return ImageData(mimeType: mime, data: bytes);
  }
  var scale = maxImageSide / (w > h ? w : h);
  if (scale > 1) scale = 1;
  while (true) {
    final codec = await descriptor.instantiateCodec(
      targetWidth: (w * scale).round(),
      targetHeight: (h * scale).round(),
    );
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final out = png!.buffer.asUint8List();
    if (out.length <= maxImageBytes || scale < 0.1) {
      descriptor.dispose();
      return ImageData(mimeType: 'image/png', data: out);
    }
    scale *= 0.75;
  }
}

/// The file types an image can be attached from.
const _imageTypes = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

/// Whether a file's name says it's an image that can be attached.
bool isImageFile(String path) =>
    _imageTypes.contains(path.split('.').last.toLowerCase());

/// The images attached to the prompt being written, each prepared with
/// [prepare] ([prepareImage]), which takes a moment: [ready] waits for them.
class Attachments extends ValueNotifier<List<ImageData>> {
  new({this.prepare = prepareImage}) : super(const []);

  final Future<ImageData> Function(Uint8List) prepare;
  int _preparing = 0;
  Completer<void>? _idle;

  /// Adds an image once it is prepared, to the images there are then.
  Future<void> add(Uint8List bytes) async {
    _preparing++;
    try {
      final image = await prepare(bytes);
      value = [...value, image];
    } finally {
      if (--_preparing == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  /// Done once no image is still being prepared.
  Future<void> ready() =>
      _preparing == 0 ? Future.value() : (_idle ??= Completer()).future;

  /// Attaches the image files among [paths].
  Future<void> addFiles(Iterable<String> paths) async {
    for (final p in paths.where(isImageFile)) {
      await add(await File(p).readAsBytes());
    }
  }

  void removeAt(int i) => value = [...value]..removeAt(i);

  void clear() => value = const [];

  /// Attaches the clipboard's image files, or else its image; false if it
  /// has neither.
  Future<bool> paste() async {
    final files = (await Pasteboard.files()).where(isImageFile).toList();
    if (files.isNotEmpty) {
      await addFiles(files);
      return true;
    }
    final image = await Pasteboard.image;
    if (image != null) await add(image);
    return image != null;
  }

  /// Attaches images picked in an open panel.
  Future<void> pick() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Images', extensions: _imageTypes),
      ],
      confirmButtonText: 'Attach',
    );
    await addFiles(files.map((f) => f.path));
  }
}

/// Shows an image large, over the window; a click or Escape closes it.
void showImagePreview(BuildContext context, ImageProvider image) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Image(image: image, fit: BoxFit.contain),
          ),
        ),
      ),
    );

/// Small thumbnails of images; a click shows one large. With [onRemove]
/// each has a button that removes it.
class Thumbnails extends StatelessWidget {
  const new(this.images, {super.key, this.onRemove, this.size = 64});

  final List<ImageData> images;
  final void Function(int index)? onRemove;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, img) in images.indexed)
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Clickable(
                image: _provider[img] ??= MemoryImage(
                  Uint8List.fromList(img.data),
                ),
                size: size,
                border: t.borderSubtle,
              ),
              if (onRemove != null) RemoveBadge(() => onRemove!(i)),
            ],
          ),
      ],
    );
  }
}

/// Each attachment's image, decoded once (the box rebuilds as replies stream).
final _provider = Expando<ImageProvider>();

/// The small round × on an attachment's top right corner, in a [Stack].
class RemoveBadge extends StatelessWidget {
  const new(this.onTap, {super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Positioned(
      top: -6,
      right: -6,
      child: Tap(
        tooltip: 'Remove',
        onTap: onTap,
        radius: 9,
        child: CircleAvatar(
          radius: 9,
          backgroundColor: t.borderStrong,
          child: Icon(Icons.close, size: 12, color: t.text),
        ),
      ),
    );
  }
}

/// An image that shows large when clicked, [size] tall at most.
class _Clickable extends StatelessWidget {
  const new({required this.image, required this.size, this.border});

  final ImageProvider image;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.zoomIn,
    child: GestureDetector(
      onTap: () => showImagePreview(context, image),
      child: Container(
        constraints: BoxConstraints(maxHeight: size, maxWidth: size * 4),
        decoration: BoxDecoration(
          border: border == null ? null : Border.all(color: border!),
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image(
          // Decoded at the size shown; the preview has it whole.
          image: ResizeImage(
            image,
            height: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            policy: ResizeImagePolicy.fit,
          ),
          gaplessPlayback: true,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => const Icon(Icons.broken_image),
        ),
      ),
    ),
  );
}

/// The largest local file a markdown image reads.
const int maxImageFile = 20 << 20;

/// A markdown image: a local file (an absolute path or a file: URL; a
/// regular file of [maxImageFile] at most, never a device or a pipe) or a
/// data: URL shows at once; a remote one only after "Load image", since
/// loading it tells its server that, and when, the reply was read.
Widget markdownImage(Uri uri, String? alt) {
  if (uri.scheme == 'data') {
    final bytes = uri.data?.contentAsBytes();
    if (bytes != null) return _Clickable(image: MemoryImage(bytes), size: 320);
  }
  if (uri.scheme == 'file' ||
      (uri.scheme.isEmpty && uri.path.startsWith('/'))) {
    // Only a plain path: a host or a query isn't a local file (and
    // toFilePath throws on them, which would break the whole message).
    final local = uri.host.isEmpty && !uri.hasQuery && !uri.hasFragment;
    try {
      final file = File(uri.toFilePath());
      final stat = file.statSync();
      if (local &&
          stat.type == FileSystemEntityType.file &&
          stat.size <= maxImageFile) {
        return _Clickable(image: FileImage(file), size: 320);
      }
    } on Object {
      // not a file Nushi reads
    }
    return Text('[image: ${alt ?? uri} (not an image file Nushi reads)]');
  }
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return _RemoteImage(uri, alt);
  }
  return Text('[image: ${alt ?? uri}]');
}

class _RemoteImage extends StatefulWidget {
  const new(this.uri, this.alt);

  final Uri uri;
  final String? alt;

  @override
  State<_RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<_RemoteImage> {
  bool _load = false;

  @override
  Widget build(BuildContext context) {
    if (_load) {
      return _Clickable(image: NetworkImage(widget.uri.toString()), size: 320);
    }
    final theme = NushiTheme.of(context), t = theme.t;
    final alt = widget.alt;
    return Tooltip(
      message: widget.uri.toString(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: box(t.borderSubtle, radius: NushiTheme.control),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 14, color: t.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                alt == null || alt.isEmpty ? widget.uri.host : alt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
            const SizedBox(width: 8),
            Tap(
              onTap: () => setState(() => _load = true),
              child: Text('Load image', style: theme.ui(t.link, size: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
