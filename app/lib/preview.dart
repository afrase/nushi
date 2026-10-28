import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/preview_text.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The daemon's API that has WatchChatFile.
const previewApi = 75;

/// What a preview shows a file as.
enum PreviewKind {
  markdown,
  image,
  html,
  svg,
  pdf,
  csv,

  /// Code and text: its source only, highlighted.
  code;

  /// Drawn by a web view (the Mac) or a frame (the phone).
  bool get page => this == html || this == svg || this == pdf;

  /// Has Preview and Source.
  bool get rendered =>
      this == markdown || this == html || this == svg || this == csv;
}

/// Extensions of code and text files a preview shows as source.
const _code = {
  'json', 'jsonl', 'yaml', 'yml', 'toml', 'txt', 'log', 'ini', 'cfg', //
  'conf', 'xml', 'go', 'dart', 'py', 'js', 'mjs', 'cjs', 'ts', 'tsx', //
  'jsx', 'swift', 'rs', 'rb', 'java', 'kt', 'kts', 'scala', 'c', 'h', //
  'cc', 'cpp', 'hpp', 'm', 'mm', 'cs', 'sh', 'bash', 'zsh', 'fish', //
  'sql', 'css', 'scss', 'less', 'proto', 'lua', 'php', 'pl', 'r', 'ex', //
  'exs', 'erl', 'hs', 'ml', 'clj', 'el', 'vim', 'tf', 'hcl', 'graphql', //
  'vue', 'svelte', 'zig', 'nix', 'gradle', 'diff', 'patch', 'mk', //
};

/// Files named without an extension that are code.
const _codeNames = {'Makefile', 'Dockerfile', 'Justfile', 'Gemfile'};

/// How [path] previews, or null for a file the preview can't show (a
/// binary, an unknown type).
PreviewKind? previewKind(String path) {
  final name = baseName(path);
  if (_codeNames.contains(name)) return PreviewKind.code;
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'md' || 'markdown' => PreviewKind.markdown,
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' => PreviewKind.image,
    'html' || 'htm' => PreviewKind.html,
    'svg' => PreviewKind.svg,
    'pdf' => PreviewKind.pdf,
    'csv' => PreviewKind.csv,
    final e when _code.contains(e) => PreviewKind.code,
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

/// Why [watch]'s file shows nothing yet, as a note in its place: the
/// daemon refused it, it hasn't come, it isn't there, or it's over the
/// daemon's cap (unless [capped] is false: a web view reads it from disk),
/// offering [onReveal] (Open in Finder) when given. Null once it can show.
Widget? previewStatus(
  BuildContext context,
  FileWatch watch, {
  VoidCallback? onReveal,
  bool capped = true,
}) {
  final f = watch.file;
  if (watch.error.isNotEmpty) return PreviewNote(watch.error);
  if (f == null) {
    return const Center(
      child: SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
    );
  }
  if (f.missing) return const PreviewNote('The file isn’t there (yet).');
  if (f.tooLarge && capped) {
    return PreviewNote(
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
  return null;
}

/// A few words in a preview's place, centered, with an [action] under.
class PreviewNote extends StatelessWidget {
  const new(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.ui(theme.t.textSecondary),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// What a preview shows of [watch]'s file, by its kind ([previewKind]):
/// Markdown rendered, an image, a CSV's table, a page through [page] (the
/// Mac's web view or the phone's frame, which follow [watch] themselves),
/// or, for code and with [source], its text highlighted ([SourceView]).
class PreviewBody extends StatelessWidget {
  const new({
    required this.watch,
    required this.source,
    super.key,
    this.onReveal,
    this.page,
    this.padding = const EdgeInsets.fromLTRB(28, 22, 28, 28),
  });

  final FileWatch watch;
  final bool source;
  final VoidCallback? onReveal;
  final Widget Function(FileWatch watch)? page;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final kind = previewKind(watch.path) ?? PreviewKind.code;
    final page = this.page;
    if (!kind.page || page == null) return _file(context, kind, source);
    if (kind == PreviewKind.pdf) return page(watch);
    // Both stay built, so the web view is made once.
    return IndexedStack(
      index: source ? 1 : 0,
      sizing: StackFit.expand,
      children: [page(watch), _file(context, kind, true)],
    );
  }

  Widget _file(BuildContext context, PreviewKind kind, bool source) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ListenableBuilder(
      listenable: watch,
      builder: (context, _) {
        if (previewStatus(context, watch, onReveal: onReveal)
            case final status?) {
          return status;
        }
        final f = watch.file!;
        if (kind == PreviewKind.image) {
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
        if (kind == PreviewKind.pdf) {
          return const PreviewNote('Open it on your Mac to see it.');
        }
        final text = utf8.decode(f.data, allowMalformed: true);
        if (kind == PreviewKind.csv && !source) {
          return CsvTable(text, padding: padding);
        }
        if (kind != PreviewKind.markdown || source) {
          return SourceView(text, path: watch.path, padding: padding);
        }
        return SelectionArea(
          child: SingleChildScrollView(
            padding: padding,
            child: Align(
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
