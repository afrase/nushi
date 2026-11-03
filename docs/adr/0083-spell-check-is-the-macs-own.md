# 0083. The composer's spell check is the Mac's own, asked from the app

## Context
Flutter has no spell service on macOS, so a prompt with a typo went out as typed. The owner tried a mock and chose dotted underlines, a small menu over the word, and `⌘;`. Something has to judge the words, and a prompt is half prose, half paths and code.

## Decision
- **`NSSpellChecker`, in the app, over a method channel** (`nushi/spelling`, `macos/Runner/Spelling.swift`, `lib/speller.dart`). It already has the user's languages and dictionary, costs no dependency, and nothing leaves the Mac. The daemon isn't involved: spell check is about the window, and a phone's browser has its own. So its switch is an app preference, not a daemon setting.
- **Only words go over, never the prompt.** `scanWords` keeps prose words and skips code, paths, URLs, flags, mentions, identifiers and likely names; each distinct word is asked once, and the answers are kept by word, so a late one can't land on the wrong characters.
- **A controller draws the marks** (`ComposerText.buildTextSpan`), not `TextField.spellCheckConfiguration`. Flutter rechecks there only when the text changes, and hands the result straight to the field; whether a word is flagged depends on the caret too, and that moves without the text changing.
- **`requestChecking` works off the main thread**; a menu's guesses, asked one word at a time on a click, are the only synchronous call.

## Consequences
- A failing or missing channel means no underlines and nothing else; `Speller` calls are never allowed to reach typing.
- Which words count as wrong is macOS's call, not ours: on the owner's Mac "dosen't", "havent" and "Teh" pass.
- Add to dictionary writes the macOS user dictionary, for every app; Ignore lasts until Nushi quits, across chats (one document tag).
- A subagent's box, a reply box and a review comment have no spell check.

## Alternatives considered
- **A word list in the app**: the mock's; a large asset, one language, and a dictionary of its own beside the Mac's.
- **The daemon**: no gain, a call per pause, and prompts on a socket for nothing.
- **Sending the whole prompt** to `requestChecking`: simpler, but code and paths then go to the checker and come back as hits to throw away.
