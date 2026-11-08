import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat_images.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart' show ClickableImage;
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';

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
