# 0107. Diffs side by side or unified

Status: accepted, 2026-11-09.

## Context
The owner asked for an inline diff view (2026-11-09): a new file showed side by side with an empty left pane, half the width wasted. Every diff in the app is a `DiffBox` over diff_view's `SideBySideDiff` (Changes, a tool call's and an edit's diffs, a pull request's Files). diff_view 0.2.0 adds `UnifiedDiff`, one column with both line numbers, each change's deleted lines above its inserted ones, driven by the same `DiffViewController` as the side-by-side view. A switch between them keeps the line in place and rebuilds nothing.

## Decision
- **One switch for every diff**, `diffUnified` in `app.json` (`unified`), off at first. It lives in Changes' bar beside the list's tree or list, as an icon of the view it goes to ("Show unified", "Show side by side"; left out where Changes is too narrow for two panes beside its list, as it would change nothing), in View › Show Diffs Unified and in the palette, wherever the window is (a pull request's Files in the GitHub view included). Tool calls, edits and a pull request's Files follow it too, so one choice reads the same everywhere.
- **One column whatever the switch says** when a side is empty (an added or a deleted file, a file emptied), when the diff is narrower than 560 points (two panes of under 280 each; the app's narrow width, as a pull request's header and Changes' bar have it), and on the phone. The switch keeps what you picked, for the next file that has two sides.
- **Everything on a diff works in both views**: review comments (a unified selection becomes lines of one side: one with a line on every row picked, the new one first, else the side of its last row, the new one but for a deleted line), Send to agent, a finding's line (selected in both views, so a switch keeps it), ⌘F (its hits go top to bottom as the unified view shows them), copy, and GitHub's line comments. The scrollbar follows the view shown.

## Consequences
- A comment begun over a change's deleted and inserted rows covers only the inserted lines: Nushi's comments are on one side.
- The tool-call cards and Changes at about 720 wide now show one column, where they showed two cramped panes.
- diff_view comes from a local path until 0.2.0 is published (`app/pubspec.yaml`).

## Alternatives considered
- A switch per view (Changes, Files, cards): three choices for one question of taste.
- A resizable left pane for added files: still a blank pane, and a drag to make it go.
- Unified only for added and deleted files, no switch: a modified file is often easier to read in one column too, and the library had the mode.
