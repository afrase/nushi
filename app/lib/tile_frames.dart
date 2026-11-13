import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_picture.dart';
import 'package:nushi/tile_trim.dart';

/// A tile's own image as Change tile… frames and trims it (ADR 0112),
/// decoded once when it's opened: each frame's time, a strip of [cells]
/// thumbnails [thumbSide] pixels high for the trimmer, and the frame at
/// the playhead [side] pixels on its shorter side for the framing square.
/// No whole frame is kept: each is scaled down and let go as it's
/// decoded. It holds the trim being set ([start] to [end]) and plays it.
class TileFrames extends ChangeNotifier {
  new(
    this.picture, {
    required this.side,
    required this.thumbSide,
    TileTrim? trim,
  }) : _from = trim;

  /// How many thumbnails the strip shows.
  static const cells = 12;

  final TilePicture picture;
  final int side;
  final int thumbSide;
  final TileTrim? _from;

  /// The frame shown in the framing square: the playhead's.
  final ValueNotifier<ui.Image?> frame = ValueNotifier(null);

  /// Which frame [frame] is.
  @visibleForTesting
  int? shown;

  /// The strip's thumbnails, by time; one may stand in several cells.
  List<ui.Image> thumbs = const [];

  /// Whether it's decoded, or found it can't be.
  bool loaded = false;

  List<Duration> _starts = const [Duration.zero]; // and the end
  int start = 0;
  int end = 0;
  int playhead = 0;
  bool playing = false;

  Uint8List? _bytes;
  ui.Codec? _codec; // for the playhead's frame
  int _next = 0; // the frame _codec gives next
  int? _want; // the frame to show next
  bool _seeking = false;
  Timer? _tick;
  bool _gone = false;

  /// How many frames it has: more than one to trim.
  int get count => _starts.length - 1;

  /// When frame [index] starts; [count] is the end.
  Duration startOf(int index) => _starts[index.clamp(0, count)];

  /// How long all its frames take.
  Duration get length => _starts.last;

  /// The trim set, null when it keeps every frame.
  TileTrim? get trim => TileTrim(start, end).of(count);

