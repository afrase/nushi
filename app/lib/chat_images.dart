import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart' show ClickableImage;
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';

/// Whether [image] came as a reference (ADR 0099): its bytes are fetched
/// on their own.
bool isImageRef(ImageData image) =>
    image.data.isEmpty && image.sha256.isNotEmpty;

/// The size above which the daemon sends an image as a reference (the
/// daemon's `refAbove`, ADR 0099): smaller ones always come inline.
const int refAbove = 64 << 10;

/// [data] as a [Uint8List] without copying it when it is one already, as
/// protobuf's bytes are: a screenshot isn't held twice.
Uint8List bytesOf(List<int> data) =>
    data is Uint8List ? data : Uint8List.fromList(data);

/// The lowercase hex SHA-256 of [bytes], as the daemon names an image that
/// came as a reference. Hashed a slice at a time, letting frames through
/// between them: a screenshot takes a while in the phone's browser.
Future<String> imageHash(List<int> bytes) async {
  const slice = 256 << 10;
  final data = bytesOf(bytes);
  final digest = _Digest();
  final hash = sha256.startChunkedConversion(digest);
  for (var at = 0; at < data.length; at += slice) {
    if (at > 0) await Future<void>.delayed(Duration.zero);
    final end = at + slice < data.length ? at + slice : data.length;
    hash.add(Uint8List.sublistView(data, at, end));
  }
  hash.close();
  return digest.value.toString();
}

class _Digest implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Where a view's images that came as references come from: the app's
/// [ChatImages] and the chat they are in.
typedef ImageRefs = ({ChatImages images, String chatId});

/// The images of chats that came as references (ADR 0099), fetched with
/// [fetch] as they are about to show, [parallel] at a time, and kept by
/// hash up to [maxBytes], the least recently shown going first.
class ChatImages {
  new(
    this.fetch, {
    this.maxBytes = 64 << 20,
    this.parallel = 3,
    this.local = false,
  });

  /// Fetches one of a chat's images by its hash (GetChatImage).
  final Future<Uint8List> Function(String chatId, String sha256) fetch;
  final int maxBytes;
  final int parallel;

  /// Whether a fetch is cheap, the daemon on this machine (the Mac's): a
  /// row lets its image go once it is far off the screen, so the decoded
  /// pixels of a long chat's images aren't all held while it shows, and
  /// takes it back from here, or fetches it again, as it comes near. The
  /// phone's rows hold theirs: a fetch again goes over the relay.
  final bool local;

  // In insertion order: the first is the least recently shown.
  final _kept = <String, MemoryImage>{};
  int _bytes = 0;
  // The [hold]s of each kept image not shown yet.
  final _held = <String, int>{};
  final _jobs = <String, _Job>{};
  final _waiting = Queue<_Job>();
  int _running = 0;

  /// The bytes of the images it keeps now.
  int get bytes => _bytes;

  /// The image of [sha256] if it is kept, now the most recently shown.
  MemoryImage? kept(String sha256) {
    final image = _kept.remove(sha256);
    if (image != null) _kept[sha256] = image;
    return image;
  }

  /// Keeps [bytes] as the image of [sha256], which this app has already
  /// (it sent them): shown at once, not fetched. Not if it is kept or on
  /// its way already (a fetch brings it); whether it was put.
  bool put(String sha256, Uint8List bytes) {
    if (kept(sha256) != null || _jobs.containsKey(sha256)) return false;
    _keep(sha256, MemoryImage(bytes));
    return true;
  }

  /// Keeps [bytes] as the image of [sha256] for a queued message that will
  /// show it when it runs, counted: each hold takes a [release] or, once
  /// the image shows, [shown]. Those kept already for what showed stay as
  /// they are, and one on its way comes as fetched.
  void hold(String sha256, Uint8List bytes) {
    if (_held[sha256] case final n?) {
      _held[sha256] = n + 1;
    } else if (put(sha256, bytes)) {
      _held[sha256] = 1;
    }
  }

  /// Whether any image is held for a queued message.
  bool get holding => _held.isNotEmpty;

  /// Lets go of a [hold] for a message that won't run (taken out of the
  /// queue): its image goes with the last.
  void release(String sha256) {
    switch (_held[sha256]) {
      case null:
        return;
      case 1:
        _held.remove(sha256);
        forget(sha256);
      case final n:
        _held[sha256] = n - 1;
    }
  }

  /// The image of [sha256] showed (a message ran with it): kept as any
  /// other, what held it no longer counted.
  void shown(String sha256) => _held.remove(sha256);

