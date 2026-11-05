import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/history_table.dart' show diskSize;
import 'package:nushi/images.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/preview_sniff.dart';
import 'package:nushi/preview_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/syntax_languages.dart' show codeNames;
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

  /// A Mermaid diagram (`.mmd`, `.mermaid`).
  mermaid,

  /// Code and text: its source only, highlighted.
  code;

  /// Drawn by a web view (the Mac) or a frame (the phone).
  bool get page =>
      this == html || this == svg || this == pdf || this == mermaid;

  /// Has Preview and Source.
  bool get rendered =>
      this == markdown ||
      this == html ||
      this == svg ||
      this == csv ||
      this == mermaid;

  /// Made to be looked at: listed in Artifacts, with a Preview button on
  /// its tool row. Code and text show only through ⌘P's Open file
  /// (Changes shows what the agent did to them).
  bool get artifact => this != code;

  /// What it is, in a word: the Artifacts widget's rows say it.
  String get label => switch (this) {
    markdown => 'Markdown',
    image => 'Image',
    html => 'HTML',
    svg => 'SVG',
    pdf => 'PDF',
    csv => 'CSV',
    mermaid => 'Diagram',
    code => 'Code',
  };

  /// Its icon, in the preview's header and the Files pane's rows.
  IconData get icon => switch (this) {
    image => Icons.image_outlined,
    html || svg => Icons.web_outlined,
    mermaid => Icons.account_tree_outlined,
    code => Icons.code,
    markdown || pdf || csv => Icons.description_outlined,
  };
}

/// The extensions of artifacts ([PreviewKind.artifact]), which the daemon
/// knows too: the show tool takes these (`filewatch.Artifact`). Both sides'
/// tests read `internal/filewatch/testdata/artifacts.json`.
const Map<String, PreviewKind> artifactKinds = {
  'md': PreviewKind.markdown,
  'markdown': PreviewKind.markdown,
  'png': PreviewKind.image,
  'jpg': PreviewKind.image,
  'jpeg': PreviewKind.image,
  'gif': PreviewKind.image,
  'webp': PreviewKind.image,
  'html': PreviewKind.html,
  'htm': PreviewKind.html,
  'svg': PreviewKind.svg,
  'pdf': PreviewKind.pdf,
  'csv': PreviewKind.csv,
  'mmd': PreviewKind.mermaid,
  'mermaid': PreviewKind.mermaid,
};

/// Extensions of code and text files a preview shows as source.
const _code = {
  'json', 'jsonl', 'yaml', 'yml', 'toml', 'txt', 'log', 'ini', 'cfg', //
  'conf', 'xml', 'go', 'dart', 'py', 'js', 'mjs', 'cjs', 'ts', 'tsx', //
  'jsx', 'swift', 'rs', 'rb', 'java', 'kt', 'kts', 'scala', 'c', 'h', //
  'cc', 'cpp', 'hpp', 'm', 'mm', 'cs', 'sh', 'bash', 'zsh', 'fish', //
  'sql', 'css', 'scss', 'less', 'proto', 'lua', 'php', 'pl', 'r', 'ex', //
  'exs', 'erl', 'hs', 'ml', 'clj', 'el', 'vim', 'tf', 'hcl', 'graphql', //
  'vue', 'svelte', 'zig', 'nix', 'gradle', 'diff', 'patch', 'mk', //
  'jsonnet', 'libsonnet', 'tfvars', 'jsonc', 'json5', 'ndjson', 'htm', //
  'astro', 'mdx', 'pyi', 'pyx', 'bzl', 'jl', 'env', 'j2', 'jinja2', //
  'just', 'rake', 'cts', 'mts', 'cljs', 'mli', 'wgsl', //
};

/// How [path] previews by its name, or null when the name doesn't say (no
/// extension, a dotfile, an unknown type, a binary). What needs a sure
/// answer asks this: the file links in messages, Artifacts. What lists a
/// folder's files asks [opensInPreview].
PreviewKind? previewKind(String path) {
  final name = baseName(path);
  if (codeNames.contains(name)) return PreviewKind.code;
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  return artifactKinds[ext] ?? (_code.contains(ext) ? PreviewKind.code : null);
}

/// Whether the Files pane and ⌘P open [path] in the preview: a kind
/// [previewKind] names, or any file not surely binary by its name
/// ([surelyBinary]); the preview reads such a file's bytes to tell
/// whether it's text ([FileWatch.notText]).
bool opensInPreview(String path) =>
    previewKind(path) != null || !surelyBinary(baseName(path));

/// Whether [path] is an artifact: a file of a kind that renders
/// ([PreviewKind.artifact]).
bool isArtifact(String path) => previewKind(path)?.artifact ?? false;

/// The last part of [path] (all of it when it ends in a slash).
String baseName(String path) {
  final name = path.substring(path.lastIndexOf('/') + 1);
  return name.isEmpty ? path : name;
}

/// Opens a file's preview from the tool rows below it, the one open
/// ([current]) marked. With no [open] (an older daemon) there's no
/// Preview button.
class Previews extends InheritedWidget {
  const new({
    required this.open,
    required super.child,
    super.key,
    this.current,
    this.name,
  });

  final void Function(String path)? open;
  final ValueListenable<String?>? current;

  /// The chat's one name for a file however a row or the preview named it
  /// (`relativeIn`): a show call's path is the agent's, often absolute,
  /// and the file may be open by the Artifacts widget's relative name.
  /// Without it, names are compared as given.
  final String Function(String path)? name;

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

  /// Whether the file came and isn't text, by its bytes ([isText]): asked
  /// only of one whose name doesn't say what it is ([previewKind]), each
  /// time it comes.
  bool notText = false;

  StreamSubscription<WatchChatFileResponse>? _sub;
  bool _disposed = false;

  void _watch() {
    _sub = daemon.client
        .watchChatFile(WatchChatFileRequest(chatId: chatId, path: path))
        .listen(
          (f) {
            file = f;
            notText =
                previewKind(path) == null &&
                !f.missing &&
                !f.tooLarge &&
                !isText(f.data);
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
/// offering [onReveal] (Show in Finder) when given. Null once it can show.
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
      'Too large to preview (${diskSize(f.size.toInt())}).',
      action: onReveal == null
          ? null
          : Button(
              label: 'Show in Finder',
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
/// or, for code and with [source], its text highlighted ([SourceView]),
/// its lines wrapped as [wrapLines] says.
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

  /// Draws a page's file (HTML, SVG, Mermaid: needed for those, else they
  /// show as source), and a PDF where it can (the Mac's WebKit); without
  /// it a PDF says to open it on the Mac.
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
        if (watch.notText) {
          return PreviewNote(
            'Can’t show this file: it isn’t text.',
            action: onReveal == null
                ? null
                : Button(
                    label: 'Show in Finder',
                    icon: Icons.folder_open_outlined,
                    onPressed: onReveal,
                  ),
          );
        }
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
          return ValueListenableBuilder(
            valueListenable: wrapLines,
            builder: (context, wrap, _) => SourceView(
              text,
              path: watch.path,
              padding: padding,
              wrap: wrap,
            ),
          );
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
