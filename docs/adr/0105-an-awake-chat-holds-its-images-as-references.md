# 0105. An awake chat holds its images as references

Status: accepted, 2026-11-09.

## Context
An asleep chat holds nothing of its transcript ([ADR 0103](0103-an-asleep-chat-lets-go-of-its-transcript.md)), but an awake one held every image in it, though its copy ([ADR 0047](0047-nushis-copy-of-transcripts.md)) has each as a file named by its hash. On a synthetic chat of 5,600 items (about 20 MB of text) with 200 screenshots of 270 KB, most of what the chat held was image bytes. Since the Mac and the phone both take images as references ([ADR 0099](0099-the-phone-fetches-a-chats-images-on-their-own.md)), nothing they show needs those bytes in memory: only a fetch, a client that takes images inline, and what goes to an agent or another chat's folder.

## Decision
- **Held by reference once the copy has it**: an image over 64 KB (`model.SmallImage`, the API's reference threshold) is held as its hash, length and pixel size (`model.Image.Size`, `Width`, `Height`; `Ref()`), without its bytes, once a write of its item to the copy succeeded (`copyLocked`, a reopen's `saveCopyLocked`). One the copy hasn't yet (just arrived, the copy not written, copies off, a write that failed, a side chat, which has no copy) keeps its bytes. A smaller one always keeps them.
- **Taken as it comes in**: the length and pixels are read once, beside the hash, from the header (`internal/imagesize`: PNG, JPEG, GIF); the copy's record keeps them (`size`, `w`, `h`). Reading a copy gives its large images as references, its small ones with their bytes; an older record's image takes its length from its file and its pixels from its header.
- **Read back only where the bytes go** (`withBytes`, from the copy's file by hash, its length checked): `GetChatImage`; a snapshot, page or event for a client that didn't ask for references (`Service.Inline`, in the API); a rewound or taken-back message (`messageOf`), so the agent gets them when it's sent again; a fork's items and a kept side chat's base, before they're written to the new chat's folder; and every held image before Clear deletes an open chat's copy. A queued message's images aren't in the transcript and keep their bytes.
- **Failing visibly**: a file gone or cut short is an error, never other bytes: `GetChatImage` refuses (logged), a rewind, take-back or fork fails, a client that takes images inline gets the image as a reference without bytes (logged), and writing a held image to a copy that lacks its file fails the write rather than leaving an empty file.
- **No proto change**: `ImageData` already carries a reference (ADR 0099).

## Consequences
- Measured on that chat (`TestAwakeChatHeap`, `NUSHI_MEASURE_HEAP=1`): awake after its copy was written, 79.0 MB of live heap became 25.9 MB; woken from its copy, 79.0 MB became 25.8 MB, as reading back no longer reads its images.
- A page of an asleep chat no longer reads its images' files; a fetch reads one file, and the inline paths read each image they send (as before).
- A held image's file must outlive it: rewriting a copy keeps the files its records name, and a rewind's message reads its images before the cut.

## Alternatives considered
- Reading images back for every snapshot and page: the Mac's pages would read every image they hold again, though it takes references.
- Holding references only for asleep chats: ADR 0103 does, and an awake chat of screenshots still held them all.
