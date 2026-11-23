import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart' show findKey;
import 'package:nushi/change_marks.dart' show MarksAgainst;
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/line_base.dart';
import 'package:nushi/native.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_find.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_text.dart' show prettyJson;
import 'package:nushi/settings.dart' show indentGuides, scrollPastEnd, tabSize;
import 'package:nushi/source_editor.dart';
import 'package:nushi/source_menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_find.dart';
import 'package:nushi/web_page.dart';
import 'package:nushi/web_views.dart';

/// The file the Files pane's viewer shows (ADR 0123), and what lives as
/// long as it shows: its watch, its web view or diagram, its edit's coming
/// (ADR 0096), whether its Source shows. Made as its tab shows and let go
/// as another does; the pane's top row (Live), its bar (the path, the
/// source button, the actions) and the viewer ([FileView]) all read it.
final class ShownFile {
  new(this.chat, this.daemon, this.path)
    : watch = FileWatch(daemon, chat.id, path),
      kind = previewKind(path) ?? PreviewKind.code {
    final kind = this.kind;
    page = kind.page && kind != PreviewKind.mermaid ? native.web.page() : null;
    diagram = kind == PreviewKind.mermaid ? native.web.diagram() : null;
    source.value = chat.files.sources.contains(path);
    watch.addListener(_fileCame);
    lines = LineBase(daemon, chat, watch);
  }

  final ChatState chat;
  final Daemon daemon;
  final String path; // as its tab names it
  final FileWatch watch;
  final PreviewKind kind;

  /// Its text before the chat's work, its source's change marks drawn
  /// against, and what its path row says of them (ADR 0131).
  late final LineBase lines;

  (String, bool)? _pretty; // whether a version, by its sha, is reformatted

  /// The web view of a page, or the diagram's, by its kind.
  late final PageHost? page;
  late final DiagramHost? diagram;

  /// Whether a file that renders shows its Source; kept per file, while
  /// its tab is open (`FileTabs.sources`).
  final source = ValueNotifier<bool>(false);

  /// Whether its watch has sent a message yet.
  bool _heard = false;

  /// The file's edits, while it's being edited (ADR 0096).
  FileEdit? get edit => chat.edits[path];

  /// A file that came is edited when it can be (text the editor gives
  /// back byte for byte; not an image or a PDF); an edit hears of each
  /// version, and goes once it has nothing unsaved and the file went or
  /// can't be edited now.
  void _fileCame() {
    final f = watch.file;
    if (f == null) return;
    final first = !_heard;
    _heard = true;
    if (edit case final edit?) {
      edit.receive(f, first: first);
      if (!edit.unsaved && (f.missing || edit.readOnly != null)) {
        chat.dropEdit(path);
      }
      return;
    }
    if (kind == PreviewKind.image || kind == PreviewKind.pdf) return;
    if (f.missing || notEditable(f) != null) return;
    final (file, _) = decodeFile(f.data);
    chat.edit(path, () => FileEdit(daemon, chat.id, path, file!, f.sha256));
  }

  /// Why the file shows read-only, when it can't be edited (an edit's
  /// own reason shows in its bars).
  String? readOnly() {
    final f = watch.file;
    if (f == null || f.missing || edit != null || watch.notText) return null;
    return notEditable(f);
  }

  /// Its absolute path, as the daemon found it once it has.
  String get abs => watch.file?.path ?? absoluteIn(chat.folder, path);

  /// Shows it in Finder (Folder on Linux).
  void reveal() => native.desktop.reveal(abs).ignore();

  /// What its source's right-click menu does (issue 75): a quote goes to
  /// the chat's box as a reply card, the chat's transcript showing.
  late final menu = SourceActions(
    folder: chat.folder,
    path: path,
    onQuote: (r) {
      chat.draft.addReply(r);
      chat.tab.value = ChatTab.chat;
    },
    onReveal: reveal,
    onOpen: () => native.desktop.openAsText(abs).ignore(),
  );

  /// Whether it has the source button: a file that renders, but a diagram
  /// only with something to draw it (Linux has none, ADR 0104).
  bool get switches =>
      kind.rendered && (kind != PreviewKind.mermaid || diagram != null);

  /// Whether it shows the file's text, a source view: code, a diagram with
  /// nothing to draw it, or the Source of one that renders. Only then do
  /// its lines wrap or not.
  bool get showsSource =>
      kind == PreviewKind.code && !watch.notText ||
      kind.rendered && (source.value || !switches);

  /// Whether its source shows other than as saved, so has no change
  /// marks: JSON shown read-only is pretty-printed (`SourceView`).
  bool get reformatted {
    final f = watch.file;
    if (edit != null ||
        f == null ||
        f.missing ||
        !showsSource ||
        !path.toLowerCase().endsWith('.json')) {
      return false;
    }
    if (_pretty case (final sha, final pretty) when sha == f.sha256) {
      return pretty;
    }
    final text = utf8.decode(f.data, allowMalformed: true);
    final pretty = prettyJson(text).trimRight() != text.trimRight();
    _pretty = (f.sha256, pretty);
    return pretty;
  }

