import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nushi/chat_images.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/image_ref.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The longest side an attached image keeps; larger ones are scaled down
/// (Claude scales images past about 1,568 pixels down anyway).
const maxImageSide = 1568;

/// The most an attached image may weigh once encoded; the API's limit is
/// 5 MB of base64.
const maxImageBytes = 3750000;

/// The decoded pixels the Mac's image cache keeps of images no longer
/// shown (Flutter's default is 100 MB): a chat's thumbnails are decoded at
/// the size they show, about 1.5 MB a screenshot, so this keeps a few
/// screens of them to scroll back to; further back they decode again from
/// the bytes `ChatImages` keeps, or come again from the daemon.
const int imageCacheBytes = 64 << 20;

/// Holds the image cache to [imageCacheBytes]: the Mac's app does as it
/// starts.
void limitImageCache() =>
    PaintingBinding.instance.imageCache.maximumSizeBytes = imageCacheBytes;

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
/// [prepare] ([prepareImage]), which takes a moment: [ready] waits for them,
/// and for whatever else is still being attached ([track]).
class Attachments extends ValueNotifier<List<ImageData>> {
  new({this.prepare = prepareImage}) : super(const []);

  final Future<ImageData> Function(Uint8List) prepare;
  int _preparing = 0;
  Completer<void>? _idle;

  /// Runs [work], which attaches something (reads a file or the clipboard,
  /// then adds it): [ready] waits for all of it, the reads too, so a
  /// message sent meanwhile goes with what it attaches.
  Future<T> track<T>(Future<T> Function() work) async {
    _preparing++;
    try {
      return await work();
    } finally {
      if (--_preparing == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  /// Adds an image once it is prepared, to the images there are then.
  Future<void> add(Uint8List bytes) => track(() async {
    final image = await prepare(bytes);
    value = [...value, image];
  });

  /// Done once nothing is still being attached.
  Future<void> ready() =>
      _preparing == 0 ? Future.value() : (_idle ??= Completer()).future;

  void removeAt(int i) => value = [...value]..removeAt(i);

  void clear() => value = const [];
}

/// Shows an image large, over the window; a click or Escape closes it.
void showImagePreview(BuildContext context, ImageProvider image) =>
    showDialog<void>(
      context: context,
      barrierColor: NushiTheme.of(context).t.scrim,
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
/// each has a button that removes it. An image that came as a reference
/// (ADR 0099) is fetched from [refs]'s chat as it shows ([ImageRef]).
class Thumbnails extends StatelessWidget {
  const new(this.images, {super.key, this.onRemove, this.size = 64, this.refs});

  final List<ImageData> images;
  final void Function(int index)? onRemove;
  final double size;
  final ImageRefs? refs;

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
              if ((refs, isImageRef(img)) case (final refs?, true))
                ImageRef(refs.images, refs.chatId, img, size: size)
              else
                ClickableImage(
                  image: _provider[img] ??= MemoryImage(bytesOf(img.data)),
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
class ClickableImage extends StatelessWidget {
  const new({
    required this.image,
    required this.size,
    super.key,
    this.border,
    this.waiting,
  });

  final ImageProvider image;
  final double size;
  final Color? border;

  /// What shows in its place until the image decodes: an image has no size
  /// before, so a row in a list would shrink to its border and grow back,
  /// moving what is below it.
  final Widget? waiting;

  @override
  Widget build(BuildContext context) {
    Widget framed(Widget child) => MouseRegion(
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
          child: child,
        ),
      ),
    );
    return Image(
      // Decoded at the size shown; the preview has it whole.
      image: ResizeImage(
        image,
        height: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        policy: ResizeImagePolicy.fit,
      ),
      gaplessPlayback: true,
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, _) =>
          frame == null && waiting != null ? waiting! : framed(child),
      errorBuilder: (context, _, _) => framed(const Icon(Icons.broken_image)),
    );
  }
}

/// The largest local file a markdown image reads.
const int maxImageFile = 20 << 20;

/// Whether a markdown image may read the file at a path: a regular file of
/// [maxImageFile] at most, never a device or a pipe. Asked off the UI
/// thread: a path from an agent's text can be on a network volume that
/// takes long to answer.
Future<bool> Function(String path) readableImage = (path) async {
  try {
    // Async on purpose: statSync on the UI thread froze the window on a
    // network volume that didn't answer.
    // ignore: avoid_slow_async_io
    final stat = await File(path).stat();
    return stat.type == FileSystemEntityType.file && stat.size <= maxImageFile;
  } on Object {
    return false;
  }
};

/// A markdown image: a local file (an absolute path or a file: URL;
/// [readableImage] says which) shows once checked, a data: URL at once; a
/// remote one only after "Load image", since loading it tells its server
/// that, and when, the reply was read.
Widget markdownImage(Uri uri, String? alt) {
  if (uri.scheme == 'data') {
    final bytes = uri.data?.contentAsBytes();
    if (bytes != null) {
      return ClickableImage(image: MemoryImage(bytes), size: 320);
    }
  }
  if (uri.scheme == 'file' ||
      (uri.scheme.isEmpty && uri.path.startsWith('/'))) {
    // Only a plain path: a host, a query or an encoded slash (/a%2Fb.png)
    // isn't a local file (and toFilePath throws on them, which would break
    // the whole message).
    final local =
        uri.host.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        !uri.pathSegments.any((s) => s.contains('/'));
    if (local && !kIsWeb) {
      return _LocalImage(uri.toFilePath(), '[image: ${alt ?? uri}');
    }
    return Text('[image: ${alt ?? uri} (not an image file Nushi reads)]');
  }
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    // The phone's web app loads nothing from other origins (its CSP).
    if (kIsWeb) return Text('[image: ${alt ?? uri}]');
    return _RemoteImage(uri, alt);
  }
  return Text('[image: ${alt ?? uri}]');
}

/// A local file as a markdown image, once [readableImage] said it may be
/// read; until then, room for it.
class _LocalImage extends StatefulWidget {
  const new(this.path, this.said);

  final String path;
  final String said; // "[image: <alt>", for a file it doesn't read

  @override
  State<_LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<_LocalImage> {
  late Future<bool> _readable = readableImage(widget.path);

  @override
  void didUpdateWidget(_LocalImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _readable = readableImage(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _readable,
    builder: (context, snap) => switch (snap.data) {
      null => const SizedBox(width: 320, height: 24),
      true => ClickableImage(image: FileImage(File(widget.path)), size: 320),
      false => Text('${widget.said} (not an image file Nushi reads)]'),
    },
  );
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
      return ClickableImage(
        image: NetworkImage(widget.uri.toString()),
        size: 320,
      );
    }
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
            Button(
              label: 'Load image',
              onPressed: () => setState(() => _load = true),
            ),
          ],
        ),
      ),
    );
  }
}
