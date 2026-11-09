import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/native.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_header.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/source_editor.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_views.dart';

/// A file the agent wrote, beside the chat where a subagent's pane opens.
/// Its header ([PreviewHeader]):
/// its name (a click shows it in the Files pane; with several files open,
/// the tabs of them all, [PreviewTabs]), Live while the daemon keeps it
/// current, wrapping the lines or not while it shows a source
/// ([WrapButton], and ⌥Z with the focus in the pane), Reload (in the app's
/// own web view) and Open in browser (a page, not a diagram), Show in
/// Finder and Close, which closes every tab (browser tabs too,
/// `BrowserPane`). Under them its path line ([PathLine]): the path, which a
/// click copies, and the source button for a file that renders (not a
/// diagram with nothing to draw it; ADR 0106). It's one file's view, made
/// again as its tab shows.
class PreviewPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.path,
    required this.onClose,
    super.key,
    this.tabsKey,
  });

  final ChatState chat;
  final Daemon daemon;
  final String path; // as the tool row names it
  final VoidCallback onClose;

  /// The key of its [PreviewTabs], from outside a view that's keyed by file,
  /// so the tabs' row outlives it.
  final Key? tabsKey;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  late final _watch = FileWatch(widget.daemon, widget.chat.id, widget.path);
  late final PreviewKind _kind = previewKind(widget.path) ?? PreviewKind.code;
  late final PageHost? _page = _kind.page && _kind != PreviewKind.mermaid
      ? native.web.page()
      : null;
  late final DiagramHost? _diagram = _kind == PreviewKind.mermaid
      ? native.web.diagram()
      : null;
  late bool _source = widget.chat.previewSources.contains(widget.path);
  final _focus = FocusNode(debugLabel: 'preview');

  @override
  void initState() {
    super.initState();
    _watch.addListener(_fileCame);
  }

  /// Whether this pane's watch has sent a message yet.
  bool _heard = false;

  /// The file's edits, while it's being edited (ADR 0096).
  FileEdit? get _edit => widget.chat.edits[widget.path];

  /// A file that came is edited when it can be (text the editor gives
  /// back byte for byte; not an image or a PDF); an edit hears of each
  /// version, and goes once it has nothing unsaved and the file went or
  /// can't be edited now.
  void _fileCame() {
    final f = _watch.file;
    if (f == null || widget.daemon.daemonApi < editApi) return;
    final first = !_heard;
    _heard = true;
    if (_edit case final edit?) {
      edit.receive(f, first: first);
      if (!edit.unsaved && (f.missing || edit.readOnly != null)) {
        widget.chat.dropEdit(widget.path);
      }
      return;
    }
    if (_kind == PreviewKind.image || _kind == PreviewKind.pdf) return;
    if (f.missing || notEditable(f) != null) return;
    final (file, _) = decodeFile(f.data);
    widget.chat.edit(
      widget.path,
      () =>
          FileEdit(widget.daemon, widget.chat.id, widget.path, file!, f.sha256),
    );
  }

  /// Why the file shows read-only, when it can't be edited (an edit's
  /// own reason shows in its bars).
  String? _readOnly() {
    final f = _watch.file;
    if (f == null || f.missing || _edit != null || _watch.notText) return null;
    if (widget.daemon.daemonApi < editApi) return null;
    return notEditable(f);
  }

  /// The editor in the source's place, while the file is being edited.
  Widget? _editor({required bool wrap}) => switch (_edit) {
    final edit? => SourceEditor(
      key: ObjectKey(edit),
      edit: edit,
      wrap: wrap,
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
    ),
    null => null,
  };

  @override
  void dispose() {
    _watch.removeListener(_fileCame);
    _focus.dispose();
    _watch.dispose();
    _page?.dispose();
    _diagram?.dispose();
    super.dispose();
  }

  String get _abs =>
      _watch.file?.path ?? absoluteIn(widget.chat.folder, widget.path);

  void _reveal() => revealInFinder(_abs).ignore();

  /// Whether it has the source button: a file that renders, but a diagram
  /// only with something to draw it (Linux has none, ADR 0104).
  bool get _switches =>
      _kind.rendered && (_kind != PreviewKind.mermaid || _diagram != null);

  /// Whether it shows the file's text, a source view: code, a diagram with
  /// nothing to draw it, or the Source of one that renders. Only then do its
  /// lines wrap or not.
  bool get _showsSource =>
      _kind == PreviewKind.code && !_watch.notText ||
      _kind.rendered && (_source || !_switches);

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent || !_showsSource) return KeyEventResult.ignored;
    // In the editor ⌥Z types its character.
    if (_edit != null && !_focus.hasPrimaryFocus) return KeyEventResult.ignored;
    if (!wrapKey.accepts(e, HardwareKeyboard.instance)) {
      return KeyEventResult.ignored;
    }
    toggleWrap();
    return KeyEventResult.handled;
  }

  void _showSource(bool source) {
    setState(() => _source = source);
    final sources = widget.chat.previewSources;
    if (source) {
      sources.add(widget.path);
    } else {
      sources.remove(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final kind = _kind;
    final page = _page;
    final diagram = _diagram;
    final actions = <(IconData, String, double, VoidCallback)>[
      if (page != null) ...[
        // A page in the browser reloads there (ADR 0104).
        if (webEmbedded)
          (Icons.refresh, 'Reload', 15, () => page.reload().ignore()),
        (
          Icons.open_in_new,
          'Open in browser',
          14,
          () => openInBrowserOrSay(context, Uri.file(_abs)).ignore(),
        ),
      ],
    ];
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PreviewHeader(
            daemon: widget.daemon,
            chat: widget.chat,
            path: widget.path,
            tabsKey: widget.tabsKey,
            watch: _watch,
            kind: kind,
            page: page != null,
            actions: actions,
            wraps: () => _showsSource,
            onReveal: _reveal,
            onClose: widget.onClose,
          ),
          LayoutBuilder(
            builder: (context, pane) => ValueListenableBuilder(
              valueListenable: widget.chat.previewTabs,
              builder: (context, open, _) => PathLine(
                folder: widget.chat.folder,
                path: widget.path,
                // The source button under Close.
                end: previewHeaderEnd(pane.maxWidth, open, page: page != null),
                trailing: _switches
                    ? SourceButton(source: _source, onChanged: _showSource)
                    : null,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: widget.chat.editsChanged,
            builder: (context, _) => switch (_edit) {
              final edit? => EditBars(
                edit: edit,
                onDiscard: () => widget.chat.dropEdit(widget.path),
              ),
              null => const SizedBox.shrink(),
            },
          ),
          Expanded(
            // A click in a source takes the focus to the pane, for ⌥Z;
            // a page's web view and the editor keep their own.
            child: Listener(
              onPointerDown: (_) {
                if (_showsSource && _edit == null && !_focus.hasFocus) {
                  _focus.requestFocus();
                }
              },
              child: ColoredBox(
                color: t.base,
                // An edit coming or going swaps the source and the editor.
                child: ListenableBuilder(
                  listenable: widget.chat.editsChanged,
                  builder: (context, _) => PreviewBody(
                    watch: _watch,
                    source: _source,
                    onReveal: _reveal,
                    editor: _editor,
                    readOnly: _readOnly,
                    page: switch ((page, diagram)) {
                      (final page?, _) => (watch) => WebPage(
                        host: page,
                        watch: watch,
                        roots: [
                          widget.chat.folder,
                          ?widget.chat.worktree?.path,
                        ],
                      ),
                      (_, final diagram?) => (watch) => DiagramView(
                        host: diagram,
                        watch: watch,
                      ),
                      _ => null,
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
