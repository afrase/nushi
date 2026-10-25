import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';

/// An issue whole (next step).
class JiraIssuePane extends StatelessWidget {
  const new({
    required this.daemon,
    required this.site,
    required this.issueKey,
    required this.onOpen,
    super.key,
  });

  final Daemon daemon;
  final String site;
  final String issueKey;

  /// Shows another issue (a subtask, a link) in its place.
  final void Function(String key) onOpen;

  @override
  Widget build(BuildContext context) => Center(child: Text(issueKey));
}
