import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_trim.dart';

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

/// The first frames decoded so far, by picture, size in pixels and crop,
/// so a tile built again (a list that rebuilds) shows its image at once.
/// Small: each is a tile's size, an animated one's too ([tileFrame]). One
/// goes when its picture does ([forgetPicture]); of a picture at one size,
/// only the uncropped one and the last crop are kept, so framing in
/// Change tile… doesn't leave one behind for each step of a drag.
final Map<String, _First> _firsts = runMap();
final Map<String, Future<_First?>> _decoding = runMap();

/// Lets go of what's kept of the picture called [key]: its stored image
/// was deleted, or the dialog that picked it closed.
void forgetPicture(String key) {
  _firsts.removeWhere((k, _) => k.startsWith('$key@'));
}

/// Keeps [first] under [key], a crop of the picture at a size ([at]) in
/// the place of any other.
void _keep(String at, String key, _First first) {
  if (key != at) _firsts.removeWhere((k, _) => k.startsWith('$at#'));
  _firsts[key] = first;
}

/// [picture] in a tile [size] square: decoded at that size in the screen's
/// pixels, never its own, cropped to the square from its middle or to
/// [crop]'s, on [fill]
/// where it's see-through, its corners [radius]. Until it's decoded, and
/// if it can't be, [fallback].
///
/// A GIF or an animated WebP shows its first frame ([trim]'s start), and
/// plays, looping (back to [trim]'s start after its end), only while the
/// pointer is over the tile: not under Reduce Motion, and
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
    this.crop,
    this.trim,
  });

  final TilePicture picture;

  /// The square of it shown; null for the middle one.
  final TileCrop? crop;

  /// The frames of it played; null for all.
  final TileTrim? trim;
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
  String? _shown; // what _first is of: another crop's, while one decodes
  bool _hover = false;

  // While it plays: the codec, the frame shown, the wait for the next,
  // and the watch on Nushi leaving the front.
  ui.Codec? _codec;
  ui.Image? _frame;
  Timer? _next;
  AppLifecycleListener? _front;
  int _run = 0; // which start of playing is the current one
  bool _opening = false; // its file is being read to play
  bool _loading = false; // its first frame is being decoded
  // While a trimmed one plays: the frames played, the next one's index,
  // and the file's bytes, to start again from its start.
  TileTrim? _range;
  int _index = 0;
  Uint8List? _bytes;

  /// How many frames it has shown since it last started playing; 0 at
  /// rest, where it shows the first.
  @visibleForTesting
  int played = 0;

  /// Whether its picture's first frame is here, as it's to be shown (its
  /// crop's, not the last one's).
  @visibleForTesting
  bool get decoded => _first != null && _shown == _key;

  /// Whether its picture is decoded and has more than one frame.
  @visibleForTesting
  bool get animated => _first?.animated ?? false;

  /// Whether anything of its playing exists: nothing does at rest.
  @visibleForTesting
  bool get busy =>
      _opening || _codec != null || _next != null || _front != null;

  String get _at => '${widget.picture.key}@$_side';
  String get _key {
    final (crop, start) = (widget.crop, widget.trim?.start ?? 0);
    if (crop == null && start == 0) return _at;
    return '$_at#${crop?.key ?? ''}>$start';
  }

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
    final another = oldWidget.picture.key != widget.picture.key;
    if (another ||
        side != _side ||
        oldWidget.crop != widget.crop ||
        oldWidget.trim != widget.trim) {
      _side = side;
      // Another crop or size of the same picture shows the last until
      // it's decoded: framing it doesn't blink to the fallback.
      if (another) _first = null;
      _stop();
      _load();
    }
  }

  @override
  void dispose() {
    _stop(tell: false);
    super.dispose();
  }

  /// Decodes its first frame as it's to be shown, one at a time: while
  /// one is decoded, a change (a crop dragged) waits, and only the last
  /// is decoded after it.
  void _load() {
    final key = _key;
    if (_firsts[key] case final first?) {
      _first = first;
      _shown = key;
      return;
    }
    if (_loading) return;
    _loading = true;
    final (at, picture, side) = (_at, widget.picture, _side);
    final decoded = _decoding[key] ??= _decodeFirst(
      picture,
      side,
      widget.crop,
      widget.trim,
    );
    unawaited(
      decoded.then((first) {
        unawaited(_decoding.remove(key));
        if (first != null) _keep(at, key, first);
        _loading = false;
        if (!mounted) return;
        if (key != _key) return setState(_load);
        setState(() {
          _first = first;
          _shown = key;
        });
        if (_hover) _start();
      }),
    );
  }

  static Future<_First?> _decodeFirst(
    TilePicture picture,
    int side,
    TileCrop? crop,
    TileTrim? trim,
  ) async {
    try {
      final bytes = await picture.read();
      final codec = await tileImageCodec(bytes, side, crop: crop);
      // A trimmed one's first is its start's: the frames before it are
      // decoded and let go, one at a time.
      await skipFrames(codec, trim?.of(codec.frameCount)?.start ?? 0);
      final frame = await codec.getNextFrame();
      final animated = codec.frameCount > 1;
      codec.dispose();
      final image = await tileFrame(frame.image, side, crop: crop);
      return (image: image, animated: animated);
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
      final bytes = await widget.picture.read();
      final codec = await tileImageCodec(bytes, _side, crop: widget.crop);
      final range = widget.trim?.of(codec.frameCount);
      await skipFrames(codec, range?.start ?? 0);
      _opening = false;
      if (run != _run || !mounted) return codec.dispose();
      _codec = codec;
      _range = range;
      _index = range?.start ?? 0;
      _bytes = range == null ? null : bytes;
      await _advance(run);
    } on Object {
      _opening = false;
      if (run == _run) _pause();
    }
  }

  Future<void> _advance(int run) async {
    var codec = _codec;
    if (codec == null) return;
    final ui.FrameInfo frame;
    try {
      if (_range case final range? when _index >= range.end) {
        // Past its end: back to its start, from a codec made again and
        // the frames before the start decoded and let go, rather than
        // decoding on through the rest.
        codec.dispose();
        _codec = null;
        codec = await tileImageCodec(_bytes!, _side, crop: widget.crop);
        await skipFrames(codec, range.start);
        if (run != _run || !mounted) return codec.dispose();
        _codec = codec;
        _index = range.start;
      }
      frame = await codec.getNextFrame();
      _index++;
    } on Object {
      if (run == _run) _pause();
      return;
    }
    if (run != _run || !mounted) return frame.image.dispose();
    final ui.Image image;
    try {
      image = await tileFrame(frame.image, _side, crop: widget.crop);
    } on Object {
      if (run == _run) _pause();
      return;
    }
    if (run != _run || !mounted) return image.dispose();
    final before = _frame;
    setState(() {
      _frame = image;
      played++;
    });
    before?.dispose();
    _next = Timer(frameWait(frame.duration), () => unawaited(_advance(run)));
  }

  /// Stops playing and shows the first frame; the watch stays while the
  /// pointer does.
  void _pause() {
    _run++;
    _next?.cancel();
    _next = null;
    _codec?.dispose();
    _codec = null;
    _range = null;
    _bytes = null;
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
    _range = null;
    _bytes = null;
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
