import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The daemon's API that has WatchChatFile.
const previewApi = 75;

/// What a preview shows a file as.
enum PreviewKind { markdown, image }

/// How [path] previews, or null for a file the preview can't show.
PreviewKind? previewKind(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot < path.lastIndexOf('/')) return null;
  return switch (path.substring(dot + 1).toLowerCase()) {
    'md' || 'markdown' => PreviewKind.markdown,
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' => PreviewKind.image,
    _ => null,
  };
}

/// The last part of [path].
String baseName(String path) => path.substring(path.lastIndexOf('/') + 1);

/// Opens a file's preview from the tool rows below it, the one open
/// ([current]) marked. With no [open] (an older daemon) there's no
/// Preview button.
class Previews extends InheritedWidget {
  const new({
    required this.open,
    required super.child,
    super.key,
    this.current,
  });

  final void Function(String path)? open;
  final ValueListenable<String?>? current;

  static Previews? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Previews>();

  @override
  bool updateShouldNotify(Previews oldWidget) =>
      (oldWidget.open == null) != (open == null) ||
      oldWidget.current != current;
}

/// A file of a chat's as the daemon sends it: again each time it changes,
/// while this lives. [live] while the daemon watches it.
class FileWatch extends ChangeNotifier {
  new(this.daemon, this.chatId, this.path) {
    _watch();
  }

  final Daemon daemon;
  final String chatId;
  final String path; // as asked: relative to the chat's folder, or absolute

  WatchChatFileResponse? file;
  String error = ''; // why the daemon won't read it
  bool live = false;
  StreamSubscription<WatchChatFileResponse>? _sub;
  bool _disposed = false;

  void _watch() {
    _sub = daemon.client
        .watchChatFile(WatchChatFileRequest(chatId: chatId, path: path))
        .listen(
          (f) {
            file = f;
            error = '';
            live = true;
            notifyListeners();
          },
          onError: (Object e) {
            live = false;
            // Refused: it stays so. Anything else (the daemon went away):
            // watch again.
            if (e is ConnectException &&
                const [
                  Code.permissionDenied,
                  Code.failedPrecondition,
                  Code.notFound,
                  Code.unimplemented,
                ].contains(e.code)) {
              error = e.message;
            } else {
              _again();
            }
            notifyListeners();
          },
          onDone: () {
            if (!live) return; // after an error
            live = false;
            notifyListeners();
            _again();
          },
          cancelOnError: true,
        );
  }

  void _again() => Timer(const Duration(seconds: 2), () {
    if (!_disposed) _watch();
  });

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

/// What a preview shows of [watch]'s file: the Markdown rendered (or its
/// [source] in the code font), the image, or why it can't show it. Too
/// large a file offers [onReveal] (Open in Finder) when given.
class PreviewBody extends StatelessWidget {
  const new({
    required this.watch,
    required this.source,
    super.key,
    this.onReveal,
    this.padding = const EdgeInsets.fromLTRB(28, 22, 28, 28),
  });