  /// Shows its Source, or its rendering again.
  void showSource({required bool on}) {
    source.value = on;
    chat.files.showSource(path, on: on);
  }

  /// A page's actions: Reload (in the app's own web view, ADR 0104) and
  /// Open in browser; each its icon, tooltip, icon size and what it does.
  List<(IconData, String, double, VoidCallback)> actions(BuildContext context) {
    final page = this.page;
    if (page == null) return const [];
    return [
      if (webEmbedded)
        (Icons.refresh, 'Reload', 15, () => page.reload().ignore()),
      (
        Icons.open_in_new,
        'Open in browser',
        14,
        () => openInBrowserOrSay(context, Uri.file(abs)).ignore(),
      ),
    ];
  }

  void dispose() {
    lines.dispose();
    watch
      ..removeListener(_fileCame)
      ..dispose();
    source.dispose();
    page?.dispose();
    diagram?.dispose();
  }
}

/// The Files pane's viewer of one file ([ShownFile]): its edit's bars
/// over the file, rendered or as source, or its editor (ADR 0096). ⌥Z
/// wraps a source's lines with the focus in it. It's one file's view, made
/// again as its tab shows; the pane's rows over it are the pane's.
class FileView extends StatefulWidget {
  const new({required this.shown, super.key});

  final ShownFile shown;

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  final _focus = FocusNode(debugLabel: 'file view');

  ShownFile get _shown => widget.shown;

  @override
  void dispose() {
    _focus.dispose();
    _pageFind?.dispose();
    super.dispose();
  }

  /// The editor in the source's place, while the file is being edited.
  Widget? _editor({required bool wrap}) => switch (_shown.edit) {
    final edit? => SourceEditor(
      key: ObjectKey(edit),
      edit: edit,
      wrap: wrap,
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      base: _shown.lines,
      menu: _shown.menu,
    ),
    null => null,
  };

  /// ⌘F with the focus in the view: the preview's own find ([FindSlot]);
  /// the editor's, deeper, takes it first while it has the focus. An HTML
  /// page finds with its web view's own text, where the web view can
  /// ([PageHost.finder]; ADR 0143).
  late final _slot = FindSlot()
    ..choose = () =>
        _shown.page != null && !_shown.showsSource ? _pageFind : null;
  late final WebFind? _pageFind = switch (_shown.page?.finder) {
    final finder? when _shown.kind == PreviewKind.html => WebFind(finder),
    _ => null,
  };

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (findKey.accepts(e, HardwareKeyboard.instance)) {
      final f = _slot.current;
      if (f == null) return KeyEventResult.ignored;
      f.open();
      return KeyEventResult.handled;
    }
    if (!_shown.showsSource) return KeyEventResult.ignored;
    // In the editor the default ⌥Z types its character; a chosen key
    // types none (the Mac refuses a chosen ⌥ key), so it wraps there too
    // (ADR 0146).
    if (_shown.edit != null && !_focus.hasPrimaryFocus && !wrapKey.chosen) {
      return KeyEventResult.ignored;
    }
    if (!wrapKey.accepts(e, HardwareKeyboard.instance)) {
      return KeyEventResult.ignored;
    }
    toggleWrap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final shown = _shown;
    final chat = shown.chat;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: chat.editsChanged,
            builder: (context, _) => switch (shown.edit) {
              final edit? => EditBars(
                edit: edit,
                onDiscard: () => chat.dropEdit(shown.path),
              ),
              null => const SizedBox.shrink(),
            },
          ),
          Expanded(
            // A click in a source takes the focus to the view, for ⌥Z,
            // and in any file Flutter draws, for ⌘F; a page's web view and
            // the editor keep their own.
            child: Listener(
              onPointerDown: (_) {
                final page = shown.page != null && !shown.showsSource;
                final editing = shown.edit != null && shown.showsSource;
                if (!page && !editing && !_focus.hasFocus) {
                  _focus.requestFocus();
                }
              },
              child: ColoredBox(
                color: t.base,
                // An edit coming or going swaps the source and the editor.
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    chat.editsChanged,
                    shown.source,
                    tabSize,
                    indentGuides,
                    scrollPastEnd,
                    shown.lines,
                  ]),
                  builder: (context, _) => MarksAgainst.of(
                    shown.lines,
                    child: FindSlotScope(
                      slot: _slot,
                      child: PreviewBody(
                        watch: shown.watch,
                        source: shown.source.value,
                        tabSize: tabSize.value,
                        guides: indentGuides.value,
                        pastEnd: scrollPastEnd.value,
                        base: shown.lines.value,
                        onReveal: shown.reveal,
                        menu: shown.menu,
                        editor: _editor,
                        readOnly: shown.readOnly,
                        page: switch ((shown.page, shown.diagram)) {
                          (final page?, _) => (watch) {
                            final view = WebPage(
                              host: page,
                              watch: watch,
                              roots: [chat.folder, ?chat.worktree?.path],
                            );
                            final find = _pageFind;
                            return find == null
                                ? view
                                : PageFindFrame(find: find, child: view);
                          },
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
            ),
          ),
        ],
      ),
    );
  }
}
