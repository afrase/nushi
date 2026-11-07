# 0099. The phone fetches a chat's images on their own

Status: accepted, 2026-11-07.

## Context
The owner's phone sat on "Couldn't load it yet: trying again" for minutes. The chat's recent 80 items held four screenshots inline (2.5–3.4 MB each, about 12 MB): over a weak cell link and the relay (8 MB at once, then 1 MB/s) the snapshot outlived the phone's link checks (`app/lib/phone/link.dart`), the link dropped, and the load started over, four times in two minutes. Text loads in a fraction of that; images were the weight.

## Decision
- **References on request**: `GetChatRequest`, `GetChatItemsRequest` and `EventsRequest` take `image_refs`. With it, an image over 64 KB comes without its bytes: `ImageData.sha256` (hex of the bytes, as the transcript copy names its files), `size`, and `width`/`height` when the daemon reads them from the header (PNG, JPEG, GIF; else 0). Smaller ones stay inline: a call of their own would cost more. Without the flag nothing changes, so the Mac and older phones get what they did.
- **`GetChatImage{chat_id, sha256}`**: the bytes of one of that chat's own items' images whose hash matches, else NotFound; anything but 64 lowercase hex digits is refused before a lookup, so no path is ever made from it; at most 32 MB. Not macOnly: it's for the phone.
- **The phone asks for references** on all three; the Mac doesn't. An image arriving as a reference is fetched when its row is built (the transcript builds rows near the screen only), three at a time, kept in memory by hash (64 MB, least recently shown out first). While it comes it shows a box of its size with a spinner; a failure says so with Try again. Try again on a failed turn fetches the message's images before sending them back.
- An older daemon ignores the flag and sends images inline, which show as before; the phone calls `GetChatImage` only for an image that came as a reference, so it never asks a daemon that lacks it.

## Consequences
- A chat of screenshots opens on the phone as fast as one without; each image then takes its own few seconds, and a dropped link costs one image, not the load.
- Hashing: each reference hashes its image (milliseconds for a screenshot), and a `GetChatImage` hashes the chat's images until one matches; nothing is cached for it.
- The queue's and a rewound message's images still come inline (a message being written, small and rare).

## Alternatives considered
- A smaller `recent` on the phone: still 12 MB whenever four screenshots are near the end.
- Longer link timeouts: the load still starts over on every drop, and the phone waits on bytes it may never scroll to.
- Thumbnails made by the daemon: an image library and its CPU for each image, when the phone shows them at 240 points anyway and a whole image is needed for the preview.
