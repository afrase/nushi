import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Attachments fetched through the daemon (Jira's own, from the site
/// added), by site and id: the last [_keep]. One that failed isn't kept:
/// shown again, it's asked for again (after Allow…, or the daemon back).
final _fetched = <String, Future<GetJiraAttachmentResponse>>{};
const _keep = 64;

Future<GetJiraAttachmentResponse> _fetch(
  NushiServiceClient client,
  String site,
  String id, {
  required bool thumbnail,
}) {
  final key = '$site $id $thumbnail';
  if (_fetched[key] case final kept?) return kept;
  final f = _fetched[key] = client.getJiraAttachment(
    GetJiraAttachmentRequest(site: site, id: id, thumbnail: thumbnail),
  );
  unawaited(_dropIfFailed(key, f));
  if (_fetched.length > _keep) {
    final old = _fetched.keys.take(_fetched.length - _keep).toSet();
    _fetched.removeWhere((k, _) => old.contains(k));
  }
  return f;
}

Future<void> _dropIfFailed(
  String key,
  Future<GetJiraAttachmentResponse> f,
) async {
  try {
    await f;
  } on Object {
    _fetched.removeWhere((k, v) => k == key && identical(v, f));
  }
}

/// What an image in an issue's text shows as: an attachment of the
/// issue's, fetched through the daemon (never a URL of the text's own: an
/// issue's author could make the app fetch anything, and tell who read
/// it). Anything else is its alt text.
Widget Function(Uri, String?) jiraImages(
  NushiServiceClient client,
  String site,
) => (uri, alt) {
  if (uri.scheme != 'jira-attachment' || int.tryParse(uri.path) == null) {
    return Text('[image: ${alt ?? ''}]');
  }
  return AttachmentImage(client, site, uri.path, size: 320);
};

/// An attachment's image, [size] tall at most; it shows large when
/// clicked.
class AttachmentImage extends StatelessWidget {
  const new(this.client, this.site, this.id, {required this.size, super.key});

  final NushiServiceClient client;
  final String site;
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _fetch(client, site, id, thumbnail: false),
    builder: (context, r) => switch (r) {
      AsyncSnapshot(:final data?) when data.mimeType.startsWith('image/') =>
        ClickableImage(
          image: MemoryImage(Uint8List.fromList(data.data)),
          size: size,
        ),
      AsyncSnapshot(hasError: true) => const Icon(Icons.broken_image, size: 16),
      AsyncSnapshot(:final data?) => Text('[${data.mimeType}]'),
      _ => SizedBox(height: size / 4, width: size / 4),
    },
  );
}

/// Asks for what a transition's screen needs; the values by field id, or
/// null when cancelled.
Future<Map<String, String>?> askFields(
  BuildContext context,
  JiraTransition t,
) => showDialog(context: context, builder: (_) => _FieldsForm(t));

class _FieldsForm extends StatefulWidget {
  const new(this.transition);

  final JiraTransition transition;

  @override
  State<_FieldsForm> createState() => _FieldsFormState();
}

class _FieldsFormState extends State<_FieldsForm> {
  final _values = <String, String>{};
  late final Map<String, TextEditingController> _text = {
    for (final f in widget.transition.fields)
      if (f.options.isEmpty) f.id: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _all => {
    ..._values,
    for (final MapEntry(:key, :value) in _text.entries)
      if (value.text.trim().isNotEmpty) key: value.text.trim(),
  };

  String? _picked(JiraField f) =>
      f.options.where((o) => o.id == _values[f.id]).firstOrNull?.name;

  bool get _complete => widget.transition.fields.every(
    (f) => !f.required || (_all[f.id] ?? '').isNotEmpty,
  );

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return nushiDialog(
      widget.transition.name,
      SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in widget.transition.fields) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(
                  '${f.name}${f.required ? ' *' : ''}',
                  style: theme.ui(t.textSecondary, size: 12),
                ),
              ),
              if (f.options.isNotEmpty)
                Row(
                  children: [
                    MenuField(
                      entries: [
                        for (final o in f.options)
                          MenuEntry(
                            o.name,
                            checked: _values[f.id] == o.id,
                            onPick: () => setState(() => _values[f.id] = o.id),
                          ),
                      ],
                      label: Text(_picked(f) ?? 'Pick'),
                    ),
                  ],
                )
              else
                TextField(
                  controller: _text[f.id],
                  minLines: 1,
                  maxLines: f.type == 'text' ? 6 : 1,
                  style: theme.ui(t.text),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: switch (f.type) {
                      'text' => 'Markdown',
                      'user' => 'an account id',
                      'array:string' => 'words, space between',
                      _ => '',
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
      [
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(
          label: widget.transition.name,
          kind: ButtonKind.primary,
          onPressed: _complete ? () => Navigator.pop(context, _all) : null,
        ),
      ],
    );
  }
}

/// The box a comment is written in, as Markdown; ⌘⏎ posts it.
class CommentBox extends StatefulWidget {
  const new({required this.onPost, super.key});

  /// Posts the comment; it throws when Jira refused it (the box keeps it).
  final Future<void> Function(String markdown) onPost;

  @override
  State<CommentBox> createState() => _CommentBoxState();
}

class _CommentBoxState extends State<CommentBox> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final md = _text.text.trim();
    if (md.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPost(md);
      _text.clear();
    } on Object catch (e) {
      if (mounted) setState(() => _error = jiraError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          skipTraversal: true,
          // ⌘⏎ before the field reads it as a line break.
          onKeyEvent: (_, e) {
            if (e is KeyUpEvent ||
                e.logicalKey != LogicalKeyboardKey.enter ||
                !HardwareKeyboard.instance.isMetaPressed) {
              return KeyEventResult.ignored;
            }
            unawaited(_post());
            return KeyEventResult.handled;
          },
          child: TextField(
            controller: _text,
            enabled: !_busy,
            minLines: 2,
            maxLines: 10,
            style: theme.ui(t.text),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Add a comment (Markdown)',
            ),
          ),
        ),
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(e, style: theme.ui(t.crashed, size: 12)),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Button(
              label: _busy ? 'Posting…' : 'Comment',
              hint: '⌘⏎',
              kind: ButtonKind.primary,
              onPressed: _busy || _text.text.trim().isEmpty ? null : _post,
            ),
          ],
        ),
      ],
    );
  }
}
