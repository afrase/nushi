import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/preview.dart';

/// The first daemon that says which files are there (FindChatFiles).
const findFilesApi = 82;

/// A path as an agent writes one in plain text (`lib/a.dart`,
/// `./notes.md`, `/tmp/x.html`, `README.md`, with `:12` or `:12:3` after
/// it): an extension that starts with a letter (not `1.2.3`), and nothing
/// of a word, path or URL around it.
final _pathPattern = RegExp(
  r'(?<![\w/.~:@-])(?:\.{1,2}/|/)?(?:[\w.@+-]+/)*[\w@+-][\w.@+-]*\.[A-Za-z][A-Za-z0-9]{0,9}(?::\d+(?::\d+)?)?(?![\w/])',
);

/// An inline code span's text, outside fenced blocks.
final _codeSpan = RegExp('`([^`\n]+)`');
final _fence = RegExp(
  r'^ {0,3}(```|~~~)[\s\S]*?(?:^ {0,3}\1[^\n]*$|(?![\s\S]))',
  multiLine: true,
);

/// The paths [markdown] names that a preview could show, each as written
/// (an inline code span's text, or a word of plain text) to the path
/// without its line: what to look for on disk, before making links of
/// them. At most [max].
Map<String, String> namedFiles(String markdown, {int max = 100}) {
  final text = markdown.replaceAll(_fence, '');
  final out = <String, String>{};
  void add(String written) {
    final w = written.trim();
    if (out.length >= max || w.isEmpty || w.contains(' ')) return;
    final path = w.replaceFirst(RegExp(r':\d+(?::\d+)?$'), '');
    if (previewKind(path) != null) out[w] = path;
  }

  for (final m in _codeSpan.allMatches(text)) {
    add(m[1]!);
  }
  for (final m in _pathPattern.allMatches(text.replaceAll(_codeSpan, ' '))) {
    add(m[0]!);
  }
  return out;
}

/// Which files a chat's messages name are there, as the daemon says
/// (FindChatFiles): asked once per message for what isn't known yet, and
/// kept while the app runs; one found missing is asked again after a
/// minute (the agent may write it later).
class FileLinks extends ChangeNotifier {
  final _there = <String, bool>{};
  final _missingAt = <String, DateTime>{};
  final _asking = <String>{};

  /// Whether [path] is there: null while not known.
  bool? there(String path) => _there[path];

  /// Asks the daemon about those of [paths] it doesn't know yet, in one
  /// call, and tells listeners once it has answered.
  Future<void> look(
    Daemon daemon,
    String chatId,
    Iterable<String> paths,
  ) async {
    final now = DateTime.now();
    final ask = {
      for (final p in paths)
        if (!_asking.contains(p) &&
            (_there[p] == null ||
                _there[p] == false &&
                    now.difference(_missingAt[p]!) >
                        const Duration(minutes: 1)))
          p,
    }.toList();
    if (ask.isEmpty) return;
    _asking.addAll(ask);
    try {
      final r = await daemon.client.findChatFiles(
        FindChatFilesRequest(chatId: chatId, paths: ask),
      );
      final found = r.found.toSet();
      var changed = false;
      for (final p in ask) {
        final was = _there[p];
        _there[p] = found.contains(p);
        if (!found.contains(p)) _missingAt[p] = DateTime.now();
        changed |= was != _there[p];
      }
      if (changed) notifyListeners();
    } on Object {
      // Not now (the daemon away): asked again on the next build.
    } finally {
      _asking.removeAll(ask);
    }
  }
}

/// An agent's message whose paths of files the chat's preview shows are
/// links to it ([namedFiles], [FileLinks]): on the Mac underlined on
/// hover, on the phone its full-screen preview. Only once it has finished
/// streaming, and only paths that are there: in the chat's folder or
/// worktree, or files it wrote.
class LinkedMarkdown extends StatefulWidget {
  const new(this.text, this.chat, this.daemon, {required this.live, super.key});

  final String text;
  final ChatState chat;
  final Daemon daemon;
  final bool live;

  @override
  State<LinkedMarkdown> createState() => _LinkedMarkdownState();
}

class _LinkedMarkdownState extends State<LinkedMarkdown> {
  Map<String, String> _named = const {};

  @override
  void initState() {
    super.initState();
    _look();
  }

  @override
  void didUpdateWidget(LinkedMarkdown old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.live != widget.live) _look();
  }

  void _look() {
    final w = widget;
    _named = w.live || w.daemon.daemonApi < findFilesApi
        ? const {}
        : namedFiles(w.text);
    if (_named.isNotEmpty) {
      unawaited(w.chat.fileLinks.look(w.daemon, w.chat.id, _named.values));
    }
  }

  @override
  Widget build(BuildContext context) => Paced(
    widget.text,
    live: widget.live,
    builder: (context, shown) => shown != null
        ? AgentMarkdown(widget.text, live: true, shown: shown)
        : _linked(context),
  );

  Widget _linked(BuildContext context) {
    final open = Previews.of(context)?.open;
    if (open == null || _named.isEmpty) {
      return AgentMarkdown(widget.text, live: widget.live);
    }
    final links = widget.chat.fileLinks;
    return ListenableBuilder(
      listenable: links,
      builder: (context, _) => AgentMarkdown(
        widget.text,
        files: {
          for (final MapEntry(:key, :value) in _named.entries)
            if (links.there(value) ?? false) key: value,
        },
        onTapFile: open,
      ),
    );
  }
}
