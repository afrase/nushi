import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/file_text.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/native.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/source_editor.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/web_page.dart';
import 'package:nushi/web_views.dart';

/// A file the agent wrote, beside the chat where a subagent's pane opens:
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

/// Below this width the pane's header has no room for every button (a page
/// has three and Close, beside Live and the switch): they fold into a ⋯.
const double _foldsBelow = 380;

/// From this wide the pane's header has the gutters and leaves the name about
/// what it had: a page's has two more buttons.
const double _roomyFrom = 460;
const double _roomyWithPageFrom = 520;

/// From this wide it has 24 between groups too. Below, at the pane's 560 to
/// start with, that room is three short names' tabs (ADR 0072).
const double _gapsFrom = 640;

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
          LayoutBuilder(
            builder: (context, pane) {
              // The gutters where the row has room for them, and the bar's
              // full gaps where it has more (ADR 0072). Narrower, what it has
              // always had, so it keeps the name's room and folds where it did.
              final roomy =
                  pane.maxWidth >=
                  (page == null ? _roomyFrom : _roomyWithPageFrom);
              final wide = pane.maxWidth >= _gapsFrom;
              // What a group adds to the row's 8. The tabs' end needs none
              // short of wide: a last tab keeps a ✕'s room.
              final group = wide
                  ? NushiTheme.groupGap - 8
                  : roomy
                  ? NushiTheme.barGap - 8
                  : 0.0;
              return ValueListenableBuilder(
                valueListenable: widget.chat.previewTabs,
                // Beside a browser tab its row's ends are the browser's, so
                // going from one tab to the other moves no chip (ADR 0094).
                builder: (context, open, row) {
                  final chips = open.length > 1 && previewChips(open);
                  return PaneHeader(
                    inset: chips
                        ? previewChipInset
                        : roomy
                        ? NushiTheme.gutter
                        : 12,
                    end: _end(pane.maxWidth, open),
                    child: row!,
                  );
                },
                child: LayoutBuilder(
                  builder: (context, box) => ListenableBuilder(
                    listenable: Listenable.merge([
                      _watch,
                      widget.chat.previewTabs,
                      wrapLines,
                    ]),
                    builder: (context, _) {
                      final open = widget.chat.previewTabs.value;
                      final tabs = open.length > 1;
                      // A tab's file on its way keeps Live's room: a pick
                      // would otherwise widen the tabs' row for a moment,
                      // and move it.
                      final coming =
                          tabs && _watch.file == null && _watch.error.isEmpty;
                      final folds = box.maxWidth < _foldsBelow;
                      final wraps = _showsSource;
                      return Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: wide ? group : 0),
                              child: Row(
                                spacing: roomy ? 6 : 8,
                                children: [
                                  // A chip has its own icon.
                                  if (!tabs || !previewChips(open))
                                    Icon(
                                      kind.icon,
                                      size: 14,
                                      color: t.textSecondary,
                                    ),
                                  // The name shows the file in the Files
                                  // pane; several open, their tabs take its
                                  // place.
                                  Expanded(
                                    child: tabs
                                        ? _tabs(open)
                                        : Align(
                                            alignment: Alignment.centerLeft,
                                            child: _Name(
                                              daemon: widget.daemon,
                                              chat: widget.chat,
                                              path: widget.path,
                                              tooltip:
                                                  _watch.file?.path ??
                                                  widget.path,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_watch.live || coming)
                            Visibility.maintain(
                              visible: _watch.live,
                              child: LiveMark(version: _watch.file),
                            ),
                          if (wraps && !folds) const WrapButton(),
                          Padding(
                            padding: EdgeInsets.only(left: group),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: wide ? NushiTheme.iconGap : 0,
                              children: [
                                if (folds)
                                  MenuIcon.line(
                                    LineIcon.more,
                                    tooltip: 'More',
                                    filter: false,
                                    entries: [
                                      if (wraps)
                                        MenuEntry(
                                          wrapLabel(wrap: wrapLines.value),
                                          icon: Icons.wrap_text,
                                          onPick: toggleWrap,
                                        ),
                                      for (final (icon, tooltip, _, onTap)
                                          in actions)
                                        MenuEntry(
                                          tooltip,
                                          icon: icon,
                                          onPick: onTap,
                                        ),
                                      MenuEntry(
                                        conventions.reveal,
                                        line: LineIcon.folderOpen,
                                        onPick: _reveal,
                                      ),
                                    ],
                                  )
                                else ...[
                                  for (final (icon, tooltip, size, onTap)
                                      in actions)
                                    IconTap(
                                      icon,
                                      tooltip: tooltip,
                                      size: size,
                                      onTap: onTap,
                                    ),
                                  IconTap.line(
                                    LineIcon.folderOpen,
                                    tooltip: conventions.reveal,
                                    size: 14,
                                    onTap: _reveal,
                                  ),
                                ],
                                IconTap.line(
                                  LineIcon.close,
                                  tooltip: 'Close',
                                  size: 15,
                                  onTap: widget.onClose,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
          LayoutBuilder(
            builder: (context, pane) => ValueListenableBuilder(
              valueListenable: widget.chat.previewTabs,
              builder: (context, open, _) => PathLine(
                folder: widget.chat.folder,
                path: widget.path,
                // The source button under Close.
                end: _end(pane.maxWidth, open),
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

  /// The room right of the header's last button (Close) in a pane [width]
  /// wide with [open]'s tabs: the path line's ends there too.
  double _end(double width, List<PreviewEntry> open) {
    if (open.length > 1 && previewChips(open)) return previewChipInset;
    final roomy = width >= (_page == null ? _roomyFrom : _roomyWithPageFrom);
    return roomy ? NushiTheme.gutter : 4;
  }

  /// The tabs of [open], this file's showing; as chips, the + after them,
  /// as a browser tab's title row has it, so the row keeps its shape as
  /// you move between the two.
  Widget _tabs(List<PreviewEntry> open) {
    final tabs = PreviewTabs(
      key: widget.tabsKey,
      chat: widget.chat,
      tabs: open,
      current: PreviewFile(widget.path),
    );
    if (!previewChips(open)) return tabs;
    return Row(
      spacing: 2,
      children: [
        Flexible(child: tabs),
        NewBrowserTab(chat: widget.chat),
      ],
    );
  }
}

/// The one file's name, plain, its absolute path ([tooltip]) in a tooltip:
/// a click shows it in the Files pane ([showInFiles]) when the file is in
/// the chat's folder, and does nothing otherwise. Its text sits where a
/// tab's would ([PreviewTabs]), so a second file opening moves nothing.
class _Name extends StatelessWidget {
  const new({
    required this.daemon,
    required this.chat,
    required this.path,
    required this.tooltip,
  });

  final Daemon daemon;
  final ChatState chat;
  final String path;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final inside = inFiles(daemon, chat, path);
    return Pressable(
      onTap: inside == null ? null : () => showInFiles(chat, inside),
      tooltip: plainPath(tooltip),
      // Tinted under the pointer and ringed with the keys on it, as a
      // control is; the text stays where a tab's is.
      builder: (context, look) => Container(
        padding: const EdgeInsets.fromLTRB(previewNameInset, 3, 3, 3),
        decoration: look.hover
            ? BoxDecoration(
                color: look.pressed ? t.pressed : t.hover,
                borderRadius: BorderRadius.circular(NushiTheme.control),
              )
            : null,
        foregroundDecoration: focusRing(t, look),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 7,
          children: [
            Flexible(
              child: Text(
                plainPath(baseName(path)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.code(t.text, size: 12),
              ),
            ),
            // Its unsaved edits' dot (ADR 0096).
            EditedMark(
              chat: chat,
              path: path,
              close: const SizedBox.shrink(),
              shown: false,
              hover: false,
            ),
          ],
        ),
      ),
    );
  }
}