  /// Lets the image of [sha256] go.
  void forget(String sha256) {
    if (_kept.remove(sha256) case final image?) _bytes -= image.bytes.length;
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
    forget(sha256); // counted once, whatever kept it before
    _kept[sha256] = image;
    _bytes += image.bytes.length;
    while (_bytes > maxBytes && _kept.length > 1) {
      final first = _kept.keys.first;
      _bytes -= _kept.remove(first)!.bytes.length;
      _held.remove(first);
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

  /// The size it showed at before it let its image go ([ChatImages.local]):
  /// its place keeps it, so nothing above the screen moves.
  Size? _was;

  /// Asked for: on its way, or waiting for its turn.
  bool _asked = false;

  /// The list it scrolls in, watched until it comes near the screen.
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (position != _position) {
      _position?.removeListener(_look);
      _position = position?..addListener(_look);
    }
  }

  @override
  void didUpdateWidget(ImageRef old) {
    super.didUpdateWidget(old);
    if (old.image.sha256 != widget.image.sha256) _start();
  }

  @override
  void dispose() {
    _position?.removeListener(_look);
    super.dispose();
  }

  /// Shows the image if it's kept, else fetches it once it is near the
  /// screen (looked at after this frame, once it has its place).
  void _start() {
    _failed = _asked = false;
    _was = null;
    _image = widget.images.kept(widget.image.sha256);
    if (_image == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _look();
      });
    }
  }

  /// Whether it is on the screen or within a screen of it. The transcript
  /// lays every item out (transcript.dart), so being built isn't enough:
  /// a chat's images are fetched as it scrolls to them (ADR 0099). Outside
  /// a scrolling list it shows, so it's near.
  bool get _near {
    if (!mounted) return false;
    if (_position == null) return true;
    final w = _where;
    return w != null && w.bottom > -w.screen && w.top < 2 * w.screen;
  }

  /// Whether it is more than two screens off: a screen past [_near], so a
  /// row near the edge doesn't let go and take back in turn.
  bool get _far {
    final w = mounted ? _where : null;
    return w != null && (w.bottom < -2 * w.screen || w.top > 3 * w.screen);
  }

  /// Its top and bottom in the list it scrolls in, and the list's height,
  /// as last laid out; null until both are.
  ({double top, double bottom, double screen})? get _where {
    final box = context.findRenderObject();
    final list = _position?.context.notificationContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || list is! RenderBox) return null;
    if (!box.attached || !list.attached || !list.hasSize) return null;
    final top = box.localToGlobal(Offset.zero, ancestor: list).dy;
    return (top: top, bottom: top + box.size.height, screen: list.size.height);
  }

  void _look() {
    if (_image == null) {
      if (!_asked && !_failed && _near) _load();
    } else if (widget.images.local && _far) {
      // After this task: the list can move while it's laid out.
      scheduleMicrotask(_letGo);
    }
  }

  /// Lets its image go, far off the screen ([ChatImages.local]), keeping
  /// its size; [_look] takes it back as it comes near.
  void _letGo() {
    if (_image == null || !_far) return;
    setState(() {
      _was = (context.findRenderObject()! as RenderBox).size;
      _image = null;
      _asked = false;
    });
  }

  void _load() {
    final sha = widget.image.sha256;
    _asked = true;
    unawaited(
      widget.images
          .load(widget.chatId, sha, wanted: () => _near)
          .then(
            (image) {
              if (mounted && widget.image.sha256 == sha) {
                setState(() => _image = image);
              }
            },
            onError: (Object e) {
              if (!mounted || widget.image.sha256 != sha) return;
              // Dropped while it waited, scrolled away: asked again when
              // it comes near.
              if (e is ImageNotWanted) {
                _asked = false;
              } else {
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
      final shown = ClickableImage(
        image: image,
        size: widget.size,
        border: t.borderSubtle,
      );
      // Taken back after it let go: its room kept while it decodes again.
      if (_was case final was?) {
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: was.height),
          child: shown,
        );
      }
      return shown;
    }
    return _box(context);
  }

  /// The image's place: the size it showed at if it let its image go
  /// (failing, the room its words need), else [_waiting]'s.
  Widget _box(BuildContext context) {
    if (_was case final size? when !_failed) {
      return SizedBox.fromSize(size: size, child: _waiting(context));
    }
    return _waiting(context);
  }

  /// A box of the image's size when the daemon said it, else a square,
  /// with a spinner while it comes or the failure with Try again.
  Widget _waiting(BuildContext context) {
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
        child: Spinner(strokeWidth: small ? 2 : 3, color: t.textSecondary),
      );
    } else {
      final said = Text(
        'Couldn’t load the image',
        textAlign: TextAlign.center,
        style: theme.ui(t.text, size: small ? 12 : 13),
      );
      final again = Button(
        label: 'Try again',
        onPressed: () => setState(() {
          _failed = false;
          _load();
        }),
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
