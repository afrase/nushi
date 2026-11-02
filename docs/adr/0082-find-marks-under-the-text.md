# 0082. A find's marks are read from the laid-out text and painted under it

## Context
⌘F in a chat marked whole entries, with a tint and a bar drawn over them, and went to an entry's top. The owner wanted the exact characters marked, in Markdown, code, tool rows and subagent rows. A message's text isn't ours to split: `flutter_markdown_plus` builds its paragraphs, each with a `UniqueKey`, so new spans mean parsing again and new paragraphs at every keystroke, losing what's selected. And an item's text is its Markdown source: `**` and a link's address are in it, and "foo bar" isn't in `foo **bar**`, so counting there can't agree with what shows.

## Decision
- **The laid-out text is the truth.** `TextMarks` (`packages/markdown`) walks an entry's `RenderParagraph`s for the query, case aside. What's counted is what's marked. Each entry is walked only after it's laid out again, so a streamed chunk costs one entry's walk, not the transcript's.
- **Painted under the text, spans untouched.** A `Marks` render object paints the boxes before its child. No text changes, so nothing is laid out again and selection, copy and Reply can't be affected. Text on an opaque fill needs a `Marks` inside that fill; a table's head became a tint for this.
- **Only selectable text is looked in**, without a message's actions on hover (`Unmarked`): a label isn't the text, and a count mustn't change as the pointer passes.
- **A find builds all of the transcript at once** (ADR 0026's filling in ends): matches need layout, and "1 of n" must not move as entries arrive.
- **Something closed marks its row and stays closed** (`FoldedMarks`), with how many matches it holds; each counts in the bar, and ⏎ stops on the row for each. Opening it shows them marked in place. A subagent's steps have no place in the transcript at all, and opening rows while stepping would move everything below them.
- **A jump is a jump.** A glide was cut short by the list moving as it filled in, and hides nothing worth seeing. `BottomFollower.hold` keeps the list there, even at the very bottom, until the user scrolls to the bottom or takes the chip.

## Consequences
- Marks show a frame after the text they're in; a paragraph built again in a frame loses its marks for that frame.
- A tool row's diffs aren't looked in, as before: they aren't paragraphs.
- Text cut by a "Show all" inside an open row isn't counted until shown. A title cut by an ellipsis counts on its row.
- A keystroke repaints every entry that has a mark or had one.

## Alternatives considered
- **Spans with a background**: see Context, and a query of a few characters would rebuild most of a long chat.
- **Searching items and painting where the text matches**: two truths, and the count and the marks disagree on anything Markdown changes.
- **An overlay on each entry**: paints over the glyphs; it's what cut off the first letter of each line.
- **Opening the row of the current match**: lands on the characters, but the list moves under each ⏎ and needs an open state that isn't the user's.
