import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tree_rows.dart';

/// The Mac's Files pane on the phone: the same tree of the chat's folder
/// ([FolderTree], the same rows a size up), a tap opening a folder or a
/// file's full-screen preview; the filter over it, and the eye in its bar
/// for what git ignores. No keys: the phone has none to move with.
class FilesScreen extends StatefulWidget {
  const new(this.daemon, this.chat, {super.key});

  final Daemon daemon;
  final ChatState chat;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late final FolderTree _tree = folderTreeOf(widget.chat);
  final _query = TextEditingController();
  final _git = GitFiles();
  final _filter = FilterMemo();

  @override
  void initState() {
    super.initState();
    _tree.attach(widget.daemon);
    _query.addListener(() {
      if (_query.text.trim().isNotEmpty) {
        _git.ask(widget.daemon, widget.chat.folder);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tree.detach();
    _query.dispose();
    _git.dispose();
    super.dispose();
  }

  void _tap(TreeRow r, {required bool filtering}) {
    _tree.select(r.path);
    if (r.kind == TreeRowKind.folder && !filtering) {
      _tree.toggle(r.path);
    } else if (r.opens) {
      PreviewScreen.open(context, widget.daemon, widget.chat, r.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ValueListenableBuilder(
      valueListenable: filesIgnored,
      builder: (context, ignored, _) => PhoneScreen(
        title: 'Files',
        actions: [
          PhoneIcon(
            ignored ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            label: ignored ? 'Hide what git ignores' : 'Show what git ignores',
            onTap: () => filesIgnored.value = !ignored,
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _query,
                style: phoneText(context),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Filter files',
                  prefixIcon: Icon(Icons.search, size: 18, color: t.textMuted),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([_tree, _git, widget.chat]),
                builder: (context, _) => _list(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final q = _query.text.trim();
    final filtering = q.isNotEmpty;
    final rows = filtering ? _filter.of(_tree, _git, q).rows : _tree.rows();
    final marks = writtenMarks(widget.chat);
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No file matches',
          style: phoneText(context, color: NushiTheme.of(context).t.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        return SizedBox(
          height: r.entry ? null : touch,
          child: TreeRowView(
            r,
            large: true,
            selected: false,
            showing: false,
            wrote: r.kind == TreeRowKind.folder
                ? marks.folders.contains(r.path)
                : marks.files.contains(r.path),
            onTap: r.entry ? () => _tap(r, filtering: filtering) : null,
          ),
        );
      },
    );
  }
}
