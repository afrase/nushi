import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart' show ClickableImage;
import 'package:nushi/theme/theme.dart';

/// Whether [image] came as a reference (ADR 0099): its bytes are fetched
/// on their own.
bool isImageRef(ImageData image) =>
    image.data.isEmpty && image.sha256.isNotEmpty;

/// Where a view's images that came as references come from: the app's
/// [ChatImages] and the chat they are in.
typedef ImageRefs = ({ChatImages images, String chatId});

/// The images of chats that came as references (the phone asks for them:
/// ADR 0099), fetched with [fetch] as they are about to show, [parallel] at
/// a time, and kept by hash up to [maxBytes], the least recently shown
/// going first.
class ChatImages {
  new(this.fetch, {this.maxBytes = 64 << 20, this.parallel = 3});

  /// Fetches one of a chat's images by its hash (GetChatImage).
  final Future<Uint8List> Function(String chatId, String sha256) fetch;
  final int maxBytes;
  final int parallel;

  // In insertion order: the first is the least recently shown.
  final _kept = <String, MemoryImage>{};
  int _bytes = 0;
  final _jobs = <String, _Job>{};
  final _waiting = Queue<_Job>();
  int _running = 0;

  /// The image of [sha256] if it is kept, now the most recently shown.
  MemoryImage? kept(String sha256) {
    final image = _kept.remove(sha256);
    if (image != null) _kept[sha256] = image;
    return image;
  }

  /// The image of [sha256] in [chatId], kept or fetched. A fetch still
  /// waiting for its turn when no caller [wanted] it any more (their rows
  /// scrolled away) is dropped, failing with [ImageNotWanted].
  Future<MemoryImage> load(
    String chatId,
    String sha256, {
    bool Function()? wanted,
  }) {
    if (kept(sha256) case final image?) return Future.value(image);
    final job = _jobs[sha256] ??= _Job(chatId, sha256);
    job.wanted.add(wanted ?? () => true);
    if (job.wanted.length == 1) {
      _waiting.add(job);
      _next();
    }
    return job.done.future;
  }

  /// [images] with those that came as references fetched whole: to send
  /// again (a failed turn's Try again).
  Future<List<ImageData>> whole(String chatId, List<ImageData> images) =>
      Future.wait([
        for (final i in images)
          if (isImageRef(i))
            load(
              chatId,
              i.sha256,
            ).then((m) => ImageData(mimeType: i.mimeType, data: m.bytes))
          else
            Future.value(i),
      ]);

  void _next() {
    while (_running < parallel && _waiting.isNotEmpty) {
      final job = _waiting.removeFirst();
      if (!job.wanted.any((w) => w())) {
        _jobs.remove(job.sha256);
        job.done.completeError(const ImageNotWanted());
        continue;
      }
      _running++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_Job job) async {
    try {
      final image = MemoryImage(await fetch(job.chatId, job.sha256));
      _keep(job.sha256, image);
      job.done.complete(image);
    } on Object catch (e, s) {
      job.done.completeError(e, s);
    } finally {
      _jobs.remove(job.sha256);
      _running--;
      _next();
    }
  }

  void _keep(String sha256, MemoryImage image) {
    _kept[sha256] = image;
    _bytes += image.bytes.length;
    while (_bytes > maxBytes && _kept.length > 1) {
      final first = _kept.keys.first;
      _bytes -= _kept.remove(first)!.bytes.length;
    }
  }
}

/// A fetch dropped before its turn: nothing showed it any more.
class ImageNotWanted implements Exception {
  const new();
}

class _Job {
  new(this.chatId, this.sha256) {
    // A dropped or failed fetch whose rows went away has no one listening.
    done.future.ignore();
  }

  final String chatId;
  final String sha256;
  final wanted = <bool Function()>[];
  final done = Completer<MemoryImage>();
}

/// One of a chat's images that came as a reference, [size] tall at most
/// as [ClickableImage]: while it comes, a box of its size with a spinner;
/// if it fails, a box that says so with Try again.
class ImageRef extends StatefulWidget {
  const new(this.images, this.chatId, this.image, {super.key, this.size = 64});

  final ChatImages images;
  final String chatId;
  final ImageData image;
  final double size;

  @override
  State<ImageRef> createState() => _ImageRefState();
}

class _ImageRefState extends State<ImageRef> {
  MemoryImage? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ImageRef old) {
    super.didUpdateWidget(old);
    if (old.image.sha256 != widget.image.sha256) {
      _image = null;
      _load();
    }
  }

  void _load() {
    final sha = widget.image.sha256;
    _failed = false;
    _image = widget.images.kept(sha);
    if (_image != null) return;
    unawaited(
      widget.images
          .load(widget.chatId, sha, wanted: () => mounted)
          .then(
            (image) {
              if (mounted && widget.image.sha256 == sha) {
                setState(() => _image = image);
              }
            },
            onError: (Object e) {
              if (mounted &&
                  widget.image.sha256 == sha &&
                  e is! ImageNotWanted) {
                setState(() => _failed = true);
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_image case final image?) {
      final t = NushiTheme.of(context).t;
      return ClickableImage(
        image: image,
        size: widget.size,
        border: t.borderSubtle,
      );
    }
    return _box(context);
  }

  /// The image's place: its size when the daemon said it, else a square.
  Widget _box(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final size = widget.size;
    final (w, h) = (widget.image.width, widget.image.height);
    final ratio = w > 0 && h > 0 ? w / h : 1.0;
    final small = size < 120;
    final Widget inside;
    if (!_failed) {
      inside = SizedBox.square(
        key: const ValueKey('image-loading'),
        dimension: small ? 20 : 28,
        child: CircularProgressIndicator(
          strokeWidth: small ? 2 : 3,
          color: t.textSecondary,
        ),
      );
    } else {
      final said = Text(
        'Couldn’t load the image',
        textAlign: TextAlign.center,
        style: theme.ui(t.text, size: small ? 12 : 13),
      );
      final again = Button(
        label: 'Try again',
        onPressed: () => setState(_load),
      );
      final icon = Icon(
        Icons.broken_image_outlined,
        size: small ? 16 : 24,
        color: t.crashed,
      );
      inside = small
          ? Row(
              key: const ValueKey('image-failed'),
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                icon,
                Flexible(child: said),
                again,
              ],
            )
          : Column(
              key: const ValueKey('image-failed'),
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [icon, said, again],
            );
    }
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: t.selected,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(child: inside),
      ),
    );
    // A failure in a small thumbnail's place needs the room for its words.
    if (_failed && small) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: size),
        child: IntrinsicWidth(child: box),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: size, maxWidth: size * 4),
      child: AspectRatio(aspectRatio: ratio, child: box),
    );
  }
}
