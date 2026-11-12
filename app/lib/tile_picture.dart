import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/tile_images.dart';

/// A tile's own image: Nushi's stored copy by its name, or one just picked
/// in Change tile…, not kept yet.
class TilePicture {
  /// The stored image called [name] (`TileLook.image`).
  const new stored(String name) : key = name, _bytes = null;

  /// [bytes] picked and found good, under a [key] of its own.
  const new picked(this.key, Uint8List bytes) : _bytes = bytes;

  /// What tells it from every other picture.
  final String key;
  final Uint8List? _bytes;

  /// Its file's bytes: read when it's decoded, and again each time it
  /// plays, so none of a stored image's file stays in memory at rest.
  Future<Uint8List> read() async =>
      _bytes ?? await tileImageFile(key)!.readAsBytes();
}

/// A picture's first frame at one size, and whether it has more.
typedef _First = ({ui.Image image, bool animated});

/// The first frames decoded so far, by picture and size in pixels, so a
/// tile built again (a list that rebuilds) shows its image at once. Small:
/// each is a tile's size. One goes when its picture does ([forgetPicture]).
final _firsts = <String, _First>{};
final _decoding = <String, Future<_First?>>{};

/// Lets go of what's kept of the picture called [key]: its stored image
/// was deleted, or the dialog that picked it closed.
void forgetPicture(String key) {
  _firsts.removeWhere((k, _) => k.startsWith('$key@'));
}

/// [picture] in a tile [size] square: decoded at that size in the screen's
/// pixels, never its own, cropped to the square from its middle, on [fill]
/// where it's see-through, its corners [radius]. Until it's decoded, and
/// if it can't be, [fallback].
///
/// A GIF or an animated WebP shows its first frame, and plays, looping,
/// only while the pointer is over the tile: not under Reduce Motion, and
/// not while Nushi isn't in front ([appInFront]). At rest there is no
/// timer, ticker or listener, and no codec: an image that played always
/// would keep the window drawing frames for as long as it showed (ADR
/// 0112). It's a layer of its own, so a playing one repaints only itself.
class TilePictureView extends StatefulWidget {
  const new({
    required this.picture,
    required this.size,
    required this.radius,
    required this.fill,
    required this.fallback,
    super.key,
  });

  final TilePicture picture;
  final double size;
  final double radius;
  final Color fill;
  final Widget fallback;

  @override
  State<TilePictureView> createState() => TilePictureViewState();
}

/// The state of a [TilePictureView]; a test reads where its playing is.
class TilePictureViewState extends State<TilePictureView> {
  int _side = 0; // the tile's side in the screen's pixels
  _First? _first;
  bool _hover = false;

  // While it plays: the codec, the frame shown, the wait for the next,
  // and the watch on Nushi leaving the front.
  ui.Codec? _codec;
  ui.Image? _frame;
  Timer? _next;
  AppLifecycleListener? _front;
  int _run = 0; // which start of playing is the current one
  bool _opening = false; // its file is being read to play

  /// How many frames it has shown since it last started playing; 0 at
  /// rest, where it shows the first.
  @visibleForTesting
  int played = 0;

  /// Whether its picture's first frame is here.
  @visibleForTesting
  bool get decoded => _first != null;

  /// Whether its picture is decoded and has more than one frame.
  @visibleForTesting
  bool get animated => _first?.animated ?? false;

  /// Whether anything of its playing exists: nothing does at rest.
  @visibleForTesting
  bool get busy =>
      _opening || _codec != null || _next != null || _front != null;

