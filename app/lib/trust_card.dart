import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What a folder would have the agent run on its own, before a chat starts
/// or moves there: each file and what it runs, exactly, with "Start
/// anyway" and Cancel. A warning, not a rule (ADR 0023).
class TrustCard extends StatelessWidget {
  const new(this.ask, {super.key});

  final TrustAsk ask;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final byFile = <String, List<FolderRun>>{};
    for (final r in ask.runs) {
      (byFile[r.file] ??= []).add(r);
    }
    String shown(String file) => file.startsWith('${ask.folder}/')
        ? file.substring(ask.folder.length + 1)
        : tildePath(file);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: box(t.needs, fill: t.needsSoft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: t.needs),
                    Flexible(
                      child: Text(
                        '${folderParts(ask.folder).$1} brings its own code '
                        'to run',
                        style: theme.ui(t.text, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${knownAgents[ask.agent]?.title ?? 'The agent'} runs these '
                  'without asking as soon as a chat starts '
                  'in ${tildePath(ask.folder)}, and it hasn’t been told to '
                  'trust the folder. Look before you start.',
                  style: theme.ui(t.textSecondary, size: 12),
                ),
                for (final MapEntry(key: file, value: runs) in byFile.entries)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        shown(file),
                        style: theme.code(t.textMuted, size: 11.5),
                      ),
                      for (final r in runs)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: r.command.contains('\n')
                              ? _Block(r)
                              : SelectableText.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${r.what}  ',
                                        style: theme.ui(t.text, size: 12.5),
                                      ),
                                      TextSpan(
                                        text: r.command,
                                        style: theme.code(t.text, size: 12),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                    ],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    Button(
                      label: 'Cancel',
                      kind: ButtonKind.ghost,
                      onPressed: () => ask.decide(start: false),
                    ),
                    Button(
                      label: 'Start anyway',
                      kind: ButtonKind.primary,
                      onPressed: () => ask.decide(start: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A run whose text has many lines (a file shown whole), in a box of its
/// own that scrolls.
class _Block extends StatelessWidget {
  const new(this.run);

  final FolderRun run;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(run.what, style: theme.ui(t.text, size: 12.5)),
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          width: double.infinity,
          decoration: box(t.borderSubtle, fill: t.base),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SelectableText(
              run.command,
              style: theme.code(t.text, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// What [folder] would have the agent run, shown before a chat starts or
/// moves there; [answer] is true for "Start anyway".
class TrustAsk {
  new(this.folder, this.action, this.runs, this.agent);

  final String folder;
  final String action;
  final List<FolderRun> runs;
  final String agent; // the agent that runs them (Agent.name)
  final answer = Completer<bool>();

  void decide({required bool start}) {
    if (!answer.isCompleted) answer.complete(start);
  }
}
