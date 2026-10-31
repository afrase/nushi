# 0071. One look for tabs

Status: accepted, 2026-10-31.

## Context
The owner dislikes the segmented pill (`Segmented`): a rounded box with a filled segment, used for every switch in the app. They approved the plain file tabs of the preview pane (ADR 0070) and asked for that look everywhere, so the app has one tab style. The pill's width is built into the chat header's fold (`headerFolds`), and a line under a label has to sit somewhere in a 34-point row.

## Decision
- **Views of the same thing are `PlainTabs`** (`app/lib/plain_tabs.dart`): the chat header's Chat, Changes and Pull request, Preview and Source, Changes' scopes, History's filters, a pull request's sections, a diagram's Diagram and Source. Text only: the one showing in the primary color with a 2-point line under it, the others muted, a step up under the pointer. No box and no tint. They're on `Pressable`, so a focused tab wears the ring and Enter and Space pick it.
- **One look, shared.** `TabFace` (the line) and `tabText` (the colors) draw both `PlainTabs` and the file tabs. The file tabs stay in code type, being file names; these stay in the UI type.
- **The same measure as the pill.** `PlainTabs` is exactly as wide and as high as `Segmented` for the same labels, with the labels where they were, so nothing moves and the fold's numbers stand. A test holds it to that.
- **In a bordered row the line lies on the border.** `fill` takes the row's height, so the line ends where the border starts, as the file tabs' does (the chat header, the pane's title row, Changes' bar, a code block's). Elsewhere it's under the label, in the pill's height.
- **A form's values stay `Segmented`**: a review's verdict and an MCP server's scope and transport. They aren't places to go: the pick is saved or sent, and as tabs Approve looks like a page of the dialog, and the muted options like text under a field's label.
- **The phone stays as it was.** Under `TouchTargets`, `SourceSwitch` draws the pill: the phone's Preview and Source, its only one, is unchanged until its web app takes this look.

## Consequences
- The pill remains in the app's three form fields, and on the phone.
- These tabs can take the keyboard's focus, which the pill's segments never could: one Tab stop each.
- With a rendered file open and several tabs, the pane's title row has two sets of tabs, each with its line.
- Tabs that aren't `Segmented` (the terminal's, a question card's) keep their own look.

## Alternatives considered
- Converting the form fields too: tried; see above. `MenuField`, ADR 0049's control for a value, would suit them if the pill has to go.
- The line under the label in a bordered row too, floating above the border: it would differ from the file tabs beside it.
- A narrower control with tighter padding: it would move what's beside it, and every fold number would need measuring again.