  final FileWatch watch;
  final bool source;
  final VoidCallback? onReveal;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ListenableBuilder(
      listenable: watch,
      builder: (context, _) {
        final f = watch.file;
        Widget note(String text, {Widget? action}) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.ui(t.textSecondary),
                ),
                ?action,
              ],
            ),
          ),
        );
        if (watch.error.isNotEmpty) return note(watch.error);
        if (f == null) {
          return const Center(
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          );
        }
        if (f.missing) return note('The file isn’t there (yet).');
        if (f.tooLarge) {
          return note(
            'Too large to preview (${_size(f.size.toInt())}).',
            action: onReveal == null
                ? null
                : Button(
                    label: 'Open in Finder',
                    icon: Icons.folder_open_outlined,
                    onPressed: onReveal,
                  ),
          );
        }
        if (previewKind(watch.path) == PreviewKind.image) {
          return Padding(
            padding: padding,
            child: Center(
              child: Image.memory(
                Uint8List.fromList(f.data),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Text(
                  'Not an image Nushi can show.',
                  style: theme.ui(t.textSecondary),
                ),
              ),
            ),
          );
        }
        final text = utf8.decode(f.data, allowMalformed: true);
        return SelectionArea(
          child: SingleChildScrollView(
            padding: padding,
            child: source
                ? Text(text, style: theme.code(t.textSecondary, size: 12))
                : Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: AgentMarkdown(
                        text,
                        images: (uri, alt) => _image(f.path, uri, alt),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  /// An image in the Markdown: one of the chat's files through the
  /// daemon (relative to the Markdown file's folder); a remote one as its
  /// text, as the phone shows it.
  Widget _image(String file, Uri uri, String? alt) {
    if (uri.scheme == 'data') return markdownImage(uri, alt);
    final local =
        (uri.scheme.isEmpty || uri.scheme == 'file') &&
        uri.host.isEmpty &&
        uri.path.isNotEmpty;
    if (!local) return Text('[image: ${alt ?? uri}]');
    final String p;
    try {
      p = Uri.decodeComponent(uri.path);
    } on FormatException {
      return Text('[image: ${alt ?? uri}]');
    }
    final dir = file.substring(0, file.lastIndexOf('/') + 1);
    return _ChatImage(
      watch.daemon,
      watch.chatId,
      p.startsWith('/') ? p : '$dir$p',
      alt ?? p,
    );
  }
}

String _size(int n) => n < 1 << 20
    ? '${(n / 1024).toStringAsFixed(0)} KB'
    : '${(n / (1 << 20)).toStringAsFixed(1)} MB';

/// One of a chat's images, read (and kept current) through the daemon.
class _ChatImage extends StatefulWidget {
  const new(this.daemon, this.chatId, this.path, this.alt);

  final Daemon daemon;
  final String chatId;
  final String path;
  final String alt;

  @override
  State<_ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<_ChatImage> {
  late final _watch = FileWatch(widget.daemon, widget.chatId, widget.path);

  @override
  void dispose() {
    _watch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _watch,
    builder: (context, _) {
      final f = _watch.file;
      final muted = TextStyle(color: NushiTheme.of(context).t.textMuted);
      if (_watch.error.isNotEmpty ||
          f != null && (f.missing || f.tooLarge || f.data.isEmpty)) {
        return Text('[image: ${widget.alt}]', style: muted);
      }
      if (f == null) return const SizedBox(height: 24);
      return ClickableImage(
        image: MemoryImage(Uint8List.fromList(f.data)),
        size: 480,
      );
    },
  );
}

/// The Preview and Source switch over a Markdown file.
class SourceSwitch extends StatelessWidget {
  const new({required this.source, required this.onChanged, super.key});

  final bool source;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Segmented(
    value: source,
    segments: const [(false, 'Preview'), (true, 'Source')],
    onChanged: onChanged,
  );
}

/// The green mark of a preview the daemon keeps current; its dot pulses
/// once each time [version] (the file as last sent) changes.
class LiveMark extends StatefulWidget {
  const new({super.key, this.size = 12, this.version});

  final double size;
  final Object? version;

  @override
  State<LiveMark> createState() => _LiveMarkState();
}

class _LiveMarkState extends State<LiveMark>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );
  late final Animation<double> _grow = _scale.animate(_pulse);

  // Up to 1.8 times its size and back, each way easing out.
  static final Animatable<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.8,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.8,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 70,
    ),
  ]);

  @override
  void didUpdateWidget(LiveMark old) {
    super.didUpdateWidget(old);
    if (old.version != null &&
        !identical(old.version, widget.version) &&
        !reduceMotion(context)) {
      _pulse.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Tooltip(
      message: 'Updates as the file changes',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          ScaleTransition(
            scale: _grow,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: t.done, shape: BoxShape.circle),
            ),
          ),
          Text('Live', style: theme.ui(t.done, size: widget.size)),
        ],
      ),
    );
  }
}