  /// The frame showing at [time].
  int frameAt(Duration time) {
    var (low, high) = (0, count - 1);
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_starts[mid] <= time) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return max(0, low);
  }

  /// The frame boundary nearest [time]: 0 to [count].
  int boundaryAt(Duration time) {
    final at = frameAt(time);
    final (before, after) = (time - _starts[at], _starts[at + 1] - time);
    return before <= after ? at : at + 1;
  }

  /// Decodes it once, in order: each frame's time; thumbnail candidates
  /// spaced evenly through its frames, halved whenever there are twice as
  /// many as [cells], then the nearest to each cell's time taken; and the
  /// trim's start at [side] for the framing square.
  Future<void> load() async {
    ui.Codec? codec;
    final candidates = <int, ui.Image>{};
    try {
      final bytes = await picture.read();
      codec = await tileImageCodec(bytes, side);
      final total = codec.frameCount;
      final from = _from?.of(total);
      start = from?.start ?? 0;
      end = from?.end ?? total;
      playhead = start;
      final starts = [Duration.zero];
      var step = 1;
      for (var i = 0; i < total; i++) {
        final next = await codec.getNextFrame();
        if (_gone) return next.image.dispose();
        starts.add(starts.last + frameWait(next.duration));
        if (i == start) _show(await tileFrame(next.image.clone(), side), i);
        if (total > 1 && i % step == 0) {
          candidates[i] = await tileFrame(next.image, thumbSide);
        } else {
          next.image.dispose();
        }
        if (candidates.length > 2 * cells) {
          step *= 2;
          candidates.removeWhere((at, image) {
            if (at % step == 0) return false;
            image.dispose();
            return true;
          });
        }
      }
      _starts = starts;
      _bytes = total > 1 ? bytes : null;
      thumbs = [
        for (var c = 0; c < cells && total > 1; c++)
          candidates[_nearest(candidates.keys, length * ((c + 0.5) / cells))]!,
      ];
      final used = thumbs.toSet();
      for (final image in candidates.values) {
        if (!used.contains(image)) image.dispose();
      }
      candidates.clear();
    } on Object {
      // Not an image after all: the square and the strip stay empty.
    } finally {
      codec?.dispose();
      if (_gone) {
        for (final image in candidates.values) {
          image.dispose();
        }
      }
    }
    if (_gone) return;
    loaded = true;
    notifyListeners();
  }

  int _nearest(Iterable<int> frames, Duration time) => frames.reduce(
    (a, b) => (startOf(a) - time).abs() <= (startOf(b) - time).abs() ? a : b,
  );

  /// Moves the trim's start to frame [index], showing it.
  void moveStart(int index) {
    _stopPlaying();
    start = index.clamp(0, end - TileTrim.minFrames);
    _go(start);
  }

  /// Moves the trim's end to [index] (the frame after the last kept),
  /// showing the last kept.
  void moveEnd(int index) {
    _stopPlaying();
    end = index.clamp(start + TileTrim.minFrames, count);
    _go(end - 1);
  }

  /// Shows frame [index], within the trim.
  void scrub(int index) {
    _stopPlaying();
    _go(index.clamp(start, end - 1));
  }

  /// Back to the trim's start, the frame a tile shows at rest.
  void rest() => _go(start);

  /// Plays the trim from the playhead, looping; or stops where it is.
  void toggle() {
    if (playing) {
      _stopPlaying();
      return notifyListeners();
    }
    if (count < 2) return;
    playing = true;
    if (playhead >= end - 1) playhead = start;
    _go(playhead);
    _wait();
  }

  void _wait() {
    _tick = Timer(startOf(playhead + 1) - startOf(playhead), () {
      if (!playing || _gone) return;
      _go(playhead + 1 >= end ? start : playhead + 1);
      _wait();
    });
  }

  void _stopPlaying() {
    playing = false;
    _tick?.cancel();
    _tick = null;
  }

  void _go(int index) {
    playhead = index;
    notifyListeners();
    _want = index;
    unawaited(_seek());
  }

  /// Decodes the frame wanted, one at a time; while one is decoded, the
  /// next wanted waits, and only the last is decoded after it.
  Future<void> _seek() async {
    if (_seeking || _bytes == null) return;
    _seeking = true;
    try {
      while (!_gone) {
        final want = _want;
        if (want == null) break;
        _want = null;
        final image = await _decode(want);
        if (_gone) return image.dispose();
        _show(image, want);
      }
    } on Object {
      // Left as it was.
    } finally {
      _seeking = false;
    }
  }

  /// Frame [index] at [side]: a GIF decodes only in order, so from the
  /// codec's place on, or from a new codec for one before it.
  Future<ui.Image> _decode(int index) async {
    var codec = _codec;
    if (codec == null || index < _next) {
      codec?.dispose();
      _codec = codec = await tileImageCodec(_bytes!, side);
      _next = 0;
    }
    await skipFrames(codec, index - _next);
    final next = await codec.getNextFrame();
    _next = index + 1;
    return await tileFrame(next.image, side);
  }

  void _show(ui.Image image, int index) {
    if (_gone) return image.dispose();
    shown = index;
    final before = frame.value;
    frame.value = image;
    if (before == null) return;
    // After the frame that stops showing it.
    WidgetsBinding.instance.addPostFrameCallback((_) => before.dispose());
  }

  @override
  void dispose() {
    _gone = true;
    _stopPlaying();
    _codec?.dispose();
    _codec = null;
    _bytes = null;
    frame.value?.dispose();
    frame.dispose();
    for (final image in thumbs.toSet()) {
      image.dispose();
    }
    thumbs = const [];
    super.dispose();
  }
}
