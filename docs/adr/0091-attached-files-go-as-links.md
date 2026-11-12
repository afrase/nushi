# 0091. Attached files go to the agent as links

## Context
The owner asked for the composer's + to attach any file, not only images (2026-11-04). ACP gives a client two ways to hand an agent a file: a `resource_link` (a URI; every agent must take one) or an embedded `resource` with the text (only for an agent whose `promptCapabilities.embeddedContext` says so). Every agent Nushi runs turns a `file://` link into a mention its model reads with its own tools: Claude (both agents) and Codex as `[@name](uri)`, the Ante and Pi/PiG bridges as `@path`. omp (18.12.6) gives its model only the link's name, never its URI, so a link's name is the file's path: its path in the folder, or its absolute path outside it. The phone's files aren't on the Mac.

## Decision
- **A file goes as a `resource_link` to where it is**, never as a copy and never embedded: inside the chat's folder by its path there (as an @ mention), outside it by its absolute path (`SendPromptRequest.files`, API 106). The agent reads it when it needs it, as it is then, under its own permission rules: Claude asks before reading outside its folder, and that question is the harness's card (ADR 0007).
- **No embedded text, even for a small text file to an agent that takes it.** The agents replay a user message as they were sent it, so an embedded file would come back as the user's words, whole, on every reopen; and an agent that reads by path costs one tool call for it.
- **An image goes as an image** when the agent takes images, as before; to one that doesn't, it is a file like any other.
- **No sandbox stands between an agent and a linked file**: Nushi runs no agent under `sandbox-exec`, and Codex's read-only mode limits writes, not reads.
- **The phone's files come whole** (`SendPromptRequest.uploads`): the daemon saves each in its data folder's `uploads/<chat>/<random>/<name>` (the name's last part only, 0600) and links that copy. At most 8 MB a file and 10 files a message; a chat keeps 100 MB of them, the oldest removed first (never a queued message's, which the agent hasn't had), and deleting the chat removes them (a fork has its own hard links to those it links).
- The transcript's user message lists its files (`Item.files`); those its text doesn't mention as `@path` show as file chips.
- 2026-11-12 (the owner, on an iPhone: the + did nothing, and a paste attached nothing): **The phone's picker opens inside the tap, and its paste attaches.** Flutter's menu runs a row's action a frame after the tap, and Safari opens a file picker only from the tap itself, so the + menu's **Add files or photos** runs as the finger lifts (`MenuEntry.inTap`). The page's `paste` event hands its files (`clipboardData.files`: a copied photo, a file) to the box being typed in, as picked files; Nushi never asks the browser for the clipboard.

## Consequences
- An agent that can't read a path (an unreachable volume, a file moved since) says so in its turn; Nushi doesn't check that it can first.
- A phone's file lives in the data folder until the chat is deleted or crowded out, outside any repository: an agent that wants it in the project copies it.

## Alternatives considered
- Copying every file outside the folder into the uploads folder: the agent would read a stale copy, and Claude asks before reading there too.
- Embedding small text files by size: see above; the replay makes it worse than a link.
- The phone offering photos only: the daemon can take the bytes over the channel it has (32 MB a request).