  String get _key => '${widget.picture.key}@$_side';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final side = (widget.size * MediaQuery.devicePixelRatioOf(context)).ceil();
    if (side != _side) {
      _side = side;
      _load();
    }
  }

  @override
  void didUpdateWidget(TilePictureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final side = (widget.size * MediaQuery.devicePixelRatioOf(context)).ceil();
    if (oldWidget.picture.key != widget.picture.key || side != _side) {
      _side = side;
      _stop();
      _load();
    }
  }

  @override
  void dispose() {
    _stop(tell: false);
    super.dispose();
  }

  void _load() {
    final key = _key;
    _first = _firsts[key];
    if (_first != null) return;
    final picture = widget.picture;
    final side = _side;
    final decoded = _decoding[key] ??= _decodeFirst(picture, side);
    unawaited(
      decoded.then((first) {
        unawaited(_decoding.remove(key));
        if (first != null) _firsts[key] = first;
        if (!mounted || key != _key) return;
        setState(() => _first = first);
        if (_hover) _start();
      }),
    );
  }

  static Future<_First?> _decodeFirst(TilePicture picture, int side) async {
    try {
      final codec = await tileImageCodec(await picture.read(), side);
      final frame = await codec.getNextFrame();
      final animated = codec.frameCount > 1;
      codec.dispose();
      return (image: frame.image, animated: animated);
    } on Object {
      return null; // gone, or not an image after all: the fallback
    }
  }

  void _enter() {
    _hover = true;
    _start();
  }

  void _leave() {
    _hover = false;
    _stop();
  }

  /// Plays, if it's animated, the pointer is on it, motion is wanted and
  /// Nushi is in front; while the pointer stays, it watches for Nushi
  /// leaving the front and coming back.
  void _start() {
    if (!mounted || !_hover || !animated || reduceMotion(context)) return;
    _front ??= AppLifecycleListener(
      onStateChange: (_) => appInFront ? _start() : _pause(),
    );
    if (!appInFront || _opening || _codec != null || _next != null) return;
    unawaited(_open(++_run));
  }

  /// Opens the picture's file again and shows its frames in turn.
  Future<void> _open(int run) async {
    _opening = true;
    try {
      final codec = await tileImageCodec(await widget.picture.read(), _side);
      _opening = false;
      if (run != _run || !mounted) return codec.dispose();
      _codec = codec;
      await _advance(run);
    } on Object {
      _opening = false;
      if (run == _run) _pause();
    }
  }

  Future<void> _advance(int run) async {
    final codec = _codec;
    if (codec == null) return;
    final ui.FrameInfo frame;
    try {
      frame = await codec.getNextFrame();
    } on Object {
      if (run == _run) _pause();
      return;
    }
    if (run != _run || !mounted) return frame.image.dispose();
    final before = _frame;
    setState(() {
      _frame = frame.image;
      played++;
    });
    before?.dispose();
    // A file that says no time, or next to none, means a tenth of a
    // second, as browsers take it.
    final wait = frame.duration < const Duration(milliseconds: 20)
        ? const Duration(milliseconds: 100)
        : frame.duration;
    _next = Timer(wait, () => unawaited(_advance(run)));
  }

  /// Stops playing and shows the first frame; the watch stays while the
  /// pointer does.
  void _pause() {
    _run++;
    _next?.cancel();
    _next = null;
    _codec?.dispose();
    _codec = null;
    final frame = _frame;
    _frame = null;
    if (frame == null && played == 0) return;
    played = 0;
    if (mounted) setState(() {});
    // After the frame that stops showing it.
    WidgetsBinding.instance.addPostFrameCallback((_) => frame?.dispose());
  }

  /// Ends everything of its playing.
  void _stop({bool tell = true}) {
    _front?.dispose();
    _front = null;
    if (tell) return _pause();
    _run++;
    _next?.cancel();
    _next = null;
    _codec?.dispose();
    _codec = null;
    _frame?.dispose();
    _frame = null;
  }

  @override
  Widget build(BuildContext context) {
    final first = _first;
    if (first == null) return widget.fallback;
    final image = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox.square(
          dimension: widget.size,
          child: ColoredBox(
            color: widget.fill,
            child: RawImage(
              image: _frame ?? first.image,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
    if (!first.animated) return image;
    return MouseRegion(
      onEnter: (_) => _enter(),
      onExit: (_) => _leave(),
      child: image,
    );
  }
}
